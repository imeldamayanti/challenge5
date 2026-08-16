-- 0011 — conflict resolution, and the losing row nobody throws away.
-- docs/backend-supabase.md §9.4, §9.2, §14 defects 6, 7, 8, 9. FR-SYNC-02.
--
-- `revision` alone cannot express "the device that authored the content wins": two devices both
-- editing from revision 3 both write 4, and neither is "the author" in any sense the counter
-- records. The rule as implemented is: higher revision wins; equal revisions from different
-- devices break to the earlier `updated_at` (arbitrary, but stable and decided in advance, which
-- is the whole point); and the loser is written to app.sync_conflicts, never dropped.

create table app.sync_conflicts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  table_name       text not null,
  row_id           uuid not null,
  losing_row       jsonb not null,   -- the whole rejected row, so a human can read it back
  winning_revision bigint not null,
  losing_revision  bigint not null,
  recorded_at      timestamptz not null default now()
);

create index sync_conflicts_user on app.sync_conflicts (user_id, recorded_at desc);

alter table app.sync_conflicts enable row level security;
alter table app.sync_conflicts force  row level security;

create policy sync_conflicts_select on app.sync_conflicts
  for select using (user_id = (select auth.uid()));

-- No insert policy for any client role: only the trigger writes here. The policy below exists
-- solely so the `security definer` function, which runs as `postgres`, can write past
-- `force row level security`. PostgREST never connects as `postgres` — anon, authenticated and
-- service_role are the only roles a client can ever hold — so this is unreachable from outside.
create policy sync_conflicts_trigger_insert on app.sync_conflicts
  for insert to postgres with check (true);

grant select on app.sync_conflicts to authenticated;

-- --------------------------------------------------------------------------------------------
-- Why this is a trigger rather than a clause in the upsert.
--
-- §9.2's `on conflict … do update … where excluded.revision > t.revision` discards the loser with
-- no opportunity to record it, and a BEFORE UPDATE trigger cannot see an update that the WHERE
-- clause prevented from happening at all. So the resolution moves INTO the trigger and returns
-- NULL for a losing write: a BEFORE trigger returning NULL skips the row entirely, which means the
-- row is not written AND it does not come back in `returning` — which is exactly the contract
-- §14 defect 6 depends on. A client marks `synced` only for ids that come back.
--
-- SECURITY DEFINER, unavoidably: app.sync_conflicts has no insert policy for the caller's role,
-- and it must not. `set search_path = ''` with every name qualified is therefore mandatory
-- (§8.1 case 3) — a mutable search path here would let a caller shadow a name and run their own
-- code as the owner.
-- --------------------------------------------------------------------------------------------
create or replace function app.resolve_sync_conflict() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  loser jsonb;
begin
  -- A CASCADED update is not a push and must never be discarded. `task_results.photo_id` is
  -- `on delete set null` (§4.5): Postgres performs that as an internal UPDATE, which arrives here
  -- with the same revision and the same device_id and would be indistinguishable from an
  -- idempotent retry — so returning NULL for it silently cancels a referential action and leaves
  -- `photo_id` pointing at a row that no longer exists. `pg_trigger_depth() > 1` is what separates
  -- them: a client statement reaches this function at depth 1, a referential action at depth 2.
  -- (Found by test 3.14, which is the whole argument for writing it.)
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  -- The service role moves rows between users (§7.3's merge) and deletes them (FR-SET-02); neither
  -- is a device push and neither carries a revision bump. Nothing a client can hold reaches this
  -- branch: PostgREST gives a client `anon` or `authenticated`, never `service_role`.
  if current_user = 'service_role' or new.user_id is distinct from old.user_id then
    return new;
  end if;

  -- §9.2: `revision` arrives from the client, and one buggy build writing a near-int8-max value
  -- makes that row permanently unwritable by every device including the one that broke it.
  -- PostgREST maps SQLSTATE 'PT400' to HTTP 400 (§14 defect 9).
  if new.revision > old.revision + 1000 then
    raise exception 'revision jump of % rejected (stored %, limit +1000)',
      new.revision - old.revision, old.revision
      using errcode = 'PT400',
            hint = 'design §9.2 clamps client-supplied revisions';
  end if;

  if new.revision > old.revision then
    return new;                                   -- ordinary winning push
  end if;

  if new.revision = old.revision and new.device_id = old.device_id then
    return null;                                  -- an idempotent retry, not a conflict
  end if;

  loser := to_jsonb(new);

  if new.revision = old.revision and new.updated_at < old.updated_at then
    -- The incoming row wins on the tie-break, so the STORED row is the loser and gets recorded.
    loser := to_jsonb(old);
    insert into app.sync_conflicts
      (user_id, table_name, row_id, losing_row, winning_revision, losing_revision)
    values (old.user_id, tg_table_name, old.id, loser, new.revision, old.revision);
    return new;
  end if;

  insert into app.sync_conflicts
    (user_id, table_name, row_id, losing_row, winning_revision, losing_revision)
  values (old.user_id, tg_table_name, old.id, loser, old.revision, new.revision);
  return null;
end $$;

comment on function app.resolve_sync_conflict() is
  'FR-SYNC-02 conflict resolution (design §9.4). Returns NULL for a losing write so the row is neither modified nor returned by RETURNING.';

-- Named `<table>_resolve_conflict`, which sorts before `<table>_stamp_seq`: Postgres fires BEFORE
-- triggers in alphabetical order, so a losing write is discarded before it can burn a sequence
-- value.
create trigger runs_resolve_conflict before update on app.runs
  for each row execute function app.resolve_sync_conflict();
create trigger photos_resolve_conflict before update on app.photos
  for each row execute function app.resolve_sync_conflict();
create trigger checkpoint_results_resolve_conflict before update on app.checkpoint_results
  for each row execute function app.resolve_sync_conflict();
create trigger task_results_resolve_conflict before update on app.task_results
  for each row execute function app.resolve_sync_conflict();
create trigger awards_resolve_conflict before update on app.awards
  for each row execute function app.resolve_sync_conflict();
