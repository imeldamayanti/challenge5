-- 0014 — a read path for the published suppressions document.
-- docs/backend-supabase.md §6.1, AD-5, FR-ERR-09. c1 §2, §4a.
--
-- Purely additive (b0 D2, D3): one new function. No table is altered, nothing is dropped, and no
-- existing behaviour changes. A merged migration is never edited, so this arrives as its own file.
--
-- WHY THIS EXISTS AT ALL.
-- Migration 0004 maintains ops.suppressions_document and states that publication is "a read of one
-- row by a privileged caller". Nothing could actually perform that read: `ops` is deliberately
-- absent from config.toml's `[api] schemas = ["app"]`, and that setting is a security control
-- rather than a preference (b0 D1) — so PostgREST cannot reach ops for ANY role, service_role
-- included. The kill-switch therefore had a generator and no publisher, which makes AD-5 a release
-- gate that never releases: a place can be withdrawn in the database and no installed app ever
-- hears about it.
--
-- The alternative — adding 'ops' to the exposed schemas — was rejected. It would put ops.events and
-- ops.survey_responses on the public API to publish one document.

-- `security definer` because the caller must read a table in a schema whose USAGE it does not hold,
-- and this is §8.1 case 3's shape done deliberately: the function takes no arguments, so there is
-- no argument to validate and no way to steer it at a row the caller should not see. It returns one
-- row of already-public data — the document is published to a public-read bucket seconds later.
--
-- `set search_path = ''` with every name qualified, as everywhere else in this schema.
create or replace function app.published_suppressions()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
  select d.document from ops.suppressions_document d where d.id;
$$;

comment on function app.published_suppressions() is
  'The rendered schema-2 suppressions document (schema.md §A.8), for the publish-suppressions Edge Function. service_role only; ops stays off the public API.';

-- Postgres grants EXECUTE to PUBLIC on a new function by default — advisor 0028, and the whole
-- subject of migration 0013. Revoke first, then grant to exactly one role.
revoke all on function app.published_suppressions() from public, anon, authenticated;
grant execute on function app.published_suppressions() to service_role;
