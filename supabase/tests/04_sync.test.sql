-- b2 §4 — sync: push, pull, conflict. The section where the defects were.
-- docs/backend-supabase.md §9, §14 defects 1, 2, 3, 5, 6, 8, 9, 11.
--
-- 4.2.7 (a transaction that claims a server_seq and commits behind a reader) needs two sessions
-- and lives in tests/concurrency/concurrency.test.ts with the rest of §6.

begin;
set local search_path to extensions, tests, app, public;
select no_plan();

select tests.as_user(tests.user_a());

create temp table pushed (id uuid, revision bigint, server_seq bigint) on commit drop;

-- =============================================================================================
-- 4.1 Push
-- =============================================================================================

-- 4.1.1 — a new row is inserted and comes back.
with p as (
  insert into app.runs as t
    (id, user_id, quest_id, content_version, language, state, current_checkpoint_index,
     started_at, device_id, revision, created_at, updated_at)
  values ('1d000000-0000-4000-8000-0000000000d1', tests.user_a(), 'quest-push', '2026.08.1', 'id',
          'active', 0, now(), '99999999-9999-4999-8999-999999999999', 5, now(), now())
  on conflict (id) do update
    set state = excluded.state, current_checkpoint_index = excluded.current_checkpoint_index,
        revision = excluded.revision, updated_at = excluded.updated_at
    where excluded.revision > t.revision
  returning t.id, t.revision, t.server_seq
)
insert into pushed select * from p;
select is((select count(*) from pushed), 1::bigint, '4.1.1 a new row is inserted and returned');
select isnt((select server_seq from pushed), null, '4.1.1b …carrying a server_seq');
delete from pushed;

-- 4.1.2 — THE ONE THAT MATTERS MOST (§14 defect 6). A losing upsert returns 200 with zero rows
-- changed. A client that marks `synced` on a 200 has recorded that a row it never wrote is safely
-- on the server: data loss that reports success. The contract is that `returning` is EMPTY.
with p as (
  insert into app.runs as t
    (id, user_id, quest_id, content_version, language, state, current_checkpoint_index,
     started_at, device_id, revision, created_at, updated_at)
  values ('1d000000-0000-4000-8000-0000000000d1', tests.user_a(), 'quest-push', '2026.08.1', 'id',
          'active', 0, now(), '99999999-9999-4999-8999-999999999999', 5, now(), now())
  on conflict (id) do update
    set state = excluded.state, revision = excluded.revision, updated_at = excluded.updated_at
    where excluded.revision > t.revision
  returning t.id, t.revision, t.server_seq
)
insert into pushed select * from p;
select is((select count(*) from pushed), 0::bigint,
  '4.1.2 re-pushing an identical row at the same revision returns NOTHING');
delete from pushed;

-- 4.1.3 — a stale revision is a no-op, and changes nothing.
with p as (
  insert into app.runs as t
    (id, user_id, quest_id, content_version, language, state, current_checkpoint_index,
     started_at, device_id, revision, created_at, updated_at)
  values ('1d000000-0000-4000-8000-0000000000d1', tests.user_a(), 'quest-push', '2026.08.1', 'id',
          'active', 9, now(), '99999999-9999-4999-8999-999999999999', 3, now(), now())
  on conflict (id) do update
    set current_checkpoint_index = excluded.current_checkpoint_index,
        revision = excluded.revision, updated_at = excluded.updated_at
    where excluded.revision > t.revision
  returning t.id, t.revision, t.server_seq
)
insert into pushed select * from p;
select is((select count(*) from pushed), 0::bigint, '4.1.3 revision 3 over stored 5 returns nothing');
select is(
  (select current_checkpoint_index from app.runs where id = '1d000000-0000-4000-8000-0000000000d1'),
  0, '4.1.3b …and the stored row is untouched');
select is((select revision from app.runs where id = '1d000000-0000-4000-8000-0000000000d1'), 5::bigint,
  '4.1.3c …at its own revision');
delete from pushed;

-- 4.1.4 — a newer revision applies.
with p as (
  insert into app.runs as t
    (id, user_id, quest_id, content_version, language, state, current_checkpoint_index,
     started_at, device_id, revision, created_at, updated_at)
  values ('1d000000-0000-4000-8000-0000000000d1', tests.user_a(), 'quest-push', '2026.08.1', 'id',
          'active', 3, now(), '99999999-9999-4999-8999-999999999999', 6, now(), now())
  on conflict (id) do update
    set current_checkpoint_index = excluded.current_checkpoint_index,
        revision = excluded.revision, updated_at = excluded.updated_at
    where excluded.revision > t.revision
  returning t.id, t.revision, t.server_seq
)
insert into pushed select * from p;
select is((select count(*) from pushed), 1::bigint, '4.1.4 revision 6 over stored 5 is applied');
select is((select current_checkpoint_index from app.runs where id = '1d000000-0000-4000-8000-0000000000d1'),
  3, '4.1.4b …and the change landed');
delete from pushed;

-- 4.1.5 — the client cannot write the cursor.
insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                      device_id, revision, created_at, updated_at, server_seq)
values ('1d000000-0000-4000-8000-0000000000d5', tests.user_a(), 'quest-seq', '1', 'id', 'active',
        now(), gen_random_uuid(), 1, now(), now(), 999999999);
select isnt((select server_seq from app.runs where id = '1d000000-0000-4000-8000-0000000000d5'),
  999999999::bigint, '4.1.5 a client-supplied server_seq is overwritten by the trigger');

-- 4.1.6 — §9.2's clamp (§14 defect 9). One buggy build writing a near-int8-max revision would
-- otherwise make that row permanently unwritable by every device, including the one that broke it.
select throws_ok(
  format($$ insert into app.runs as t
              (id, user_id, quest_id, content_version, language, state, started_at, device_id,
               revision, created_at, updated_at)
            values ('1d000000-0000-4000-8000-0000000000d1', %L, 'quest-push', '1', 'id', 'active',
                    now(), gen_random_uuid(), 5006, now(), now())
            on conflict (id) do update set revision = excluded.revision,
                                           updated_at = excluded.updated_at
              where excluded.revision > t.revision $$, tests.user_a()),
  'PT400', null,
  '4.1.6 a revision jump of +5000 is rejected as a bad request');

-- 4.1.7 — THE TEST THAT PROVES THE PUSH ORDER IS LOAD-BEARING (§14 defect 5). The earlier order
-- pushed task_results before photos while referencing them, so the first photo task ever synced
-- would have failed on a foreign key.
select throws_ok(
  format($$ insert into app.task_results
              (id, checkpoint_result_id, run_id, user_id, task_id, type, skipped, photo_id,
               completed_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), '30000000-0000-4000-8000-000000000001', %L, %L,
                    'task-photo-x', 'photo', false, gen_random_uuid(), now(), gen_random_uuid(),
                    now(), now()) $$, tests.run_a(), tests.user_a()),
  '23503', null,
  '4.1.7 a task_result whose photo has not been pushed violates a foreign key');

-- 4.1.8 — the documented order, end to end, all seven tables.
select lives_ok($$
  insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                        device_id, created_at, updated_at)
  values ('1e000000-0000-4000-8000-0000000000e1', tests.user_a(), 'quest-order', '1', 'id',
          'active', now(), gen_random_uuid(), now(), now());
  -- Paths supplied since 0015 (NOT NULL): §4.7 writes them at insert, before the bytes exist.
  insert into app.photos (id, user_id, run_id, storage_path, thumb_path,
                          captured_at, device_id, created_at, updated_at)
  values ('2e000000-0000-4000-8000-0000000000e2', tests.user_a(),
          '1e000000-0000-4000-8000-0000000000e1',
          'u/r/2e.heic', 'u/r/2e_t.heic', now(), gen_random_uuid(), now(), now());
  insert into app.checkpoint_results
    (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
     snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
     device_id, created_at, updated_at)
  values ('3e000000-0000-4000-8000-0000000000e3', '1e000000-0000-4000-8000-0000000000e1',
          tests.user_a(), 'cp-order', 0, now(), 'gps', 'P', '[]', '[]', '1', gen_random_uuid(),
          now(), now());
  insert into app.task_results
    (id, checkpoint_result_id, run_id, user_id, task_id, type, skipped, photo_id, completed_at,
     device_id, created_at, updated_at)
  values ('4e000000-0000-4000-8000-0000000000e4', '3e000000-0000-4000-8000-0000000000e3',
          '1e000000-0000-4000-8000-0000000000e1', tests.user_a(), 'task-order', 'photo', false,
          '2e000000-0000-4000-8000-0000000000e2', now(), gen_random_uuid(), now(), now());
  insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name, awarded_at,
                          device_id, created_at, updated_at)
  values ('5e000000-0000-4000-8000-0000000000e5', tests.user_a(),
          '1e000000-0000-4000-8000-0000000000e1', 'stamp', 'stamp-order', 'S', now(),
          gen_random_uuid(), now(), now());
  insert into app.journal_entries (id, user_id, run_id, body, device_id, created_at, updated_at)
  values ('6e000000-0000-4000-8000-0000000000e6', tests.user_a(),
          '1e000000-0000-4000-8000-0000000000e1', 'x', gen_random_uuid(), now(), now());
  insert into app.share_cards (id, user_id, run_id, template, storage_path, device_id,
                               created_at, updated_at)
  values ('7e000000-0000-4000-8000-0000000000e7', tests.user_a(),
          '1e000000-0000-4000-8000-0000000000e1', 'classic', 'x/y/card.png', gen_random_uuid(),
          now(), now());
$$, '4.1.8 pushing in the documented order succeeds for all seven tables');

-- =============================================================================================
-- 4.2 Pull
-- =============================================================================================

-- 4.2.1 — every row, ordered by server_seq.
select ok(
  (select bool_and(ordered) from (
     select server_seq >= lag(server_seq) over (order by server_seq) as ordered
       from app.runs where user_id = tests.user_a() and server_seq > 0
   ) s where ordered is not null),
  '4.2.1 a pull from cursor 0 comes back ordered by server_seq');

-- 4.2.2 — an update moves the row's cursor value, so it reappears on the next pull.
create temp table cursors (name text primary key, value bigint) on commit drop;
insert into cursors values ('runs', (select max(server_seq) from app.runs where user_id = tests.user_a()));

update app.runs set current_checkpoint_index = 4, revision = revision + 1, updated_at = now()
 where id = '1d000000-0000-4000-8000-0000000000d1';

select is(
  (select count(*) from app.runs
    where user_id = tests.user_a()
      and server_seq > (select value from cursors where name = 'runs')
      and id = '1d000000-0000-4000-8000-0000000000d1'),
  1::bigint, '4.2.2 an updated row reappears past the previous cursor');

-- 4.2.3 — tombstones travel through the same query, which is how a deletion propagates at all.
update cursors set value = (select max(server_seq) from app.runs where user_id = tests.user_a());
update app.runs set deleted_at = now(), revision = revision + 1, updated_at = now()
 where id = '1d000000-0000-4000-8000-0000000000d5';
select is(
  (select count(*) from app.runs
    where user_id = tests.user_a()
      and server_seq > (select value from cursors where name = 'runs')
      and deleted_at is not null),
  1::bigint, '4.2.3 a tombstoned row is returned by the pull');

-- 4.2.4 / 4.2.5 — paging. server_seq is UNIQUE, so unlike an updated_at cursor there is no tie
-- that can straddle a page boundary and drop rows between two pages (§14 defect 3). The two rows
-- below are given the SAME updated_at deliberately.
update app.runs set updated_at = '2026-08-01T00:00:00Z'
 where id in ('1d000000-0000-4000-8000-0000000000d1', '1e000000-0000-4000-8000-0000000000e1');

create temp table page1 (id uuid, server_seq bigint) on commit drop;
create temp table page2 (id uuid, server_seq bigint) on commit drop;

insert into page1
select id, server_seq from app.runs where user_id = tests.user_a() and server_seq > 0
 order by server_seq limit 2;
insert into page2
select id, server_seq from app.runs
 where user_id = tests.user_a() and server_seq > (select max(server_seq) from page1)
 order by server_seq limit 100;

select is(
  (select count(*) from page1) + (select count(*) from page2),
  (select count(*) from app.runs where user_id = tests.user_a() and server_seq > 0),
  '4.2.4 two pages cover every row — none falls between them');
select is(
  (select count(*) from page1 p1 join page2 p2 on p1.id = p2.id), 0::bigint,
  '4.2.4b …and no row appears in both');
select is(
  (select count(*) from (select id from page1 union all select id from page2) u
    where u.id in ('1d000000-0000-4000-8000-0000000000d1', '1e000000-0000-4000-8000-0000000000e1')),
  2::bigint,
  '4.2.5 two rows sharing an updated_at both arrive, on whichever side of the boundary they fall');

-- 4.2.6 — THE REGRESSION TEST FOR THE FALSE CLAIM THAT STARTED THE REVIEW (§14 defect 1). This
-- writes what a three-day-slow phone would write and asserts the row is still delivered.
update cursors set value = (select max(server_seq) from app.runs where user_id = tests.user_a());
update app.runs
   set updated_at = now() - interval '3 days', revision = revision + 1
 where id = '1e000000-0000-4000-8000-0000000000e1';
select is(
  (select count(*) from app.runs
    where user_id = tests.user_a()
      and server_seq > (select value from cursors where name = 'runs')),
  1::bigint,
  '4.2.6 a row stamped three days in the past by the device is still pulled — the cursor is not a clock');

-- 4.2.8 — RLS applies to the cursor query like any other.
select tests.as_user(tests.user_b());
select is((select count(*) from app.runs where server_seq > 0), 0::bigint,
  '4.2.8 a pull as B returns none of A''s rows');
select tests.as_user(tests.user_a());

-- =============================================================================================
-- 4.3 Conflict
-- =============================================================================================
insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                      device_id, revision, created_at, updated_at)
values ('1f000000-0000-4000-8000-0000000000f1', tests.user_a(), 'quest-conflict', '1', 'id',
        'active', now(), 'dddddddd-0001-4000-8000-000000000001', 4,
        now(), '2026-08-10T10:00:00Z');

-- 4.3.1 — device 2 pushes revision 5 over device 1's revision 4.
update app.runs set revision = 5, device_id = 'dddddddd-0002-4000-8000-000000000002',
                    updated_at = '2026-08-10T11:00:00Z', current_checkpoint_index = 2
 where id = '1f000000-0000-4000-8000-0000000000f1';
select is((select revision from app.runs where id = '1f000000-0000-4000-8000-0000000000f1'),
  5::bigint, '4.3.1 the higher revision is stored');

-- 4.3.2 — the same pair arriving in the other order. Order of arrival must not matter.
update app.runs set revision = 4, device_id = 'dddddddd-0001-4000-8000-000000000001',
                    updated_at = '2026-08-10T10:00:00Z', current_checkpoint_index = 1
 where id = '1f000000-0000-4000-8000-0000000000f1';
select is((select revision from app.runs where id = '1f000000-0000-4000-8000-0000000000f1'),
  5::bigint, '4.3.2 revision 5 still stands when revision 4 arrives afterwards');
select is((select current_checkpoint_index from app.runs where id = '1f000000-0000-4000-8000-0000000000f1'),
  2, '4.3.2b …and the losing row''s data did not leak into the stored one');

-- 4.3.4 — the loser is written to sync_conflicts IN FULL, never dropped. "We resolved it and threw
-- the other one away" is not an answer anybody can act on afterwards.
select is(
  (select count(*) from app.sync_conflicts
    where row_id = '1f000000-0000-4000-8000-0000000000f1' and losing_revision = 4),
  1::bigint, '4.3.4 the losing push is recorded in sync_conflicts');
select is(
  (select losing_row->>'current_checkpoint_index' from app.sync_conflicts
    where row_id = '1f000000-0000-4000-8000-0000000000f1' and losing_revision = 4),
  '1', '4.3.4b …with the whole rejected row, readable by a human');

-- 4.3.3 — equal revisions from different devices: the earlier updated_at wins (§9.4 rule 2).
-- Arbitrary, but stable and decided in advance, which is the whole point.
update app.runs set revision = 5, device_id = 'dddddddd-0003-4000-8000-000000000003',
                    updated_at = '2026-08-10T09:00:00Z', current_checkpoint_index = 7
 where id = '1f000000-0000-4000-8000-0000000000f1';
select is((select current_checkpoint_index from app.runs where id = '1f000000-0000-4000-8000-0000000000f1'),
  7, '4.3.3 at equal revisions the earlier updated_at wins');
select is(
  (select count(*) from app.sync_conflicts
    where row_id = '1f000000-0000-4000-8000-0000000000f1'),
  2::bigint, '4.3.3b …and the row it displaced was recorded too');

-- 4.3.5 / 4.3.6
select tests.as_user(tests.user_b());
select is((select count(*) from app.sync_conflicts), 0::bigint,
  '4.3.5 B sees none of A''s conflicts');
select throws_ok(
  format($$ insert into app.sync_conflicts
              (user_id, table_name, row_id, losing_row, winning_revision, losing_revision)
            values (%L, 'runs', gen_random_uuid(), '{}', 2, 1) $$, tests.user_b()),
  '42501', null,
  '4.3.6 a client cannot insert into sync_conflicts — only the trigger writes there');
select tests.as_user(tests.user_a());

-- 4.3.7 — two devices both start the same quest offline. Postgres holding FR-START-06 means
-- Postgres REJECTING a sync, which needs a client answer rather than a retry loop (§9.5).
insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                      device_id, created_at, updated_at)
values ('1f000000-0000-4000-8000-0000000000fa', tests.user_a(), 'quest-race', '1', 'id', 'active',
        '2026-08-10T08:00:00Z', 'dddddddd-0001-4000-8000-000000000001', now(), now());
insert into app.checkpoint_results
  (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
   snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version, device_id,
   created_at, updated_at)
values (gen_random_uuid(), '1f000000-0000-4000-8000-0000000000fa', tests.user_a(), 'cp-1', 0,
        now(), 'gps', 'One', '[{"text":"kept"}]', '[]', '1', gen_random_uuid(), now(), now());

select throws_ok(
  format($$ insert into app.runs (id, user_id, quest_id, content_version, language, state,
                                  started_at, device_id, created_at, updated_at)
            values ('1f000000-0000-4000-8000-0000000000fb', %L, 'quest-race', '1', 'id', 'active',
                    '2026-08-10T09:00:00Z', 'dddddddd-0002-4000-8000-000000000002', now(), now()) $$,
         tests.user_a()),
  '23505', null,
  '4.3.7 the second device''s run violates runs_one_active_per_quest');

-- §9.5's resolution: keep the Run with more checkpoint_results, abandon the other, lose nothing.
update app.runs set state = 'abandoned', abandoned_at = now(), abandon_reason = 'userChoice',
                    revision = revision + 1, updated_at = now()
 where id = '1f000000-0000-4000-8000-0000000000fa';
select lives_ok(
  format($$ insert into app.runs (id, user_id, quest_id, content_version, language, state,
                                  started_at, device_id, created_at, updated_at)
            values ('1f000000-0000-4000-8000-0000000000fb', %L, 'quest-race', '1', 'id', 'active',
                    '2026-08-10T09:00:00Z', 'dddddddd-0002-4000-8000-000000000002', now(), now()) $$,
         tests.user_a()),
  '4.3.7b …and the second run inserts once the first is abandoned');
select is(
  (select count(*) from app.checkpoint_results where run_id = '1f000000-0000-4000-8000-0000000000fa'),
  1::bigint,
  '4.3.7c the abandoned run keeps its snapshots — neither run''s data is lost');

select * from finish();
rollback;
