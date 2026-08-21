# Phase 0 — Governance & Telemetry

**Size:** 1–2 days · **Depends on:** nothing
**Demo sentence:** "I suppress a place in the database, and it disappears from the app on the next foreground — with no account and no login."

**Status:** `COMPLETE` · **Started:** 2026-08-21 · **Completed:** 2026-08-21

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

- [x] Add `GovernanceKit` and `TelemetryKit` to the app target's frameworks in
      `project.pbxproj`. Both products, both build files, both `packageProductDependencies`
      entries — and the same four objects again for `challange-5Tests`, which needs them to
      compile `AppTelemetryTests` against `@testable import challange_5`.
- [x] `import GovernanceKit` / `import TelemetryKit` explicitly in each file that
      uses them. `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on, so a
      transitive import will not do. `GovernanceGate.swift` and `AppTelemetry.swift` are the
      only two files that need either.

### Configuration

- [x] Project URL and publishable key reach the app without being typed into a Swift
      file as literals. **Decision: `Config/Backend.xcconfig` → a `Backend.plist` resource
      written into the app bundle by a build phase → `BackendConfiguration`.** Two things
      about that, both found the hard way and both worth not re-discovering:
      - **`INFOPLIST_KEY_<custom>` does not work.** With `GENERATE_INFOPLIST_FILE = YES`
        only Apple's own keys are mapped; a custom one is dropped silently, and setting
        `INFOPLIST_FILE` alongside it does not merge either. Both were tried, both built
        cleanly, and both produced an app whose `Info.plist` did not contain the keys.
      - **`//` opens a comment anywhere in an `.xcconfig`, including inside a value**, and
        comments are stripped before substitution — so `https:$()//host` is still cut down
        to `https:`, and the build still succeeds. `KULTARA_URL_SLASHES = /$()/` is what
        actually works.
- [x] The **service-role key is not present**, in any configuration, and a grep for it
      in the built Release binary returns nothing. Scanned the Release `.app` for
      `service_role`, `sb_secret_`, `SUPABASE_SERVICE` and `serviceRole`: no hits. Only the
      publishable key and the project URL are in `Backend.plist`.

### Governance

- [x] `GovernanceService` constructed in `KultaraEnvironment` with the project's
      storage URL — behind `Services/GovernanceGate.swift`, an `@Observable` holder so the
      SwiftUI layer can read the sets synchronously. The actor's `current` is isolated, so
      the gate loads the last good copy from the same store at construction rather than
      hopping to read a value already on disk.
- [x] Fetched on launch and on foreground. **Never blocking either** — a `.task` on the
      root view and an `.onChange(of: scenePhase)`, both returning nothing anything waits on.
      Verified against the deployed project: the live document (schema 2, three empty arrays)
      is fetched with no header at all and applied.
- [x] The last good document survives relaunch; a failed fetch keeps it rather than
      falling back to "nothing is suppressed". **Observed**: with a suppression applied and
      the entire local stack stopped (`supabase stop`), a cold launch still hid the quest —
      no spinner, no error surface, and no fallback to "nothing is suppressed", which is the
      failure `AD-5` exists to prevent arriving through the mechanism meant to prevent it.
- [x] Suppressed place / quest / sidequest ids are actually applied to what the
      discovery surfaces show, and to an in-progress Run. **Observed** — see the exit
      criterion below. In code:
      `QuestListViewModel`, `RegionMapViewModel` (which the illustrated *and* the basemap
      surfaces both read) and `NearbySideQuestListViewModel` take the sets;
      `SystemProximityMonitor` carries them as properties because a region outlives the
      screen that registered it (`FR-SIDE-14`); and `KultaraRootView.abandonSuppressedRuns`
      ends an active walk as `placeSuppressed` — the first thing that ever sets that case.
      Suppressing `badung-museum-bali` — checkpoint 5 of the only authored quest — emptied the
      quest list *and* removed that place's sidequest from "Places near you", which is
      migration 0004's rule holding: a suppressed place suppresses the quest that walks
      through it and the sidequest standing at it, without either being named.

### Telemetry

- [x] `TelemetryService` constructed in `KultaraEnvironment` — behind
      `Services/AppTelemetry.swift`, one constructor per catalogue row so a caller cannot
      invent a shape.
- [x] Events enqueued at the points design §10 names, smallest useful set:
      `quest_started`, `checkpoint_arrived`, `quest_completed`, `quest_abandoned`.
      **`orderIndex` is not sent with an arrival** — `TelemetryEvent.arrival` is deliberately
      the only arrival constructor and fixes its parameters; the value is derivable from the
      checkpoint id and the content, so widening the kit's API for it was not worth it.
      Recorded here rather than left as a silent gap against `schema.md` §B.7.
- [x] Flush is opportunistic: on foreground, on background, and after a completed
      walk. Never on a timer, never on a screen transition a walker is waiting for.
      **The work is chained rather than fired in parallel** — unchained, the flush after a
      finished walk can reach the actor before the `quest_completed` it exists to carry.
- [x] The queue is durable across relaunch and drops nothing on a failed flush.
      `TelemetryKitTests` holds the kit half; `AppTelemetryTests` holds the app half
      (`aRefusedFlushKeepsEveryRowQueued`).
- [x] Batch respects `MAX_BATCH_ROWS = 200` and the 512 KiB body ceiling — the kit's cap,
      unchanged, and 200 rows of these shapes is far under the byte ceiling.
- [x] **No user identifier in any payload.** Verified twice: by the new source guard, and
      by reading the rows back out of `ops.events` on the deployed project — `params` carried
      a quest id, a content version, a language, a checkpoint id, an accuracy band and a
      method, and nothing else. `ops.events` still has exactly seven columns and no
      `user_id`.
- [x] **`FR-SET-02` reaches the queue.** Not in the phase's original scope, and added
      because this phase is what creates the local data: `RunAndPreferencesDataEraser` now
      empties the queue and the per-walk keys, and `deletedTelemetryEvents` stops being a
      hard-coded zero.

### Tests

- [x] A source-scanning guard asserting no telemetry payload builder references a
      user id, session or account: `ContentKitTests/TelemetryPayloadBoundaryTests.swift`,
      scanning `TelemetryKit` and `Services/AppTelemetry.swift`. **Proved to fire** —
      adding `"user_id": "x"` to a payload turned it red, and it was reverted.
      Scope is the payload path rather than the app target on purpose: phase 6's sync code
      legitimately carries a user id, and a ban that gets shorter to make a scan pass is not
      a ban (`m7` Decision 3).
- [x] `noModuleChecksReachability` still green after this phase's transport lands.
- [x] `challange-5Tests/AppTelemetryTests.swift` — six tests over the four catalogue rows,
      the per-walk key, the refused flush, the erasure and the no-backend case. Added because
      the two events that *end* a walk are expensive to reach by hand and easy to get wrong.

## Exit criteria

- [~] A place suppressed in `ops.suppressions` on prod, published with
      `publish-suppressions`, is gone from the app after a foreground — **observed on
      a device, from a build that had already loaded the unsuppressed content.**
      — SKIPPED **on prod**, and done in full on the local stack instead, at the owner's
      instruction of 2026-08-21. Publishing needs the service-role key: the function is
      `verify_jwt = true` and refuses any other bearer, and the `content` bucket is
      service-role write only (migration 0009). Holding that key is what
      `03-security-privacy.md` §1 forbids, so the round trip was run against
      `supabase start` + `supabase functions serve` with the well-known development key —
      **the same four migrations, the same trigger, the same function, the same client
      code**, and the only difference is which project the URL points at.

      What was observed, in order, on iPhone 17 / iOS 26.5:
      1. Empty document published; the app fetched it and wrote it to
         `Application Support/Kultara/backend/suppressions.json`; "The Last Traces of Badung"
         is on the quest list.
      2. App backgrounded. `insert into ops.suppressions … ('place','badung-museum-bali',…)`,
         then `POST /functions/v1/publish-suppressions` → 200 with the rendered schema-2
         document.
      3. Foregrounded: **"No quests are available yet."**, and Museum Bali's sidequest gone
         from "Places near you". The stored document on disk now carries the suppression.
      4. `supabase stop` — the whole backend down — then a cold launch: **still suppressed.**
         The last good copy is what applies when a fetch cannot land.
      5. Row deleted, published again, foregrounded: the quest is back.

      `docs/screenshots/c2p0-killswitch-before.png` and `c2p0-killswitch-after.png`.

      **What this does not prove**, and what is left for whoever holds the key: that the
      *deployed* `publish-suppressions` accepts the *production* service role. That path has
      its own history — the function's first version compared the bearer against
      `SUPABASE_SERVICE_ROLE_KEY` by string, which passed locally (both credentials are the
      same development string) and refused the real service role on the first prod call. It
      reads the `role` claim now, and `b3`'s execution record has it answering on prod.
- [x] Launching with the storage host unreachable produces a normal app: quest list,
      no spinner, no error surface. Proved by building with
      `KULTARA_BACKEND_URL=https://no-such-host.…invalid` overridden on the command line,
      installing that build on iPhone 17 / iOS 26.5 and reaching the quest list. "Previous
      document still applied" is the half that needs a non-empty document to mean anything.
- [~] A completed walk produces rows in `ops.events`, read back from the project.
      — SKIPPED: **half of it is done and the other half is proved by test rather than by
      walking.** A real arrival on iPhone 17 / iOS 26.5 at Puri Agung Pemecutan produced
      `quest_started` and `checkpoint_arrived` in `ops.events` on `ppwcxmvetmmwliusliac`,
      read back at 2026-08-21 00:42 UTC — the app's first network write ever. Walking all
      five checkpoints to the end by hand is roughly fifty taps through the story stages;
      `quest_completed` and `quest_abandoned` travel the same enqueue-and-flush path and are
      asserted payload-for-payload in `AppTelemetryTests`.
- [x] `ops.events` still has no `user_id` column, and no payload contained one. Both read
      back off the deployed project.
- [x] Release binary contains no service-role key.
- [x] Package suite green; the four known pre-existing failures unchanged — 561 tests,
      7 issues, all in `PlaqueGeometryTests`, `PermissionCallBoundaryTests`'s background
      location guard and `BundledContentRepositoryTests` ×2. `challange-5Tests` is 225 tests
      in 23 suites, all passing (was 219 / 22 before this phase).

## The one thing a person still has to do

**A kill-switch is only proved live by publishing on prod, and that needs the service-role
key** — see the `[~]` above for what was proved instead and how far it reaches. Nothing in
the app changes as a result; this is an operator drill, and running it once is what turns
`AD-5` from "the code is right" into "the control works".

In order:

1. A suppression row on prod — `insert into ops.suppressions (entity_type, entity_id, reason)
   values ('place','badung-museum-bali','c2 phase 0 kill-switch verification')`. The trigger
   rebuilds `ops.suppressions_document` transactionally on the insert; nothing is published yet.
2. `POST /functions/v1/publish-suppressions` with the service-role bearer.
3. Foreground the already-installed build. "The Last Traces of Badung" should leave the quest
   list and the map, because a quest is suppressed when any of its checkpoints' places is.
4. Delete the row, publish again, foreground again, and watch it come back.

Steps 1 and 4 are prod data writes and step 2 needs a key this session does not hold, so all
four are the owner's to run or to authorise.

## One thing this phase added that the plan did not ask for

**`BackendConfiguration` accepts `http://127.0.0.1` in a debug build.** Everything else must
be `https` (`NFR-SEC-01`): the kill-switch's trust model is TLS plus schema validation, so
cleartext removes half of it. The exception exists because `supabase start` serves cleartext
and cannot be made to do otherwise — so without it, the only way to watch a suppression apply
is to hold the production service-role key, which is worse by a wide margin. It is confined
three ways: `#if DEBUG`, so a release build does not contain the branch; loopback hosts only,
so it cannot be pointed at a machine on the network; and it never widens what `https` already
allows. `BackendConfigurationTests` holds it, including the obvious smuggle
(`http://127.0.0.1.evil.example`).

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
