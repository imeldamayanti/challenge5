-- b2 §3 — constraints and data integrity.
-- docs/backend-supabase.md §4.3–§4.7, §14 defects 4 and 10, FR-START-06, AD-2.

begin;
set local search_path to extensions, tests, app, public;
select no_plan();

select tests.as_user(tests.user_a());

-- =============================================================================================
-- 3.1 / 3.2 — FR-START-06, and why the index is PARTIAL on state = 'active'.
-- =============================================================================================
insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                      device_id, created_at, updated_at)
values ('1a000000-0000-4000-8000-00000000a001', tests.user_a(), 'quest-one', '2026.08.1', 'id',
        'active', now(), gen_random_uuid(), now(), now());

select throws_ok(
  format($$ insert into app.runs (id, user_id, quest_id, content_version, language, state,
                                  started_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, 'quest-one', '2026.08.1', 'id', 'active', now(),
                    gen_random_uuid(), now(), now()) $$, tests.user_a()),
  '23505', null,
  '3.1 a second ACTIVE run for the same (user, quest) violates runs_one_active_per_quest');

-- 3.2 — the seeded run for badung-empat-wajah is `completed`, so a new active one is allowed.
select lives_ok(
  format($$ insert into app.runs (id, user_id, quest_id, content_version, language, state,
                                  started_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, 'badung-empat-wajah', '2026.08.1', 'id', 'active',
                    now(), gen_random_uuid(), now(), now()) $$, tests.user_a()),
  '3.2 a new active run is allowed once the previous one is completed');

-- =============================================================================================
-- 3.3 — §14 defect 10. A plain unique would let a tombstone hold its own key forever, so the
-- walker could never re-arrive at a checkpoint whose result had been soft-deleted.
-- =============================================================================================
update app.checkpoint_results set deleted_at = now(), revision = revision + 1
 where id = '30000000-0000-4000-8000-000000000001';

select lives_ok(
  format($$ insert into app.checkpoint_results
              (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
               snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
               device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, %L, 'cp-pemecutan', 0, now(), 'gps',
                    'Puri Agung Pemecutan', '[]', '[]', '2026.08.1', gen_random_uuid(),
                    now(), now()) $$, tests.run_a(), tests.user_a()),
  '3.3 a checkpoint result can be re-inserted after the previous one is tombstoned');

-- =============================================================================================
-- 3.4 / 3.5 — §14 defect 4. `nulls not distinct` is what makes the letter case work at all.
-- =============================================================================================
select throws_ok(
  format($$ insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name,
                                    awarded_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, null, 'letter', 'sidequest-kumbasari',
                    'Surat dari Kumbasari', now(), gen_random_uuid(), now(), now()) $$,
         tests.user_a()),
  '23505', null,
  '3.4 two run_id-null awards with the same type and source_id are rejected (nulls not distinct)');

select lives_ok(
  format($$ insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name,
                                    awarded_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, '1a000000-0000-4000-8000-00000000a001', 'stamp',
                    'stamp-pemecutan', 'Cap Puri Agung Pemecutan', now(), gen_random_uuid(),
                    now(), now()) $$, tests.user_a()),
  '3.5 the same stamp earned on a different walk is a distinct award');

-- 3.6 / 3.7 — the type list, which will grow again (§15.8's `not valid` + `validate` pattern).
select lives_ok(
  format($$ insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name,
                                    awarded_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, null, 'letter', 'sidequest-catur-muka', 'Surat',
                    now(), gen_random_uuid(), now(), now()) $$, tests.user_a()),
  '3.6 awards.type = ''letter'' is accepted');

select throws_ok(
  format($$ insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name,
                                    awarded_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, null, 'trophy', 'x', 'X', now(), gen_random_uuid(),
                    now(), now()) $$, tests.user_a()),
  '23514', null, '3.7 awards.type = ''trophy'' is rejected');

-- =============================================================================================
-- 3.9–3.12, 3.15 — the check constraints on runs and checkpoint_results.
-- =============================================================================================
select throws_ok(
  format($$ insert into app.runs (id, user_id, quest_id, content_version, language, state,
                                  started_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, 'q', '1', 'id', 'notStarted', now(),
                    gen_random_uuid(), now(), now()) $$, tests.user_a()),
  '23514', null,
  '3.9 runs.state = ''notStarted'' is rejected — an in-memory-only state must not be representable');

select throws_ok(
  format($$ insert into app.runs (id, user_id, quest_id, content_version, language, state,
                                  started_at, completed_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, 'q2', '1', 'id', 'completed', now(), null,
                    gen_random_uuid(), now(), now()) $$, tests.user_a()),
  '23514', null, '3.10 a completed run with no completed_at is rejected');

select throws_ok(
  format($$ insert into app.runs (id, user_id, quest_id, content_version, language, state,
                                  started_at, abandoned_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, 'q3', '1', 'id', 'abandoned', now(), now(),
                    gen_random_uuid(), now(), now()) $$, tests.user_a()),
  '23514', null, '3.11 an abandoned run with no abandon_reason is rejected');

-- The en-dash guard. schema.md §B.7 writes the middle band as `20–75m`; the tokens are what the
-- column accepts, and one copy-paste between the documents is a violation nobody would look for.
select throws_ok(
  format($$ insert into app.checkpoint_results
              (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
               gps_accuracy_bucket, snapshot_place_name, snapshot_lore, snapshot_sources,
               snapshot_content_version, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, %L, 'cp-x', 9, now(), 'gps', '20-75m', 'X', '[]', '[]',
                    '1', gen_random_uuid(), now(), now()) $$, tests.run_a(), tests.user_a()),
  '23514', null, '3.12 gps_accuracy_bucket = ''20-75m'' is rejected — tokens only');
select lives_ok(
  format($$ insert into app.checkpoint_results
              (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
               gps_accuracy_bucket, snapshot_place_name, snapshot_lore, snapshot_sources,
               snapshot_content_version, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, %L, 'cp-y', 9, now(), 'gps', 'b20_75', 'Y', '[]', '[]',
                    '1', gen_random_uuid(), now(), now()) $$, tests.run_a(), tests.user_a()),
  '3.12b …and ''b20_75'' is accepted');

select throws_ok(
  format($$ insert into app.runs (id, user_id, quest_id, content_version, language, state,
                                  started_at, device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, 'q4', '1', 'jv', 'active', now(), gen_random_uuid(),
                    now(), now()) $$, tests.user_a()),
  '23514', null, '3.15 runs.language outside (id,en) is rejected');

select throws_ok(
  format($$ insert into app.checkpoint_results
              (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
               snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
               device_id, created_at, updated_at)
            values (gen_random_uuid(), %L, %L, 'cp-z', 9, now(), 'beacon', 'Z', '[]', '[]', '1',
                    gen_random_uuid(), now(), now()) $$, tests.run_a(), tests.user_a()),
  '23514', null, '3.15b arrival_method outside (gps,manual) is rejected');

select throws_ok(
  -- Paths supplied since 0015: they are NOT NULL, and without them this insert now fails on the
  -- path constraint before it ever reaches the content_type check this test is about.
  format($$ insert into app.photos (id, user_id, run_id, content_type, storage_path, thumb_path,
                                    captured_at, device_id,
                                    created_at, updated_at)
            values (gen_random_uuid(), %L, %L, 'image/png', 'u/r/p.heic', 'u/r/p_t.heic',
                    now(), gen_random_uuid(), now(), now()) $$,
         tests.user_a(), tests.run_a()),
  '23514', null, '3.15c photos.content_type outside (image/heic,image/jpeg) is rejected');

select throws_ok(
  format($$ insert into app.task_results
              (id, checkpoint_result_id, run_id, user_id, task_id, type, skipped, completed_at,
               device_id, created_at, updated_at)
            values (gen_random_uuid(), '30000000-0000-4000-8000-000000000002', %L, %L, 't', 'audio',
                    false, now(), gen_random_uuid(), now(), now()) $$,
         tests.run_a(), tests.user_a()),
  '23514', null, '3.15d task_results.type outside (photo,reflection,question) is rejected');

-- =============================================================================================
-- 3.8 — ops.suppressions, and the schema-2 document the trigger regenerates (§6.1).
-- =============================================================================================
select tests.reset_role();
select lives_ok(
  $$ insert into ops.suppressions (entity_type, entity_id, reason)
     values ('sidequest', 'sidequest-kumbasari', 'story withdrawn at the family''s request') $$,
  '3.8 suppressions.entity_type = ''sidequest'' is accepted');
select throws_ok(
  $$ insert into ops.suppressions (entity_type, entity_id, reason)
     values ('region', 'badung', 'x') $$,
  '23514', null, '3.8b an unknown entity_type is rejected');

select is(
  (select document->>'schemaVersion' from ops.suppressions_document),
  '2', '3.8c the published document is schema 2');
select is(
  (select document->'suppressedSideQuestIds' from ops.suppressions_document),
  '["sidequest-kumbasari"]'::jsonb,
  '3.8d …and the trigger put the withdrawn sidequest into it');
select is(
  (select document->'suppressedPlaceIds' from ops.suppressions_document),
  '[]'::jsonb, '3.8e …with the other arrays present and empty, not absent');

-- =============================================================================================
-- 3.13 / 3.14 — cascade and set-null. Deletes here run as the owner: no client can reach them.
-- =============================================================================================
select is((select count(*) from app.checkpoint_results where run_id = tests.run_a()), 4::bigint,
  '3.13 A''s run has its checkpoint results before the delete');
delete from app.runs where id = tests.run_a();
select is((select count(*) from app.checkpoint_results where run_id = tests.run_a()), 0::bigint,
  '3.13b deleting a run cascades to its checkpoint results');
select is((select count(*) from app.task_results where run_id = tests.run_a()), 0::bigint,
  '3.13c …and to its task results, leaving no orphans');

-- 3.14 needs a run that still exists.
insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                      device_id, created_at, updated_at)
values ('1c000000-0000-4000-8000-0000000000c1', tests.user_a(), 'quest-photo', '1', 'id',
        'active', now(), gen_random_uuid(), now(), now());
-- Paths supplied since 0015 (NOT NULL): §4.7 writes them at insert, before the bytes exist.
insert into app.photos (id, user_id, run_id, storage_path, thumb_path,
                        captured_at, device_id, created_at, updated_at)
values ('2c000000-0000-4000-8000-0000000000c2', tests.user_a(),
        '1c000000-0000-4000-8000-0000000000c1',
        'u/r/2c.heic', 'u/r/2c_t.heic', now(), gen_random_uuid(), now(), now());
insert into app.checkpoint_results
  (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
   snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version,
   device_id, created_at, updated_at)
values ('3c000000-0000-4000-8000-0000000000c3', '1c000000-0000-4000-8000-0000000000c1',
        tests.user_a(), 'cp-p', 0, now(), 'gps', 'P', '[]', '[]', '1', gen_random_uuid(),
        now(), now());
insert into app.task_results
  (id, checkpoint_result_id, run_id, user_id, task_id, type, skipped, photo_id, completed_at,
   device_id, created_at, updated_at)
values ('4c000000-0000-4000-8000-0000000000c4', '3c000000-0000-4000-8000-0000000000c3',
        '1c000000-0000-4000-8000-0000000000c1', tests.user_a(), 'task-photo', 'photo', false,
        '2c000000-0000-4000-8000-0000000000c2', now(), gen_random_uuid(), now(), now());

delete from app.photos where id = '2c000000-0000-4000-8000-0000000000c2';
select is((select count(*) from app.task_results where id = '4c000000-0000-4000-8000-0000000000c4'),
  1::bigint, '3.14 deleting a photo leaves the task result standing');
select is((select photo_id from app.task_results where id = '4c000000-0000-4000-8000-0000000000c4'),
  null, '3.14b …with photo_id set to null rather than the row removed');

-- =============================================================================================
-- 3.15 / 3.16 — migration 0015. Two defects found by reading the deployed schema back.
-- =============================================================================================

-- §2.4: "NFR-PRIV-02/03/05 are enforced by the ABSENCE OF COLUMNS, not by a policy somebody has to
-- remember." A dwell measurement on a user_id-keyed row is the thing that sentence forbids, and
-- asserting its absence is the only way that stays true — a re-added column would otherwise be
-- caught by nobody. NFR-OBS-06 is met by the anonymous `checkpoint_departed` event in ops.events.
select hasnt_column('app', 'checkpoint_results', 'lore_dwell_ms',
  '3.17 no per-user dwell measurement may sit beside user_id');

-- …while the FR-CP-04 fact that lore was opened is NOT a measurement and must stay.
select has_column('app', 'checkpoint_results', 'lore_first_opened_at',
  '3.17b …but the fact that lore was opened is not a duration, and stays');

-- §4.7 writes the photo row BEFORE the bytes, precisely so a failure leaves a resumable row; and
-- FR-SET-02 deletes by path unconditionally. A null path is an object nothing can find or erase —
-- "a privacy failure that passes every database test", in §4.7's own words.
select col_not_null('app', 'photos', 'storage_path',
  '3.18 a photo row without a full-size path cannot be resumed or erased');
select col_not_null('app', 'photos', 'thumb_path',
  '3.18b FR-SET-02 deletes two objects per row, so the thumb path is load-bearing too');

-- The insert that proves it, rather than only the catalog: paths omitted must be refused.
select throws_ok($$
  insert into app.photos (id, user_id, captured_at, device_id, created_at, updated_at)
  values ('4d000000-0000-4000-8000-0000000000d1', tests.user_a(), now(), gen_random_uuid(),
          now(), now())
$$, '23502', null, '3.18c inserting a photo with no paths is refused, not stored');

-- =============================================================================================
-- 3.19 / 3.20 — migration 0016. Index hygiene and the timeout 0002 forgot.
-- =============================================================================================

-- No index may be a strict PREFIX of another index on the same table. A B-tree on (a,b) serves
-- `where a = ?` exactly as well as one on (a), so the shorter one earns nothing and costs a write
-- on every insert and every update touching the column — on the sync tables, the hottest path
-- there is. Eight of these shipped; this is what stops a ninth.
select is_empty($$
  with idx as (
    select n.nspname sch, t.relname tbl, i.relname idx,
           (select array_agg(a.attname order by k.ord)
              from unnest(ix.indkey::int[]) with ordinality k(att, ord)
              join pg_attribute a on a.attrelid = t.oid and a.attnum = k.att) cols,
           ix.indisunique, pg_get_expr(ix.indpred, ix.indrelid) pred
      from pg_index ix
      join pg_class i on i.oid = ix.indexrelid
      join pg_class t on t.oid = ix.indrelid
      join pg_namespace n on n.oid = t.relnamespace
     where n.nspname in ('app','ops'))
  select a.sch || '.' || a.tbl || ': ' || a.idx || ' is a prefix of ' || b.idx
    from idx a join idx b
      on a.sch = b.sch and a.tbl = b.tbl and a.idx <> b.idx
     and b.cols[1:array_length(a.cols,1)] = a.cols
     and array_length(b.cols,1) > array_length(a.cols,1)
   where a.pred is null and b.pred is null and not a.indisunique
$$, '3.19 no index is a redundant prefix of another on the same table');

-- …and none duplicates the primary key outright, which app.profiles did.
select is_empty($$
  select n.nspname || '.' || t.relname || ': ' || i.relname
    from pg_index ix
    join pg_class i on i.oid = ix.indexrelid
    join pg_class t on t.oid = ix.indrelid
    join pg_namespace n on n.oid = t.relnamespace
   where n.nspname in ('app','ops') and not ix.indisprimary
     and exists (select 1 from pg_index p
                  where p.indrelid = ix.indrelid and p.indisprimary
                    and p.indkey::int[] = ix.indkey::int[])
$$, '3.19b no index duplicates its table primary key');

-- Every foreign key still has an index whose LEADING column is the referencing column. Asserted
-- AFTER the drops, because "dropped a redundant index" and "dropped the FK support" look identical
-- until something does a cascading delete on a big table.
select is_empty($$
  select c.conrelid::regclass::text || ' (' || a.attname || ')'
    from pg_constraint c
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
    join pg_class cl on cl.oid = c.conrelid
    join pg_namespace n on n.oid = cl.relnamespace
   where c.contype = 'f' and n.nspname in ('app','ops')
     and not exists (select 1 from pg_index i
                      where i.indrelid = c.conrelid and a.attnum = i.indkey[0])
$$, '3.19c every foreign key still has a leading-column index');

-- 0002 set timeouts on authenticated and anon and forgot service_role — the role all four Edge
-- Functions run as, the only one that bypasses RLS, and the only one that interleaves Postgres
-- work with Storage HTTP calls inside a transaction.
select isnt_empty($$
  select 1 from pg_db_role_setting s join pg_roles r on r.oid = s.setrole
   where r.rolname = 'service_role'
     and array_to_string(s.setconfig, ',') like '%statement_timeout%'
$$, '3.20 service_role has a statement timeout');
select isnt_empty($$
  select 1 from pg_db_role_setting s join pg_roles r on r.oid = s.setrole
   where r.rolname = 'service_role'
     and array_to_string(s.setconfig, ',') like '%idle_in_transaction_session_timeout%'
$$, '3.20b …and an idle-in-transaction timeout, which is the one that holds the vacuum horizon');

-- =============================================================================================
-- 3.21 — migration 0017. Retention that exists AND runs.
-- =============================================================================================

select has_function('ops', 'prune_events', '3.21 the retention horizon exists');

-- service_role only. A definer function that deletes rows is exactly the shape §8.1 case 3 warns
-- about, so the grant is the guard.
select is_empty($$
  select 1 where has_function_privilege('anon', 'ops.prune_events(interval)', 'execute')
              or has_function_privilege('authenticated', 'ops.prune_events(interval)', 'execute')
$$, '3.21b no client role may execute the retention delete');

-- It actually removes old rows and actually spares recent ones — asserted by inserting on both
-- sides of the horizon rather than by trusting the interval arithmetic.
insert into ops.events (id, name, params, schema_version, occurred_at, received_at) values
  ('5a000000-0000-4000-8000-0000000000a1','old','{}',1, now() - interval '400 days', now() - interval '400 days'),
  ('5a000000-0000-4000-8000-0000000000a2','new','{}',1, now(), now());
select is(ops.prune_events(), 1::bigint, '3.21c the row past the horizon is removed');
select is((select count(*) from ops.events where id = '5a000000-0000-4000-8000-0000000000a2'),
  1::bigint, '3.21d …and the recent row is untouched');

-- FR-SURV / FR-ERR-10: survey responses are the study, not telemetry. A retention job that aged
-- them out would delete the research while looking like hygiene.
insert into ops.survey_responses (id, run_key, quest_id, question_id, response, occurred_at, received_at)
values ('5b000000-0000-4000-8000-0000000000b1', gen_random_uuid(), 'q', 'q1', 'ingat',
        now() - interval '400 days', now() - interval '400 days');
select ops.prune_events();
select is((select count(*) from ops.survey_responses where id = '5b000000-0000-4000-8000-0000000000b1'),
  1::bigint, '3.21e survey responses are never pruned by the events horizon');

-- And it is SCHEDULED. A retention function nobody calls is a policy that never executes — the
-- same gap publish-suppressions was written to close.
select isnt_empty($$select 1 from cron.job where jobname = 'ops-prune-events'$$,
  '3.21f the retention job is actually scheduled');

-- =============================================================================================
-- 3.22 — migration 0018. The guard that matters more than the migration.
-- =============================================================================================

-- Every table carrying `server_seq` is part of the delta-sync set, and §15.7 requires the tightened
-- autovacuum thresholds on all of them: tombstones mean rows are never removed, and every sync
-- update bumps an INDEXED column, which rules out a HOT update and leaves a dead tuple plus fresh
-- index entries per write.
--
-- Keyed on the COLUMN, never on a list of table names. A hand-maintained list is exactly what
-- failed: 0010 tuned the five tables that existed, 0012 added journal_entries and share_cards, and
-- nothing noticed for six migrations. This fails the moment a syncable table is added untuned.
select is_empty($$
  select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'app' and c.relkind = 'r'
     and exists (select 1 from pg_attribute a
                  where a.attrelid = c.oid and a.attname = 'server_seq' and not a.attisdropped)
     and (c.reloptions is null
          or not (array_to_string(c.reloptions, ',') like '%autovacuum_vacuum_scale_factor%'))
$$, '3.22 every syncable table has the §15.7 autovacuum tuning');

select * from finish();
rollback;
