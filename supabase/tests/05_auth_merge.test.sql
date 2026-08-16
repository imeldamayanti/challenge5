-- b2 §5 — anonymous identities, the merge, and the cull predicate.
-- docs/backend-supabase.md §7, §7.3, §7.4, §9.5, §14 defects 20 and 21.
--
-- The half of §5 that is a property of the DATABASE lives here. The half that is a property of the
-- TOKENS — anonymous sign-in, linking, a forged anon token, an in-flight push queue — is proved
-- over HTTP against a running GoTrue in tests/http/, because that is where a JWT signature can
-- actually be checked (§7.3's whole argument for the merge being an Edge Function).

begin;
set local search_path to extensions, tests, app, public;
select no_plan();

-- =============================================================================================
-- 5.12 / 5.13 — the cull predicate. Supabase's own guidance is to periodically delete unused
-- anonymous users, and running that as written would silently delete the synced walks of exactly
-- the population §7.2 identifies as unrecoverable.
-- =============================================================================================
select is(
  (select count(*) from app.anonymous_cull_candidates()
    where user_id = tests.user_walked_anon()),
  0::bigint,
  '5.12 an anonymous user with ONE run is not deletable, at any age');

select is(
  (select count(*) from app.anonymous_cull_candidates()
    where user_id = tests.user_empty_anon()),
  1::bigint,
  '5.13 an anonymous user 91 days idle with no runs, journal or photos is deletable');

-- A journal entry alone is enough to keep them.
insert into app.journal_entries (id, user_id, body, device_id, created_at, updated_at)
values (gen_random_uuid(), tests.user_empty_anon(), 'satu catatan', gen_random_uuid(),
        now(), now());
select is(
  (select count(*) from app.anonymous_cull_candidates()
    where user_id = tests.user_empty_anon()),
  0::bigint,
  '5.13b …and a single journal entry takes them off the list again');
delete from app.journal_entries where user_id = tests.user_empty_anon();

-- A signed-in (non-anonymous) user is never a candidate whatever their age.
select is(
  (select count(*) from app.anonymous_cull_candidates('0 days'::interval)
    where user_id in (tests.user_a(), tests.user_b())),
  0::bigint,
  '5.13c a linked account is never a cull candidate');

-- =============================================================================================
-- 5.9 — refusing to merge an identity into itself.
-- =============================================================================================
select throws_ok(
  format($$ select app.merge_anonymous_rows(%L, %L) $$, tests.user_a(), tests.user_a()),
  'PT400', null,
  '5.9 merge where target_uid = anon_uid is rejected');

-- =============================================================================================
-- 5.6 — both identities hold the same quest active. §7.3 rule 2 resolves it the way §9.5 does:
-- keep the Run with more checkpoint_results, abandon the other, NEVER delete either.
-- =============================================================================================
-- The anonymous walker already owns an active run of badung-empat-wajah (seed.sql). Give user B
-- an active run of the same quest with more checkpoint results, and merge the anon into B.
insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                      device_id, created_at, updated_at)
values ('1b000000-0000-4000-8000-0000000000b9', tests.user_b(), 'badung-empat-wajah', '1', 'id',
        'active', now(), gen_random_uuid(), now(), now());
insert into app.checkpoint_results
  (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
   snapshot_place_name, snapshot_lore, snapshot_sources, snapshot_content_version, device_id,
   created_at, updated_at)
values (gen_random_uuid(), '1b000000-0000-4000-8000-0000000000b9', tests.user_b(), 'cp-1', 0,
        now(), 'gps', 'One', '[]', '[]', '1', gen_random_uuid(), now(), now());

-- And a letter held under BOTH identities, for 5.7. The anonymous copy is the LATER one.
insert into app.awards (id, user_id, run_id, type, source_id, snapshot_name, awarded_at,
                        device_id, created_at, updated_at)
values (gen_random_uuid(), tests.user_b(), null, 'letter', 'sidequest-shared', 'Surat',
        '2026-08-01T00:00:00Z', gen_random_uuid(), now(), now()),
       (gen_random_uuid(), tests.user_walked_anon(), null, 'letter', 'sidequest-shared', 'Surat',
        '2026-08-05T00:00:00Z', gen_random_uuid(), now(), now());

select lives_ok(
  format($$ select app.merge_anonymous_rows(%L, %L) $$,
         tests.user_walked_anon(), tests.user_b()),
  '5.6 the merge completes with a colliding active quest and a duplicate letter');

select is(
  (select count(*) from app.runs
    where user_id = tests.user_b() and quest_id = 'badung-empat-wajah'),
  2::bigint,
  '5.6b both runs survive the merge — neither is deleted');
select is(
  (select count(*) from app.runs
    where user_id = tests.user_b() and quest_id = 'badung-empat-wajah' and state = 'active'),
  1::bigint,
  '5.6c …and exactly one of them is still active');
select is(
  (select state from app.runs where id = '10000000-0000-4000-8000-000000000009'),
  'abandoned',
  '5.6d the run with fewer checkpoint results is the one abandoned');
select is(
  (select abandon_reason from app.runs where id = '10000000-0000-4000-8000-000000000009'),
  'userChoice', '5.6e …with the reason §7.3 rule 2 specifies');

-- 5.7 — the duplicate letter is DROPPED, not tombstoned: it was never a distinct award.
select is(
  (select count(*) from app.awards
    where user_id = tests.user_b() and source_id = 'sidequest-shared'),
  1::bigint, '5.7 only one copy of the shared letter survives');
select is(
  (select awarded_at from app.awards
    where user_id = tests.user_b() and source_id = 'sidequest-shared'),
  '2026-08-01T00:00:00Z'::timestamptz,
  '5.7b …and it is the earlier awarded_at that is kept');
select is(
  (select count(*) from app.awards
    where source_id = 'sidequest-shared' and deleted_at is not null),
  0::bigint, '5.7c …dropped rather than tombstoned');

-- Rule 5: the anonymous auth.users row goes last, in the same transaction.
select is(
  (select count(*) from auth.users where id = tests.user_walked_anon()),
  0::bigint, '5.6f the anonymous identity is gone once its rows have moved');

-- 5.5 — idempotent. It runs again after a dropped response and moves nothing the second time.
select lives_ok(
  format($$ select app.merge_anonymous_rows(%L, %L) $$,
         tests.user_walked_anon(), tests.user_b()),
  '5.5 a second run of the merge does not fail');
select is(
  ((select app.merge_anonymous_rows(tests.user_walked_anon(), tests.user_b()))->>'moved_runs')::int,
  0, '5.5b …and moves nothing');
select is(
  (select count(*) from app.runs
    where user_id = tests.user_b() and quest_id = 'badung-empat-wajah'),
  2::bigint, '5.5c …leaving the merged state exactly as it was');

-- =============================================================================================
-- The storage paths move with the rows (§7.3 rule 4). A row whose object name still begins with
-- the anonymous uid points at a path §8.3's policy no longer grants to anyone.
-- =============================================================================================
insert into app.runs (id, user_id, quest_id, content_version, language, state, started_at,
                      device_id, created_at, updated_at)
values ('1b000000-0000-4000-8000-0000000000ba', tests.user_empty_anon(), 'quest-paths', '1', 'id',
        'active', now(), gen_random_uuid(), now(), now());
insert into app.photos (id, user_id, run_id, storage_path, thumb_path, captured_at, device_id,
                        created_at, updated_at)
values ('2b000000-0000-4000-8000-0000000000bb', tests.user_empty_anon(),
        '1b000000-0000-4000-8000-0000000000ba',
        tests.user_empty_anon() || '/1b000000-0000-4000-8000-0000000000ba/p.heic',
        tests.user_empty_anon() || '/1b000000-0000-4000-8000-0000000000ba/p_t.heic',
        now(), gen_random_uuid(), now(), now());

select is(
  ((select app.merge_anonymous_rows(tests.user_empty_anon(), tests.user_a()))->>'moved_runs')::int,
  1, 'the merge moves the anonymous walker''s one run onto the target account');
select is(
  (select storage_path from app.photos where id = '2b000000-0000-4000-8000-0000000000bb'),
  tests.user_a() || '/1b000000-0000-4000-8000-0000000000ba/p.heic',
  'the full derivative''s object name is rewritten to the target uid');
select is(
  (select thumb_path from app.photos where id = '2b000000-0000-4000-8000-0000000000bb'),
  tests.user_a() || '/1b000000-0000-4000-8000-0000000000ba/p_t.heic',
  'and so is the thumbnail''s — both derivatives sit under the same prefix (§8.3)');

select * from finish();
rollback;
