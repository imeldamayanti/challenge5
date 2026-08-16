# Backend Design — Supabase

**Status: design only, and now committed to.** Nothing here is implemented yet, and none of it is a
dependency of the app as it stands today. This document decides the shape of the server so that v2
(accounts + sync) and v3 (CMS) can be built without renegotiating the architecture, and so the
screens the app-flow chart draws — login, journal, share, recommendations — have somewhere to live.

**Accounts are decided (§13.1, 2026-08-15).** The deciding requirement is photograph storage. The
credential is required at upload, never at quest start — `AD-3` and `FR-START-08` between them make
a login wall at Start unwalkable in the field (§7.1).

**Companions:** [`system-design.md`](system-design.md) (§1 Edge Services, §4 two stores, §15 seams),
[`schema.md`](schema.md) (Part B local persistence, Part C migration).
**Requirements:** `.claude/prds/cultural-heritage-quest.full.prd.md`.

**Revised 2026-08-15**, in two passes:

1. *Sidequests* (`.claude/plans/sidequest/`, PRD §5.15 `FR-SIDE-*`, still `PROPOSED — NOT ACCEPTED`)
   — §6.1 suppressions carry sidequests, §6.2 gains the sidequest event rows, §4.5 `awards.type`
   gains `letter`, §4.7 records that sidequest photographs never reach this schema at all.
2. *Accounts decided* — §7 rewritten with the gate table, the email-collision merge (§7.3) and the
   anonymous-retention policy (§7.4); §4.7 rebuilt for two derivatives and a row-before-upload
   ordering; §9 corrected throughout; §13.1 and §13.3 settled.
3. *Postgres review* — §2.3 pins **UUIDv7**; §8 gains the grants layer, the four accidental RLS
   bypasses and a pgTAP suite; §15 is new and covers N+1, lock ordering, the races specific to this
   design, indexes, bloat, and non-locking migrations.

**§14 is the defect ledger for this document.** Thirteen silent failures were found in §4 and §9 and
are fixed in place; five remain open. Read it before implementing either section.

---

## 1. What the backend is for, and what it must never become

Three jobs, and they are separate on purpose:

| Tier | Job | Supabase surface | When |
|---|---|---|---|
| **Edge Services** | kill-switch, anonymous telemetry + survey ingest | Storage object, one table, one Edge Function | v1 (exists in design today, unbuilt) |
| **Accounts & sync** | an account, and a walk that survives a lost phone | Auth, Postgres + RLS, Storage | v2 |
| **Content platform** | authored content published without an App Store release | Postgres (authoring) → Storage (published bundle) | v3 |

And one prohibition that outranks all three:

> **No core flow may require the server.** Discovery, preview, starting, walking, arriving, reading
> lore, answering a task, completing, and reading a summary all work with the radio off, forever
> (`AD-3`, `FR-OFF-01`, `NFR-REL-03`). The server is where data goes *afterwards*, and where content
> comes from *beforehand*. There is still no reachability check anywhere in the app.

The concrete test: turn Supabase off entirely and the app loses the ability to sign in, to sync, and
to receive new content — and loses nothing else.

---

## 2. Four decisions that shape everything below

### 2.1 Content is published as a versioned bundle, never queried row by row

Supabase Postgres is the **authoring** store for content in v3. Clients never read `catalog.quests`
directly. CI exports the authored rows to the same JSON tree the validator already checks
(`schema.md` §A.1), runs `content-validator` over it, and publishes an immutable archive to Storage
under its `contentBundleVersion`.

The client's v3 `CachedRemoteContentRepository` then does exactly one network thing: ask which bundle
is current, and download it if it does not have it. Everything else reads from the local cache.

Why not read tables directly, when Supabase makes that a one-liner:

- A per-screen query is a per-screen network dependency, and `AD-3` forbids that.
- `AD-4` pins a Run to a `contentVersion`. A version is an artifact, not a moving set of rows.
- The validator (`V1`–`V18`) is the mechanism that turns cultural governance into a build failure
  (`NFR-GOV-01`). A table you can `UPDATE` in the dashboard has no build to fail.
- `ContentRepository` was designed as a wholesale-replacement seam. Bundles preserve that; row
  queries quietly replace it with something else.

### 2.2 The server copies the client's two-store separation, including the missing foreign keys

`app.runs.quest_id` is `text`. It is **not** a foreign key to `catalog.quests`. Neither is
`checkpoint_id`, `place_id`, `stamp_id`, or `badge_id`. This looks like a modelling mistake and is
the single most important line in the schema: content is replaced wholesale, user data is permanent,
and a foreign key between them means a content correction can cascade-delete somebody's completed
walk (`system-design.md` §4, `schema.md` §C.3 rule 1).

The snapshot columns come with it. `app.checkpoint_results` carries the rendered lore, place name and
citations as `jsonb`, exactly as `CheckpointResultRecord` does on device. The server never joins a
summary to content, for the same reason `RunSummaryViewModel` takes no `ContentRepository`.

### 2.3 Device-generated UUIDs are the server's primary keys, and they are UUIDv7

Every local record already carries a `UUID` and timestamps from v1 — that was `NFR-MAINT-04`'s whole
purpose. So sync is `insert … on conflict (id) do update`, idempotent by construction. There is no
identity migration, no id mapping table, and a retried push is harmless.

**The version of the UUID is not incidental.** `Foundation.UUID()` produces a v4 — 122 random bits —
and a random primary key is a known B-tree anti-pattern: every insert lands on an arbitrary page, so
the index takes page splits instead of appends, the working set stops fitting in cache, WAL volume
rises, and bloat scales with the table rather than staying flat. On a schema that is almost entirely
append (`checkpoint_results`, `task_results`, `awards`, `photos`, `events`), that is precisely the
wrong-shaped key.

**UUIDv7 fixes it and changes nothing else.** A 48-bit millisecond timestamp prefix followed by
random bits: still 128-bit, still globally unique, still generated on device with no coordination and
no server round trip. Inserts land at the right edge of the index like a `bigserial` would. Every
property this section depends on is preserved.

```swift
// RunEngine. ~20 lines, because iOS 18 has no native UUIDv7.
// unix_ts_ms (48b) | ver=7 (4b) | rand_a (12b) | var=0b10 (2b) | rand_b (62b)   [RFC 9562]
public enum UUIDv7 {
    public static func make(now: Date = Date()) -> UUID { … }
}
```

Two things to be clear about:

- **The column type does not change**, and neither does `schema.md` Part B. Rows already written with
  a v4 stay valid, sort before every v7, and need no migration. This is a change to *generation*
  only, at the one call site that mints a new record id.
- **The timestamp prefix is not sensitive here.** A v7 id leaks the millisecond a record was created,
  which is already `created_at` on the same row. It would matter if ids were guessable identifiers
  for other people's data — they are not, because §8 gates every read on `user_id` rather than on the
  id being unguessable.

`ops.events` and `ops.survey_responses` should use v7 for the same reason; their ids are minted on
device too.

### 2.4 Telemetry has no user column, and gets a different key

Signing in must not deanonymise the measurement apparatus. Telemetry and survey rows carry a
`run_key` — a random UUID generated on device per Run, stored locally, and **never** written to
`app.runs`. The funnel stays analysable; the join back to a person does not exist to be made.

`NFR-PRIV-02`/`03`/`05` are enforced by the absence of columns, not by a policy somebody has to
remember.

---

## 3. Schema layout

```
auth.users                     Supabase-managed

app.        user data — RLS on every table, user_id = auth.uid()
  profiles
  runs ──1:N──► checkpoint_results ──1:N──► task_results
    │
    ├──1:N──► awards
    ├──1:N──► journal_entries
    ├──1:N──► photos
    └──1:N──► share_cards

catalog.    authored content — service role writes, nobody reads at runtime except `bundles`
  places · quests · checkpoints · lore_blocks · tasks · consent_records
  bundles                      ← the only table a client reads

ops.        governance and measurement — no user_id anywhere
  suppressions · events · survey_responses
```

---

## 4. `app` — user data

### 4.1 Columns every syncable table carries

```sql
id                uuid primary key,          -- generated on device (§2.3)
user_id           uuid not null references auth.users(id) on delete cascade,
device_id         uuid not null,             -- which device authored this revision (FR-SYNC-02)
revision          bigint not null default 1, -- bumped by the device on each local write
created_at        timestamptz not null,      -- device clock; display only
updated_at        timestamptz not null,      -- device clock; display only, NEVER a sync cursor
server_seq        bigint not null default nextval('app.sync_seq'),  -- the pull cursor. §9
deleted_at        timestamptz                -- tombstone; rows are never hard-deleted (§C.3 rule 3)
```

`user_id` is repeated on child tables rather than reached through a join, so every RLS policy is an
index lookup instead of a recursive `exists`.

**`server_seq` is the load-bearing column and it is not a timestamp.** `created_at` and `updated_at`
arrive from the device — they are what the walker's phone believed the time was — so neither can
order a pull. A phone three days slow writes a row stamped in the past, another device's cursor is
already beyond it, and that row is never pulled by anybody, ever.

A timestamp assigned *by the server* does not fix it either: `now()` returns transaction-start time,
so a slow transaction can commit a row whose stamp is older than a cursor that has already gone past.
The row is skipped permanently, and nothing anywhere reports it.

A sequence has neither problem, because a value is claimed at write time and the reader orders by the
value rather than by a clock:

```sql
create sequence app.sync_seq;
grant usage on sequence app.sync_seq to authenticated;

-- On every syncable table. The client cannot write this column; the trigger overwrites whatever
-- arrives. NOT `security definer` — a BEFORE trigger already sets the value regardless of what the
-- caller sent, so definer rights buy nothing and only widen the blast radius (§8.1 case 3). The
-- grant above is what makes `nextval` callable; that is the whole reason definer looked necessary.
create or replace function app.stamp_server_seq() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.server_seq := nextval('app.sync_seq');
  return new;
end $$;

create trigger runs_stamp_seq before insert or update on app.runs
  for each row execute function app.stamp_server_seq();
```

**This column costs write amplification, and the trade is deliberate.** `server_seq` changes on every
update and is indexed, which means Postgres can never take the HOT (heap-only tuple) path for a sync
write: each update writes a fresh entry into every index containing the column and leaves a dead
tuple behind. Combined with tombstones — rows are never removed (§C.3 rule 3) — these tables only
grow, and autovacuum settings stop being optional (§15.7).

A correct cursor is worth more than a cheap update at these volumes, so the column stays. It is named
here so the bloat is a known cost rather than a surprise six months in.

One shared sequence rather than one per table, so a single cursor per table still works while gaps
(from rolled-back transactions) stay harmless — the reader only ever asks for *greater than*, never
for *the next one*.

There is still a window: a sequence value is claimed before commit, so a long transaction can commit
`server_seq = 500` after a reader has passed 500. §9's pull covers it with a small overlap rather
than pretending it cannot happen.

### 4.2 Profile

```sql
create table app.profiles (
  user_id             uuid primary key references auth.users(id) on delete cascade,
  display_name        text,
  avatar_path         text,                -- Storage object, may be null
  preferred_language  text check (preferred_language in ('id','en')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
```

Deliberately thin. The Profile screen in the flow chart shows counts (walks, stamps, badges) — those
are derived from `app.runs` and `app.awards`, never stored as denormalised counters that can drift.

### 4.3 Runs

```sql
create table app.runs (
  id                        uuid primary key,
  user_id                   uuid not null references auth.users(id) on delete cascade,
  quest_id                  text not null,      -- content reference. NOT a foreign key (§2.2)
  content_version           text not null,      -- pinned at start (AD-4)
  language                  text not null check (language in ('id','en')),
  state                     text not null check (state in ('active','completed','abandoned')),
  current_checkpoint_index  int  not null default 0,
  started_at                timestamptz not null,
  completed_at              timestamptz,
  abandoned_at              timestamptz,
  abandon_reason            text check (abandon_reason in ('userChoice','placeSuppressed')),
  device_id                 uuid not null,
  revision                  bigint not null default 1,
  created_at                timestamptz not null,
  updated_at                timestamptz not null,
  deleted_at                timestamptz,

  constraint runs_completed_has_timestamp
    check ((state <> 'completed') or (completed_at is not null)),
  constraint runs_abandoned_has_reason
    check ((state <> 'abandoned') or (abandoned_at is not null and abandon_reason is not null))
);

-- FR-START-06, at last expressible as a constraint. SwiftData could not state this
-- (schema.md §B.2) and RunEngine holds it in code; Postgres can hold it as well.
create unique index runs_one_active_per_quest
  on app.runs (user_id, quest_id)
  where state = 'active' and deleted_at is null;

create index runs_user_updated on app.runs (user_id, updated_at);
create index runs_user_state   on app.runs (user_id, state, completed_at desc);
```

`notStarted` is absent from the check constraint: it is a client-side state that is never persisted
locally either, and a state that only exists in memory should not be representable in the database.

### 4.4 Checkpoint results — where the snapshot lives

```sql
create table app.checkpoint_results (
  id                       uuid primary key,
  run_id                   uuid not null references app.runs(id) on delete cascade,
  user_id                  uuid not null references auth.users(id) on delete cascade,
  checkpoint_id            text not null,
  order_index              int  not null,

  arrived_at               timestamptz not null,
  arrival_method           text not null check (arrival_method in ('gps','manual')),
  -- Tokens, not punctuation. `schema.md` §B.7 writes the middle band with an en dash (`20–75m`)
  -- and this document previously wrote a hyphen; one copy-paste between them is a runtime
  -- constraint violation nobody would look for.
  gps_accuracy_bucket      text check (gps_accuracy_bucket in ('lt20','b20_75','gt75')),
  lore_first_opened_at     timestamptz,
  -- `lore_dwell_ms` was here and was REMOVED by migration 0015. A dwell measurement on a row that
  -- carries `user_id not null` is exactly what §2.4 says the schema must make impossible, and
  -- nothing ever wrote it. NFR-OBS-06 is met by the anonymous `checkpoint_departed` event
  -- (`schema.md` §B.7) into ops.events, which has no user column. `lore_first_opened_at` stays:
  -- it is the FR-CP-04 fact that lore was opened, not a duration, and the award rules read it.
  stamp_awarded_at         timestamptz,

  -- Content snapshot, captured on device at arrival (system-design §4.1). Stored, never derived.
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

-- Partial, so a tombstone does not block re-insert. A plain `unique (run_id, checkpoint_id)` means
-- a soft-deleted row permanently occupies its own key and the walker can never re-arrive there.
-- Same pattern as `runs_one_active_per_quest`; it applies everywhere `deleted_at` exists.
create unique index checkpoint_results_one_per_checkpoint
  on app.checkpoint_results (run_id, checkpoint_id)
  where deleted_at is null;

create index checkpoint_results_pull on app.checkpoint_results (user_id, server_seq);
```

**One deliberate difference from the device schema.** On device, `CheckpointResultRecord` stores
`gpsAccuracyM: Double?` — a real metre figure, useful for diagnosing a walk. The server stores a
*bucket*. A precise accuracy reading beside a checkpoint id and a timestamp is a location trace by
another name, and `NFR-PRIV-02` forbids sending one. The client narrows the value on push; the local
column is unchanged.

A `check` constraint asserting the shape of `snapshot_lore` is tempting and is not worth it — the
snapshot's meaning may only ever be *added* to (`schema.md` §C.3 rule 2), and a JSON-shape constraint
turns that additive rule into a migration.

**No index on any `snapshot_*` column, ever.** They are write-only from the server's point of view:
nothing queries inside them, because §2.2 forbids the server joining a summary to content and
`RunSummaryViewModel` renders from the device's own copy. A GIN index on a `jsonb` column nobody
filters on is pure write amplification — it doubles the cost of every insert to serve no query. This
is worth stating because adding one *looks* like diligence. (`ops.events.params` is the opposite case
and does want GIN — §6.2.)

These columns are large enough to be TOASTed, so `select *` on this table pulls the snapshots out of
TOAST storage. Any list query — anything that shows titles and dates rather than lore — should name
its columns rather than take `*`.

### 4.5 Task results, awards

```sql
create table app.task_results (
  id                   uuid primary key,
  checkpoint_result_id uuid not null references app.checkpoint_results(id) on delete cascade,
  run_id               uuid not null references app.runs(id) on delete cascade,
  user_id              uuid not null references auth.users(id) on delete cascade,
  task_id              text not null,
  type                 text not null check (type in ('photo','reflection','question')),
  skipped              boolean not null,        -- a first-class outcome, not a failure (AD-2)
  answer_text          text,
  photo_id             uuid references app.photos(id) on delete set null,
  completed_at         timestamptz not null,
  device_id uuid not null, revision bigint not null default 1,
  created_at timestamptz not null, updated_at timestamptz not null, deleted_at timestamptz,
  server_seq bigint not null default nextval('app.sync_seq')
);

create unique index task_results_one_per_task
  on app.task_results (checkpoint_result_id, task_id)
  where deleted_at is null;

create table app.awards (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  run_id        uuid references app.runs(id) on delete cascade,   -- null = cross-quest badge (v2),
                                                                  -- and null for every letter (§4.9)
  type          text not null check (type in ('stamp','badge','letter')),
  source_id     text not null,        -- stampId / badgeId from content; sideQuestId for a letter
  snapshot_name text not null,        -- survives content changes
  awarded_at    timestamptz not null,
  device_id uuid not null, revision bigint not null default 1,
  created_at timestamptz not null, updated_at timestamptz not null, deleted_at timestamptz,
  server_seq bigint not null default nextval('app.sync_seq')
);

-- NULLS NOT DISTINCT, because `run_id` is null for cross-quest badges and for every letter.
-- Postgres treats NULLs as distinct by default, so a plain unique would let the exact rows this
-- constraint exists to protect duplicate without limit. Partial, for the tombstone reason above.
create unique index awards_one_per_source
  on app.awards (user_id, run_id, type, source_id)
  nulls not distinct
  where deleted_at is null;
```

Note `task_results.photo_id` is nullable and `on delete set null`: a photo the user later removes from
the server must not take the record of the task with it.

**`letter` arrived with the sidequest feature** (`s2` §1, `schema.md` §B.5). A letter is an `Award`
like a stamp is, held on a `SideQuestRecord` rather than a Run — hence `run_id` null. The collection
badge is `type = 'badge'` with the collection's `badgeId` as `source_id`, and it is *derived* on
device from whether every slot is filled (`s2` §5), never stored as a counter that can drift.

### 4.6 Journal — the flow chart's Create Journal / Trip Summary

```sql
create table app.journal_entries (
  id         uuid primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  run_id     uuid references app.runs(id) on delete cascade,  -- nullable: see below
  title      text,
  body       text not null default '',
  device_id uuid not null, revision bigint not null default 1,
  created_at timestamptz not null, updated_at timestamptz not null, deleted_at timestamptz
);

create index journal_user_created on app.journal_entries (user_id, created_at desc);
```

`run_id` is nullable on purpose. The chart draws Create Journal hanging off the completion screen, but
a journal about a place someone simply passed (the notification branch) has no Run behind it. A
nullable column costs nothing now and avoids a migration when that branch is built.

The Trip Summary screen is a **read**, not a table: one `app.runs` row, its cascaded children, its
journal entry and its photos. It is a query, and it renders from snapshots — no content join, exactly
as `RunSummaryViewModel` does today.

### 4.7 Photos

```sql
create table app.photos (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  run_id        uuid references app.runs(id) on delete cascade,
  checkpoint_id text,

  -- Object NAMES, with no bucket prefix. Deterministic from `id`, so the row can be written before
  -- the bytes exist (see the ordering below). Supabase keeps the bucket in
  -- `storage.objects.bucket_id`, not in `name`, so a path written as 'trip-photos/{user_id}/…'
  -- makes the §8 policy compare 'trip-photos' against auth.uid() and never match.
  --   full  '{user_id}/{run_id}/{id}.heic'        1600 px long edge
  --   thumb '{user_id}/{run_id}/{id}_t.heic'       400 px long edge
  --   NOT NULL since migration 0015. The upload ordering below writes the row BEFORE the bytes
  --   with both paths already set, and FR-SET-02 deletes by path unconditionally. This DDL used to
  --   leave them nullable, contradicting the ordering three paragraphs down; the nullable half won
  --   and the schema shipped with it. A null path is an object nothing can find or erase.
  storage_path  text not null,
  thumb_path    text not null,

  content_type  text check (content_type in ('image/heic','image/jpeg')),
  width_px      int,          -- of the full derivative, so a grid can lay out before downloading
  height_px     int,
  byte_size     int,          -- full + thumb, for FR-SET-03's storage report and orphan detection

  captured_at   timestamptz not null,
  uploaded_at   timestamptz,  -- null until the bytes are actually on the server. See ordering below.
  device_id uuid not null, revision bigint not null default 1,
  created_at timestamptz not null, updated_at timestamptz not null,
  server_seq bigint not null default nextval('app.sync_seq'),
  deleted_at timestamptz
);

create index photos_pending_upload on app.photos (user_id, captured_at)
  where uploaded_at is null and deleted_at is null;
```

**Photos do not sync by default.** `NFR-PRIV` and the v1 posture (`system-design.md` §12) put *no*
photos on a server; introducing accounts must not silently reverse that. A row exists so the summary
knows a photo was taken; `storage_path` stays null and the bytes stay on the phone until the user
turns on photo backup or shares a card. The local path stays relative (`NFR-REL-05`) and is never
uploaded — a container path is meaningless on another device.

**Sidequest photos are stricter, and the difference is a requirement.** `FR-SIDE-13` and
`NFR-PRIV-01` say a sidequest challenge photograph stays on the device — full stop, with no opt-in
that reverses it. **This table is therefore checkpoint photographs only; a sidequest photo has no row
here at all.** Its only record is `SideQuestChallengeResult.photoRelativePath` on device
(`schema.md` §B.13). Any photo-backup feature must exclude `Documents/sidequest-photos/` by
construction rather than by a filter somebody remembers to write — the two policies read alike and
are not the same.

#### Two derivatives, never the original

A photograph is downscaled on device before it leaves, and stored twice:

| | Long edge | Typical | Fetched by |
|---|---|---|---|
| `thumb_path` | 400 px | ~35 KB | every summary card, grid, journal row |
| `storage_path` | 1600 px | ~250 KB | only when the user taps to view one |

The original is never uploaded. A 4032 × 3024 capture displayed in a 390 pt card wastes about 90% of
its bytes, and 1600 px still covers a full-width @3x display.

The thumbnail costs 13% more storage and removes roughly 85% of egress, because browsing shows
thumbnails and few people tap through. That ratio is the whole reason for the second column:
**egress is $0.09/GB against storage at $0.021/GB**, and an image is uploaded once and viewed many
times. Optimise what leaves the bucket, not what sits in it.

HEIC because iOS encodes it natively at roughly half the bytes of JPEG for the same perceived
quality. `content_type` is a column rather than an assumption because HEIC is effectively
iOS-only — a web client later means generating JPEG derivatives, and that should be a column read,
not a path rewrite.

#### Upload ordering, and the orphan it prevents

```
1. insert app.photos   — storage_path and thumb_path set, uploaded_at NULL
2. PUT the thumb
3. PUT the full
4. update app.photos   — uploaded_at = now()
```

**Row first.** The reverse order — upload, then insert — leaves an object nobody can find, nobody
can delete, and which still counts toward both the bill and the deletion obligations under
`FR-SET-02`, if the insert fails or the app is killed between the two. Writing the row first means
the paths are deterministic from `id`, and a failure leaves a row with `uploaded_at` null, which is
resumable and visible.

A sweeper deletes storage objects with no matching row. Nothing else can find them.

`FR-SET-02` deletion now removes **two** objects per row plus the row, and a row whose
`uploaded_at` is null may still have a partial object at either path. The Edge Function must delete
by path unconditionally rather than branching on `uploaded_at` — attempting to delete an object that
was never written is free; leaving one behind is a privacy failure that passes every database test.

### 4.8 Share cards

```sql
create table app.share_cards (
  id           uuid primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  run_id       uuid not null references app.runs(id) on delete cascade,
  template     text not null,
  storage_path text not null,
  public_slug  text unique,              -- null until a link is minted
  expires_at   timestamptz,
  revoked_at   timestamptz,
  created_at   timestamptz not null default now()
);
```

Sharing is the one place data deliberately leaves the account, so it gets three guards:

1. **Composition rules stay on device.** `FR-SHARE-05` — a sacred place's photo policy is enforced
   when the card is built, where the content is.
2. **The server re-checks before minting a link.** `issue-share-link` looks the quest's places up in
   `catalog` and refuses a public slug if any is `photoPolicy.level = 'prohibited'`. Defence in depth,
   because the client that composes the card is the client that could be wrong.
3. **Links expire and are revocable.** A signed URL with an expiry, not a public bucket. `revoked_at`
   exists because "delete my shared card" has to mean something.

---

## 5. `catalog` — content, authored server-side, published as a bundle

Tables mirror `schema.md` Part A one-to-one (`places`, `quests`, `checkpoints`, `lore_blocks`,
`tasks`, `sources`, `consent_records`), with `jsonb` for every `LocalizedText` and a `check` that both
`id` and `en` keys are present and non-empty — `V1`, held by the database as well as the validator.

Two things about it matter:

```sql
create table catalog.bundles (
  version      text primary key,          -- contentBundleVersion, e.g. '2026.08.1'
  manifest     jsonb not null,
  archive_path text not null,             -- Storage: 'content/{version}.zip'
  checksum     text not null,             -- sha256, verified on device before use
  published_at timestamptz not null default now(),
  is_current   boolean not null default false
);

create unique index bundles_one_current on catalog.bundles (is_current) where is_current;
```

- **`catalog.bundles` is the only catalog table with a read policy for `anon`.** Everything else is
  service-role only. A client asks "what is current", downloads, verifies the checksum, and never
  speaks to the catalog again.
- **`consent_records` is never published.** It is a build input (`schema.md` §A.7); putting named
  individuals' details into a downloadable archive would undo the reason it is excluded from the app
  bundle today. It lives in Postgres so the validator can read it in CI, behind service role, and
  should carry column-level access restrictions on `granted_by_name` / `granted_by_role`.

**Publish pipeline** (CI, service role, `publish-content` Edge Function):

```
authored rows  ──►  export to the JSON tree of schema.md §A.1
                     │
                     ▼
              content-validator (V1–V18)  ──► non-zero exit stops the publish
                     │
                     ▼
              zip + sha256 ──► Storage 'content/{version}.zip'
                     │
                     ▼
              insert catalog.bundles, flip is_current in one transaction
```

The validator stays the gate. Moving authoring into a database does not get to skip it.

---

## 6. `ops` — governance and measurement

### 6.1 Kill-switch (`AD-5`)

```sql
create table ops.suppressions (
  entity_type   text not null check (entity_type in ('place','quest','sidequest')),
  entity_id     text not null,
  reason        text not null,
  suppressed_at timestamptz not null default now(),
  released_at   timestamptz,
  primary key (entity_type, entity_id)
);
```

A trigger regenerates the published `suppressions.json` (the document in `schema.md` §A.8) into
Storage on every change. **The client's contract does not change**: it still fetches one static,
schema-validated JSON file over TLS, still discards anything malformed in favour of the last good
copy, still never blocks launch. Supabase is where the file is edited, not a new runtime dependency.

**`'sidequest'` and the published document's schema 2.** `s3` §7 gives the kill-switch authority over
sidequests as well: a withdrawn sidequest disappears from every surface and its region is
deregistered on next launch (`FR-SIDE-14`), while **the letter it already awarded is retained** —
the record is a snapshot and the walk happened. The published file becomes:

```json
{
  "schemaVersion": 2,
  "updatedAt": "2026-08-15T09:00:00Z",
  "suppressedPlaceIds": [],
  "suppressedQuestIds": [],
  "suppressedSideQuestIds": []
}
```

Two rules on that bump, and the second is the one that bites:

- Suppressing a **place** already suppresses the sidequests standing at it — `ContentRepository`'s
  discovery method takes both id sets and filters on either (`s1` §6). `suppressedSideQuestIds` is
  for withdrawing one story while the place itself stays walkable, which is the likelier request.
- **The client must decode the new array as `decodeIfPresent … ?? []`.** Schema validation that
  rejects a schema-1 document sends the app to its last good copy (`NFR-SEC-02`, `FR-ERR-09`) — and
  the failure mode is a withdrawal that silently stops applying, which is the exact thing `AD-5`
  exists to prevent. A schema-1 file must keep validating and simply carry no sidequests. Same rule
  the content manifest already follows for its own two new arrays (`s1` §2).

### 6.2 Telemetry and survey — the anonymous tier

```sql
create table ops.events (
  id             uuid primary key,
  name           text not null,
  params         jsonb not null default '{}',
  run_key        uuid,                       -- pseudonymous, per Run (§2.4). Never joins to app.runs
  schema_version int not null,
  occurred_at    timestamptz not null,
  received_at    timestamptz not null default now()
);

create table ops.survey_responses (
  id          uuid primary key,
  run_key     uuid,
  quest_id    text,
  question_id text not null,
  response    text not null,
  occurred_at timestamptz not null,
  received_at timestamptz not null default now()
);

-- BRIN, not B-tree. This table is append-only and `received_at` is monotonic, so physical row order
-- already correlates with time — which is the exact case BRIN exists for. It stores a min/max per
-- block range: kilobytes where a B-tree would be megabytes, and entirely adequate for both the
-- retention delete (§15.7) and time-range analytics. A B-tree here would be the larger, slower,
-- more-write-amplifying choice for no gain.
create index events_received_brin  on ops.events           using brin (received_at);
create index survey_received_brin  on ops.survey_responses using brin (received_at);

-- GIN, because this jsonb IS queried — analytics filters on `params->>'questID'` and friends.
-- `jsonb_path_ops` is smaller and faster than the default operator class when containment (@>) is
-- all that is needed, which it is. Contrast `app.checkpoint_results.snapshot_lore` (§4.4), which is
-- never queried and must never be indexed.
create index events_params_gin on ops.events using gin (params jsonb_path_ops);

create index events_name_time on ops.events (name, occurred_at);
```

`id` is a **UUIDv7** here too (§2.3) — minted on device, and these are the most append-heavy tables in
the system, so the random-key page-split cost would land hardest here.

Neither table has a `user_id`, and neither should ever acquire one. The event catalogue is
`schema.md` §B.7; `accuracy_bucket` remains a band.

**Sidequests need catalogue rows, and have none today.** No DDL changes — `name text` plus
`params jsonb` absorbs anything — but an uninstrumented metric is not a metric (`NFR-OBS-01`), and
the sidequest plans (`s6`) specify no telemetry at all. Six screens and a second engagement loop
currently measured by nothing. Proposed rows, one per question worth answering:

| Event | Params | Serves |
|---|---|---|
| `sidequest_alert_shown` \| `sidequest_alert_opened` | sideQuestID | whether the notification is the value it is assumed to be |
| `sidequest_discovered` | sideQuestID, arrivalMethod, accuracyBucket | how often the radius gate fails in the field, versus quests |
| `sidequest_quiz_resolved` | sideQuestID, attempts, wasRevealed | which questions are badly written — `s2` keeps `attempts` for exactly this, and nothing carries it off-device today |
| `sidequest_completed` | sideQuestID, collectionID | letter conversion |
| `collection_completed` | collectionID, durationDays | whether a collection is finishable at all |

`schema_version` bumps when they land. **They carry no `run_key`** — §2.4's key is per Run and a
sidequest has no Run. Minting a second pseudonymous key to correlate a person's sidequests across a
region would rebuild the thing §2.4 exists to prevent; these events are single-shot and there is no
funnel to reconstruct. Leave the column null.

Ingest is one Edge Function, `POST /ingest`: write-only, accepts a batch, no reads, rate-limited by
IP, and it does not care whether the caller is signed in. Insert-only RLS for `anon` on these tables
would be simpler and is rejected — it hands every installed app a token that can write to the database
directly, and the function is where batching limits, schema-version rejection and rate limits live.

The client side is unchanged from `system-design.md` §10: durable local queue, opportunistic flush,
`200` marks sent, anything else leaves the rows queued. Survey rows are never pruned (`FR-ERR-10`).

### 6.3 What is never sent, with or without an account

- Coordinates, in any form. Arrival reports a checkpoint id and an accuracy band.
- `ProximityAlertRecord`. The local table exists solely to enforce the rate limits in `FR-PROX-09`,
  and a server copy is a movement history — precisely what `NFR-PRIV-09` forbids. It stays on device
  and is pruned at 7 days. Sidequests share that table and its `targetID` namespace (`s2` §6,
  `schema.md` §B.8), which widens what a server copy would reveal without changing the answer: it
  still never leaves.
- Photo bytes, unless the user asks (§4.7) — and sidequest photographs not even then (`FR-SIDE-13`).
- Consent records, to any client.

**One thing this list should stop implying.** "Coordinates, in any form" describes the encoding, not
the information. A `run_key` with an ordered series of checkpoint ids and real timestamps is a
trajectory over a published route — each checkpoint being a known circle of 75 m at a published
location. This complies with `NFR-PRIV-02` as written, and it is worth saying plainly rather than
leaving a reader to infer that nothing locational is transmitted. What is true is narrower and still
defensible: no position is transmitted, and what is transmitted is bounded to one walk.

---

## 7. Authentication, and the "Skip for now" the flow chart draws

```
launch ─► anonymous session (supabase.auth.signInAnonymously)
             │  a walk can start immediately; nothing is gated on an account
             ▼
        user registers later ─► link email/password to the SAME auth.users row
             │
             ▼
        user_id never changes ─► every row written while anonymous is kept
```

This is the design that makes the login wireframe's "Skip for now" honest rather than a dead end. The
alternative — a local-only mode with a data import at registration — is a migration path that has to
be written, tested and supported, to reach the same place.

### 7.1 Where the credential is actually required

Accounts exist because photographs have to be stored somewhere that survives the phone (§13.1). That
is the only thing that genuinely needs a credential, and it is the only place the app asks for one:

| Moment | Account state | Network required |
|---|---|---|
| Browse, search, preview a quest | anonymous session, created silently at first launch | **no** |
| Start a quest, walk it, arrive, read lore, answer a task, complete | same anonymous session | **no** |
| Discover and complete a sidequest, earn a letter | same | **no** |
| Take a photograph | same — it writes to the app container | **no** |
| **Upload that photograph, or restore onto a new phone** | a linked credential (email) | yes |

**Nothing in the walk is gated on a credential or a radio, and that is not a preference.** `AD-3`,
`FR-OFF-01` and `NFR-REL-03` require every core flow to work with the radio off, and *starting* is
named in that list. `FR-START-08` compounds it: a quest can only start inside the first checkpoint's
radius — physically standing at the site, which is precisely where signal fails. It is why
`FR-MAP-01` bans live tiles and why `FR-START-10` makes the manual override mandatory rather than a
nicety. A login wall at Start means a walker who travelled to Puri Agung Pemecutan cannot begin the
walk they came for.

> **A gate at quest start was requested, and is placed at upload instead.** The stated need —
> "we have to store the image, so we need an account" — is fully met here: every user has an
> `auth.users` row from first launch, every Run is attributable, and photographs cannot leave the
> device without a credential. The "bypass" that request also asked for is not a temporary hack to
> remove later; it *is* the anonymous session, and it is permanent. If product still wants a hard
> credential wall in front of Start, that is a knowing `AD-3` exception with an owner's name against
> it, and it needs an offline answer for the walker standing at the gate with no bars.

The prompt to register therefore appears at the honest moment — *"make an account to keep these
photographs"* — rather than in front of the thing the user opened the app to do.

### 7.2 Consequences accepted deliberately

- An anonymous session lost with the device is a walk lost, because there is no credential to recover
  it with. The app should say so where it asks people to register, not in a privacy policy.
- Anonymous sign-in still requires the network, so **it cannot gate anything**. If it fails, the app
  runs exactly as it does today: local store, no sync, no complaint. The session attempt belongs at
  the platform layer with the rest of the optional infrastructure.
- Sign-in providers are a product decision (§10). Email/password is assumed here because it is what
  the chart draws.

### 7.3 Linking, when the email already exists

The diagram above is true for the *first* link only. The case it does not cover, and which will
happen: a walker reinstalls, walks anonymously for a week, then registers with the address they used
last year. Supabase rejects the link — that identity is taken — and the anonymous rows are stranded
with no path anywhere.

Anonymous rows cannot simply be re-pointed by the client: RLS forbids writing another `user_id`, and
it must, or reassigning rows would be an account-takeover primitive.

**This is an Edge Function, not a `security definer` SQL function.** A definer function that rewrites
`user_id` *is* the takeover primitive — anyone who can call it with a source uid they do not own
steals an account, so its entire safety rests on argument validation inside plpgsql, and plpgsql
cannot verify a JWT signature without the signing secret. The Edge Function can: it holds the
service role, verifies both tokens through the auth admin API, and only then issues SQL with two
uids it has actually proven.

```
POST /merge-anonymous
  Authorization: Bearer <session for the TARGET account, just signed in>
  body: { anon_access_token: "<the anonymous session's token>" }

  1. verify the caller's JWT   → target_uid, and it is NOT anonymous
  2. verify anon_access_token  → anon_uid, is_anonymous = true, no linked identity
  3. refuse if target_uid = anon_uid, or if either verification fails
  4. move rows, move objects, delete the anonymous auth.users row
```

Both identities are proven from tokens the caller had to actually hold. Neither uid is ever read
from a request body.

Rules it has to hold, all of which are the awkward part rather than the reassignment:

1. **Idempotent.** It runs again after a dropped response and moves nothing the second time.
2. **`runs_one_active_per_quest` will collide** — the same quest may be active on both identities.
   Resolve it the way §9.5 already resolves the sync case: keep the Run with more
   `checkpoint_results`, abandon the other with `abandon_reason = 'userChoice'`. Never delete either.
3. **`awards_one_per_source` will collide** on any stamp or letter earned under both. Keep the
   earlier `awarded_at`; drop the duplicate rather than tombstoning it, since it was never a distinct
   award.
4. **Storage objects move too,** or the row points at a path under an old uid that §8's policy no
   longer grants. Copy then delete, and do it before the row moves so a failure leaves the original
   readable.
5. **The anonymous `auth.users` row is deleted last,** inside the same transaction.

Until this function exists, the app must not offer the link at all — it should detect the collision
up front and say the address is already in use, rather than failing after the walker has agreed.

### 7.4 Anonymous users are billable, and must not be culled blindly

Every install creates an `auth.users` row and each counts toward MAU. Supabase's own guidance is to
periodically delete unused anonymous users, and running that as written would **silently delete the
synced walks of exactly the population §7.2 identifies as unrecoverable** — people who never
registered and whose device is their only other copy.

The policy, stated so nobody reaches for the default cron:

```sql
-- Deletable: anonymous, no linked identity, and holds nothing worth keeping.
select u.id from auth.users u
where u.is_anonymous
  and u.last_sign_in_at < now() - interval '90 days'
  and not exists (select 1 from app.runs          r where r.user_id = u.id)
  and not exists (select 1 from app.journal_entries j where j.user_id = u.id)
  and not exists (select 1 from app.photos        p where p.user_id = u.id);
```

An anonymous user with a single Run is never culled, at any age. The cost of keeping an empty row is
a fraction of a cent; the cost of the other error is somebody's walk.

---

## 8. Row-level security

RLS on, forced, on every table in `app`. One shape, applied everywhere:

```sql
alter table app.runs enable row level security;
alter table app.runs force row level security;

create policy runs_select on app.runs
  for select using (user_id = (select auth.uid()));

create policy runs_insert on app.runs
  for insert with check (user_id = (select auth.uid()));

create policy runs_update on app.runs
  for update using (user_id = (select auth.uid()))
          with check (user_id = (select auth.uid()));

-- No delete policy at all. Rows are tombstoned with deleted_at, never removed by a client.
```

**RLS is not one defence among several — it is the only one.** The publishable key ships inside every
copy of the app and is meant to be public; anyone who installs the app can extract it and speak to
PostgREST directly with any query they like. Nothing in the client constrains what reaches the
database. A missing policy on one table is that table readable by everybody, and it fails silently
because the app's own screens never ask for another user's rows.

Points that are easy to get wrong and expensive to discover later:

- `(select auth.uid())` rather than bare `auth.uid()` — Postgres caches the scalar sub-select per
  statement instead of re-evaluating per row.
- `force row level security` matters because the table owner otherwise bypasses its own policies.
- `user_id` is denormalised onto every child table (§4.1) so no policy needs a join to `app.runs`.
- **The `service_role` key never ships in the app, under any circumstance.** It bypasses RLS
  entirely. It belongs in Edge Function environment and CI secrets, nowhere else, and it should be
  rotated on any suspicion.

**RLS is one of two layers, and the doc above only describes one.** `GRANT` decides whether a role
may touch a table at all; RLS decides which rows. They are independent, and the safe posture needs
both — least privilege on grants, so that a table which somehow ships without RLS is still
unreachable rather than wide open:

```sql
revoke all on schema public from public;

-- `anon` never touches user data. Even the anonymous session in §7 is `authenticated` as far as
-- Postgres is concerned — Supabase issues a real JWT for it, `is_anonymous` is a claim, not a role.
revoke all on all tables in schema app from anon;
grant usage on schema app to authenticated;
grant select, insert, update on all tables in schema app to authenticated;
-- No `delete` grant anywhere: §8's policies already omit it, and this makes that structural rather
-- than a policy somebody could add later.

alter default privileges in schema app grant select, insert, update on tables to authenticated;
```

That `alter default privileges` line is what stops the next table from arriving ungranted and then
being fixed with a too-broad `grant all` in a hurry.

**PostgREST exposes only the schemas named in its configuration**, and that setting is the real
enforcement of "clients never read `catalog` or `ops`" (§5, §6.2). Expose `app` only. `catalog.bundles`
is the single exception the client needs, and it is better served by a view in `app` or a
`security definer` reader than by exposing the whole `catalog` schema for one table.

### 8.1 Four ways RLS gets bypassed by accident

Each of these has shipped in real projects, and none of them looks wrong in review.

1. **A new table without policies.** RLS is per-table and off by default. A table with
   `enable row level security` and *no* policy denies everything (safe, obvious in testing); a table
   with **no RLS at all** allows everything to anyone holding the publishable key (unsafe, invisible
   in testing). The two failures look nothing alike and the dangerous one is the quiet one. A CI
   check should assert that every table in `app` has RLS enabled, forced, and at least a select
   policy — the same "hold it with a test, not a review" rule this repo already applies to import
   boundaries and contrast.

2. **A view.** Views run as their owner by default and **do not inherit the RLS of their base
   tables**, so a convenience view over `app.runs` hands out every user's rows. Postgres 15+ fixes
   this per-view:

   ```sql
   create view app.my_recent_runs with (security_invoker = true) as …
   ```

   Rule: no view in `app` is created without `security_invoker = true`.

3. **A `security definer` function.** It runs with the owner's rights and skips RLS on everything it
   touches. Two absolute requirements: `set search_path = ''` on every one (a mutable search path
   lets a caller shadow a function name and run their own code as the owner — this is Supabase's
   most-flagged advisor warning), and fully-qualified table names inside. The functions in this
   design that qualify are `app.stamp_server_seq` (§4.1) and the conflict trigger (§9.4); the merge
   deliberately is **not** one (§7.3).

4. **`postgres`/owner sessions in the dashboard.** SQL run from the Supabase SQL editor is not
   subject to RLS. Fine for migrations, and a reason not to test policies there — a query that works
   in the dashboard proves nothing about what a client can do.

### 8.2 Proving isolation, rather than reviewing it

`CLAUDE.md` states the working rule for this codebase: invariants are held by tests, not by review,
because a reasonable-looking change silently breaks a guarantee. RLS is the clearest case of that
rule in the whole system and it currently has no test at all.

A pgTAP suite, run in CI against a migrated database, with two seeded users:

| Assertion | Why it is the one that matters |
|---|---|
| A `select` as user B returns **zero** rows of A's runs, checkpoint_results, task_results, awards, journal_entries, photos, share_cards, sync_conflicts | the headline guarantee, per table, because one missing policy is one leaked table |
| An `insert` by B carrying `user_id = A` is **rejected** | `with check` present on insert, not only `using` on select |
| An `update` by B on A's row id is **rejected**, and does not merely match zero rows | a policy that silently matches nothing looks identical to one that denies, until the day the predicate changes |
| A `delete` by anyone is rejected on every table in `app` | there is no delete policy anywhere, and that is deliberate |
| Every table in `app` has `relrowsecurity` **and** `relforcerowsecurity` set | catches the new-table-without-RLS case above, mechanically |
| Every view in `app` has `security_invoker` | catches case 2 |
| Every `security definer` routine has a non-mutable `search_path` | catches case 3 |
| A storage object under A's prefix is not readable by B | §8.3 — the bucket is a separate authorization system and needs its own proof |
| A `select` with **no** JWT returns zero rows everywhere in `app` | `auth.uid()` is null when unauthenticated; this asserts the comparison denies rather than errors |

The last four are the ones that will actually catch a regression, because they are structural — they
fail when somebody adds a table, view, or function, which is exactly when the hand-written per-table
assertions above them get forgotten.

Add two catalogue queries to the same CI job. Neither needs a fixture; both fail the build on a
non-empty result, and both keep holding after everyone has forgotten they exist:

```sql
-- 1. Any table in `app` without RLS forced. The dangerous case from §8.1, mechanically.
select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'app' and c.relkind = 'r'
  and not (c.relrowsecurity and c.relforcerowsecurity);

-- 2. Any foreign key with no index on its referencing column (§15.5). Postgres does not create
--    these, and every `on delete cascade` in §4 scans without them.
select conrelid::regclass as table_name, a.attname as column_name
from pg_constraint c
join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
where c.contype = 'f'
  and not exists (select 1 from pg_index i
                  where i.indrelid = c.conrelid and a.attnum = any(i.indkey));
```

This is the same move the package already makes with `ImportBoundaryTests` and the contrast suites:
a rule that a reviewer would have to remember becomes a query that fails the build.

### 8.3 Storage is a second authorization system

Bucket policies are separate objects from table policies and are frequently written for `select`
only, leaving `insert`, `update` and `delete` open. All four are needed, on both private buckets:

```sql
create policy trip_photos_read on storage.objects
  for select using (
    bucket_id = 'trip-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
-- …and the same predicate for insert (with check), update (using + with check), delete (using).
```

`storage.foldername(name)[1]` is the first segment of the **object name**, which excludes the bucket
— the reason §4.7 stores paths without a bucket prefix. Both derivatives of a photograph sit under
the same `{user_id}/` prefix, so one predicate covers `…/{id}.heic` and `…/{id}_t.heic` together.

A signed URL, once issued, ignores all of this until it expires. That is what §4.8's `revoked_at`
cannot overcome (defect 14) and why share-card links want short lifetimes.
- **Deletion is a server-side operation, not a client one.** `FR-SET-02` ("delete all my data") runs
  as an Edge Function, because the same bug exists here as on device: dropping database rows and
  leaving the images is a privacy failure that passes every database test.

  **It cannot be one transaction, and an earlier draft of this document claimed it could.** Postgres
  and object storage are two systems; no transaction spans them. The order has to make the
  *surviving* state safe instead:

  ```
  1. mark the user deleting            (a flag the upload path checks — §15.3)
  2. delete every storage object       (idempotent; deleting a missing object is a no-op)
  3. hard-delete rows, in batches      (see §15.2 on why one giant statement is wrong)
  4. delete the auth.users row
  ```

  Objects first. A crash after step 2 leaves rows pointing at bytes that are gone, which reads as a
  broken thumbnail and is recoverable. A crash after step 3 in the reverse order leaves bytes with no
  row — unreachable, undeletable, and still personal data. Of the two possible half-states, only one
  is survivable, so the order is not a preference.
- `catalog`: `select` for `anon` on `bundles` only. `ops`: no client policies at all; the ingest
  function uses the service role.
- Storage buckets `trip-photos` and `share-cards` are private, with `storage.objects` policies keyed
  on the first segment of the **object name** being `auth.uid()::text` —
  `(storage.foldername(name))[1] = auth.uid()::text`. The bucket is *not* part of `name`; it lives in
  `bucket_id`, which is why §4.7 stores the object name without a bucket prefix. Writing the prefix
  into the path makes this policy compare `'trip-photos'` against a uid and match nothing, and the
  symptom is uploads that fail for a reason the error does not name. `content` is public-read (it is
  the published bundle) and service-role write.

---

## 9. Sync protocol

Runs are append-mostly and single-author; nothing here needs CRDTs. It is still a replication
protocol, and the earlier draft of this section called itself "deliberately dull" while getting the
cursor, the push order and the conflict mechanism wrong. What follows is the corrected version; §14
keeps the record of what was wrong, because the failures were all silent ones.

### 9.1 Protocol version

Every request carries `X-Sync-Schema: 1`. `ops.events` has carried a `schema_version` since it was
designed and sync had none, which is backwards — a telemetry row that arrives in an old shape is
noise in a chart, and a Run row that does is somebody's walk. The server rejects an unknown version
with `426` and the client stops syncing and says so, rather than pushing into a schema it does not
understand. Bump on any change to a payload's meaning.

### 9.2 Push

The client holds a local `sync_state` per row (`local | pending | synced`, `schema.md` §C.1) and
pushes in dependency order:

```
runs ─► photos ─► checkpoint_results ─► task_results ─► awards ─► journal_entries ─► share_cards
```

**`photos` moves ahead of `task_results`,** because `task_results.photo_id references app.photos(id)`
(§4.5). The earlier order pushed the child first and the first photo task ever synced would have
failed on a foreign key. `photos` has no dependency of its own beyond `runs`.

```sql
insert into app.runs as t (…)
values (…)
on conflict (id) do update
  set … ,
      revision   = excluded.revision,
      updated_at = excluded.updated_at
  where excluded.revision > t.revision      -- a stale retry is a no-op
returning id, revision, server_seq;
```

Three things about that statement:

- **Idempotent by primary key** (§2.3), so a retry after a dropped response is safe.
- **`returning` is not optional.** The `where` clause makes a losing upsert a silent success — zero
  rows changed, `200` returned, and a client that marks everything `synced` on a `200` has just
  recorded that a row it never wrote is safely on the server. **Mark `synced` only for ids that come
  back**; anything absent stayed `pending` and is retried.
- **`revision` is clamped server-side.** It arrives from the client, and one buggy build writing a
  near-`int8`-max value makes that row permanently unwritable by every device including the one that
  broke it. Reject `excluded.revision > t.revision + 1000` as a bad request rather than storing it.

### 9.3 Pull

One cursor per table — the last `server_seq` this device has seen (§4.1), never a timestamp:

```sql
select * from app.runs
where user_id = auth.uid()
  and server_seq > $cursor - 100      -- overlap, see below
order by server_seq
limit $n;
```

Tombstones come through the same query so a deletion propagates.

**The overlap is deliberate and small.** A sequence value is claimed before commit, so a transaction
that starts early and commits late can land a row *behind* a cursor a reader has already passed.
Re-reading a window of recent values costs a few rows per pull and closes the hole; rows the client
already has are recognised by `id` and skipped unless `revision` moved. Ordering by `server_seq`
alone is also unambiguous — it is unique, so unlike an `updated_at` cursor there is no tie that can
straddle a page boundary and drop rows between them.

The cursor advances to `max(server_seq)` of the page actually received, never to `cursor + limit`.

### 9.4 Conflict

`FR-SYNC-02` says the device that authored the content wins. **`revision` alone cannot express
that** — two devices both editing from revision 3 both write 4, and neither is "the author" in any
sense the counter records. The rule as implemented:

1. Higher `revision` wins.
2. Equal revisions, different `device_id`: the earlier `updated_at` wins. Arbitrary, but stable and
   decided in advance, which is the whole point.
3. **The loser is written to `app.sync_conflicts`, never dropped.**

That third clause cannot live in the upsert — the `where` clause discards the loser with no chance
to record it — so the write goes through a trigger:

```sql
create table app.sync_conflicts (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  table_name   text not null,
  row_id       uuid not null,
  losing_row   jsonb not null,      -- the whole rejected row, so it can be read back by a human
  winning_revision bigint not null,
  losing_revision  bigint not null,
  recorded_at  timestamptz not null default now()
);

alter table app.sync_conflicts enable row level security;
alter table app.sync_conflicts force row level security;
create policy sync_conflicts_select on app.sync_conflicts
  for select using (user_id = (select auth.uid()));
-- No insert policy: only the trigger writes here.
```

With one account per person this is rare. It is specified now so it is not decided during an
incident, and the losing row is kept because "we resolved it and threw the other one away" is not an
answer anybody can act on afterwards.

### 9.5 The `runs_one_active_per_quest` collision

Two devices, both offline, both start the same quest. Both push. The second violates
`runs_one_active_per_quest` (§4.3) and gets a `409` — Postgres holding `FR-START-06` means Postgres
*rejecting a sync*, which needs a client answer rather than a retry loop.

The answer: **the client resolves it the same way the app already resolves a duplicate draft.** On
`409` it pulls both Runs, keeps the one with more `checkpoint_results` (ties break to the earlier
`started_at`), marks the other `abandoned` with `abandon_reason = 'userChoice'`, and pushes again.
No data is lost — the abandoned Run keeps its snapshots and still renders. Silently discarding either
one is the outcome this rule exists to prevent.

### 9.6 The rest

**Not synced:** the proximity alert log (§6.3), telemetry (it has its own path), photo bytes by
default (§4.7), sidequest photographs at all (`FR-SIDE-13`), and anything derived — profile counters,
recommendations, collection progress.

**When sync runs:** foreground, after a Run transitions, and on a background refresh task. Never in a
user path, never awaited by a view, never with a spinner in front of a walk.

**How this is tested.** RLS and the conflict trigger are the security and correctness boundary here,
and this repo's stated practice is that invariants are held by tests rather than review
(`CLAUDE.md`). A pgTAP suite asserting that user A cannot select, update or delete user B's rows —
and that a losing upsert lands in `sync_conflicts` — is the backend equivalent of
`ImportBoundaryTests`. Without it, §8 and §9.4 are review-only, which is the category this project
already has too much of.

---

## 10. Recommendations and the notification branch

**Recommendation ("shows recommendation for next adventure")** is a server-side function over
published content and the user's own history:

```sql
create function app.recommend_quests(limit_n int default 3)
returns table (quest_id text, reason text)
language sql stable security invoker as $$
  … candidate = published quests, minus completed, minus suppressed,
    ranked by region affinity from completed runs, then by shortest first …
$$;
```

`security invoker` so RLS still applies to the history it reads. It must degrade to "here are the
quests you have not walked" without a network — which means the client computes that fallback
locally from the bundle and its own store, and only *upgrades* the list when the function answers.
A recommendation strip that shows a spinner offline is a regression, not a feature.

**The passing-by notification branch needs no server at all.** It is region monitoring plus a local
notification (`system-design.md` §6.2); no push infrastructure, no device token table, no APNs
credential. If it ever becomes a server-driven push, that is a new privacy decision — a server that
can notify you about where you are is a server that knows where you are — and `NFR-PRIV-09` is the
reason it is not designed here.

---

## 11. Client-side seams this needs

Nothing above requires a rewrite, and that is the point of checking:

| Server capability | Client seam that already exists | Work |
|---|---|---|
| Content delivery | `ContentRepository` protocol | New `CachedRemoteContentRepository`. No use case changes (`system-design.md` §15). |
| Run sync | `RunStore` protocol in front of `FileRunStore` | A reconciliation worker behind the protocol, never a call in front of it. |
| Accounts | — | A new `AccountService` at the platform layer, optional at runtime like every other service there. |
| Photos, share cards | `MediaKit` (designed, unbuilt) | Upload path only. |
| Telemetry, kill-switch | `TelemetryKit`, `GovernanceKit` (designed, unbuilt) | Point them at Supabase URLs. |

Add to `schema.md` §C.1's additive columns: `device_id uuid` and `revision bigint`, both needed by §9
and both cheap to add now.

---

## 12. Rollout

| Phase | Ships | Gate |
|---|---|---|
| 0 | `ops.suppressions` + published `suppressions.json`; `POST /ingest` | Edge Services ownership decided (`system-design.md` §16) |
| 1 | Auth (anonymous + email), `app.profiles`, `app.runs` and children, push-only sync | A privacy policy and a deletion path exist |
| 2 | Pull sync, multi-device, `app.sync_conflicts` | Phase 1 stable for one content cycle |
| 3 | `app.journal_entries`, photo backup opt-in, `app.share_cards` + `issue-share-link` | Photo activities actually shipped on device |
| 4 | `catalog` authoring + `publish-content`; client swaps to `CachedRemoteContentRepository` | Validator runs in the publish pipeline, not beside it |

Each phase is independently revertible: turning it off returns the app to the phase below, never to a
broken state.

---

## 13. Open decisions

These need an owner before implementation, not during it.

1. ~~**Do accounts belong in this product at all?**~~ **DECIDED 2026-08-15: yes.** The deciding
   requirement is photograph storage — checkpoint photographs have to survive the device, and there
   is no way to hold somebody's images server-side without an identity to hold them against. That
   is a product commitment, not an inference, and it settles what §4, §7, §8 and §9 are for.

   The reasoning that was weighed against it, kept because it bounds what the tier should cost:
   iOS encrypted device backup already restores Runs, letters and photographs onto a new phone with
   no server involved (`system-design.md` §12 keeps them in the container as user content), so
   "surviving a lost phone" was largely covered before this decision. **CloudKit was considered as
   the middle path and rejected** — schema promotion between environments, unactionable error
   surfaces, immature `CKSyncEngine`. The platform is iOS-only for now, so nothing is being kept
   open for Android.

   What the decision therefore obliges, and these are now work rather than open questions:

   - **The credential is required at upload, not at Start** (§7.1). Gating the walk breaks `AD-3`,
     `FR-OFF-01` and `FR-START-08` together.
   - **Item 3 below is now urgent, not advisory.** Holding Indonesian users' photographs in
     Singapore is a cross-border transfer with a named controller and a data-subject-request window
     attached, from the first row.
   - **`FR-SET-02` grows teeth.** Deletion spans two storage objects per photograph plus every row,
     in one transaction (§4.7, §8).
   - **§7.3 and §7.4 must exist before launch,** not after: the email-collision merge, and an
     anonymous-user retention policy that cannot delete somebody's only copy of a walk.

   Rollout is unchanged in shape (§12) — phase 0 still ships first, because ingest is what produces
   a verdict on the product's own hypothesis and it needs no account at all.
2. **Auth providers.** Email/password is assumed. Sign in with Apple is mandatory on iOS if any
   third-party social provider ships.
3. **Region and residency.** Users and content are Indonesian, and **Indonesia's Personal Data
   Protection Law (UU 27/2022) applies** — this document previously said only that residency "should
   be checked", which is the vaguest sentence in it. Supabase's nearest region is Singapore, so the
   moment `app` holds a row the project is making a cross-border transfer of personal data, with
   controller obligations, a data-subject-request window, and a breach-notification duty attached.
   Three things need naming before rows exist, not after: **the law, the region, and who the
   controller is.** For a student project whose consent records are still self-grants
   (`docs/consent-log.md`), this is the item most likely to make item 1 answer itself.
4. **Photo backup default.** Designed as opt-in (§4.7). If product wants opt-out, that reverses the
   v1 privacy posture and needs to be a stated decision with a name against it.
5. **Public share links.** Expiry length, and whether a link can be indexed. `FR-SHARE-05` covers the
   photo policy; it does not cover a permanent public URL naming a sacred place.
6. **Survey linkage.** §2.4 keeps the survey anonymous even for signed-in users. If research wants
   longitudinal per-person data, that is a different consent conversation, not a schema tweak.
7. **Content authoring UI.** Postgres as the authoring store implies someone edits it — dashboard,
   custom admin, or continue authoring JSON in git and use Postgres only as a publish target. The
   last option is the cheapest and keeps content review inside pull requests — and it is not only
   cheapest, it is the only option that keeps the validator gating a **merge**, which is the
   mechanism `NFR-GOV-01` actually relies on. §5 designs the Postgres-authoring route anyway; that
   is a contradiction inside this document and it resolves in favour of git.

---

## 14. Known defects in this document

Found reviewing this document on 2026-08-15, before any of it was built. **Items 1–13 are fixed in
place and 19–21 are now specified; they are kept here because every one of them failed silently, and
a reader who inherits this design should know which parts were wrong rather than extending the
corrected text the same confidence that produced the errors.** Items 14–18 remain open.

§13.1 has since decided that the account tier *is* being built, so this list is a work record rather
than a warning against implementing §4 and §9. Nothing here affects §6.

**Sync (§9) — the section with the highest blast radius, and the one that was least finished.**

1. ~~**The pull cursor is client-authored.**~~ **Fixed, §4.1 and §9.3.** `updated_at` has no default
   and the upsert wrote `excluded.updated_at`, so the cursor was the walker's phone clock. A slow
   device stamped rows in the past and no other device ever pulled them. Now `server_seq`, from a
   sequence, written by a trigger, unwritable by a client.
2. ~~**`now()` is transaction-start time.**~~ **Fixed, §9.3.** A server timestamp would not have
   saved it: a long transaction commits behind a cursor that has already passed. A sequence has the
   same window, so the pull carries a 100-value overlap and dedupes by `id`.
3. ~~**Keyset pagination is wrong.**~~ **Fixed, §9.3.** `server_seq` is unique, so there is no tie to
   straddle a page boundary and no tuple comparison needed.
4. ~~**`app.awards`' unique constraint was defeated by NULL.**~~ **Fixed, §4.5.** Postgres treats
   NULLs as distinct, so the rows with a null `run_id` — cross-quest badges and every letter, the
   exact rows the constraint existed to protect — could duplicate without limit. Now
   `nulls not distinct`, and partial on `deleted_at is null`.
5. ~~**Push order violates a foreign key this document declares.**~~ **Fixed, §9.2.** `task_results`
   pushed before `photos` while referencing it. The first photo task ever synced would have failed.
   `photos` now precedes it.
6. ~~**The upsert no-ops silently.**~~ **Fixed, §9.2.** `where excluded.revision > …` returns `200`
   having changed nothing, and a client marking `synced` on a `200` records a row that was never
   written. Now `returning id, revision, server_seq`, and only returned ids are marked.
7. ~~**`app.sync_conflicts` is referenced and never defined.**~~ **Fixed, §9.4.** Defined, with RLS,
   no client insert policy, and a trigger — the upsert's `where` clause discards the loser with no
   opportunity to record it, so it could never have lived there.
8. ~~**"Higher revision wins" is not `FR-SYNC-02`.**~~ **Fixed, §9.4.** Stated plainly that revision
   does not encode authorship, with the tie-break and the audit row spelled out instead of implied.
9. ~~**`revision` is client-controlled and unclamped.**~~ **Fixed, §9.2.** Jumps beyond `+1000` are
   rejected as a bad request, so one buggy build cannot make a row permanently unwritable.
10. ~~**Tombstones collide with unique constraints.**~~ **Fixed, §4.4 and §4.5.** A soft-deleted row
    held its own key forever, so a walker could never re-arrive at a checkpoint whose result had been
    tombstoned. Partial unique indexes throughout, matching `runs_one_active_per_quest`.
11. ~~**`runs_one_active_per_quest` has no reconciliation story.**~~ **Fixed, §9.5.** A `409` now has
    a defined client resolution that abandons the lesser Run rather than discarding either.
12. ~~**Sync carries no schema version.**~~ **Fixed, §9.1.** `X-Sync-Schema`, and a `426` on
    unknown.
13. ~~**The photo storage path will not match its policy.**~~ **Fixed, §4.7 and §8.** Supabase keeps
    the bucket in `storage.objects.bucket_id`, not in `name`, so `'trip-photos/{user_id}/…'` made the
    policy compare a bucket name against a uid. Object names now carry no bucket prefix.

**Open — storage and sharing.**

14. **`revoked_at` cannot revoke a signed URL** already in someone's hands (§4.8). Either serve share
    cards through a function that checks it per request, or keep signed-URL lifetimes to minutes.
    `expires_at` and the URL's own expiry are also two clocks that will drift. Left open because the
    fix is a product decision about what "delete my shared card" promises, not a schema change.

**Open — content platform.**

15. **`app.recommend_quests` contradicts §5.** It is `security invoker` and ranks published quests,
    but §5 makes `catalog.bundles` the only client-readable table — so under the caller's RLS the
    function returns nothing. Since §10 already requires the client to compute the full ranking
    locally from the bundle, delete the function rather than promoting it to `security definer` and
    opening a new privacy surface.
16. **Bundle integrity rests on a checksum stored beside the artifact** (§5). Whoever can write
    Storage can usually write `catalog.bundles`. This archive decides what claims the app makes about
    sacred sites, so it warrants a detached signature verified against a key pinned in the binary,
    **and** a client-side re-run of `V1`–`V18` at load — the rules already live in `ContentKit` for
    exactly this. Untrusted-archive handling (entry paths, decompression limits) is also unspecified.

**Open — privacy claims that outrun their mechanism.**

17. **"Enforced by the absence of columns" (§2.4) holds for the table and not the system.** Edge
    Function logs record client IPs with timestamps; a signed-in request and an anonymous ingest from
    one IP seconds apart re-link what the schema separated. The claim needs a stated IP-handling and
    log-retention policy behind it.
18. **`ops.events` has no server-side retention.** The client prunes at 30 days (`schema.md` §B.11);
    the server keeps forever. Correctly undeletable under `FR-SET-02` — which is exactly why it needs
    a retention horizon of its own.
19. ~~**Indonesian PDP Law (UU 27/2022) is not named.**~~ **Named, §13.3** — but naming it is not
    resolving it. The region, the controller, and the cross-border transfer still need an owner, and
    that owner is the same person who signs §13.1.

**Auth — specified since the tier is now being built (§13.1).**

20. ~~**Anonymous-to-email linking fails when the address already exists.**~~ **Specified, §7.3.**
    `app.merge_anonymous_into`, with the two constraint collisions it has to survive
    (`runs_one_active_per_quest`, `awards_one_per_source`) and the storage-object move. Until it
    exists the app must detect the collision up front rather than failing mid-flow.
21. ~~**Anonymous users are billable MAU, and Supabase advises culling unused ones.**~~
    **Specified, §7.4.** The cull predicate requires zero Runs, zero journal entries and zero photos,
    at any age. An anonymous user with one Run is never deleted.

---

## 15. Concurrency, locking, and query shape

Everything here is a failure that appears only under real use — two devices, a slow network, a user
who taps twice. None of it shows up in development against one simulator.

### 15.1 N+1, and where it would appear

The Trip Summary is a run, its checkpoint results, each result's task results, its awards, its
journal entry and its photos. Fetched naively that is `1 + 1 + N + 1 + 1 + 1` round trips over a
mobile connection.

It should be one request. PostgREST embeds related resources through the foreign keys that already
exist:

```
GET /rest/v1/runs
    ?id=eq.<run_id>
    &select=*,checkpoint_results(*,task_results(*)),awards(*),journal_entries(*),photos(*)
```

RLS still applies to every embedded table, so this is not a way around §8 — an embedded row the
caller cannot select simply is not returned.

Two notes that matter more than the query:

- **This path is for a restored device only.** `RunSummaryViewModel` renders from local snapshots and
  takes no repository, which is how `FR-DONE-04/05` and `FR-RUN-06` are guaranteed rather than
  intended. The server query exists to *repopulate the local store* after a reinstall, never to draw
  a screen. A summary that fetches to render is a summary that fails in airplane mode.
- **A list screen must not embed children at all.** "My walks" needs `runs` alone —
  `select=id,quest_id,state,completed_at` — because embedding checkpoint results for fifty runs to
  show fifty titles is the N+1 problem inverted into one enormous response.

### 15.2 Lock ordering, and the deadlock that is one line away

A deadlock needs two transactions taking the same locks in opposite orders. The push in §9.2 is
exactly the shape that produces one, and two rules prevent it:

**Fixed table order, which §9.2 already specifies.** Every client pushes
`runs → photos → checkpoint_results → task_results → awards → journal_entries → share_cards`, always.
That ordering was written for foreign keys, and it doubles as the lock ordering — no two pushes can
take table locks in opposite sequence because there is only one sequence.

**Fixed row order within a batch, which was missing.** Two devices upserting the same twenty
checkpoint results in different orders will deadlock on the rows themselves regardless of table
order. **Sort every batch by `id` before sending.** UUIDs are arbitrary but they are *consistently*
arbitrary, and that is the entire requirement — any total order shared by all clients works.

Three more, none exotic:

- **Never hold a transaction across a network call.** Open, write, commit. An upload sitting inside
  an open transaction holds row locks for the duration of a mobile upload, which is how a deadlock
  becomes a five-second stall for somebody else.
- **Batch the cascade in `FR-SET-02`.** `delete from auth.users where id = …` cascades through every
  table for that user in a single statement, taking every lock at once. For a heavy user that is a
  long transaction blocking their own sync. Delete leaf-first in batches — `task_results`, then
  `checkpoint_results`, then `runs` — committing between them.
- **Bound transaction lifetime at the database.** `statement_timeout` and
  `idle_in_transaction_session_timeout` set on the anon and authenticated roles turn a hung client
  from an indefinite lock-holder into an error. This also bounds §15.4's cursor window.

### 15.3 Races that are specific to this design

**Upload completes after deletion.** The user taps "delete all my data" while a photograph is
uploading. §8's Edge Function removes the row and the objects; the in-flight PUT lands afterwards and
recreates one. The result is an object with no row — unreachable, undeletable, and still personal
data, on the one code path where that is least acceptable. Two guards, both needed: a `deleting` flag
the upload path checks before its final PUT, and the orphan sweeper (§4.7) as the backstop, because
the flag is a race narrowed rather than a race closed.

**Double-tap on a challenge or a task.** `SideQuestEngine.answerQuiz` awards at most one letter ever
and `discover` is idempotent, both held by tests in `swift test`. The server's half is
`awards_one_per_source` (§4.5) — with `nulls not distinct`, so it actually applies to letters. Two
simultaneous pushes of the same award: one inserts, the other hits the unique index and is a no-op.
Correct by construction, provided that index exists, which is why defect 4 mattered.

**Two devices starting the same quest offline.** Handled at §9.5 rather than prevented; the
constraint fires and the client resolves it.

**Concurrent merge and sync.** §7.3's merge moves rows between users while a device may be pushing
to either identity. The merge should reject if the anonymous user has rows with `sync_state` in
flight — simpler than reconciling mid-move, and the client can retry after its queue drains.

### 15.4 The pull cursor's remaining window, stated honestly

§9.3 pulls `server_seq > cursor - 100`. **That overlap is a mitigation, not a proof.** A sequence
value is claimed before commit, so a transaction that claims 500 and commits slowly can land behind a
reader that has already passed 500. If more than 100 values are claimed during that transaction's
lifetime, the row is still missed.

What makes it sound is the bound in §15.2: with `idle_in_transaction_session_timeout` set, no
transaction outlives that timeout, so the overlap has to cover only the values claimed within it.
Sync writes arrive in small batches from one user, so 100 is generous — but the number is derived
from the timeout and the write rate, and it should be revisited if either changes rather than treated
as a constant.

The client dedupes by `id` and `revision` on receipt regardless, which it must do anyway for retries.
The overlap is therefore free apart from a few extra rows per pull.

**Revisited 2026-08-16, because migration 0016 changed one of the two inputs above.** This section
says the number "is derived from the timeout and the write rate, and it should be revisited if
either changes". The timeout changed twice on the same day:

- Before 0016, `service_role` had **no** `idle_in_transaction_session_timeout` at all — 0002 set it
  on `authenticated` and `anon` only. So for any service-role write the bound this section rests on
  did not exist, and the overlap was unsound rather than generous. That was not noticed when 0002
  was written.
- 0016 sets it to 60s, which restores the bound but at **twice** `authenticated`'s 30s.

The case that matters is `merge-anonymous`. It rewrites `user_id` across a whole anonymous account's
history in one transaction, and every one of those updates fires `stamp_server_seq` and claims a
sequence value. **An account with more than 100 rows therefore claims more than 100 values inside a
single transaction** — the precise condition this section names as the one the overlap does not
cover. A second device pulling concurrently during that merge can miss rows.

No code changed for this. There is no client sync yet (`c1` §2), so the 100 is still only a number
in this document, and the right time to set it is when the pull is built — with the 60s bound and
the merge's row count in hand, not before. Written down here so it is a decision waiting to be made
rather than a constant somebody copies.

### 15.5 Indexes

**Postgres does not index foreign key columns automatically.** Every `on delete cascade` in §4
resolves by scanning the child table for matching parent ids, so without these, deleting one user
sequentially scans every table:

```sql
create index checkpoint_results_run   on app.checkpoint_results (run_id);
create index task_results_checkpoint  on app.task_results (checkpoint_result_id);
create index task_results_run         on app.task_results (run_id);
create index task_results_photo       on app.task_results (photo_id);   -- on delete set null
create index awards_run               on app.awards (run_id);
create index photos_run               on app.photos (run_id);
create index share_cards_run          on app.share_cards (run_id);
```

`task_results_photo` earns its place twice: the `on delete set null` in §4.5 also scans without it.

**Pull needs `(user_id, server_seq)` on every syncable table** — §9.3's query filters on the first
and orders by the second, and only `runs` and `checkpoint_results` have it written out so far.

**Retention on `ops` uses BRIN, not B-tree** — specified at §6.2, for the horizon defect 18 says is
missing. At pilot volume a scheduled `delete` against a BRIN index is enough; partitioning by month
is the answer if event volume ever makes the delete itself the problem, and it is not worth paying
for speculatively.

**A covering index is available for the one hot list query** and is not worth taking yet. "My walks"
reads `id, quest_id, state, completed_at` — `(user_id, completed_at desc) include (quest_id, state)`
would serve it index-only. At tens of runs per user the heap fetch is free, and an `INCLUDE` column
is one more thing to keep in step with the query. Revisit if the list ever grows.

Everything else in §4 is precautionary at v1 volumes — tens of runs and thousands of events per
user — and costs nothing to add now. The FK indexes above are not precautionary; they are the
difference between a linear and a quadratic account deletion.

### 15.6 Connections

PostgREST pools on the client's behalf, so the app needs nothing. Edge Functions opening direct
Postgres connections must use the **transaction-mode pooler** rather than the direct port: a
serverless function scales to many short-lived invocations, and one direct connection per invocation
exhausts `max_connections` under exactly the load you would want it to survive. Transaction mode
means no session-level state — no `SET`, no prepared statements held across statements, no advisory
locks — which is a constraint on how those functions are written, not a setting.

### 15.7 Bloat, vacuum, and the settings that bound them

Postgres does not leak memory the way a process does. **It leaks dead tuples**, and this schema is
unusually exposed to it for three reasons that are all deliberate:

- Tombstones mean rows are never removed (`schema.md` §C.3 rule 3), so tables only grow.
- Every sync update bumps the indexed `server_seq`, which rules out HOT updates and leaves a dead
  tuple plus fresh index entries on each write (§4.1).
- The snapshot columns are wide, so each dead tuple is expensive rather than incidental.

The setting that matters most is not a vacuum setting at all:

```sql
alter role authenticated set statement_timeout = '30s';
alter role authenticated set idle_in_transaction_session_timeout = '30s';
alter role anon          set statement_timeout = '10s';
```

**A single long-lived transaction holds back the vacuum horizon for the entire database**, not just
its own rows — nothing newer than its snapshot can be reclaimed anywhere. One hung mobile client with
an open transaction is therefore a cluster-wide bloat event, and the timeout is what turns it into an
error instead. It is also what makes §15.4's cursor overlap sound, so it is load-bearing twice.

Then the vacuum settings themselves, on the sync tables only:

```sql
alter table app.runs set (
  autovacuum_vacuum_scale_factor  = 0.05,   -- default 0.2 waits until a fifth of the table is dead
  autovacuum_analyze_scale_factor = 0.02
);
```

And `work_mem`, which is the one genuine memory footgun: it is allocated **per sort or hash operation,
not per connection**, so a query with several sorts across many connections multiplies well past what
the number suggests. 8 MB is a sane default at this size; raising it globally to fix one slow query is
how a database gets OOM-killed.

`pg_stat_statements` should be on from day one — it costs almost nothing and it is the only way to
answer "which query got slow" after the fact rather than by guessing.

### 15.8 Migrations that do not lock the table

Two of the changes in this revision — `'letter'` on `awards.type` (§4.5) and `'sidequest'` on
`suppressions.entity_type` (§6.1) — extend a `check` constraint. Done naively that is a drop and
re-add, which takes `ACCESS EXCLUSIVE` and re-scans the whole table to validate: harmless on an empty
table, a stall on a live one, and these lists will keep growing.

```sql
alter table app.awards drop constraint awards_type_check;
alter table app.awards add constraint awards_type_check
  check (type in ('stamp','badge','letter')) not valid;      -- instant, no scan, no long lock
alter table app.awards validate constraint awards_type_check; -- scans under a weak lock
```

`NOT VALID` accepts the constraint for new rows immediately and defers the check of existing ones to
`VALIDATE`, which takes only `SHARE UPDATE EXCLUSIVE` and does not block reads or writes.

The same discipline applies to the rest of this document's DDL:

- **New indexes use `CREATE INDEX CONCURRENTLY`** once there is data. It cannot run inside a
  transaction, so it needs its own migration step — which is exactly why it gets forgotten and then
  locks a table during a deploy.
- **A new `not null` column needs a default or two steps.** Postgres 11+ makes a constant default
  cheap, but `server_seq`'s default is `nextval(…)` — a volatile expression — so adding it to a
  populated table rewrites it. Add nullable, backfill in batches, then set `not null`.
- **`text` + `check` was chosen over Postgres enums for exactly this reason.** `ALTER TYPE … ADD
  VALUE` is cheap but cannot be dropped, cannot always run in a transaction with its use, and
  serializes awkwardly through PostgREST. A check constraint is editable in both directions with the
  pattern above.

---

*Companions: [`system-design.md`](system-design.md), [`schema.md`](schema.md).*
