# Phase 3 — Push Sync

**Size:** 3 days · **Depends on:** phases 1, 2
**Demo sentence:** "I walked the whole quest in airplane mode. Here are its rows in the database, and here is a second user's token getting nothing when it asks for them."

**Status:** `NOT STARTED` · **Started:** — · **Completed:** —

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

## Goal

A completed — or in-progress — walk reaches `app.runs`, `app.checkpoint_results`,
`app.task_results` and `app.awards`, and can be read back by nobody but its author.

Push only. Pull is not in C2 (`../00-scope.md` §6).

## Why push before pull

Pull surfaces conflicts, and a conflict has to be shown to somebody. `app.sync_conflicts`
and the `<table>_resolve_conflict` triggers exist and are tested; the presentation for
a conflict does not exist, and a pull that silently picks a winner is worse than no
pull at all.

Push-only also means **the device is the only writer**, so the conflict machinery has
nothing to arbitrate. If a push is rejected as a conflict anyway, that is a broken
assumption in this plan — log it and stop pushing that row, do not "handle" it.

## Scope

### `SyncCoordinator`

- [ ] Lives in `challange-5/Services/`. Reads `RunStore`; **nothing reads it**.
- [ ] Not injected into `RunEngine`, not called by any view model. Deleting the type
      removes syncing and breaks nothing else — if that stops being true, the design
      drifted.
- [ ] Wired into `KultaraEnvironment` as `any RunSyncing` with a default.
- [ ] Not `@MainActor`. Serialising a walk's records on the main actor will be visible
      in whatever is on screen.

### Wire format

- [ ] DTOs in `Services/`, **not** in `RunEngine`. A `Codable` shaped for PostgREST is
      a transport concern; on the domain model it makes the server a `FileRunStore`
      migration risk.
- [ ] `snapshot_lore` and `snapshot_sources` as `jsonb`. No shape constraint exists
      server-side on purpose — the snapshot's meaning may only ever be **added** to
      (`schema.md` §C.3 rule 2).
- [ ] Content ids (`quest_id`, `checkpoint_id`, `source_id`) sent as plain `text`. See
      the risk note.

### Push order

- [ ] `runs` → `photos` → `checkpoint_results` → `task_results` → `awards`. Fixed by
      foreign keys; migration 0006 creates `photos` before `task_results` for exactly
      this reason. Phase 3 pushes an empty photo step.
- [ ] `app.profiles` is **not** in the sequence — it carries no `server_seq` and is
      absent from the design's push order.

### Idempotency and retry

- [ ] Upsert on the row's own UUID. Pushing the same walk twice is a no-op, not a
      duplicate.
- [ ] A local "pushed at revision N" marker so an unchanged record is not re-sent.
- [ ] Backoff on failure. No retry storm on a flaky connection, and no retry loop that
      runs while the app is backgrounded.
- [ ] Partial success is survivable: `runs` landing and `awards` failing must leave
      the next attempt able to finish, not restart.

### Triggers

- [ ] Push on: app foreground, walk completion, and when a walk is abandoned.
- [ ] **Never** during arrival, lore, or a task. Those are the moments a walker is
      waiting for a screen.
- [ ] Never on a timer.

### Erasure

- [ ] `DataEraser` calls `delete-account` in addition to erasing locally. Once rows
      exist on the server, local-only erasure makes Settings say something untrue
      (`FR-SET-02`).
- [ ] Deletion failure is reported honestly rather than swallowed — this is the one
      exception to `../01-architecture.md` R4's silence.

## Exit criteria

- [ ] Walk a full quest with the network off. Relaunch with signal. All four tables
      hold the walk, read back **over HTTP with the walker's own token**.
- [ ] A second user's token asking for the same ids gets **zero rows**, proved by real
      HTTP, not by `execute_sql`.
- [ ] Pushing twice produces no duplicates and no errors.
- [ ] Killing the app mid-push leaves the next launch able to finish the push.
- [ ] An abandoned walk carries `abandoned_at` and `abandon_reason`, satisfying the
      `runs_abandoned_has_reason` constraint.
- [ ] A completed walk carries `completed_at`, satisfying `runs_completed_has_timestamp`.
- [ ] Settings erasure removes the server rows too, verified from a second token's
      point of view.
- [ ] Airplane-mode walk is still indistinguishable from today's behaviour.

## Out of scope

Pull. Conflict UI. `app.journal_entries` — no producer exists (`../00-scope.md` §6).
Photos — phase 4, and this phase pushes an empty photo step to keep the order intact.
`app.profiles`.

## Risk notes

- **`execute_sql` proves nothing about isolation.** It runs elevated and bypasses RLS.
  A suite written with it passes against a completely open database. Every isolation
  assertion goes in `supabase/tests/http/` with a real user token (`b3` §4).
- **Never add a foreign key from user data to content.** Migration 0006 opens with
  "the most important line in this file is an absence". A convenience join that only
  works while today's content is current is the same mistake wearing a different hat.
- **`snapshot_lore` must never be indexed.** Nothing queries inside it, and a GIN
  index there is pure write amplification that *looks* like diligence.
- **A run stays writable after completion.** `markLoreOpened` and `recordTaskResult`
  accept `completed`, because the final checkpoint completes the walk while the walker
  is still standing there with the closing reflection unanswered. A sync that treats
  `completed` as immutable will drop `FR-TASK-07`'s answer.
- **Foreground push and a resumed walk collide.** A walker who foregrounds mid-walk
  triggers a push of a run that is about to change again. Upsert-by-id makes this
  safe; a "create once" assumption does not.
