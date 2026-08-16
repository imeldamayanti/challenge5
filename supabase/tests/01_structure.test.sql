-- b2 §1 — structural rules: the tests that survive being forgotten.
-- docs/backend-supabase.md §8.1, §8.2, §15.5.
--
-- These need no fixtures and fail the day somebody ADDS a table, view, function or foreign key —
-- which is exactly when the hand-written assertions in every later file get overlooked. Same move
-- the Swift package already makes with ImportBoundaryTests and the contrast suites: a rule a
-- reviewer would have to remember becomes a build failure.

begin;
set local search_path to extensions, tests, app, public;
select no_plan();

-- 1.1 — §8.1 case 1. A table with `enable row level security` and no policy denies everything
-- (safe, obvious in testing); a table with NO RLS at all allows everything to anyone holding the
-- publishable key (unsafe, invisible in testing). The two failures look nothing alike and the
-- dangerous one is the quiet one.
select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'app' and c.relkind = 'r'
        and not (c.relrowsecurity and c.relforcerowsecurity) $$,
  '1.1 every table in app has RLS enabled AND forced'
);

-- The same rule for `ops`, which is unreachable over PostgREST but should not depend on that alone.
select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'ops' and c.relkind = 'r'
        and not (c.relrowsecurity and c.relforcerowsecurity) $$,
  '1.1b every table in ops has RLS enabled AND forced'
);

-- 1.2 — §8.1 case 2. Views run as their owner and do NOT inherit the RLS of their base tables, so
-- a convenience view over app.runs hands out every user's rows.
select is_empty(
  $$ select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'app' and c.relkind in ('v','m')
        and coalesce(array_to_string(c.reloptions, ','), '') not like '%security_invoker=%' $$,
  '1.2 every view in app is security_invoker'
);

-- 1.3 — §8.1 case 3. A mutable search_path lets a caller shadow a function name and run their own
-- code as the owner; this is Supabase's most-flagged advisor warning.
select is_empty(
  $$ select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('app','ops','catalog') and p.prosecdef
        and not exists (
          select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search\_path=%'
        ) $$,
  '1.3 every security definer routine in app/ops/catalog pins search_path'
);

-- The two routines the design names as definer are the conflict trigger and the service-role
-- helpers; app.stamp_server_seq is explicitly NOT one (§4.1), and neither is the merge (§7.3).
select is(
  (select prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'stamp_server_seq'),
  false,
  '1.3b app.stamp_server_seq is NOT security definer — the sequence grant is what made it look necessary'
);

-- 1.4 — §15.5. Postgres never creates these, and every `on delete cascade` in §4 resolves by
-- scanning the child table without one. This is the difference between a linear and a quadratic
-- account deletion. Asserted on the LEADING column: an index that merely contains the column
-- somewhere does not serve the cascade.
select is_empty(
  $$ select c.conrelid::regclass::text || '.' || a.attname
       from pg_constraint c
       join pg_namespace n on n.oid = c.connamespace
       join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
      where c.contype = 'f' and n.nspname = 'app'
        and not exists (
          select 1 from pg_index i
           where i.indrelid = c.conrelid and i.indkey[0] = a.attnum
        ) $$,
  '1.4 every foreign key in app has an index leading with its referencing column'
);

-- 1.5 — the grants layer (§8). `anon` never touches user data; Supabase's anonymous session is
-- `authenticated` as far as Postgres roles are concerned, so §7's anonymous walker loses nothing.
select is_empty(
  $$ select table_name || ':' || privilege_type from information_schema.role_table_grants
      where table_schema = 'app' and grantee = 'anon' $$,
  '1.5 no table in app grants anything to anon'
);
select ok(
  not has_schema_privilege('anon', 'app', 'usage'),
  '1.5b anon has no USAGE on schema app'
);
select is_empty(
  $$ select table_name || ':' || privilege_type from information_schema.role_table_grants
      where table_schema = 'app' and grantee = 'authenticated' and privilege_type = 'DELETE' $$,
  '1.5c authenticated has no DELETE grant anywhere in app — tombstones are the only deletion path'
);

-- 1.6 — no delete policy, anywhere. Held twice: by the absent grant above and by this.
select is_empty(
  $$ select tablename || ':' || policyname from pg_policies
      where schemaname = 'app' and cmd in ('DELETE','ALL') $$,
  '1.6 no delete policy exists on any table in app'
);

-- 1.7 — a table that syncs without a cursor is invisible to pull, forever. "Syncable" is defined
-- structurally as "has a server_seq column", so a new table cannot opt out by being forgotten.
select is_empty(
  $$ select c.relname from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
       join pg_attribute a on a.attrelid = c.oid and a.attname = 'server_seq' and a.attnum > 0
      where n.nspname = 'app' and c.relkind = 'r'
        and not exists (
          select 1 from pg_trigger t
           where t.tgrelid = c.oid and not t.tgisinternal
             and t.tgfoid = 'app.stamp_server_seq'::regproc
        ) $$,
  '1.7 every syncable table has a stamp_server_seq trigger'
);

-- And the set itself, spelled out, so that dropping server_seq from a table fails here rather than
-- quietly satisfying the structural rule above.
select set_eq(
  $$ select c.relname::text from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
       join pg_attribute a on a.attrelid = c.oid and a.attname = 'server_seq' and a.attnum > 0
      where n.nspname = 'app' and c.relkind = 'r' $$,
  array['runs','photos','checkpoint_results','task_results','awards','journal_entries','share_cards'],
  '1.7b the syncable set is exactly §9.2''s push order'
);

-- 1.8 — §9.3's query filters on user_id and orders by server_seq. Without the index it is a sort
-- over every row the user owns.
select is_empty(
  $$ select c.relname from pg_class c
       join pg_namespace n on n.oid = c.relnamespace
       join pg_attribute a on a.attrelid = c.oid and a.attname = 'server_seq' and a.attnum > 0
      where n.nspname = 'app' and c.relkind = 'r'
        and not exists (
          select 1 from pg_index i
           join pg_attribute ua on ua.attrelid = c.oid and ua.attname = 'user_id'
           where i.indrelid = c.oid and i.indkey[0] = ua.attnum and i.indkey[1] = a.attnum
        ) $$,
  '1.8 every syncable table has an index on (user_id, server_seq)'
);

-- §4.4: the snapshot columns are write-only from the server's point of view. An index on one is
-- pure write amplification serving no query — and adding one LOOKS like diligence.
select is_empty(
  $$ select i.indexrelid::regclass::text
       from pg_index i
       join pg_class c on c.oid = i.indrelid
       join pg_namespace n on n.oid = c.relnamespace
       join pg_attribute a on a.attrelid = c.oid and a.attnum = any(i.indkey)
      where n.nspname = 'app' and a.attname like 'snapshot\_%' $$,
  '1.8b no index on any snapshot_* column, ever'
);

-- ops.events and ops.survey_responses have no user_id and must never acquire one (§2.4).
select is_empty(
  $$ select table_name from information_schema.columns
      where table_schema = 'ops' and column_name = 'user_id' $$,
  '1.8c no table in ops has a user_id column'
);

-- 1.10 — no `security definer` routine in app or ops may be called by a role a client can hold.
-- Postgres grants EXECUTE to PUBLIC on every new function, so this is the default rather than a
-- mistake somebody made: migration 0013 revokes it, and this is what keeps the next one revoked.
-- Supabase advisors 0028/0029 caught this on the first push; a test catches it before the next.
select is_empty(
  $$ select n.nspname || '.' || p.proname
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('app','ops') and p.prosecdef
        and (has_function_privilege('anon', p.oid, 'execute')
             or has_function_privilege('authenticated', p.oid, 'execute')) $$,
  '1.10 no security definer routine in app/ops is executable by anon or authenticated'
);

-- The trigger functions are not callable by a client either, definer or not.
select ok(
  not has_function_privilege('authenticated', 'app.stamp_server_seq()', 'execute'),
  '1.10b app.stamp_server_seq is not callable as an RPC'
);

-- 1.11 — every policy names the role it means. A policy with no `TO` clause means PUBLIC, which
-- includes `anon`; the grants layer already denies `anon`, but a policy that names a role it does
-- not intend is a policy that stops matching the grants the day somebody "fixes" a permission
-- error with a `grant` (Supabase advisor 0012).
select is_empty(
  $$ select tablename || ':' || policyname from pg_policies
      where schemaname = 'app' and roles = '{public}' $$,
  '1.11 no policy in app applies to PUBLIC — each names authenticated (or postgres)'
);

-- 1.9 — if this is wrong every isolation assertion in 02 passes against a table with no policies
-- at all (§8.1 case 4).
select tests.as_user(tests.user_a());
select is(current_user::text, 'authenticated', '1.9 the harness runs as authenticated');
select ok(
  not (select rolsuper from pg_roles where rolname = current_user)
  and not (select rolbypassrls from pg_roles where rolname = current_user),
  '1.9b the harness role is neither superuser nor BYPASSRLS'
);
select tests.reset_role();

select * from finish();
rollback;
