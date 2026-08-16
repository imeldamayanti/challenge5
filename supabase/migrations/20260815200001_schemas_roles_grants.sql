-- 0001 — schemas, the grants layer, and an empty `public`.
-- docs/backend-supabase.md §8 (grants are the second layer under RLS), b0 D3, b0 D4.
--
-- GRANT decides whether a role may touch a table at all; RLS decides which rows. They are
-- independent, and the safe posture needs both — a table that somehow ships without RLS must still
-- be unreachable rather than wide open.

create schema if not exists app;
create schema if not exists catalog;
create schema if not exists ops;

comment on schema app is
  'User data. RLS forced on every table, user_id = auth.uid(). The only schema exposed over PostgREST.';
comment on schema catalog is
  'Authored content. b0 D5: NOT built — content is authored in git and validated at merge. Kept so the name is reserved and its absence is a decision rather than an oversight.';
comment on schema ops is
  'Governance and measurement. No user_id anywhere (design §2.4). Never exposed to clients.';

-- b0 D4: `public` is the default target for anything created without a schema qualifier, so keeping
-- it empty means an object appearing there is visibly a mistake rather than indistinguishable from
-- the rest of the schema.
revoke all on schema public from public;

-- design §15.7: "the only way to answer 'which query got slow' after the fact rather than by
-- guessing". Costs almost nothing and wants to be on from day one.
create extension if not exists pg_stat_statements with schema extensions;

-- --------------------------------------------------------------------------------------------
-- `anon` never touches user data.
--
-- Supabase's anonymous session (design §7) is `authenticated` as far as Postgres roles are
-- concerned — `is_anonymous` is a JWT claim, not a role — so §7's anonymous walker is covered by
-- the `authenticated` grants below and `anon` never needs to reach `app` at all.
-- --------------------------------------------------------------------------------------------
revoke all on all tables in schema app from anon;
revoke all on all sequences in schema app from anon;
revoke all on schema app from anon;

grant usage on schema app to authenticated;
grant select, insert, update on all tables in schema app to authenticated;
-- No `delete` grant anywhere: §8's policies already omit delete, and this makes the omission
-- structural rather than a policy somebody could add later. Rows are tombstoned (schema.md §C.3
-- rule 3), never removed by a client.

-- The line that stops the NEXT table arriving ungranted and then being fixed with a too-broad
-- `grant all` in a hurry.
alter default privileges in schema app grant select, insert, update on tables to authenticated;

-- --------------------------------------------------------------------------------------------
-- service_role.
--
-- Not named in design §8's grants block because Supabase grants it by default in `public` only —
-- and nothing here lives in `public`. Without these the three Edge Functions of b0 D7 cannot do
-- their work. The key itself never ships in the app, under any circumstance (§8).
-- --------------------------------------------------------------------------------------------
grant usage on schema app, ops to service_role;
grant all on all tables in schema app to service_role;
grant all on all tables in schema ops to service_role;
alter default privileges in schema app grant all on tables to service_role;
alter default privileges in schema ops grant all on tables to service_role;
alter default privileges in schema app grant all on sequences to service_role;
alter default privileges in schema ops grant all on sequences to service_role;

-- `ops` and `catalog` are never exposed over PostgREST (config.toml `[api] schemas = ["app"]`,
-- b0 D1). No grants to anon or authenticated, deliberately.
revoke all on schema ops, catalog from anon, authenticated;
