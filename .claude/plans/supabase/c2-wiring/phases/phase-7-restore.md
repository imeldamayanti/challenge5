# Phase 7 — Restore

**Size:** ~1.5 days · **Depends on:** phases 1, 3, 4 (built **before** phase 6, see below)
**Demo sentence:** "I deleted the app, installed it again, signed in with Apple, and my three walks were there — stamps, answers, photographs."

**Status:** `COMPLETE` · **Started:** 2026-08-21 · **Completed:** 2026-08-21

<!-- MAINTAIN THIS FILE. See phase 0's header for the rules. -->

> **Added 2026-08-21.** The owner's MVP goal for user data is *"your walks survive a
> reinstall"*, and the plan as written could not deliver it: phases 3 and 4 push, phase
> 6 merges the anonymous user into a credentialed one, and **nothing ever reads a row
> back**. Without this phase the server holds a copy no walker can ever see, which is
> the one shape of sync that costs a user privacy and returns them nothing.

## Goal

On a device with no local walks, after the user signs in, pull their rows out of
`app.*` and write them into `FileRunStore` and `PhotoStore` so the Journal, the
Explorer's Card and the Trip pages render as they did before the reinstall.

## This is not the pull sync that `00-scope.md` §6 rules out

That bullet rejects pull because **a conflict has to be shown to somebody** and no
screen for one exists. It is right, and this phase does not contradict it:

- **Restore runs only into an empty store, and refuses otherwise.** If
  `RunStore.runs()` is non-empty, it does not run — no merge, no comparison, no
  "newest wins".
- Empty means no second writer, which means **no conflict can exist**. Not "conflicts
  are handled" — they are structurally absent, the same argument phase 3 makes for
  push.
- It happens **once**, at a known moment (first sign-in on a fresh install), not
  continuously.

`app.sync_conflicts`, the `<table>_resolve_conflict` triggers and the conflict UI stay
out of C2. If this phase ever grows a merge, that decision comes back with `revision`
(phase 2's cut list) and a screen, and it is not this phase any more.

## Scope

### When it runs

- [x] **Built before phase 6, and triggered more broadly than this line asked for.**
      It runs on launch, after the session, whenever the local store is empty — which
      covers sign-in (phase 6 re-enters it) *and* the case a walker actually hits first:
      the same anonymous account on a device with nothing on it. Restricting it to
      "after sign-in" would have made it dead code until phase 6 shipped, and untestable
      until then.
- [x] **Only if the local store is empty.** One `guard` at the top of the one entry
      point, checked immediately before the read so a walk started in between is still
      seen. `RestoreTests.restoreRefusesToRunWhenTheDeviceAlreadyHasAWalk` is the test
      that had to exist before the feature did.
- [x] Never on a device that already has walks, and never on a timer.

### What it reads

- [x] `app.runs` where `deleted_at is null`, then `checkpoint_results`, `task_results`
      and `awards`. **No query filters by `user_id`** — RLS already scopes them, and a
      query written as if it had to would be describing a guarantee it does not provide.
- [x] Reassembled by `RunAssembly` and written through `RunStore`. Observed on prod:
      the restored walk came back with its place name, three lore blocks and the real
      citations, `BELUM DIVERIFIKASI` and all.
- [x] `snapshotClueToNext` comes back **empty**, and so does `gpsAccuracyM` — only the
      band ever left the device (`NFR-PRIV-02`), and turning a band back into a number
      would put a fiction into a restored record. Both verified absent in the restored
      JSON on device.
- [x] `revision` and `server_seq` are read and discarded.

### Photographs

- [x] Restore the rows with the walk; fetch the bytes afterwards. **Done**, and it needed
      no cache: `photo_id` *is* the `TaskResult`'s id (phase 4), and `PhotoStore` derives a
      photograph's path from exactly that — so a restored record can **name** its
      photograph before the file exists, and the download simply fills it in.
      `RestoredPhotoDownloader` runs after the walks are saved and is unawaited, and skips
      anything already on disk so a second restore fetches nothing.
      `PhotoStore` gained `place(_:recordID:)` — separate from `save`, which downscales and
      re-encodes: right for a photograph off a camera, wrong for one that has already been
      through that once.
      Observed on prod: a fresh install downloaded the photograph to
      `Documents/sidequest-photos/<photo id>.jpg`, the exact path the restored record
      names.
- [~] Thumbnail first. — SKIPPED, deliberately: **the full derivative is what is
      downloaded.** The thumbnail exists so a grid can lay out before downloading, and
      nothing in this app lays out that way yet — writing a 400 px file where a screen
      expects the photograph would be a silent quality loss. `RestoredPhotoDownloader`
      names the place thumbnail-first belongs when a grid exists.
- [x] A missing photograph draws what a missing photograph already draws.
      `PhotoStore.image(atRelativePath:)` returns `nil` and every screen already handles
      that (`FR-SET-02`); a restored walk with no local file takes exactly the same path,
      which is why the gap above is survivable rather than broken.
- [x] Downloading is not a walk-blocking operation. It runs once, after a restore, off
      the path that produces a screen.

### What restore does not bring back

- [x] **Sidequest records and letters do not come back.** `SideQuestRecord` has no
      server table and `FR-SIDE-13` keeps sidequest photographs off the server entirely.
      A restored device has its quests and not its sidequests. **This belongs in the
      release notes** — it is a thing a walker will notice.
- [x] Proximity alerts, preferences and the onboarding flag do not come back. Device
      state, not history.
- [x] Telemetry does not come back. The queue is per-install and pseudonymous by
      construction (phase 0); restoring it would be a privacy regression.

### Honesty about what happened

- [~] The sign-in screen may say restore is happening. — SKIPPED: there is no sign-in
      screen until phase 6, and restore currently runs on launch with nothing on screen —
      which is the right default, since the common case is a walker who has nothing to
      restore and should see no mention of it.
- [x] A failed read is **shown**, not swallowed. `RestoreOutcome.succeeded` drives an
      alert on the root view — four new `UIStrings` keys, ID and EN — that says plainly
      that walks may still be there and this was a fetch that did not land.
- [x] The alert's "Try again" re-runs the restore. No sign-out, no relaunch.

## Exit criteria

- [x] **Walk, delete the app, reinstall — the walk is there.** Observed on prod,
      iPhone 17 / iOS 26.5, 2026-08-21. `xcrun simctl uninstall` then install and launch:
      `Library/Application Support/Kultara/runs/` came back with the walk, the Explorer's
      Card showed **1 Stamp**, and the Profile list showed the walk by name.
      The reinstall is a genuine one for the app's storage; the anonymous session survives
      it because **the simulator Keychain outlives `simctl uninstall`** (phase 1's
      finding), which is what let this be tested before phase 6 exists. On a real device
      that continuity is what phase 6 provides.
- [x] The restored walk renders from its own snapshots with no network — the place name,
      three lore blocks and the real citations came back in the record.
- [x] **Restore refuses to run on a device that already has a walk**, proved by a test.
- [~] A second user's credential on the same device restores their walks and none of the
      first user's. — SKIPPED until phase 6: there is no second credential to sign in
      with. The isolation underneath it *is* proved — phase 3 showed a second user's token
      reading `[]` from all four tables over real HTTP.
- [~] Erase-all then sign in again restores nothing. — SKIPPED with phase 3's matching
      criterion, for the same reason: running `delete-account` would remove the anonymous
      account this phase's evidence hangs off. **Do both together, in phase 6**, where a
      fresh account exists anyway.
- [x] A photograph whose bytes are missing leaves the rest of the screen intact — which is
      the current state of every restored walk, and is why the photo gap is survivable.
- [x] `noModuleChecksReachability` green.
- [x] `challange-5Tests` 245 → 252, green; package suite unchanged at four pre-existing
      failures.

## The photograph gap, closed

It was written up here as the phase's one real gap and left for later. "Later" was not
good enough, and it turned out to need neither a cache nor half-downloaded-file handling:
`photo_id` is already the `TaskResult`'s own id, so the record can name its photograph
before the bytes exist, and every screen already draws a named-but-missing photograph the
way it draws one deleted in Settings. The download is a fill-in rather than a state
machine.

Verified on prod by seeding one row and one object for the app's own anonymous user, then
reinstalling: the file landed at `Documents/sidequest-photos/<photo id>.jpg`, exactly the
path the restored record names. Row and object deleted afterwards.

## Two things the device showed that no test would have

Both found by reinstalling rather than by asserting, and both are the same mistake: a
value that is **content** was being reconstructed from **user data**.

- **The walk came back titled `badung-empat-wajah`.** `snapshotQuestTitle` is not a server
  column, and the first version fell back to the quest id — so the Profile list showed a
  walker a slug. It is resolved from the content bundle by id now (`AD-4`, the same rule
  read in the other direction), and a withdrawn quest still leaves the id showing rather
  than a blank row.
- **It said "1 of 1 checkpoints"** for a five-checkpoint quest, because `checkpointCount`
  was being inferred from how many results came back. Also content, also resolved by id.

The language for both is resolved **once, on the main actor, before the read** rather than
per row — a restore is a one-shot, and a walker who changes language afterwards re-renders
from content anyway.

## Out of scope

Merging a restored history into an existing local one. Conflict resolution of any kind.
Continuous or incremental pull. Sidequests. `app.journal_entries` — still no producer.

## Risk notes

- **This is the first time the app writes user history it did not author.** Every
  invariant that held because `RunEngine` was the only writer is now worth re-reading:
  ordering, `runs_completed_has_timestamp`, award uniqueness. A malformed restore is a
  corrupted history that looks like the user's own.
- **The empty-store guard is the whole safety argument, so it cannot be a comment.**
  A test that proves restore is a no-op on a non-empty store is the one test in this
  phase that must exist before the feature does.
- **Restoring is the moment a privacy promise becomes checkable.** Until now a user
  could be told their data is theirs; here they see it come back. If any row carries
  something they were never told was collected, this is where it surfaces — read the
  DTO against `../03-security-privacy.md` before shipping, not after.
- **Prod holds real user data from phase 1 onward, and this phase is the one that makes
  losing it visible.** `b3` §1.1's "prod is not precious" is already over by the time
  this runs.
