# Phase 2 — Sync Identity

**Size:** ~half a day · **Depends on:** nothing · **Touches no network code at all**
**Demo sentence:** "Every record the app writes now knows which device wrote it and when — and none of that required a server."

**Status:** `NOT STARTED` · **Started:** — · **Completed:** —

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

> **Cut down 2026-08-21** from two days to about half of one, at the owner's
> instruction: MVP only, no speculative machinery. What went, and why each thing was
> safe to drop, is in "What this phase used to contain" at the bottom. Read that before
> putting any of it back.

## Goal

Give every syncable record the three fields the deployed schema demands and the client
does not have, **before** any transport exists to argue with.

Three, not five. `app.runs` and its four sibling tables declare `device_id`,
`created_at` and `updated_at` as `not null` with **no default** — those the client must
send. `revision` is `not null default 1` and `server_seq` is `not null default
nextval(…)`; both are the server's to fill, and a client that omits them is correct.

Full mapping: [`../02-data-model.md`](../02-data-model.md).

## Why this phase comes before push sync

Doing it inside phase 3 means debugging a schema disagreement and an HTTP problem at
the same time, on a device, with a walk in the middle. Doing it here means it is a
package change, on macOS, in milliseconds, with `swift test`.

It also means phase 3 is **transport only** — and a phase that is transport only can be
deleted if it goes wrong, which phase 2's fields cannot once records are written with
them.

## Scope

### `SyncMetadata`

- [ ] One nested value carrying `deviceID`, `createdAt`, `updatedAt` — not three loose
      properties, so a new syncable record cannot forget one.
- [ ] Added to `Run`, `CheckpointResult`, `TaskResult`, `Award`.
- [ ] `deviceID` is the per-install UUID phase 1 creates. One per installation, in
      preferences, never regenerated while the app stays installed.
- [ ] `revision` and `server_seq` are **not** client fields. The device never sends
      either. `revision` defaults to 1 server-side and the `<table>_stamp_seq` triggers
      assign `server_seq`.
- [ ] `updatedAt` is device-clock and display-only. Write a comment saying it is
      **never a sync cursor** — the migration says it twice for a reason.

### Accuracy bucketing — reuse, do not rebuild

- [ ] **`TelemetryKit.AccuracyBand` already is this.** Same three tokens (`lt20`,
      `b20_75`, `gt75`), same boundaries, shipped and tested since phase 0, and its
      rows are already in `ops.events` on prod. `app.checkpoint_results`'s
      `gps_accuracy_bucket` check constraint accepts exactly those three strings.
- [ ] So: **do not add `GPSAccuracyBucket` to `RunEngine`.** Two enums for one
      constraint is how the two drift, and the drift is silent until a row is rejected
      on a walker's device.
- [ ] Decide where the conversion lives and write it here. `RunEngine` must not import
      `TelemetryKit` (that is a new package edge for a three-case enum), so the
      likeliest answer is that the **push DTO** in `Services/` does the bucketing, since
      that is the only place both the metre value and the wire shape are in hand.
- [ ] The precise metre value stays in `FileRunStore` and never leaves the device
      (`NFR-PRIV-02`). That is the load-bearing half and it does not care which type
      does the arithmetic.

### `snapshot_sources`

- [ ] Project it from the union of `snapshotLore[].sourceCitations` at push time. No
      client change, no shipped record altered. (The alternative — snapshotting it
      separately at arrival — is more truthful to `AD-4` and is a change to a record
      users already have; it is not worth that for a value that is a projection of a
      field sitting beside it.)
- [ ] `snapshotClueToNext` stays local — it has no server column and is what the next
      screen prints, not part of the historical record.

### `lore_dwell_ms`

- [ ] Push null, deliberately. Nothing measures dwell, the column is nullable, and
      instrumenting the lore screen is a behaviour change for a metric nobody has a
      question about. Recorded as a decision, not a forgotten column.

### Migration of existing records

- [ ] A `Run` written by the pre-C2 shape still decodes. Defaults: `deviceID` = this
      install's, `createdAt` = `startedAt`, `updatedAt` = `startedAt`.
- [ ] A round-trip test that loads a checked-in fixture of the **old** JSON.

## Exit criteria

- [ ] Package suite green on macOS; the four known pre-existing failures unchanged.
- [ ] Old-shape fixture decodes and re-encodes without loss.
- [ ] `RunEngine` still imports nothing but Foundation and `ContentKit` —
      `ImportBoundaryTests` green.
- [ ] Grep proves no network type entered `RunEngine`.

## Out of scope

Any HTTP. Any DTO shaped for PostgREST — those live in `Services/` and belong to phase
3. `photo_id` resolution, which is phase 4's.

## What this phase used to contain

Three things were cut on 2026-08-21. None was wrong; each was **early**, and each cost
real work plus a permanent on-disk format it would then be dishonest to remove.

- **`revision`, bumped by the device on every local write.** It exists to resolve
  conflicts, and a conflict needs two writers. C2 has one device and no pull of live
  data, and the restore in phase 7 runs **only into an empty store**, so there is no
  second writer anywhere in the MVP. The column keeps its `default 1` and the server
  fills it. This also dissolves the sharpest risk note this file used to carry: that
  `RunEngine` writes more often than it looks — `markLoreOpened` and `recordTaskResult`
  both write, and both accept a `completed` run (`FR-DONE-01`, `FR-TASK-07`) — so any
  revision scheme assuming writes stop at completion is wrong. True, and now moot.
  **Put this back the day a second device can write, and not before.**
- **Tombstones (`deleted_at` set instead of the record removed).** They matter when a
  delete must propagate. **Nothing in the app deletes one walk**: `RunStore.delete(id:)`
  is in the protocol and has no caller, and the only delete a user can perform is
  Settings → erase everything, which is `FR-SET-02` and must genuinely erase. Phase 3
  pairs that with `delete-account`, so the server side goes too and a restore afterwards
  correctly finds nothing. The column stays nullable and stays null.
  This also dissolves the risk note about `deleteAll()` having two callers wanting
  opposite things — it has one caller, and that caller means *erase*.
  **Put this back the day the app grows a per-walk delete.**
- **`GPSAccuracyBucket` as a new `RunEngine` type.** Duplicate of
  `TelemetryKit.AccuracyBand`; see above.

## Risk notes

- **This phase changes the on-disk format of every user's existing data.** The fixture
  test is not optional. It is a smaller change than it was — three fields, all
  defaultable from data already in the record — but a `Run` that fails to decode is a
  walker's history gone.
- **`deviceID` must come from phase 1's preference, not be minted here.** Two sources
  for one per-install identity is the same mistake as two accuracy enums, one layer up.
