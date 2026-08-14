# Backend Design — Supabase

**Status: design only.** Nothing here is implemented, and none of it is a dependency of the app as it
stands today. This document decides the shape of the server so that v2 (accounts + sync) and v3 (CMS)
can be built without renegotiating the architecture, and so the screens the app-flow chart draws —
login, journal, share, recommendations — have somewhere to live.

**Companions:** [`system-design.md`](system-design.md) (§1 Edge Services, §4 two stores, §15 seams),
[`schema.md`](schema.md) (Part B local persistence, Part C migration).
**Requirements:** `.claude/prds/cultural-heritage-quest.full.prd.md`.

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

### 2.3 Device-generated UUIDs are the server's primary keys

Every local record already carries a `UUID` and timestamps from v1 — that was `NFR-MAINT-04`'s whole
purpose. So sync is `insert … on conflict (id) do update`, idempotent by construction. There is no
identity migration, no id mapping table, and a retried push is harmless.

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
id            uuid primary key,          -- generated on device (§2.3)
user_id       uuid not null references auth.users(id) on delete cascade,
device_id     uuid not null,             -- which device authored this revision (FR-SYNC-02)
revision      bigint not null default 1, -- bumped by the device on each local write
created_at    timestamptz not null,
updated_at    timestamptz not null,
deleted_at    timestamptz                -- tombstone; rows are never hard-deleted (§C.3 rule 3)
```

`user_id` is repeated on child tables rather than reached through a join, so every RLS policy is an
index lookup instead of a recursive `exists`.

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
  gps_accuracy_bucket      text check (gps_accuracy_bucket in ('<20m','20-75m','>75m')),
  lore_first_opened_at     timestamptz,
  lore_dwell_ms            int,
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
  deleted_at timestamptz,

  unique (run_id, checkpoint_id)
);
```

**One deliberate difference from the device schema.** On device, `CheckpointResultRecord` stores
`gpsAccuracyM: Double?` — a real metre figure, useful for diagnosing a walk. The server stores a
*bucket*. A precise accuracy reading beside a checkpoint id and a timestamp is a location trace by
another name, and `NFR-PRIV-02` forbids sending one. The client narrows the value on push; the local
column is unchanged.

A `check` constraint asserting the shape of `snapshot_lore` is tempting and is not worth it — the
snapshot's meaning may only ever be *added* to (`schema.md` §C.3 rule 2), and a JSON-shape constraint
turns that additive rule into a migration.

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
  unique (checkpoint_result_id, task_id)
);

create table app.awards (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  run_id        uuid references app.runs(id) on delete cascade,   -- null = cross-quest badge (v2)
  type          text not null check (type in ('stamp','badge')),
  source_id     text not null,        -- stampId / badgeId from content
  snapshot_name text not null,        -- survives content changes
  awarded_at    timestamptz not null,
  device_id uuid not null, revision bigint not null default 1,
  created_at timestamptz not null, updated_at timestamptz not null, deleted_at timestamptz,
  unique (user_id, run_id, type, source_id)
);
```

Note `task_results.photo_id` is nullable and `on delete set null`: a photo the user later removes from
the server must not take the record of the task with it.

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
  storage_path  text,                    -- 'trip-photos/{user_id}/{run_id}/{id}.heic'; null = device-only
  captured_at   timestamptz not null,
  uploaded_at   timestamptz,             -- null until the user actually asks for it to leave the phone
  device_id uuid not null, revision bigint not null default 1,
  created_at timestamptz not null, updated_at timestamptz not null, deleted_at timestamptz
);
```

**Photos do not sync by default.** `NFR-PRIV` and the v1 posture (`system-design.md` §12) put *no*
photos on a server; introducing accounts must not silently reverse that. A row exists so the summary
knows a photo was taken; `storage_path` stays null and the bytes stay on the phone until the user
turns on photo backup or shares a card. The local path stays relative (`NFR-REL-05`) and is never
uploaded — a container path is meaningless on another device.

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
  entity_type   text not null check (entity_type in ('place','quest')),
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
```

Neither table has a `user_id`, and neither should ever acquire one. The event catalogue is unchanged
(`schema.md` §B.7); `accuracy_bucket` remains a band.

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
  and is pruned at 7 days.
- Photo bytes, unless the user asks (§4.7).
- Consent records, to any client.

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

Consequences to accept deliberately:

- An anonymous session lost with the device is a walk lost, because there is no credential to recover
  it with. The app should say so where it asks people to register, not in a privacy policy.
- Anonymous sign-in still requires the network, so **it cannot gate anything**. If it fails, the app
  runs exactly as it does today: local store, no sync, no complaint. The session attempt belongs at
  the platform layer with the rest of the optional infrastructure.
- Sign-in providers are a product decision (§10). Email/password is assumed here because it is what
  the chart draws.

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

Points that are easy to get wrong and expensive to discover later:

- `(select auth.uid())` rather than bare `auth.uid()` — Postgres caches the scalar sub-select per
  statement instead of re-evaluating per row.
- `force row level security` matters because the table owner otherwise bypasses its own policies.
- `user_id` is denormalised onto every child table (§4.1) so no policy needs a join to `app.runs`.
- **Deletion is a server-side operation, not a client one.** `FR-SET-02` ("delete all my data") runs
  as an Edge Function that hard-deletes rows *and* Storage objects in one transaction, because the
  same bug exists here as on device: dropping database rows and leaving the images is a privacy
  failure that passes every database test.
- `catalog`: `select` for `anon` on `bundles` only. `ops`: no client policies at all; the ingest
  function uses the service role.
- Storage buckets `trip-photos` and `share-cards` are private, with `storage.objects` policies keyed
  on the first path segment being `auth.uid()::text`. `content` is public-read (it is the published
  bundle) and service-role write.

---

## 9. Sync protocol

Deliberately dull. Runs are append-mostly and single-author; nothing here needs CRDTs.

**Push** — the client holds a local `sync_state` per row (`local | pending | synced`, `schema.md`
§C.1) and pushes in dependency order:

```
runs ─► checkpoint_results ─► task_results ─► awards ─► journal_entries ─► photos ─► share_cards

insert … on conflict (id) do update
  set … , revision = excluded.revision, updated_at = excluded.updated_at
  where excluded.revision > app.<table>.revision      -- a stale retry is a no-op
```

Idempotent by primary key (§2.3), so a retry after a dropped response is safe, and ordering means a
child never arrives before its parent.

**Pull** — one cursor per table, `updated_at > cursor order by updated_at limit N`, including
tombstones so a deletion propagates. The cursor is the server's `updated_at`, so a device with a
skewed clock cannot skip rows.

**Conflict** — `FR-SYNC-02`: the device that authored the row wins. Concretely, higher `revision`
wins; equal revisions from different `device_id`s resolve to the earlier `updated_at`, and the loser
is kept in an `app.sync_conflicts` audit table rather than dropped. With one account per person this
is rare; the rule exists so it is decided now and not during an incident.

**Not synced:** the proximity alert log (§6.3), telemetry (it has its own path), photo bytes by
default (§4.7), and anything derived — profile counters, recommendations.

**When sync runs:** foreground, after a Run transitions, and on a background refresh task. Never in a
user path, never awaited by a view, never with a spinner in front of a walk.

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

1. **Do accounts belong in this product at all?** Everything the chart draws behind login — journal,
   trip summary, share, recommendation — works on-device without one. The account buys exactly two
   things: surviving a lost phone, and a second device. Both are real; neither is free, and an
   account brings PII, deletion obligations, and a support surface.
2. **Auth providers.** Email/password is assumed. Sign in with Apple is mandatory on iOS if any
   third-party social provider ships.
3. **Region and residency.** Users and content are Indonesian; the Supabase project region and any
   local data-residency obligation should be checked before rows exist, not after.
4. **Photo backup default.** Designed as opt-in (§4.7). If product wants opt-out, that reverses the
   v1 privacy posture and needs to be a stated decision with a name against it.
5. **Public share links.** Expiry length, and whether a link can be indexed. `FR-SHARE-05` covers the
   photo policy; it does not cover a permanent public URL naming a sacred place.
6. **Survey linkage.** §2.4 keeps the survey anonymous even for signed-in users. If research wants
   longitudinal per-person data, that is a different consent conversation, not a schema tweak.
7. **Content authoring UI.** Postgres as the authoring store implies someone edits it — dashboard,
   custom admin, or continue authoring JSON in git and use Postgres only as a publish target. The
   last option is the cheapest and keeps content review inside pull requests.

---

*Companions: [`system-design.md`](system-design.md), [`schema.md`](schema.md).*
