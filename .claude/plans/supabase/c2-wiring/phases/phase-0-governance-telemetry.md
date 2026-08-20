# Phase 0 — Governance & Telemetry

**Size:** 1–2 days · **Depends on:** nothing
**Demo sentence:** "I suppress a place in the database, and it disappears from the app on the next foreground — with no account and no login."

**Status:** `NOT STARTED` · **Started:** — · **Completed:** —

<!-- MAINTAIN THIS FILE.
     Set Status to IN PROGRESS when you begin, COMPLETE when every exit criterion is
     ticked. Tick each `- [ ]` as it lands — a ticked box means it is in the repo and
     it ran against the deployed project, not that it is written down somewhere. If
     you deliberately skip an item, change it to `- [~]` and add ` — SKIPPED: reason`
     on the same line so nobody re-litigates it later.
     Then update ../PROGRESS.md. -->

## Goal

Make the app call the backend for the first time, using the two services that need no
session at all.

`c1` wrote `GovernanceKit` and `TelemetryKit`, tested them, and stopped. This phase
adds **call sites**, not implementations.

## Why this phase is first

Three reasons, and the third is the one that matters.

1. **It needs no session, no account and no schema change.** `content` is
   world-readable (`for select to anon, authenticated`) and `ingest` is
   `verify_jwt = false` by design.
2. **It is the smallest possible proof that the transport works** — TLS, the project
   URL, the key, the app's plumbing — before any of it is load-bearing for a walk.
3. **`AD-5`'s kill-switch is currently a release gate with no release.** A place can
   be withdrawn in the database today and the app will never hear about it. That is a
   safety control that does not work, and it is the only thing in C2 that is already
   broken rather than merely absent.

## Scope

### Target linkage

- [ ] Add `GovernanceKit` and `TelemetryKit` to the app target's frameworks in
      `project.pbxproj`. **They are absent today** — this is why nothing can call
      them, and it is a two-line change that looks like nothing.
- [ ] `import GovernanceKit` / `import TelemetryKit` explicitly in each file that
      uses them. `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on, so a
      transitive import will not do.

### Configuration

- [ ] Project URL and publishable key reach the app without being typed into a Swift
      file as literals. `Info.plist` keys fed from an `.xcconfig`, or a generated
      constants file — decide and record it here.
- [ ] The **service-role key is not present**, in any configuration, and a grep for it
      in the built Release binary returns nothing.

### Governance

- [ ] `GovernanceService` constructed in `KultaraEnvironment` with the project's
      storage URL.
- [ ] Fetched on launch and on foreground. **Never blocking either** — the app draws
      whatever it has.
- [ ] The last good document survives relaunch; a failed fetch keeps it rather than
      falling back to "nothing is suppressed".
- [ ] Suppressed place / quest / sidequest ids are actually applied to what the
      discovery surfaces show, and to an in-progress Run (`abandon_reason` already has
      a `placeSuppressed` case, and nothing sets it).

### Telemetry

- [ ] `TelemetryService` constructed in `KultaraEnvironment`.
- [ ] Events enqueued at the points design §10 names. Start with the smallest useful
      set — run started, checkpoint arrived, run completed, run abandoned — rather
      than instrumenting everything.
- [ ] Flush is opportunistic: on foreground, on background, and after a completed
      walk. Never on a timer, never on a screen transition a walker is waiting for.
- [ ] The queue is durable across relaunch and drops nothing on a failed flush.
- [ ] Batch respects `MAX_BATCH_ROWS = 200` and the 512 KiB body ceiling.
- [ ] **No user identifier in any payload.** `ops.events` has no `user_id` column and
      must never acquire one (design §2.4).

### Tests

- [ ] A source-scanning guard asserting no telemetry payload builder references a
      user id, session or account. `ContentKitTests` family — it links nothing and
      runs in seconds.
- [ ] `noModuleChecksReachability` still green after this phase's transport lands.

## Exit criteria

- [ ] A place suppressed in `ops.suppressions` on prod, published with
      `publish-suppressions`, is gone from the app after a foreground — **observed on
      a device, from a build that had already loaded the unsuppressed content.**
- [ ] Launching with the storage host unreachable produces a normal app: quest list,
      no spinner, no error surface, previous document still applied.
- [ ] A completed walk produces rows in `ops.events`, read back from the project.
- [ ] `ops.events` still has no `user_id` column, and no payload contained one.
- [ ] Release binary contains no service-role key.
- [ ] Package suite green; the four known pre-existing failures unchanged.

## Out of scope

Any `app.*` table. Any session. The survey half of `ingest`
(`ops.survey_responses` — the recall survey is not built). A scheduler for
`publish-suppressions`; it stays hand-invoked, as `c1` §6 left it.

## Risk notes

- **The kill-switch's trust model is TLS plus schema validation, and nothing else.**
  §14 defect 16 wants a detached signature on published content and there is none. Do
  not add a second trust assumption on top of that quietly.
- **A kill-switch that applies too aggressively is its own outage.** Suppressing a
  place mid-walk has to abandon the run with `placeSuppressed`, not crash a screen
  that assumed content it had at arrival. The snapshot-on-complete design means a
  *finished* walk must still render — its lore was copied, and suppression must not
  reach into a summary.
- **Telemetry is the first thing that will look like a battery bug.** Flush on
  foreground and background only. `NFR-BAT-04` is about location, but the reputation
  cost is shared.
