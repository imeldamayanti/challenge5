-- 0017 — a retention horizon for ops.events, and something that actually runs it.
-- docs/backend-supabase.md §15.7 and §14 defect 18. schema.md §B.11. NFR-PRIV, FR-SURV, FR-ERR-10.
--
-- Forward-only (b0 D2). Additive: one extension, one function, one schedule. No table is altered.
--
-- Defect 18, in the design's own words: "`ops.events` has no server-side retention. The client
-- prunes at 30 days (schema.md §B.11); the server keeps forever. Correctly undeletable under
-- FR-SET-02 — which is exactly why it needs a retention horizon of its own."
--
-- The asymmetry is the point. `FR-SET-02` deletes a user's data on request, and telemetry is
-- deliberately outside that promise because `ops.events` has no `user_id` to match on (§2.4). Data
-- that cannot be deleted per-person must therefore be bounded per-age, or "we cannot identify it,
-- so we keep it forever" becomes the policy by default.

-- --------------------------------------------------------------------------------------------
-- 1. The horizon.
--
-- 180 days for events. The client already prunes its own queue at 30 days or 10 000 rows
-- (`schema.md` §B.11), so the server is the long tail: long enough to compare a release against
-- the one two releases ago, short enough that an anonymous behavioural record is not permanent.
--
-- **A STARTING VALUE, NOT A MEASUREMENT.** It is a parameter precisely so changing it is one call
-- rather than a migration, and the number should be revisited by whoever owns §13.1.
create or replace function ops.prune_events(retain interval default interval '180 days')
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  removed bigint;
begin
  -- `received_at`, not `occurred_at`: occurred_at is device wall-clock and a device with a wrong
  -- date could otherwise age its rows out on arrival — or never.
  delete from ops.events where received_at < now() - retain;
  get diagnostics removed = row_count;
  return removed;
end $$;

comment on function ops.prune_events(interval) is
  'Deletes ops.events older than the horizon (§15.7, §14 defect 18). service_role only. Does NOT touch ops.survey_responses — see the migration.';

-- Postgres grants EXECUTE to PUBLIC by default — advisor 0028, and the subject of migration 0013.
revoke all on function ops.prune_events(interval) from public, anon, authenticated;
grant execute on function ops.prune_events(interval) to service_role;

-- --------------------------------------------------------------------------------------------
-- 2. `ops.survey_responses` is DELIBERATELY NOT PRUNED.
--
-- It is not telemetry. It is the recall-survey corpus `FR-SURV` exists to analyse, and
-- `FR-ERR-10` already singles it out on the client as the one thing that is never dropped. A
-- retention job that quietly aged it out would delete the study while looking like hygiene.
--
-- That is a decision with a cost — the rows are unbounded — and it is recorded here rather than
-- left to be discovered when the table is large. When it needs a horizon it needs a research
-- decision first, not a `delete`.

-- --------------------------------------------------------------------------------------------
-- 3. Something that runs it.
--
-- A retention function nobody calls is the same gap `publish-suppressions` was written to close:
-- a policy that exists in the schema and never executes. pg_cron runs inside the database, so
-- there is no external scheduler to own, no secret to hold, and nothing to forget to deploy.
create extension if not exists pg_cron;

-- 03:17 UTC daily — off the hour, because every naive scheduler on the planet picks :00 and this
-- database shares a host. Idempotent: unschedule-then-schedule, so re-running the migration on a
-- database that already has the job does not create a second one.
do $$
begin
  perform cron.unschedule('ops-prune-events');
exception when others then
  null;   -- not scheduled yet, which is the normal case on a fresh database
end $$;

select cron.schedule('ops-prune-events', '17 3 * * *', $$select ops.prune_events()$$);
