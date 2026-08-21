# Phase 7 — Restore

**Size:** ~1.5 days · **Depends on:** phases 1, 3, 4, 6
**Demo sentence:** "I deleted the app, installed it again, signed in with Apple, and my three walks were there — stamps, answers, photographs."

**Status:** `NOT STARTED` · **Started:** — · **Completed:** —

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

- [ ] After phase 6's sign-in completes and `merge-anonymous` has returned — the rows
      have to belong to the signed-in user before they can be read as that user.
- [ ] **Only if the local store is empty.** One guard, checked immediately before the
      read, not at launch. A user who walked before signing in has local data that is
      already theirs; restoring over it is the merge this phase refuses to do.
- [ ] Never automatically on a device that already has walks, and never on a timer.

### What it reads

- [ ] `app.runs` where `deleted_at is null`, then that run's `checkpoint_results`,
      `task_results`, `awards`, `photos`. RLS already scopes every one of them to the
      caller, so the query does not filter by `user_id` and must not be written as if
      it does.
- [ ] Reassemble into `Run` values and write through `RunStore`. The rows carry the
      snapshots (`snapshot_place_name`, `snapshot_lore`, `snapshot_sources`,
      `snapshot_content_version`), which is exactly why `AD-4` put them there —
      a restored walk renders correctly even against content that has since changed or
      been withdrawn.
- [ ] `snapshotClueToNext` comes back **empty** — it has no server column (phase 2's
      decision). It is what the next screen prints during a walk, not part of the
      record, and a finished walk never shows it. Say so in code rather than inventing
      a value.
- [ ] `revision` and `server_seq` are read and discarded. The client has no field for
      either and gains nothing by keeping them.

### Photographs

- [ ] Restore the **rows** with the walk. Restore the **bytes lazily**: a photograph
      downloads when something is about to draw it, not during sign-in.
- [ ] Thumbnail first. `HisploraTripArtwork`'s medallions and the Journal grid draw the
      small one; the full derivative is only needed if a screen shows it large.
- [ ] A photograph that fails to download leaves its row in place and the screen draws
      what it draws when a file is missing today — `PhotoStore.image(atRelativePath:)`
      already returns `nil` for a photograph deleted in Settings (`FR-SET-02`), and a
      not-yet-downloaded one takes the same path. **No new empty state, no spinner, no
      error surface** (`../01-architecture.md` R4).
- [ ] Downloading is not a walk-blocking operation and must not run during one.

### What restore does not bring back

- [ ] **Sidequest records and letters.** `SideQuestRecord` has no server table and
      `FR-SIDE-13` keeps sidequest photographs off the server entirely. A restored
      device has its quests and not its sidequests, and that is a real gap — write it
      in the release notes rather than letting a user discover it.
- [ ] **Proximity alerts, preferences, the onboarding flag.** Device state, not
      history.
- [ ] **Telemetry.** The queue is per-install and pseudonymous by construction
      (phase 0); there is nothing to restore and restoring it would be a privacy
      regression.

### Honesty about what happened

- [ ] The sign-in screen may say restore is happening; it must not claim a number
      before it has one.
- [ ] If the read fails, the user is signed in with no walks and **the app does not
      pretend they had none**. This is the one place R4's silence is wrong, for the
      same reason `delete-account` failure is (phase 3): a user cannot tell "you had
      nothing" from "we could not fetch it", and only one of those is recoverable by
      trying again.
- [ ] A retry that is reachable without signing out.

## Exit criteria

- [ ] Walk two quests, complete one, take a photograph. Sign in. Delete the app.
      Reinstall, sign in with the same credential: both walks are in the Journal, the
      Explorer's Card counts match, the stamps are the right tier, the written answers
      are there and the photograph draws in the Trip Collection.
- [ ] A finished walk's Trip Summary and Trip History render from the restored
      snapshots with the network off.
- [ ] Restore refuses to run on a device that already has a walk, proved by a test, not
      by inspection.
- [ ] A second user's credential on the same device restores **their** walks and none
      of the first user's — real HTTP, real tokens, not `execute_sql`.
- [ ] Erase-all then sign in again restores nothing, because phase 3's
      `delete-account` removed the rows. Settings did not lie (`FR-SET-02`).
- [ ] A photograph whose bytes fail to download leaves the rest of the screen intact.
- [ ] `noModuleChecksReachability` green — restore attempts and reads the outcome; it
      does not ask whether the network is up.

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
