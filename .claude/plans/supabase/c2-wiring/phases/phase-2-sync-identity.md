# Phase 2 — Sync Identity

**Size:** 2 days · **Depends on:** nothing · **Touches no network code at all**
**Demo sentence:** "Every record the app writes now knows which device wrote it, which revision it is, and whether it was deleted — and none of that required a server."

**Status:** `NOT STARTED` · **Started:** — · **Completed:** —

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

## Goal

Close the five gaps between what the client records hold and what the deployed schema
requires, **before** any transport exists to argue with.

Full mapping and rationale: [`../02-data-model.md`](../02-data-model.md).

## Why this phase comes before push sync

Doing it inside phase 3 means debugging a schema disagreement and an HTTP problem at
the same time, on a device, with a walk in the middle. Doing it here means it is a
package change, on macOS, in milliseconds, with `swift test`.

It also means phase 3 is **transport only** — and a phase that is transport only can
be deleted if it goes wrong, which phase 2's fields cannot once records are written
with them.

## Scope

### `SyncMetadata`

- [ ] One nested value carrying `deviceID`, `revision`, `createdAt`, `updatedAt`,
      `deletedAt` — not five loose properties, so a new syncable record cannot forget
      one.
- [ ] Added to `Run`, `CheckpointResult`, `TaskResult`, `Award`.
- [ ] `revision` starts at 1 and is bumped by the device on **each local write**.
- [ ] `server_seq` is **not** a client field. The device never sends it and never
      stores it; the `<table>_stamp_seq` triggers assign it.
- [ ] `updatedAt` is device-clock and display-only. Write a comment saying it is
      **never a sync cursor** — the migration says it twice for a reason.

### Tombstones

- [ ] `RunStore.delete(id:)` sets `deletedAt` and keeps the record. It currently
      removes a file.
- [ ] `runs()` filters tombstones out, so nothing above the store changes behaviour.
- [ ] `deleteAll()` tombstones rather than truncates — **except** when called by
      `DataEraser`, which is `FR-SET-02` and must genuinely remove local data.
      Decide and write down which of the two `deleteAll` means; if both are needed,
      they are two methods.

### Accuracy bucketing

- [ ] `GPSAccuracyBucket` in `RunEngine`, derived from `gpsAccuracyM`.
- [ ] Tokens exactly `lt20`, `b20_75`, `gt75`. **Not** the en dash `schema.md` §B.7
      uses in prose — one copy-paste is a runtime constraint violation nobody would
      look for.
- [ ] The precise metre value stays in `FileRunStore` and never leaves the device
      (`NFR-PRIV-02`).
- [ ] Boundary tests: 19.9 → `lt20`, 20.0 → `b20_75`, 75.0 → `b20_75`, 75.1 → `gt75`,
      nil → nil.

### `snapshot_sources`

- [ ] Decide: project it from the union of `snapshotLore[].sourceCitations` at push
      time (no client change), or snapshot it separately at arrival (truthful to
      `AD-4`, changes a shipped record). **Recommendation: project it.** Record the
      decision here.
- [ ] `snapshotClueToNext` stays local — it has no server column and is what the next
      screen prints, not part of the historical record.

### `lore_dwell_ms`

- [ ] Push null, deliberately. Nothing measures dwell, the column is nullable, and
      instrumenting the lore screen is a behaviour change for a metric nobody has a
      question about. Recorded as a decision, not a forgotten column.

### Migration of existing records

- [ ] A `Run` written by the pre-C2 shape still decodes. Defaults: `revision = 1`,
      `deviceID` = this install's, `createdAt` = `startedAt`, `deletedAt` = nil.
- [ ] A round-trip test that loads a checked-in fixture of the **old** JSON.

## Exit criteria

- [ ] Package suite green on macOS; the four known pre-existing failures unchanged.
- [ ] Old-shape fixture decodes and re-encodes without loss.
- [ ] A deleted run is a tombstone, not an absence, and does not appear in `runs()`.
- [ ] Bucketing boundaries all five cases.
- [ ] `RunEngine` still imports nothing but Foundation and `ContentKit` —
      `ImportBoundaryTests` green.
- [ ] Grep proves no network type entered `RunEngine`.

## Out of scope

Any HTTP. Any DTO shaped for PostgREST — those live in `Services/` and belong to
phase 3. `photo_id` resolution, which is phase 4's.

## Risk notes

- **`deleteAll()` has two callers wanting opposite things.** Settings erasure must
  actually erase; a sync-era bulk delete must tombstone. Getting this backwards means
  either `FR-SET-02` lies, or a user's whole history resurrects from the server on the
  next device. Read both call sites before choosing.
- **`revision` is bumped by the device on each local write, and `RunEngine` writes
  more often than it looks.** `markLoreOpened` and `recordTaskResult` both write, and
  both accept a `completed` run — the final checkpoint completes the walk while the
  walker is still standing there with the closing reflection unanswered
  (`FR-DONE-01`, `FR-TASK-07`). A revision scheme that assumes writes stop at
  completion is wrong.
- **This phase changes the on-disk format of every user's existing data.** The
  fixture test is not optional.
