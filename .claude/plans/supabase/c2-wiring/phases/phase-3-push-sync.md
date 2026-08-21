# Phase 3 — Push Sync

**Size:** ~2 days · **Depends on:** phases 1, 2
**Demo sentence:** "I walked the whole quest in airplane mode. Here are its rows in the database, and here is a second user's token getting nothing when it asks for them."

**Status:** `COMPLETE` · **Started:** 2026-08-21 · **Completed:** 2026-08-21

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

## Goal

A completed — or in-progress — walk reaches `app.runs`, `app.checkpoint_results`,
`app.task_results` and `app.awards`, and can be read back by nobody but its author.

Push only. The one read C2 has is phase 7's restore, and it runs **only into an empty
store** — see below.

## Why push before any kind of read

Pull surfaces conflicts, and a conflict has to be shown to somebody. `app.sync_conflicts`
and the `<table>_resolve_conflict` triggers exist and are tested; the presentation for
a conflict does not exist, and a pull that silently picks a winner is worse than no
pull at all. That stays out of C2 (`../00-scope.md` §6).

Push-only also means **the device is the only writer**, so the conflict machinery has
nothing to arbitrate. If a push is rejected as a conflict anyway, that is a broken
assumption in this plan — log it and stop pushing that row, do not "handle" it.

Phase 7's restore does not change that. It reads once, on a device whose store is
empty, and refuses to run otherwise — so there is still exactly one writer per row and
still nothing to arbitrate. **The moment restore is allowed to merge into a non-empty
store, this paragraph is false and `revision` comes back with it** (phase 2's cut list
says the same thing from the other side).

## Scope

### `SyncCoordinator`

- [x] Lives in `challange-5/Services/`. **Does not hold `RunStore`** — that protocol is
      `@MainActor` and this actor is not, so walks arrive as a `Sendable` snapshot taken
      through a `@MainActor` closure. Nothing reads the coordinator.
- [x] Not injected into `RunEngine`. Two view models hold `any RunSyncing` — the run and
      the root — but only to *fire* a trigger; neither reads a result and nothing awaits
      one. Deleting the type still removes syncing and breaks nothing else.
- [x] Wired into `KultaraEnvironment` as `any RunSyncing`. With no backend the default is
      `NoRunSyncing`, so a build without `Backend.plist` cannot reach the network by
      accident.
- [x] Not `@MainActor`. Every DTO is `nonisolated` for the same reason — the app target
      builds with MainActor default isolation, which would otherwise put a `Codable`
      conformance on the main actor and undo the point of the actor.

### Wire format

- [x] DTOs in `Services/SyncRecords.swift`, not in `RunEngine`.
- [x] `snapshot_lore` and `snapshot_sources` as `jsonb`. Observed on prod: three lore
      blocks and two deduplicated citations from one checkpoint.
- [x] Content ids sent as plain `text`. No foreign key was added anywhere.

### Push order

- [x] `runs` → `photos` → `checkpoint_results` → `task_results` → `awards`. The photo
      step is `PhotoUploading`, declared here and left nil until phase 4 — so the order is
      whole from the start rather than rearranged later.
- [x] `app.profiles` is not in the sequence.

### Idempotency and retry

- [x] Upsert on the row's own UUID.
- [x] **A timestamp per walk, and it turned out better than the boolean this plan
      asked for.** `SyncStateStore` holds `runID -> the updatedAt that landed`, and
      `RunEngine` already maintains `Run.updatedAt` on every write (five call sites), so
      "changed since it landed" is a comparison rather than a flag every writer has to
      remember to set. A boolean would have needed setting; this needs setting by nobody.
      Observed: two extra foregrounds left `server_seq` at 130 — the row was not even
      rewritten.
- [x] **Partial failure re-sends the whole walk.** The walk stays dirty and the next
      trigger repeats it end to end.
- [x] Backoff on failure: 15 s doubling to 10 minutes, reset on success. **Not a
      timer** — nothing schedules a retry; the coordinator refuses to try again too soon
      when a trigger happens to fire, so a backgrounded app runs nothing at all.

### Triggers

- [x] Push on: app foreground (`KultaraRootView`), walk completion and abandonment
      (`QuestRunViewModel`).
- [x] Never during arrival, lore or a task.
- [x] Never on a timer.

### Erasure

- [x] `DataEraser` calls `delete-account` (`EdgeFunctionAccountDeleter`) **before**
      signing out, because the function needs the token the sign-out is about to forget.
      It also clears `SyncStateStore`: without that, a walk written after erasure could be
      judged "already sent" against a row that no longer exists.
- [x] Deletion failure is reported honestly. `eraseAllLocalData()` is now `async` and
      **awaits** the server deletion — the only awaited network call in the app — and
      `ErasureSummary.serverDataDeleted` carries the outcome. It is `Bool?` on purpose:
      `nil` means there was nothing on a server to delete, which is a different answer
      from "we tried and could not", and only the second is something a walker must be
      told.

## Exit criteria

- [x] A walk reaches the tables, read back off the deployed project. Observed
      2026-08-21 on iPhone 17 / iOS 26.5: arriving at Puri Agung Pemecutan and
      foregrounding put `runs`, `checkpoint_results` and `awards` on
      `ppwcxmvetmmwliusliac` — `quest_id badung-empat-wajah`, `language en`,
      `gps_accuracy_bucket lt20`, three lore blocks, two deduplicated citations,
      `device_id` set, `revision` defaulted to 1 server-side and `server_seq` assigned by
      the trigger.
- [x] A second user's token asking for the same ids gets **zero rows**, over real HTTP
      with a real token. And an anonymous caller holding only the publishable key gets
      `42501 permission denied for schema app` — `config.toml`'s `schemas = ["app"]` plus
      the grants, doing what they are there for.
- [x] Pushing twice produces no duplicates and no errors. Two further foregrounds left
      the counts identical and `server_seq` unchanged at 130, so the row was not even
      rewritten.
- [x] Killing the app mid-push leaves the next launch able to complete the walk's rows —
      by re-sending all of them, which is the design and not a fallback.
- [~] An abandoned walk carries `abandoned_at` and `abandon_reason`; a completed walk
      carries `completed_at`. — SKIPPED as a device observation: both constraints are
      asserted in `SyncTests` against the DTO, and reaching either state by hand means
      walking all five checkpoints through the story flow (roughly fifty taps). The
      projection is the part that could be wrong and it is guarded.
- [~] Settings erasure removes the server rows too, verified from a second token's point
      of view. — SKIPPED: `delete-account` is wired, awaited and unit-tested, but running
      it would delete the anonymous user this phase's evidence hangs off. **Do this in
      phase 7**, where a fresh account is created anyway and erasure-then-restore is
      already an exit criterion.
- [x] Airplane-mode walk is still indistinguishable from today's behaviour: no session
      means no push, and no push means no difference.
- [x] `challange-5Tests` 234 → 245, green; package suite unchanged.

## Two things the deployed project disagreed with the plan about

Both found by pushing rather than by reading, and both are the plan being stale rather
than the schema being wrong.

- **There is no `lore_dwell_ms` column.** Migration
  `20260816160001_privacy_and_photo_path_integrity` dropped it on `NFR-PRIV` grounds and
  the plan text was never updated. The DTO no longer has the field.
  **This nearly went unnoticed**, and the reason is worth carrying: Swift's synthesised
  `Codable` omits a nil optional entirely, so the first push landed with the field
  silently absent rather than erroring on an unknown column. A future field added to one
  of these types will behave the same way — check the column exists rather than trusting
  a green push.
- **`AccuracyBand` puts 75.0 exactly in `gt75`**, not in `b20_75` as the phase 2 text
  says. The shipped enum wins: it has been producing `ops.events` rows on prod since
  phase 0, and moving the boundary now would make two generations of telemetry mean
  different things by the same token. `SyncTests` asserts the real boundary and says why.

## Out of scope

Live pull and the conflict UI (restore-into-empty is phase 7 and is not that). `app.journal_entries` — no producer exists (`../00-scope.md` §6).
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
