# Milestone 6 — Quest run, vertical slice

**Status:** implemented and verified on simulator, 2026-08-13.
**Scope of requirements:** `.claude/prds/cultural-heritage-quest.full.prd.md`, `docs/system-design.md`, `docs/schema.md`.

## What this milestone is

One quest, walkable end to end, from a desk.

Start → arrival at each checkpoint → lore with accuracy labels and sources → written tasks → clue →
progress → completion → summary rendered from the Run's own snapshots. Persisted across launches.

## What is deliberately not in it

Named here so the gaps are decisions rather than oversights:

| Left out | Requirement it defers |
|---|---|
| Photo tasks | `FR-TASK-03/04`. The screen offers the prompt, says photos are not in this build, and skips. |
| Share card | `FR-SHARE-*` |
| Recall survey | `FR-SURV-*` — the closing reflection task exists and reaches the summary (`FR-TASK-07`), but the survey proper does not |
| Telemetry | `NFR-OBS-*` |
| Proximity alert | `FR-PROX-*` |
| Kill-switch | `AD-5` |
| Route canvas during a Run | `FR-MAP-02` — the clue carries the walker; there is no in-Run map yet |

## Decisions

### 1. The developer bypass simulates position, not arrival

`FR-START-08` says a quest **MUST NOT** be startable from outside the start radius *by any path*, and
release acceptance criterion 13 tests exactly that. Testing the loop from a desk in Jakarta is in
direct tension with it.

Resolved by simulating the **input**, never the decision: `SimulatedLocationProvider` reports a fix at
the next checkpoint's coordinate, and `ArrivalEvaluator` then applies the radius and accuracy rule
unchanged. What a walker in Denpasar exercises is what a developer at a desk exercises.

The whole mechanism — the provider, the switch, the Settings section — is inside `#if DEBUG`. A
release build does not contain the code, so there is no path through it to disable.

`PermissionCallBoundaryTests` was rewritten to match: `requestWhenInUseAuthorization` and
`startUpdatingLocation` are now *confined* to `LocationService.swift` and `QuestRun.swift` rather than
banned from `AppFeatures` outright, and a companion test fails if those calls stop existing, so the
confinement cannot pass by finding nothing. Background location and the tracking prompt stay banned
everywhere.

### 2. `RunEngine` is a target of its own, Foundation only

The ordering, award and snapshot rules are where correctness bugs hide, and they must be testable
without a simulator (`system-design.md` §3, §14). `ImportBoundaryTests` now scans `RunEngine` for the
same forbidden modules as `ContentKit`.

Arrival reaches it as a decided fact — a method and an accuracy, never a `CLLocation`.

### 3. `RunStore` is a file store, behind a protocol

`schema.md` Part B specifies SwiftData models. This milestone ships `FileRunStore`: one JSON document
per Run under `Application Support/Kultara/runs`, written atomically on every transition.

Reasons: `NFR-REL-04` wants one corrupt record to cost one Run rather than the app's launch, and
`swift test` covers durability on macOS with no simulator. A document per Run rather than one file for
all of them, because `FR-RUN-01` wants every transition durable within 500 ms and rewriting a user's
whole history on each arrival is a cost that grows with their walking.

`RunStore` is `@MainActor`, a deviation from `system-design.md` §9's background `@ModelActor`. A Run is
a few kilobytes and a walk produces tens of writes; moving it off the main actor later is an
implementation change behind the protocol.

### 4. Supabase is a sync target, not the store

Asked for during this milestone, and deferred with the user's agreement. Writing Runs to Postgres
directly would break `AD-3` (local store authoritative, no connectivity branching), `FR-OFF-02`
(the whole loop is a release gate in airplane mode) and `NFR-PRIV-01` (v1 transmits no location,
photographs or reflection text). Its place is the sync layer in v2 plus the two Edge Services
`system-design.md` §1 already needs — `suppressions.json` and the ingest endpoint — all of them
*underneath* `RunStore`, never in front of it.

### 5. Screens hold their view models in `@State`

`ScreenHost` in `KultaraRootView.swift`. A view model built inside a `body` is rebuilt on every
redraw, taking a fresh location provider with it and orphaning the fix already in flight. The arrival
screen sat on "looking for a location fix" forever until this was fixed, and it is the kind of bug
that reads as a location problem and is not one.

## Fixes made along the way

- **The floating tab bar was covering the foot of every scrolling screen.** `KultaraTabBar` is
  published as a `safeAreaInset`, and the reservation is not reaching content inside the navigation
  stack. Not diagnosed; worked around with `KultaraMetrics.floatingTabBarClearance`, applied by the
  screens that scroll. The Start control was unreachable without it. **Open item** — the inset should
  be understood rather than padded around.
- **The developer switch would not stay on.** A hand-rolled `Binding` over `UserDefaults` reads
  correctly and never redraws, so the switch snapped back under the finger. Now `@AppStorage` in a
  view of its own.

## Verification

Package suites: **297 tests, 28 suites, all passing** (`swift test`).
Content validator: **17 rules pass**, 3 quests / 5 places.
App and XCUITests: **TEST SUCCEEDED** on iPhone 17, iOS 26.5.

Walked on the simulator with the developer switch on, `Example Old-Town Trail`, 5 checkpoints:

| Checked | Requirement |
|---|---|
| Safety notice before anything else, once per quest | `FR-START-04`, `NFR-SAFE-03` |
| Location explanation before the system prompt | `FR-START-02`, `FR-ONB-04` |
| The purpose string names the single real use | `NFR-PRIV-10` |
| Live distance and fix accuracy, never a spinner | `FR-ARR-05`, `FR-ERR-01` |
| Arrival at each checkpoint, stamp stated on arrival | `FR-ARR-01`, `FR-CP-07` |
| Lore, then tasks, then the clue | `FR-CP-02` |
| Accuracy label as text; oral chip differs by border, not only hue | `FR-CP-05`, `NFR-A11Y-05` |
| Sources one tap from the claim | `FR-CP-06` |
| Dress code and photo policy before any task at the sacred Place | `FR-TASK-05` |
| No photo task offered where photography is prohibited | `FR-TASK-06` |
| Reflection saved, reaching the summary | `FR-TASK-07` |
| Completion on final arrival, badge awarded | `FR-DONE-01/02` |
| Summary from snapshots, naming the pinned content version | `FR-DONE-03/04` |
| Finished walk listed on Home and re-openable | `FR-DONE-06` |

Screenshots were taken during the walk but not committed; the run is reproducible in minutes with the
switch on.

## Known gaps

- `NSLocationWhenInUseUsageDescription` is English only. Purpose strings need `InfoPlist.strings` to
  follow `NFR-I18N-02`; the app's own strings are already bilingual.
- Airplane-mode traversal on a physical device (`NFR-REL-03`, release gate) has not been done. Nothing
  in the loop touches the network, but the requirement asks for the test, not the argument.
- VoiceOver and largest-Dynamic-Type traversal of the new screens has not been done (`NFR-A11Y-01/02`).
- The tab-bar inset, above.
