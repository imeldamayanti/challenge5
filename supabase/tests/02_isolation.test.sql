-- b2 §2 — isolation, per table.
-- docs/backend-supabase.md §8, §8.2.
--
-- Seeded (seed.sql): user A owns one run with two checkpoint results, three task results, two
-- awards, one journal entry, two photos and one share card. User B owns NOTHING. That is the
-- fixture, and B owning nothing is what makes "zero rows" mean something.

begin;
set local search_path to extensions, tests, app, public;
select no_plan();

-- A's conflict row, so 2.1's sync_conflicts assertion is not vacuously true.
insert into app.sync_conflicts (user_id, table_name, row_id, losing_row, winning_revision, losing_revision)
values (tests.user_a(), 'runs', tests.run_a(), '{"seeded":true}'::jsonb, 2, 1);

-- =============================================================================================
-- 2.1 — the headline guarantee, per table, individually. One missing policy is one leaked table.
-- =============================================================================================
select tests.as_user(tests.user_b());

select is((select count(*) from app.profiles           where user_id <> tests.user_b()), 0::bigint, '2.1 profiles: B sees none of A''s');
select is((select count(*) from app.runs),               0::bigint, '2.1 runs: B sees zero rows');
select is((select count(*) from app.checkpoint_results), 0::bigint, '2.1 checkpoint_results: B sees zero rows');
select is((select count(*) from app.task_results),       0::bigint, '2.1 task_results: B sees zero rows');
select is((select count(*) from app.awards),             0::bigint, '2.1 awards: B sees zero rows');
select is((select count(*) from app.journal_entries),    0::bigint, '2.1 journal_entries: B sees zero rows');
select is((select count(*) from app.photos),             0::bigint, '2.1 photos: B sees zero rows');
select is((select count(*) from app.share_cards),        0::bigint, '2.1 share_cards: B sees zero rows');
select is((select count(*) from app.sync_conflicts),     0::bigint, '2.1 sync_conflicts: B sees zero rows');

-- And A does see their own, so the assertions above are about isolation rather than about an empty
-- database.
select tests.as_user(tests.user_a());
select is((select count(*) from app.runs),               1::bigint, '2.1b A sees their own run');
select is((select count(*) from app.checkpoint_results), 2::bigint, '2.1b A sees their own checkpoint results');
select is((select count(*) from app.task_results),       3::bigint, '2.1b A sees their own task results');
select is((select count(*) from app.awards),             2::bigint, '2.1b A sees their own awards');
select is((select count(*) from app.photos),             2::bigint, '2.1b A sees their own photos');

-- =============================================================================================
-- 2.2 — `with check` on insert, not only `using` on select.
-- =============================================================================================
select tests.as_user(tests.user_b());
select throws_ok(
  format($$ insert into app.runs
              (id, user_id, quest_id, content_version, language, state, started_at,
               device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, 'badung-empat-wajah', '2026.08.1', 'id', 'active',
                    now(), gen_random_uuid(), now(), now()) $$, tests.user_a()),
  '42501',
  null,
  '2.2 B cannot insert a row carrying user_id = A'
);

-- =============================================================================================
-- 2.3 — b2 asks for this to be "asserted as an error, not as 0 rows affected".
--
-- DEVIATION, AND IT IS A PROPERTY OF THE DESIGNED POLICY RATHER THAN OF THIS TEST. With
-- `for update using (user_id = auth.uid())`, A's row is INVISIBLE to B, so Postgres has nothing to
-- reject: the statement matches zero rows and returns cleanly. An error is only reachable when the
-- row is visible and the WITH CHECK fails. Both halves are asserted below — the guarantee that
-- matters (A's row is unmodified) and the rejection that IS expressible.
-- =============================================================================================
select lives_ok(
  format($$ update app.runs set state = 'abandoned' where id = %L $$, tests.run_a()),
  '2.3 B''s update of A''s run matches nothing (an invisible row cannot be rejected)'
);
select tests.as_user(tests.user_a());
select is((select state from app.runs where id = tests.run_a()), 'completed',
  '2.3b A''s run is unchanged after B''s attempt');

-- The rejection that IS expressible: B moving their own row to A.
select tests.as_user(tests.user_b());
insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                      device_id, created_at, updated_at)
values ('1b000000-0000-4000-8000-0000000000b1', tests.user_b(), 'quest-b', '2026.08.1', 'en',
        'active', now(), gen_random_uuid(), now(), now());
select throws_ok(
  format($$ update app.runs set user_id = %L where id = '1b000000-0000-4000-8000-0000000000b1' $$,
         tests.user_a()),
  '42501',
  null,
  '2.3c B cannot hand their own row to A — the WITH CHECK denies it'
);

-- =============================================================================================
-- 2.4 — no delete policy anywhere, and no delete grant either.
-- =============================================================================================
select throws_ok(
  format($$ delete from app.runs where id = %L $$, tests.run_a()),
  '42501', null, '2.4 delete on app.runs is refused outright');
select throws_ok(
  $$ delete from app.checkpoint_results $$, '42501', null,
  '2.4b delete on app.checkpoint_results is refused outright');
select throws_ok(
  $$ delete from app.awards $$, '42501', null,
  '2.4c delete on app.awards is refused outright');
select throws_ok(
  $$ delete from app.photos $$, '42501', null,
  '2.4d delete on app.photos is refused outright');
select throws_ok(
  $$ delete from app.journal_entries $$, '42501', null,
  '2.4e delete on app.journal_entries is refused outright');

-- =============================================================================================
-- 2.5 — an upsert aimed at A's row id must not silently create a second row either.
-- =============================================================================================
select throws_ok(
  format($$ insert into app.runs
              (id, user_id, quest_id, content_version, language, state, started_at,
               device_id, revision, created_at, updated_at)
            values (%L, %L, 'stolen', '2026.08.1', 'en', 'active', now(), gen_random_uuid(), 99,
                    now(), now())
            on conflict (id) do update set quest_id = excluded.quest_id $$,
         tests.run_a(), tests.user_b()),
  null, null,
  '2.5 an ON CONFLICT upsert against A''s row id is rejected for B'
);
select tests.as_user(tests.user_a());
select is((select quest_id from app.runs where id = tests.run_a()), 'badung-empat-wajah',
  '2.5b A''s run still carries its own quest_id');
select is((select count(*) from app.runs where id = tests.run_a()), 1::bigint,
  '2.5c and no second row was created under that id');

-- =============================================================================================
-- 2.6 — no session at all. Two distinct mechanisms, and the design asserts both.
-- =============================================================================================
select tests.as_anon();
select throws_ok(
  $$ select count(*) from app.runs $$, '42501', null,
  '2.6 with the publishable key and no session the grants layer refuses `anon` outright');

-- `authenticated` with no `sub`: auth.uid() is null, and the comparison must DENY rather than
-- error (§8.2, last assertion).
select tests.as_authenticated_without_sub();
select is((select count(*) from app.runs), 0::bigint,
  '2.6b authenticated with no sub sees zero rows, and does not error');
select is((select count(*) from app.checkpoint_results), 0::bigint,
  '2.6c …the same on every table');
select is((select count(*) from app.photos), 0::bigint, '2.6d …photos too');

-- =============================================================================================
-- 2.7 / 2.8 — ops and catalog are UNREACHABLE, not empty.
--
-- The real proof is an HTTP request against a running PostgREST (b3 §4, and
-- tests/http/isolation_over_http.test.ts), because the enforcement is `[api] schemas = ["app"]`
-- and not anything inside the database. What IS provable here is the layer underneath it: no
-- client role holds any privilege on either schema, so even an exposed schema would deny.
-- =============================================================================================
select tests.reset_role();
select ok(not has_schema_privilege('anon', 'ops', 'usage'), '2.7 anon has no USAGE on ops');
select ok(not has_schema_privilege('authenticated', 'ops', 'usage'),
  '2.7b authenticated has no USAGE on ops');
select is_empty(
  $$ select table_name from information_schema.role_table_grants
      where table_schema = 'ops' and grantee in ('anon','authenticated') $$,
  '2.7c no table in ops grants anything to a client role');
select ok(not has_schema_privilege('anon', 'catalog', 'usage'), '2.8 anon has no USAGE on catalog');
select ok(not has_schema_privilege('authenticated', 'catalog', 'usage'),
  '2.8b authenticated has no USAGE on catalog');

-- The ingest RPC lives in `app` because PostgREST only routes to exposed schemas; EXECUTE is what
-- keeps it service-role-only (§6.2 rejects insert-only RLS for anon).
select ok(not has_function_privilege('anon', 'app.ingest_batch(jsonb)', 'execute'),
  '2.8c anon cannot execute app.ingest_batch');
select ok(not has_function_privilege('authenticated', 'app.ingest_batch(jsonb)', 'execute'),
  '2.8d authenticated cannot execute app.ingest_batch');
select ok(not has_function_privilege('authenticated', 'app.merge_anonymous_rows(uuid,uuid)', 'execute'),
  '2.8e authenticated cannot execute the merge — an account-takeover primitive if it could');
select ok(not has_function_privilege('authenticated', 'app.delete_account_batch(uuid,int)', 'execute'),
  '2.8f authenticated cannot execute delete_account_batch');

select * from finish();
rollback;
