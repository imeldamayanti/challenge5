-- seed.sql — LOCAL DEVELOPMENT AND TESTS ONLY.
--
-- `supabase db reset` runs this; `supabase db push` does NOT. That is the guard that keeps pgTAP
-- and these fixtures out of any deployed database (b1 §6).
--
-- Nothing here resembles a real person's walk, and there are no content rows: content comes from
-- ContentKit, not from the database (b0 D5).
--
-- DEVIATION FROM b2 §0: the plan lists `supabase/tests/00_setup.sql` as the place the pgTAP
-- extension and the `tests.as_user` helper live. `supabase test db` hands its whole directory to
-- pg_prove, which runs every .sql file it finds as a test — and a file with no plan is reported as
-- a failure rather than skipped. Setup therefore lives here, in the file the CLI already runs
-- immediately before the tests and never runs against a deployed project.

create extension if not exists pgtap with schema extensions;
-- Two real sessions, for the §6 concurrency tests. pgTAP runs in one transaction and a deadlock
-- needs two.
create extension if not exists dblink with schema extensions;

create schema if not exists tests;

-- ---------------------------------------------------------------------------------------------
-- Assuming a user.
--
-- RLS keys on auth.uid(), which reads a JWT claim, so tests set the claim directly.
-- `set_config(..., true)` is transaction-local, so each test unwinds cleanly.
--
-- TESTS MUST RUN AS `authenticated`, NEVER AS `postgres`. The owner carries BYPASSRLS, so every
-- isolation assertion below would pass against a table with no policies at all (§8.1 case 4).
-- 01_structure.test.sql asserts the harness itself is not a superuser for exactly that reason.
-- ---------------------------------------------------------------------------------------------
create or replace function tests.as_user(uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', uid, 'role', 'authenticated')::text, true),
         set_config('role', 'authenticated', true);
$$;

-- A request with the publishable key and no session: role `anon`, and no `sub` claim at all.
create or replace function tests.as_anon() returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true),
         set_config('role', 'anon', true);
$$;

-- `authenticated` with no `sub`. Separates the two failure modes the design cares about: the
-- grants layer refusing `anon` outright, and auth.uid() being null so the comparison DENIES rather
-- than errors (§8.2, last assertion).
create or replace function tests.as_authenticated_without_sub() returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('role', 'authenticated')::text, true),
         set_config('role', 'authenticated', true);
$$;

create or replace function tests.reset_role() returns void language plpgsql as $$
begin
  reset role;
  perform set_config('request.jwt.claims', '', true);
end $$;

-- §7's plan-shape assertions are made against `explain (format json)` rather than against timing,
-- so they are stable in CI (b2 §7).
create or replace function tests.plan_json(q text) returns jsonb language plpgsql as $$
declare
  out_json jsonb;
begin
  execute 'explain (format json, costs off) ' || q into out_json;
  return out_json;
end $$;

-- Fixed ids so every test file can refer to them without a lookup.
create or replace function tests.user_a() returns uuid language sql immutable as
  $$ select '11111111-1111-4111-8111-111111111111'::uuid $$;
create or replace function tests.user_b() returns uuid language sql immutable as
  $$ select '22222222-2222-4222-8222-222222222222'::uuid $$;
-- Anonymous, ninety-one days idle, owns nothing: §7.4's only deletable shape.
create or replace function tests.user_empty_anon() returns uuid language sql immutable as
  $$ select '33333333-3333-4333-8333-333333333333'::uuid $$;
-- Anonymous, equally idle, owns ONE run: never culled, at any age.
create or replace function tests.user_walked_anon() returns uuid language sql immutable as
  $$ select '44444444-4444-4444-8444-444444444444'::uuid $$;

create or replace function tests.run_a() returns uuid language sql immutable as
  $$ select '10000000-0000-4000-8000-000000000001'::uuid $$;

-- The helpers have to remain callable AFTER a test has assumed `authenticated` or `anon`, which is
-- the whole point of them.
grant usage on schema tests to authenticated, anon;
grant execute on all functions in schema tests to authenticated, anon;

-- ---------------------------------------------------------------------------------------------
-- Identities.
-- ---------------------------------------------------------------------------------------------
insert into auth.users
  (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
   created_at, updated_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_anonymous)
values
  ('00000000-0000-0000-0000-000000000000', tests.user_a(), 'authenticated', 'authenticated',
   'walker-a@example.test', crypt('walker-a-password', gen_salt('bf')), now(),
   now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}', false),
  ('00000000-0000-0000-0000-000000000000', tests.user_b(), 'authenticated', 'authenticated',
   'walker-b@example.test', crypt('walker-b-password', gen_salt('bf')), now(),
   now(), now(), now(), '{"provider":"email","providers":["email"]}', '{}', false),
  ('00000000-0000-0000-0000-000000000000', tests.user_empty_anon(), 'authenticated', 'authenticated',
   null, null, null,
   now() - interval '120 days', now() - interval '91 days', now() - interval '91 days',
   '{"provider":"anonymous","providers":["anonymous"]}', '{}', true),
  ('00000000-0000-0000-0000-000000000000', tests.user_walked_anon(), 'authenticated', 'authenticated',
   null, null, null,
   now() - interval '120 days', now() - interval '91 days', now() - interval '91 days',
   '{"provider":"anonymous","providers":["anonymous"]}', '{}', true)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------------------------
-- User A's single walk. User B owns NOTHING — that is the fixture, not an oversight (b2 §2).
-- ---------------------------------------------------------------------------------------------
insert into app.profiles (user_id, display_name, preferred_language)
values (tests.user_a(), 'Walker A', 'id'), (tests.user_b(), 'Walker B', 'en');

insert into app.runs
  (id, user_id, quest_id, content_version, language, state, current_checkpoint_index,
   started_at, completed_at, device_id, revision, created_at, updated_at)
values
  (tests.run_a(), tests.user_a(), 'badung-empat-wajah', '2026.08.1', 'id', 'completed', 5,
   now() - interval '2 days', now() - interval '2 days' + interval '90 minutes',
   '99999999-9999-4999-8999-999999999999', 1, now() - interval '2 days', now() - interval '2 days');

insert into app.photos
  (id, user_id, run_id, checkpoint_id, storage_path, thumb_path, content_type,
   width_px, height_px, byte_size, captured_at, uploaded_at, device_id, created_at, updated_at)
values
  ('20000000-0000-4000-8000-000000000001', tests.user_a(), tests.run_a(), 'cp-pemecutan',
   tests.user_a() || '/' || tests.run_a() || '/20000000-0000-4000-8000-000000000001.heic',
   tests.user_a() || '/' || tests.run_a() || '/20000000-0000-4000-8000-000000000001_t.heic',
   'image/heic', 1600, 1200, 285000, now() - interval '2 days', now() - interval '2 days',
   '99999999-9999-4999-8999-999999999999', now() - interval '2 days', now() - interval '2 days'),
  ('20000000-0000-4000-8000-000000000002', tests.user_a(), tests.run_a(), 'cp-maospahit',
   tests.user_a() || '/' || tests.run_a() || '/20000000-0000-4000-8000-000000000002.heic',
   tests.user_a() || '/' || tests.run_a() || '/20000000-0000-4000-8000-000000000002_t.heic',
   'image/heic', 1600, 1200, 291000, now() - interval '2 days', null,
   '99999999-9999-4999-8999-999999999999', now() - interval '2 days', now() - interval '2 days');

insert into app.checkpoint_results
  (id, run_id, user_id, checkpoint_id, order_index, arrived_at, arrival_method,
   gps_accuracy_bucket, snapshot_place_name, snapshot_lore, snapshot_sources,
   snapshot_content_version, device_id, created_at, updated_at)
values
  ('30000000-0000-4000-8000-000000000001', tests.run_a(), tests.user_a(), 'cp-pemecutan', 0,
   now() - interval '2 days', 'gps', 'lt20', 'Puri Agung Pemecutan',
   '[{"text":"…","accuracy":"documented","sourceCitations":["src-1"]}]', '[{"id":"src-1"}]',
   '2026.08.1', '99999999-9999-4999-8999-999999999999',
   now() - interval '2 days', now() - interval '2 days'),
  ('30000000-0000-4000-8000-000000000002', tests.run_a(), tests.user_a(), 'cp-maospahit', 1,
   now() - interval '2 days', 'manual', null, 'Pura Maospahit',
   '[{"text":"…","accuracy":"oral","sourceCitations":[]}]', '[]',
   '2026.08.1', '99999999-9999-4999-8999-999999999999',
   now() - interval '2 days', now() - interval '2 days');

insert into app.task_results
  (id, checkpoint_result_id, run_id, user_id, task_id, type, skipped, answer_text, photo_id,
   completed_at, device_id, created_at, updated_at)
values
  ('40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000001', tests.run_a(),
   tests.user_a(), 'task-reflect-1', 'reflection', false, 'Sepi, dan lebih tua dari yang saya kira.',
   null, now() - interval '2 days', '99999999-9999-4999-8999-999999999999',
   now() - interval '2 days', now() - interval '2 days'),
  ('40000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000001', tests.run_a(),
   tests.user_a(), 'task-photo-1', 'photo', false, null,
   '20000000-0000-4000-8000-000000000001', now() - interval '2 days',
   '99999999-9999-4999-8999-999999999999', now() - interval '2 days', now() - interval '2 days'),
  ('40000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000002', tests.run_a(),
   tests.user_a(), 'task-question-1', 'question', true, null, null, now() - interval '2 days',
   '99999999-9999-4999-8999-999999999999', now() - interval '2 days', now() - interval '2 days');

insert into app.awards
  (id, user_id, run_id, type, source_id, snapshot_name, awarded_at, device_id, created_at, updated_at)
values
  ('50000000-0000-4000-8000-000000000001', tests.user_a(), tests.run_a(), 'stamp',
   'stamp-pemecutan', 'Cap Puri Agung Pemecutan', now() - interval '2 days',
   '99999999-9999-4999-8999-999999999999', now() - interval '2 days', now() - interval '2 days'),
  -- run_id null: a letter belongs to a SideQuestRecord, not a Run (§4.5). This is the row shape
  -- `nulls not distinct` exists for.
  ('50000000-0000-4000-8000-000000000002', tests.user_a(), null, 'letter',
   'sidequest-kumbasari', 'Surat dari Kumbasari', now() - interval '2 days',
   '99999999-9999-4999-8999-999999999999', now() - interval '2 days', now() - interval '2 days');

insert into app.journal_entries
  (id, user_id, run_id, title, body, device_id, created_at, updated_at)
values
  ('60000000-0000-4000-8000-000000000001', tests.user_a(), tests.run_a(), 'Empat wajah',
   'Catatan singkat.', '99999999-9999-4999-8999-999999999999',
   now() - interval '2 days', now() - interval '2 days');

insert into app.share_cards
  (id, user_id, run_id, template, storage_path, device_id, created_at, updated_at)
values
  ('70000000-0000-4000-8000-000000000001', tests.user_a(), tests.run_a(), 'classic',
   tests.user_a() || '/' || tests.run_a() || '/card.png',
   '99999999-9999-4999-8999-999999999999', now() - interval '2 days', now() - interval '2 days');

-- The anonymous walker who owns one run and must therefore survive every cull (§7.4).
insert into app.runs
  (id, user_id, quest_id, content_version, language, state, started_at, device_id,
   created_at, updated_at)
values
  ('10000000-0000-4000-8000-000000000009', tests.user_walked_anon(), 'badung-empat-wajah',
   '2026.08.1', 'id', 'active', now() - interval '95 days',
   '88888888-8888-4888-8888-888888888888', now() - interval '95 days', now() - interval '95 days');
