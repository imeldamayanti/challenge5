-- b2 §7 — query shape.
-- docs/backend-supabase.md §15.5, §15.1, §6.2.
--
-- Assertions on `explain (format json)` rather than on timing, so they are stable in CI. A timing
-- assertion on a laptop and a timing assertion on a shared runner are two different tests.
--
-- The volume below exists because a planner given fifty rows will sequentially scan them whatever
-- indexes are present, and a plan assertion against fifty rows proves nothing at all.

begin;
set local search_path to extensions, tests, app, public;
select no_plan();

-- 5 000 completed runs, each on its own quest so runs_one_active_per_quest is untouched.
insert into app.runs (id, user_id, quest_id, content_version, language, state,
                      started_at, completed_at, device_id, created_at, updated_at)
select gen_random_uuid(), tests.user_a(), 'quest-' || g, '2026.08.1', 'id', 'completed',
       now() - (g || ' hours')::interval, now() - (g || ' hours')::interval + interval '90 minutes',
       gen_random_uuid(), now(), now()
  from generate_series(1, 5000) g;

insert into app.checkpoint_results
  (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
   snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version, device_id,
   created_at, updated_at)
select gen_random_uuid(), r.id, tests.user_a(), 'cp-' || g, g, now(), 'gps', 'Place',
       '[{"text":"lore"}]', '[]', '2026.08.1', gen_random_uuid(), now(), now()
  from (select id from app.runs where user_id = tests.user_a() limit 2000) r,
       generate_series(0, 1) g;

insert into app.task_results
  (id, checkpoint_result_id, run_id, user_id, task_id, type, skipped, completed_at, device_id,
   created_at, updated_at)
select gen_random_uuid(), c.id, c.run_id, tests.user_a(), 'task-a', 'reflection', false, now(),
       gen_random_uuid(), now(), now()
  from app.checkpoint_results c where c.user_id = tests.user_a();

insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name, awarded_at,
                        device_id, created_at, updated_at)
select gen_random_uuid(), tests.user_a(), r.id, 'stamp', 'stamp-a', 'S', now(),
       gen_random_uuid(), now(), now()
  from app.runs r where r.user_id = tests.user_a() and r.quest_id like 'quest-%';

-- 150 000 events across 60 days. BRIN summarises a block RANGE, so it needs enough blocks to
-- summarise before the planner will prefer it over reading the table.
insert into ops.events (id, name, params, run_key, schema_version, occurred_at, received_at)
select gen_random_uuid(), 'checkpoint_arrived',
       jsonb_build_object('questID', 'quest-' || (g % 50), 'accuracyBucket', 'lt20'),
       gen_random_uuid(), 1,
       now() - ((g % 86400) || ' seconds')::interval,
       now() - ((g * 60.0 / 150000 * 24) || ' hours')::interval
  from generate_series(1, 150000) g;

-- A second user with a small share of the rows. A cascade lookup is only an index lookup when the
-- user is one among many: filtering a table where EVERY row belongs to the target is a sequential
-- scan by correct choice, not by a missing index.
insert into app.runs (id, user_id, quest_id, content_version, language, state,
                      started_at, completed_at, device_id, created_at, updated_at)
select gen_random_uuid(), tests.user_b(), 'quest-b-' || g, '2026.08.1', 'en', 'completed',
       now() - (g || ' hours')::interval, now() - (g || ' hours')::interval + interval '60 minutes',
       gen_random_uuid(), now(), now()
  from generate_series(1, 50) g;

insert into app.checkpoint_results
  (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
   snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version, device_id,
   created_at, updated_at)
select gen_random_uuid(), r.id, tests.user_b(), 'cp-b', 0, now(), 'gps', 'Place', '[]', '[]',
       '2026.08.1', gen_random_uuid(), now(), now()
  from (select id from app.runs where user_id = tests.user_b()) r;

insert into app.task_results
  (id, checkpoint_result_id, run_id, user_id, task_id, type, skipped, completed_at, device_id,
   created_at, updated_at)
select gen_random_uuid(), c.id, c.run_id, tests.user_b(), 'task-b', 'reflection', false, now(),
       gen_random_uuid(), now(), now()
  from app.checkpoint_results c where c.user_id = tests.user_b();

insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name, awarded_at,
                        device_id, created_at, updated_at)
select gen_random_uuid(), tests.user_b(), r.id, 'stamp', 'stamp-b', 'S', now(),
       gen_random_uuid(), now(), now()
  from app.runs r where r.user_id = tests.user_b();

analyze app.runs;
analyze app.task_results;
analyze app.awards;
analyze app.checkpoint_results;
analyze ops.events;

-- =============================================================================================
-- 7.1 — the pull. §9.3 filters on user_id and orders by server_seq; without (user_id, server_seq)
-- it is a sort over every row the user owns.
-- =============================================================================================
select ok(
  tests.plan_json(format(
    $$ select id, revision, server_seq from app.runs
        where user_id = %L and server_seq > 100 order by server_seq limit 200 $$,
    tests.user_a()))::text like '%runs_pull%',
  '7.1 the pull query uses the (user_id, server_seq) index');
select ok(
  tests.plan_json(format(
    $$ select id, revision, server_seq from app.runs
        where user_id = %L and server_seq > 100 order by server_seq limit 200 $$,
    tests.user_a()))::text not like '%Seq Scan%',
  '7.1b …and does not sequentially scan app.runs');

-- =============================================================================================
-- 7.2 — the summary embed (§15.1). One request, index scans throughout. Note that this path is
-- for a RESTORED DEVICE only: RunSummaryViewModel renders from local snapshots and takes no
-- repository, which is how FR-DONE-04/05 and FR-RUN-06 are guaranteed rather than intended.
-- =============================================================================================
select ok(
  tests.plan_json(format(
    $$ select * from app.checkpoint_results where run_id = %L $$,
    (select id from app.runs where user_id = tests.user_a() limit 1)))::text
    not like '%Seq Scan on checkpoint_results%',
  '7.2 the summary''s children are reached by index, not by scanning checkpoint_results');

-- =============================================================================================
-- 7.3 — the cascade. This is the test that makes 1.4 meaningful rather than cosmetic: EXPLAIN
-- does not show a cascade's own plans, so what is asserted is the lookup each referential action
-- performs — filtering a child table by its foreign key column.
-- =============================================================================================
select ok(
  tests.plan_json(format($$ select 1 from app.checkpoint_results where user_id = %L $$,
                         tests.user_b()))::text not like '%Seq Scan%',
  '7.3 the auth.users cascade reaches checkpoint_results by index');
select ok(
  tests.plan_json(format($$ select 1 from app.task_results where user_id = %L $$,
                         tests.user_b()))::text not like '%Seq Scan%',
  '7.3b …and task_results');
select ok(
  tests.plan_json(format($$ select 1 from app.awards where user_id = %L $$,
                         tests.user_b()))::text not like '%Seq Scan%',
  '7.3c …and awards');
select ok(
  tests.plan_json(format($$ select 1 from app.photos where run_id = %L $$,
                         (select id from app.runs where user_id = tests.user_a() limit 1)))::text
    not like '%Seq Scan%',
  '7.3d …and photos, by run_id');

-- =============================================================================================
-- 7.4 — BRIN, not a full scan (§6.2). This table is append-only and received_at is monotonic, so
-- physical row order already correlates with time, which is the exact case BRIN exists for.
-- =============================================================================================
select ok(
  tests.plan_json($$ select count(*) from ops.events
                      where received_at > now() - interval '2 days' $$)::text
    like '%events_received_brin%',
  '7.4 a time-range query over ops.events uses the BRIN index');

-- =============================================================================================
-- 7.5 — GIN, because this jsonb IS queried. Contrast app.checkpoint_results.snapshot_lore, which
-- is never queried and must never be indexed (asserted at 1.8b).
-- =============================================================================================
select ok(
  tests.plan_json($$ select count(*) from ops.events
                      where params @> '{"questID":"quest-7"}'::jsonb $$)::text
    like '%events_params_gin%',
  '7.5 a containment query on events.params uses the GIN index');

-- =============================================================================================
-- 7.6 — "my walks". §15.5 notes a covering index is available and deliberately not taken yet.
-- =============================================================================================
select ok(
  tests.plan_json(format(
    $$ select id, quest_id, state, completed_at from app.runs
        where user_id = %L and state = 'completed'
        order by completed_at desc limit 20 $$, tests.user_a()))::text
    like '%runs_user_state%',
  '7.6 the "my walks" list uses (user_id, state, completed_at desc)');
select ok(
  tests.plan_json(format(
    $$ select id, quest_id, state, completed_at from app.runs
        where user_id = %L and state = 'completed'
        order by completed_at desc limit 20 $$, tests.user_a()))::text
    not like '%Sort%',
  '7.6b …and reads it in order rather than sorting 5 000 rows');

select * from finish();
rollback;
