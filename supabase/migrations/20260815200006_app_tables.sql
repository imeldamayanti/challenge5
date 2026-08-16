-- 0006 — `app`: the user's data.
-- docs/backend-supabase.md §4.2–§4.7, §2.2, §2.3.
--
-- THE MOST IMPORTANT LINE IN THIS FILE IS AN ABSENCE. `quest_id`, `checkpoint_id`, `place_id`,
-- `source_id` are `text` and are NOT foreign keys to any content table (§2.2). Content is replaced
-- wholesale and user data is permanent; a foreign key between them means a content correction can
-- cascade-delete somebody's completed walk (system-design.md §4, schema.md §C.3 rule 1).

-- --------------------------------------------------------------------------------------------
-- §4.2 Profile — deliberately thin, and NOT syncable (it carries no server_seq: it is absent from
-- §9.2's push order, and a table that syncs needs a cursor).
-- Counts on the Profile screen are derived from app.runs and app.awards, never stored as
-- denormalised counters that can drift.
-- --------------------------------------------------------------------------------------------
create table app.profiles (
  user_id            uuid primary key references auth.users(id) on delete cascade,
  display_name       text,
  avatar_path        text,
  preferred_language text check (preferred_language in ('id','en')),
  -- §15.3: "a `deleting` flag the upload path checks before its final PUT". FR-SET-02 deletion
  -- races an in-flight upload, and the object that lands afterwards has no row — unreachable,
  -- undeletable, and still personal data. The flag narrows that race; the orphan sweeper (§4.7) is
  -- the backstop, because a narrowed race is not a closed one. Not in the published §4.2 DDL,
  -- which predates §15.3.
  deleting_at        timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- --------------------------------------------------------------------------------------------
-- §4.3 Runs
-- --------------------------------------------------------------------------------------------
create table app.runs (
  id                       uuid primary key,                              -- UUIDv7 on device (§2.3)
  user_id                  uuid not null references auth.users(id) on delete cascade,
  quest_id                 text not null,        -- content reference. NOT a foreign key (§2.2)
  content_version          text not null,        -- pinned at start (AD-4)
  language                 text not null check (language in ('id','en')),
  -- `notStarted` is absent on purpose: it is a client-side state that is never persisted locally
  -- either, and a state that only exists in memory should not be representable in the database.
  state                    text not null check (state in ('active','completed','abandoned')),
  current_checkpoint_index int  not null default 0,
  started_at               timestamptz not null,
  completed_at             timestamptz,
  abandoned_at             timestamptz,
  abandon_reason           text check (abandon_reason in ('userChoice','placeSuppressed')),

  device_id  uuid   not null,                 -- which device authored this revision (FR-SYNC-02)
  revision   bigint not null default 1,       -- bumped by the device on each local write
  created_at timestamptz not null,            -- device clock; display only
  updated_at timestamptz not null,            -- device clock; display only, NEVER a sync cursor
  server_seq bigint not null default nextval('app.sync_seq'),
  deleted_at timestamptz,                     -- tombstone; never hard-deleted (schema.md §C.3 r3)

  constraint runs_completed_has_timestamp
    check ((state <> 'completed') or (completed_at is not null)),
  constraint runs_abandoned_has_reason
    check ((state <> 'abandoned') or (abandoned_at is not null and abandon_reason is not null))
);

-- --------------------------------------------------------------------------------------------
-- §4.7 Photos — created before task_results, which references it (§9.2 push order, §14 defect 5)
-- --------------------------------------------------------------------------------------------
create table app.photos (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  run_id        uuid references app.runs(id) on delete cascade,
  checkpoint_id text,

  -- Object NAMES, with NO bucket prefix (§14 defect 13). Supabase keeps the bucket in
  -- storage.objects.bucket_id, not in `name`, so 'trip-photos/{user_id}/…' would make the §8.3
  -- policy compare 'trip-photos' against auth.uid() and never match — and the symptom is uploads
  -- failing for a reason the error does not name.
  --   full  '{user_id}/{run_id}/{id}.heic'     1600 px long edge
  --   thumb '{user_id}/{run_id}/{id}_t.heic'    400 px long edge
  storage_path text,
  thumb_path   text,

  content_type text check (content_type in ('image/heic','image/jpeg')),
  width_px     int,        -- of the full derivative, so a grid can lay out before downloading
  height_px    int,
  byte_size    int,        -- full + thumb, for FR-SET-03's storage report and orphan detection

  captured_at  timestamptz not null,
  uploaded_at  timestamptz,   -- null until the bytes are actually on the server (§4.7 ordering)

  device_id  uuid not null,
  revision   bigint not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  server_seq bigint not null default nextval('app.sync_seq'),
  deleted_at timestamptz
);

comment on table app.photos is
  'Checkpoint photographs only. A sidequest photograph has NO row here at all: FR-SIDE-13 and NFR-PRIV-01 keep it on the device with no opt-in that reverses it (design §4.7).';

-- --------------------------------------------------------------------------------------------
-- §4.4 Checkpoint results — where the snapshot lives
-- --------------------------------------------------------------------------------------------
create table app.checkpoint_results (
  id            uuid primary key,
  run_id        uuid not null references app.runs(id) on delete cascade,
  user_id       uuid not null references auth.users(id) on delete cascade,
  checkpoint_id text not null,
  order_index   int  not null,

  arrived_at     timestamptz not null,
  arrival_method text not null check (arrival_method in ('gps','manual')),
  -- Tokens, not punctuation. schema.md §B.7 writes the middle band with an en dash (`20–75m`);
  -- one copy-paste between the documents is a runtime constraint violation nobody would look for.
  -- The server stores a BUCKET, not the metre figure the device keeps: a precise accuracy reading
  -- beside a checkpoint id and a timestamp is a location trace by another name (NFR-PRIV-02).
  gps_accuracy_bucket  text check (gps_accuracy_bucket in ('lt20','b20_75','gt75')),
  lore_first_opened_at timestamptz,
  lore_dwell_ms        int,
  stamp_awarded_at     timestamptz,

  -- Content snapshot, captured on device at arrival (system-design §4.1). Stored, never derived.
  -- No `check` on the shape of snapshot_lore: the snapshot's meaning may only ever be ADDED to
  -- (schema.md §C.3 rule 2), and a JSON-shape constraint turns that additive rule into a migration.
  snapshot_place_name      text  not null,
  snapshot_lore            jsonb not null,   -- [{text, accuracy, sourceCitations[]}]
  snapshot_sources         jsonb not null,
  snapshot_content_version text  not null,

  device_id  uuid not null,
  revision   bigint not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  server_seq bigint not null default nextval('app.sync_seq'),
  deleted_at timestamptz
);

comment on column app.checkpoint_results.snapshot_lore is
  'NEVER indexed. Nothing queries inside it — §2.2 forbids the server joining a summary to content. A GIN index here is pure write amplification serving no query, and adding one LOOKS like diligence.';

-- --------------------------------------------------------------------------------------------
-- §4.5 Task results, awards
-- --------------------------------------------------------------------------------------------
create table app.task_results (
  id                   uuid primary key,
  checkpoint_result_id uuid not null references app.checkpoint_results(id) on delete cascade,
  run_id               uuid not null references app.runs(id) on delete cascade,
  user_id              uuid not null references auth.users(id) on delete cascade,
  task_id              text not null,
  type                 text not null check (type in ('photo','reflection','question')),
  skipped              boolean not null,   -- a first-class outcome, not a failure (AD-2)
  answer_text          text,
  -- Nullable and `set null`: a photo the user later removes must not take the record of the task
  -- with it (§4.5).
  photo_id             uuid references app.photos(id) on delete set null,
  completed_at         timestamptz not null,

  device_id  uuid not null,
  revision   bigint not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  server_seq bigint not null default nextval('app.sync_seq'),
  deleted_at timestamptz
);

create table app.awards (
  id      uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  -- null = cross-quest badge (v2), and null for every letter (§4.5, s2 §1)
  run_id  uuid references app.runs(id) on delete cascade,
  type          text not null check (type in ('stamp','badge','letter')),
  source_id     text not null,   -- stampId / badgeId from content; sideQuestId for a letter
  snapshot_name text not null,   -- survives content changes
  awarded_at    timestamptz not null,

  device_id  uuid not null,
  revision   bigint not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  server_seq bigint not null default nextval('app.sync_seq'),
  deleted_at timestamptz
);

-- --------------------------------------------------------------------------------------------
-- §4.1's trigger, on every syncable table.
-- Named `<table>_stamp_seq`; 0011's conflict trigger is named `<table>_resolve_conflict` so that
-- Postgres's alphabetical trigger order runs the conflict resolution FIRST.
-- --------------------------------------------------------------------------------------------
create trigger runs_stamp_seq before insert or update on app.runs
  for each row execute function app.stamp_server_seq();
create trigger photos_stamp_seq before insert or update on app.photos
  for each row execute function app.stamp_server_seq();
create trigger checkpoint_results_stamp_seq before insert or update on app.checkpoint_results
  for each row execute function app.stamp_server_seq();
create trigger task_results_stamp_seq before insert or update on app.task_results
  for each row execute function app.stamp_server_seq();
create trigger awards_stamp_seq before insert or update on app.awards
  for each row execute function app.stamp_server_seq();
