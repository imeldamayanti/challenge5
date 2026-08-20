# 02 — Data Model: client ↔ server

The server schema is deployed and is not changing. This document is the mapping, and
the five places where the client does not yet have what the server requires.

## Build checklist

Tick when the client type carries the field, `FileRunStore` round-trips it, and a
package test proves it.

- [ ] `SyncMetadata` on `Run` (phase 2)
- [ ] `SyncMetadata` on `CheckpointResult` (phase 2)
- [ ] `SyncMetadata` on `TaskResult` (phase 2)
- [ ] `SyncMetadata` on `Award` (phase 2)
- [ ] Tombstone delete replaces hard delete in `RunStore` (phase 2)
- [ ] `GPSAccuracyBucket` derived on device, precise value never leaves (phase 2)
- [ ] Decoding a pre-C2 `Run` JSON still works (phase 2)
- [ ] `photo_id` resolution from `photoRelativePath` (phase 4)

## 1. The five gaps

| # | Gap | Client today | Server requires | Phase |
|---|---|---|---|---|
| G1 | Sync identity | `Run.updatedAt` only | `device_id`, `revision`, `created_at`, `updated_at`, `deleted_at` on **every** syncable row | 2 |
| G2 | Accuracy | `CheckpointResult.gpsAccuracyM: Double?` | `gps_accuracy_bucket` ∈ `lt20` / `b20_75` / `gt75` | 2 |
| G3 | Snapshot fields | `snapshotClueToNext: String?` | `snapshot_sources jsonb not null` | 2 |
| G4 | Lore dwell | nothing produces it | `lore_dwell_ms int` | 2 |
| G5 | Photo link | `TaskResult.photoRelativePath: String?` | `task_results.photo_id uuid` → `app.photos` | 4 |

### G1 — sync identity

Four columns, one shape. Add them as a single nested value rather than four loose
properties, so a new syncable record cannot forget one:

```
device_id   uuid    which device authored this revision (FR-SYNC-02)
revision    bigint  bumped by the device on each local write, starts at 1
created_at  Date    device clock, display only
updated_at  Date    device clock, display only — NEVER a sync cursor
deleted_at  Date?   tombstone
```

`server_seq` is **server-owned**. The device never sends it and never stores it. The
`<table>_stamp_seq` triggers assign it.

`updated_at` is not a cursor, and the migration says so twice. A device clock is
wrong often enough that pull sync reads `server_seq`.

`device_id` is one value per installation, generated once and kept in preferences. It
survives relaunch and does not survive reinstall, which is correct — a reinstall is a
different authoring device as far as conflict resolution is concerned.

### G2 — accuracy is bucketed on the device

This is a privacy requirement, not a format detail. The migration's comment:

> The server stores a BUCKET, not the metre figure the device keeps: a precise
> accuracy reading beside a checkpoint id and a timestamp is a location trace by
> another name (NFR-PRIV-02).

So the precise `gpsAccuracyM` stays in `FileRunStore` forever and the bucket is
derived at push time — or, better, derived in `RunEngine` as a computed property so
there is one implementation and a test can point at it.

**The band tokens are `lt20`, `b20_75`, `gt75`.** `schema.md` §B.7 writes the middle
band with an en dash (`20–75m`); one copy-paste between documents is a runtime
constraint violation nobody would think to look for. Use the tokens.

### G3 — `snapshot_sources`

The client stores `snapshotClueToNext`; the server has `snapshot_sources jsonb not
null`. These are not the same thing and neither is derivable from the other.

`CheckpointResult.snapshotLore` already carries `sourceCitations: [String]` per block,
so the sources are present — they are just nested inside the lore array rather than
held separately. Two options, and phase 2 picks one and writes it down:

1. Project `snapshot_sources` from the union of the blocks' citations at push time.
   No client change; the two representations can drift only if the projection is
   wrong.
2. Snapshot sources separately at arrival, matching the server shape exactly.
   Truthful to `AD-4` (snapshot everything at completion) and a change to a record
   that already ships.

Option 1 unless a reason appears. `snapshotClueToNext` has no server column and stays
local — it is what the *next* screen prints, not part of the historical record.

### G4 — `lore_dwell_ms`

Nothing measures it. `CheckpointResult.loreFirstOpenedAt` exists; a closing timestamp
does not.

**It is nullable on the server.** Push null and move on. Measuring dwell time means
instrumenting the lore screen's appearance and disappearance, which is a behaviour
change to a shipped screen for a metric nobody has asked a question about yet.
`NFR-PRIV` also has opinions about how precisely you may record how long somebody
looked at something.

Recorded here as a deliberate null, not a forgotten column.

### G5 — photo link

Client `TaskResult` holds `photoRelativePath: String?` — a path in the app's
Documents directory. Server `task_results.photo_id` is a UUID foreign key to
`app.photos`, `on delete set null`.

Phase 4 owns the mapping. The `set null` is load-bearing: a photograph the user later
removes must not take the record of the task with it.

## 2. Field-by-field

### `app.runs`

| Server column | Client source | Note |
|---|---|---|
| `id` | `Run.id` | UUIDv7, already correct |
| `user_id` | session | from the anonymous session, phase 1 |
| `quest_id` | `Run.questID` | **`text`, not a foreign key.** See §4 |
| `content_version` | `Run.contentVersion` | pinned at start (`AD-4`) |
| `language` | `Run.language` | `id` \| `en` |
| `state` | `Run.state` | `notStarted` is absent server-side on purpose and is never persisted locally either |
| `current_checkpoint_index` | `Run.currentCheckpointIndex` | |
| `started_at` / `completed_at` / `abandoned_at` / `abandon_reason` | same names | two `check` constraints enforce the pairs |
| sync columns | G1 | |
| — | `Run.snapshotQuestTitle` | **no server column.** Stays local |
| — | `Run.checkpointCount` | **no server column.** Derivable |

### `app.checkpoint_results`

| Server column | Client source | Note |
|---|---|---|
| `id`, `run_id`, `user_id`, `checkpoint_id`, `order_index` | direct | |
| `arrived_at`, `arrival_method` | direct | `gps` \| `manual` |
| `gps_accuracy_bucket` | G2 | derived, never the raw metres |
| `lore_first_opened_at` | `loreFirstOpenedAt` | |
| `lore_dwell_ms` | G4 | null |
| `stamp_awarded_at` | `stampAwardedAt` | |
| `snapshot_place_name`, `snapshot_lore`, `snapshot_content_version` | direct | |
| `snapshot_sources` | G3 | |
| — | `snapshotClueToNext` | stays local |

`snapshot_lore` is **never indexed** and nothing queries inside it. The migration says
a GIN index there is pure write amplification that *looks* like diligence.

### `app.task_results`

| Server column | Client source | Note |
|---|---|---|
| `id`, `task_id`, `type`, `skipped`, `completed_at` | direct | `skipped` is a first-class outcome, not a failure (`AD-2`) |
| `answer_text` | `TaskResult.text` | |
| `photo_id` | G5 | phase 4 |
| `checkpoint_result_id`, `run_id`, `user_id` | direct | |
| — | `promptSnapshot` | **no server column.** Stays local |

### `app.awards`

| Server column | Client source | Note |
|---|---|---|
| `id`, `type`, `source_id`, `snapshot_name`, `awarded_at` | direct | |
| `run_id` | enclosing `Run` | nullable server-side: null for a cross-quest badge and for every letter |
| `user_id` | session | |

### `app.photos` (phase 4)

| Server column | Source |
|---|---|
| `storage_path` | `{user_id}/{run_id}/{id}.heic` — **no bucket prefix** |
| `thumb_path` | `{user_id}/{run_id}/{id}_t.heic` |
| `content_type` | `image/heic` or `image/jpeg` |
| `width_px`, `height_px` | of the **full derivative**, so a grid can lay out before downloading |
| `byte_size` | full + thumb, for `FR-SET-03`'s storage report and orphan detection |
| `captured_at` | shutter time |
| `uploaded_at` | **null until the bytes are actually on the server** |

## 3. Records that have no server column

Not gaps. They are local by design and pushing them would be adding a column to a
deployed schema for no reader:

`Run.snapshotQuestTitle`, `Run.checkpointCount`, `CheckpointResult.snapshotClueToNext`,
`CheckpointResult.gpsAccuracyM` (the precise value), `TaskResult.promptSnapshot`, and
every sidequest record in `SideQuestStore`.

## 4. The rule that outranks all of the above

`quest_id`, `checkpoint_id`, `place_id` and `source_id` are `text` and are **not**
foreign keys to any content table. Migration 0006 opens by saying the most important
line in the file is an absence.

Content is replaced wholesale; user data is permanent. A foreign key between them
means a content correction can cascade-delete somebody's completed walk. No sync code
may add one, no client mapping may assume the server can resolve one, and no
convenience join may be written that would only work while today's content is
current.
