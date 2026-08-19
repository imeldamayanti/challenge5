# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native iOS app (SwiftUI, iOS 18.0) for story-led cultural heritage walking quests in Bali. Users walk a fixed-order route of physical checkpoints, unlock narrative lore at each one, and finish with a shareable recap.

Milestone 5 (Discovery & Preview) is implemented, and Milestone 6 ships the quest run as a vertical slice: start, arrival at each checkpoint, lore, written tasks, clue, completion, and a summary rendered from the Run's own snapshots. The share card, the recall survey and proximity alerts are not built; photo tasks are, as of 2026-08-19. Telemetry and the kill-switch are **half** built: the server side is deployed and the client kits (`TelemetryKit`, `GovernanceKit`) exist and are tested, but nothing in the app calls either — see `.claude/plans/supabase/c1-client-phase0.plan.md` §6. See also `.claude/plans/m6-quest-run-vertical-slice.plan.md`.

Milestone 8 (`.claude/plans/m8-qa-fixes.plan.md`) then did two things: fixed six QA findings, and put the run flow on a second visual direction ("Hisplora") taken from Figma. Both are shipped. `.claude/plans/m7-restore-test-guards.plan.md` — restoring the 112 tests commit `b597b5b` deleted — **is done**: 110 tests in `challange-5Tests`, all passing, plus the two source-scanning guards in the package. `.claude/plans/supabase/b0`–`b3` built and deployed a Supabase backend, and `.claude/plans/supabase/c1-client-phase0.plan.md` added the kill-switch publisher, `GovernanceKit` and `TelemetryKit` — **none of which the app calls yet**, deliberately.

## Directory layout

The repo root and the Xcode project directory share a name, which is confusing:

```
/                              repo root — CLAUDE.md and .gitignore only
├── docs/                      system-design.md, schema.md, hisplora-tokens.md,
│                              backend-supabase.md (the design of record for `supabase/`;
│                              it outranks the plans where they disagree),
│                              consent-request-pack.md and
│                              field-verification-checklist.md (what a human has
│                              to do before any of this is public — desk work,
│                              no invented values), and
│                              branch-backend-design-revision.md — what this
│                              branch did, plus the database end to end: ERD,
│                              every table, every column, read out of the
│                              running database rather than from the design
│   ├── screenshots/           captured UI verification screenshots
│   └── research/              field research artifacts — interview summary,
│                              affinity diagram, tourist-findings and
│                              top-insights photos, the team research deck
├── .claude/prds/              product requirements (the spec)
├── .claude/plans/             implementation plans, including executed verification results
├── supabase/                  the backend. Fully deployed as of 2026-08-16 —
│                              18 migrations and 4 functions on the hosted project
│   ├── config.toml            two of its settings are security controls, not preferences
│   ├── migrations/            18 forward-only files; a merged one is never edited
│   ├── functions/             ingest, delete-account, merge-anonymous,
│   │                          publish-suppressions (AD-5's kill-switch publisher)
│   ├── tests/                 pgTAP + Deno: structure, isolation, sync, concurrency, HTTP
│   └── seed.sql               local only; installs pgTAP and the fixtures
└── challange-5/               Xcode project directory
    ├── challange-5.xcodeproj
    ├── challange-5/           app target — Model/ ViewModel/ View/ Service/ Support/
    ├── challange-5UITests/    XCUITest, the only tests needing a simulator
    ├── challange-5Tests/       unit tests for the app target — view models,
    │                           presentation models, UI strings
    └── Packages/Kultara/      local SPM package — ContentKit, RunEngine,
                               UIStringsKit, DesignSystem, GovernanceKit,
                               TelemetryKit, content-validator
```

**The app target now has a unit-test target.** `challange-5Tests` was added by `m7` — hand-written
`project.pbxproj` objects in an `A0C0C0C0…C0xx` block, with a `PBXFileSystemSynchronizedRootGroup`,
so **adding a file to `challange-5Tests/` needs no project edit**. The shared scheme at
`challange-5.xcodeproj/xcshareddata/xcschemes/challange-5.xcscheme` names both test targets and *is*
tracked in Git, unlike every other scheme here.

So a view-model test is now writable. It is still often the wrong shape: a rule pushed down into a
package target as a pure value runs under `swift test` in milliseconds without a simulator, and the
arrival countdown (`RunEngine.ManualOverrideSchedule`), the map-marker tap threshold
(`DesignSystem.MapMarkerGesture`) and the route maths (`RunEngine.RouteProjection`) all went that way
for good reasons that have not changed. Prefer the package. Use `challange-5Tests` for what genuinely
needs the app target — SwiftUI-adjacent view models, `Model/` presentation types, `@testable import
challange_5`.

### Which suites run where

| Command | Runs | Needs a simulator |
|---|---|---|
| `swift test` (from `Packages/Kultara`) | 448 tests / 56 suites — `ContentKit`, `RunEngine`, `UIStringsKit`, `DesignSystem`, `GovernanceKit`, `TelemetryKit`, and the two source-scanning guards | **No** — macOS |
| `xcodebuild test -only-testing:challange-5Tests` | 164 tests / 18 suites — view models, presentation, UI strings, host linkage | Yes |
| `xcodebuild test -only-testing:challange-5UITests` | 5 XCUITests — the flow, and `AccessibilityXXXL` | Yes |

**Two `swift test` failures are pre-existing on this branch and are not yours.** They were red at
`09baa2f` and neither is in a file the Figma port touched:

- `PlaqueGeometryTests.theCornerIsAScoopArcedAboutTheCornerPointItself` — 2 issues, the plate's corner
  geometry in `PlaquePanel.swift`.
- `PermissionCallBoundaryTests.theAppUsesNoBackgroundLocationAndNoTrackingPrompt` — `SideQuestProximityService.swift`
  calls `requestAlwaysAuthorization` and `startMonitoring(for:)`, which that guard bans. A real
  finding about the sidequest proximity work, unrelated to the run flow.

`FloatingTabBarClearanceTests` was a **third** pre-existing break of a different kind: the test was
committed without the `KultaraMetrics` API it exercises, so the whole package suite failed to compile
and no test could run. The missing half is now there — `floatingTabBarContentHeight` and
`floatingTabBarClearance(labelScale:)`, plus a `.kultaraFloatingTabBarClearance()` modifier the ten
scrolling screens now use instead of the fixed 88. That closes the `NFR-A11Y-02`/`NFR-A11Y-06` bug
CLAUDE.md's "Reachable, not comfortable" note was about.

`ImportBoundaryTests` and `PermissionCallBoundaryTests` live in `ContentKitTests` and **link
nothing** — they scan source text under both the package and the app target, walking out from
`#filePath`. That is why guards about the *app* target run in two seconds on macOS. If you are adding
a rule that can be checked by reading source, put it there rather than in `challange-5Tests`.

## Commands

Run from `challange-5/Packages/Kultara` unless noted.

```bash
swift test                                    # all pure-logic suites, macOS, no simulator
swift test --filter ContentValidatorTests     # one suite
swift test --filter "ContentValidatorTests/rejectsMissingConsent"   # one test
swift build
```

Content validation — the build-time gate:

```bash
swift run content-validator Sources/ContentKit/Content
```

Exits 0 when rules V1–V18 pass, 1 on any finding, 2 on bad arguments. Point it at an authored content tree (the directory holding `manifest.json`, `places/`, `quests/`, `assets/`, `consent/`).

Backend — run from the repository root, with Docker running:

```bash
supabase start
supabase db reset && supabase db lint -s app,ops,catalog,public --fail-on warning && supabase test db
deno test --allow-net --allow-env --allow-run supabase/tests/functions/
deno test --allow-net --allow-env --allow-run supabase/tests/http/
deno test --allow-net --allow-env --allow-run supabase/tests/concurrency/
```

236 assertions (165 pgTAP + 50 + 13 + 8 Deno). Scope `db lint` to the four schemas the repo owns:
pgTAP installs ~90 plpgsql functions of its own into `extensions` and an unscoped lint reports
upstream warnings for them. `deno` needs its permission flags spelled out under Deno 2.

**`supabase functions serve` must be running for the three Deno suites.** On this machine
`supabase start` brings up no `supabase_edge_runtime_*` container, so without it every function test
fails with `503 {"message":"name resolution failed"}` — which reads like a code failure and is not
one.

**This is deployed and the repo matches it.** `Histoplora` (`ppwcxmvetmmwliusliac`,
ap-southeast-1) holds all **18 migrations**, the pushed `config.toml` and **4 functions** as of
2026-08-16. `b3`'s execution record has the first push; `c1`'s second execution entry has 0014 and
`publish-suppressions`. `AD-5`'s kill-switch document is live and world-readable at
`/storage/v1/object/public/content/suppressions.json` — currently three empty arrays, schema 2.

`config push` will say "up to date" after a change to `[functions.*] verify_jwt`, and that is not a
bug: function JWT settings are applied by `functions deploy`, not by `config push`. Verify them with
`supabase functions list`, which prints `verify_jwt` per function. Prod holds **no real users yet**, which is the only reason `db reset` on it would still be
survivable — and it will stop being true without anything announcing it.

Deploying is `link → db push --dry-run → db push → config push → functions deploy → the HTTP suite
against the prod URL`. **`config.toml` must be pushed too**: `[api] schemas = ["app"]` and
`max_rows` are security controls, and a hosted project defaults to exposing `public,
graphql_public` instead.

**Use the Supabase MCP read-only** (`b0` D9) — `apply_migration` writes to the remote and creates no
migration file, so the repo and the project diverge with nothing to detect it. `deploy_edge_function`
does the same to `supabase/functions/`. Every schema change goes: migration file → `db reset` →
tests → `db push`. There is no second path.

**This is a convention, not a guard.** `.mcp.json` carried `&read_only=true` briefly on 2026-08-16
and the server was re-registered without it later the same day, at the user's explicit instruction,
so `apply_migration`, `execute_sql` DDL and `deploy_edge_function` are all reachable again. Nothing
stops you using them and nothing detects it afterwards — which is precisely why `b0` D9 was written
down. If you want the guard back:

```bash
claude mcp remove --scope project supabase
claude mcp add --scope project --transport http supabase \
  "https://mcp.supabase.com/mcp?project_ref=ppwcxmvetmmwliusliac&read_only=true&features=docs%2Caccount%2Cdatabase%2Cdebugging%2Cdevelopment%2Cfunctions%2Cbranching"
```

Either way the change takes effect on the **next** MCP connection, not mid-session: a session that
connected before the edit keeps whatever tool list it started with. Verify by listing tools after a
restart, not by assuming.

`execute_sql` runs elevated and **bypasses RLS**, so it is good for asking what a table contains and
worthless for proving who can read it. Isolation is proved by real HTTP requests with real user
tokens (`b3` §4).

App build and UI tests — run from `challange-5/`:

```bash
xcodebuild test -project challange-5.xcodeproj -scheme challange-5 \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

Pin `OS=`. Four runtimes are installed — 26.3, 26.4 twice (26.4 and 26.4.1, and one of the two
carries no devices at all), and 26.5 — so an unpinned destination can resolve onto the empty one and
fail for a reason that has nothing to do with the code. iPhone 17 / 17 Pro / 17 Pro Max / 17e / Air
exist under 26.3, 26.4 and 26.5; **iPhone 16e exists only under 26.3**, and there is no iPhone 16 at
all. Run `xcrun simctl list devices available` before assuming any device name.

Schemes: `challange-5` (app + UI tests), plus `ContentKit`, `RunEngine`, `DesignSystem` and
`content-validator` from the package. No `.xcscheme` is tracked in Git — schemes are generated
per-machine — so an `AppFeatures` scheme left over from before `b597b5b` may still be listed locally.
It is stale; that target no longer exists.

### This machine's toolchain is misconfigured

`xcode-select` points at `/Library/Developer/CommandLineTools`, not Xcode. Every command above fails without a fix — `xcodebuild` refuses to run at all, and `swift test` dies with `no such module 'Testing'` because the CommandLineTools toolchain has no swift-testing. Prefix commands rather than guessing at the error:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

`xcodebuild test` additionally spawns `simctl`, which re-resolves through `xcode-select` and fails even with `DEVELOPER_DIR` exported. Invoke Xcode's copy by full path and put it on `PATH`:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
"$DEVELOPER_DIR/usr/bin/xcodebuild" test -project challange-5.xcodeproj -scheme challange-5 \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
```

The permanent fix needs the user's password, so it is theirs to run, not yours: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.

### Walking a quest without walking

A quest starts only inside its first checkpoint's radius (`FR-START-08`), which makes the run loop
untestable from a desk. Debug builds carry a switch — **Settings → Developer tools → Simulate arrival
anywhere** — that reports a position at the next checkpoint. The arrival rule still runs on it: the
radius and accuracy gate in `ArrivalEvaluator` is unmodified, so what gets exercised is the walker's
code path with a different input. The switch (`Service/LocationService.swift`), its provider, and the
Settings section (`View/Component/DeveloperToolsSection.swift`) are all inside `#if DEBUG`; a release
build does not contain them, which is verifiable by grepping the Release binary for
`SimulatedLocationProvider`.

## The specs are authoritative

`.claude/prds/cultural-heritage-quest.full.prd.md` is the requirements document. `docs/system-design.md` and `docs/schema.md` are the design. Read the relevant section before changing behavior — these documents contain decisions with stated reasons, and several requirements look like arbitrary constraints until you read why they exist.

Requirement IDs are the working vocabulary and are cited in code comments and test names:

| Prefix | Meaning |
|---|---|
| `FR-*` | functional requirement |
| `NFR-*` | non-functional requirement |
| `AD-1…5` | architectural decisions |
| `V1…V18` | content validation rules (`schema.md` §A.9) |

When adding code that satisfies a requirement, cite its ID. When you find yourself wanting to violate one, say so explicitly rather than working around it.

## Architecture: two decisions explain most of the code

### 1. Content and user data are separate stores, linked by string ID

Content is authored, read-only, and replaced wholesale — by an app update in v1, by a CMS fetch in v3. User data is device-authored and must survive every replacement forever.

**Never add an object reference from user data to a content entity.** A `Run` holding a relationship to a `Quest` object means replacing content orphans or cascade-deletes a user's completed walks. Use `questID: String` plus the pinned `contentVersion`.

The corollary is snapshot-on-complete: when a checkpoint completes, the rendered lore, place name, accuracy labels, and citations are copied into the user's record. That single denormalization is what makes a summary render correctly forever, offline, after content corrections and after a place is withdrawn.

### 2. `ContentRepository` is the v3 seam

`BundledContentRepository` reads from the app bundle today. v3 swaps in a cache-backed remote implementation behind the same protocol, and nothing above it changes.

The protocol deliberately has no notion of loading, refreshing, connectivity, or freshness. **There are no reachability checks anywhere in this codebase**, and adding one is the specific mistake `AD-3` exists to prevent. Every core flow must work in airplane mode.

### Layering

`ContentKit` (Foundation only) → `RunEngine` (Foundation + ContentKit) → `DesignSystem` → the app target's `Model`/`ViewModel`/`View` (SwiftUI).

The app target is not a shell — since `b597b5b` it holds every screen and view model. `DesignSystem` is the last package layer, and it knows nothing about `ContentKit`: every string is passed in by the caller (`NFR-I18N-01`), which is why components take `String` rather than `LocalizedText`.

`ContentKit` and `RunEngine` must not import SwiftUI, UIKit, CoreLocation, MapKit, or AppKit. Target linkage enforces this in the app build, but on macOS all those modules exist in the SDK and an import would compile fine — so `ImportBoundaryTests` scans the source tree and is what actually holds the boundary.

`RunEngine` owns the Run lifecycle and the rules that write user data: ordering, arrival acceptance, awards, snapshot-on-complete. Arrival reaches it as a decided fact — a method and an accuracy, never a `CLLocation` — which is what keeps those rules testable without a simulator. `RunStore` fronts persistence; `FileRunStore` writes one JSON document per Run today, and SwiftData or a Supabase-backed sync layer is a swap behind the protocol, never a call in front of it.

## The presentation layer lives in the app target

The SwiftUI layer used to be an `AppFeatures` package target. Since `b597b5b` it sits in the app target as conventional MVVM:

| Folder | Holds | Rule |
|---|---|---|
| `Model/` | view-facing presentation types | `Sendable` value types only |
| `ViewModel/` | one `@MainActor @Observable` class per screen | no SwiftUI import |
| `View/` | one screen per file | |
| `View/Component/` | shared and extracted subviews | |
| `Service/` | platform edges — location, preferences, erasure, storage reporting | |
| `Support/` | environment assembly, formatting, UI strings | |

**`Model/` is not the domain model.** Domain types live in `ContentKit` and `RunEngine`; these are resolved snapshots ready to render — strings already localized, distances already formatted. Do not mirror a `Quest` or a `Run` here.

The `Sendable` conformance on every `Model/` type is a deliberate constraint, not concurrency plumbing — most never cross an isolation boundary. It makes it structurally impossible to store a repository, a palette, or a location provider in a presentation type. `LoreBlockPresentation.Ink` is the visible consequence: it is a two-case enum rather than the obvious `KeyPath<KultaraPalette, SRGBColor>` so the model stays ignorant of the palette, and the view does the lookup.

## Invariants held by tests, not by review

These are the places where a reasonable-looking change silently breaks a guarantee:

- **`LocalizedText` has no language fallback.** A missing `id` or `en` translation is a decode failure, never a runtime degradation into a mixed-language lore passage (`NFR-I18N-03`).
- **Validator rules live in `ContentKit`**, shared by the CLI and the runtime loader, so the two cannot disagree about what valid content is. Adding a rule means adding it in one place and adding a test that proves violating content is *rejected* — a test that only confirms valid content passes proves nothing.
- **Contrast is measured, not reviewed.** `DesignSystem/Contrast.swift` plus `KultaraThemeTests` and `HisploraThemeTests` assert every pair of **both** palettes against WCAG ratios (`NFR-A11Y-03`). A palette exposes `contrastPairs`, and a second test asserts that every token appears in at least one pair — so adding a colour without measuring it fails the suite rather than shipping. Where a sampled design value fails, *the theme yields and the deviation is recorded* (`docs/hisplora-tokens.md` lists the two that moved and why).
- **`mapPoint` is authored, not derived from `coordinate`.** The region map is a hand-drawn illustration with a stylised coastline; projecting real coordinates onto it puts every pin somewhere wrong while looking precise. The validator checks range, not geography.
- **Tasks never gate progression.** `blocksProgression` must be `false` for all content (`AD-2`, rule V8). Photos are keepsakes; the GPS radius is the gate.
- **Arrival needs the accuracy check, not just the distance check.** `FR-ARR-01` is two conditions, and the second is the load-bearing one: without `horizontalAccuracy <= radius`, a 500 m cell-tower fix unlocks a 75 m checkpoint from the next neighbourhood. It is also why the manual override is mandatory rather than a nicety (`FR-START-10`) — inside a covered market the accuracy test fails legitimately and often.
- **A completed Run stays writable for reading and answering.** The final checkpoint completes the walk the instant it is reached (`FR-DONE-01`), while the walker is still standing there with the closing reflection unanswered. `markLoreOpened` and `recordTaskResult` therefore accept `completed` as well as `active`; gating them on `active` makes completion swallow the ending that `FR-TASK-07` requires.
- **The run map is drawn, never tiled.** `FR-MAP-01`/`FR-OFF-03` rule out live map tiles, so there is no `MKMapView` and there must never be one. `RunRouteMapView` projects the authored `route.geojson` onto a `Canvas` via `RunEngine.RouteProjection`, which shares `Geo.earthRadiusM` with `Geo.distanceM` so the drawn length and the printed distance cannot disagree. `Place.mapPoint` is *not* usable here — it is authored against the stylised island illustration and means nothing at street scale.

## Invariants the restored guards hold again

`AppFeaturesTests` (~1,400 lines, 112 tests) was deleted by `b597b5b`. `m7` restored them into
`challange-5Tests` and they are green: **110 tests, 11 suites, 0 failures.** UI string ID/EN parity
(`NFR-I18N-01/02`), `FR-START-08` through `QuestRunViewModel`, `FR-ONB-02/04`, the summary model
taking no `ContentRepository`, and the `@State` view-model rule are guarded again rather than
reviewed.

Two things about *how* they are guarded matter more than the count:

- **The discovery guards read a fixture, not the shipped content.** `challange-5Tests/ContentFixtures.swift`
  supplies a paid quest, a prohibited-photo place, a known `hardLatestStart`/closing pair and two
  clusterable pins. Seven guards used to assert against `BundledContentRepository` and went red when
  the `contoh-*` placeholders were replaced by `badung-empat-wajah` — no requirement had changed. A
  requirement guard that reads live content changes meaning every time an author edits JSON. **Do not
  edit shipped content to satisfy a test, and do not point a new requirement guard at the bundle.**
  The cost: a content mistake will not turn these red. `swift run content-validator` and
  `BundledContentRepositoryTests` are what catch those.
- **Restoring them found two undocumented M8 flow changes**, which is what the restoration was for.
  A fresh walk opens on `.storyPreview` *before* the `FR-START-04` safety notice — now a signed PRD
  amendment (§5.5, owner af, 2026-08-16) that splits the load-bearing half into `FR-START-04a`:
  acknowledgement must precede any sampling, any permission request and any Run write. And arrival
  lands on `.cutsceneIntro`/`.storyReveal`, not `.atCheckpoint` — five stages earlier than the tests
  expected. Both are recorded in `m7`'s second execution section.

Still unguarded:

- **`FR-CP-05`'s Story Reveal exception** remains undocumented in the PRD (§10 lists it as
  outstanding, no owner named). `theCheckpointScreenCarriesTheStoryItsLabelsAndItsSources` does *not*
  cover it — that test asserts on `CheckpointPresentation`, which still carries every accuracy label
  and citation. The omission is in the view.
- **`AccessibilityXXXL` occlusion, and the test is now red.**
  `testTheWholeFlowSurvivesTheLargestDynamicTypeSize` fails at
  `DiscoveryFlowUITests.swift:105` — "Profile did not offer a way into the app preferences" — which
  is the *existence* check, before the scroll-into-reach loop it was given. At the largest content
  size the tap on the floating bar's Profile does not switch the tab, so the Explorer's Card is
  never on screen to be scrolled. **Verified pre-existing on this branch**: the same test fails
  identically in a clean worktree at `a1d914c`, so it is not the stamp/journal/profile work.
  `testQuestListAndSettingsAreReachable` walks the same Profile → Settings path at the default size
  and is green, which is what narrows it to the size. `resetLocalData` already carries a one-retry
  workaround for exactly this mistimed-tab-bar-tap failure; `openSettings` does not.

## Two visual directions, split at a screen boundary

The museum-catalogue theme (`KultaraPalette`, light/dark) carries the quest list, region map, preview, checkpoint, summary and settings. The Hisplora direction (`HisploraPalette`, a fixed brown/cream editorial pairing that does **not** flip with the system appearance) carries the run's story flow: story preview → location states → cutscene → story reveal → place notice → **task sheet → task list → site plan** → transition — and, since 2026-08-18, **onboarding**, which is now the first Hisplora surface the app shows and is reached before the museum theme is ever seen.

The last three landed 2026-08-17 from Figma `452:3132` ("Quest 1/3"), `447:1880` ("Quest_Filled") and `452:3028` ("Site Map"): `CheckpointDetailScreen` (restyled from the earlier `51:201`), the new `TaskDetailScreen`, and the new `PlaceSiteMapScreen`. `452:3028` is the **one story-flow screen on paper rather than brown** — `mapGround`, its own token — because a plan is a document. Five new palette tokens, four new New York type roles, and four recorded deviations came with them; `docs/hisplora-tokens.md` has all of it.

Two rules keep that from rotting:

- **The seam falls between screens, never inside one.** A half-restyled screen is not survivable; a boundary between two whole screens is. `QuestRunView.isOnStoryFlow` is the switch, and it also hides the museum navigation bar on those stages.
- **Museum-inked components must not be dropped onto a Hisplora ground.** They are measured against paper. `RunRouteMapView` takes `showsChrome:` for exactly this reason — its heading is `palette.seal`, which falls to about 2:1 on brown. This shipped as a real contrast bug before it was caught on device.

Onboarding came from `523:1946`, `523:1973` and `523:1999` on 2026-08-18: four screens rather than
the frames' three, because `FR-ONB-03`'s pocket-the-phone screen is a P0 MUST that none of the three
carries and `FR-ONB-02` allows four. It is the second of the four and the one screen drawn with a
symbol rather than an export. One palette token (`trackDim`), one type role (`onboardingDisplay`) and
three illustrations came with it. **The three PNGs are 1× and want replacing**: the 3× export
composites the frame's own cream fill behind the art, and the only transparent form the Figma tool
returns is a contents-only render it will not upscale. A hand export from Figma at 3× is a drop-in —
same names, same boxes.

On 2026-08-19 the run flow gained four more from the same board: `1:4681` (the camera), `1:4827`
(the task sheet holding a photograph), `1:4609` (the story behind a task) and `1:4641` (the stamp).
They introduced **no new palette tokens, no new type roles and no new packaged art** — the plate
`1:4616` draws on is `plaque-plate.png`, already shipped for `293:1630`, and the stamp is
`HisploraStampCard` at the size `1:4647` sets it. The camera is the one screen on neither visual
direction: it is a full-bleed preview under a translucent black bar, which is the system camera's
own language rather than this app's.

`docs/hisplora-tokens.md` records where each token was sampled, every measured ratio, and — importantly — the frames' content that was deliberately **not** built: the AI-generated portrait of a named historical figure (a `FR-CP-05` claim with no source or consent record), the external-maps handoff (`AD-3`), and the map screenshot (`FR-MAP-01`).

## Content

Authored JSON under `Packages/Kultara/Sources/ContentKit/Content/`. `consent/` is excluded from the package resources — it is a build input the validator reads, and shipping named individuals' details in every user's app would serve no purpose the build-time check does not already serve.

Lore is an array of labelled `LoreBlock`s, not prose. Each block carries `accuracy` (`documented` | `oral`) and source references, because `FR-CP-05` requires the epistemic status of each claim to be visible. There is no field for an unlabelled sentence — a writer structurally cannot produce one.

Any change to any content file must bump `contentBundleVersion` in `manifest.json`.

## The app-flow chart, and the wireframes standing in for it

The team's flow chart draws nodes the app does not have: splash, login/register, a Journal branch
(visited places → trip summary → share → template preview), a Profile branch (account settings →
app preferences), the create/save-journal loop, the next-adventure recommendation, and the
passing-by notification branch. Each is reachable in the running app as a **wireframe** —
`View/WireframeScreens.swift` around `View/Component/WireframeScreen.swift`, with all copy in
`Support/WireframeCatalog.swift`.

They are drawings, not features: dashed empty boxes, a `WIREFRAME // NOT BUILT` stamp, and a note
on each saying what has to be decided before it can be built. Nothing behind them works, and
nothing in them is persisted. Deleting one means deleting its `WireframeCatalog` entry with it.
Wireframe copy is deliberately kept out of `UIStrings` so the real string table never carries
strings for screens that do not exist.

Two structural consequences: the tab bar is Quests / Journal / Profile (settings is no longer a
tab — the chart reaches it as Profile → App preferences, and `DiscoveryFlowUITests.openSettings`
follows that path), and launch goes splash → onboarding → login before Home, with the splash
auto-advancing and the login carrying a "Skip for now".

## Known state

- Deployment target is iOS 18.0. Installed simulator runtimes are iOS 26.3 / 26.4 / 26.5; layout is verified on 26.5, and the 18.0 floor itself has never been run. Do not claim otherwise.
- The app target, `challange-5Tests` and the package are all `SWIFT_VERSION = 6.0`. The app target was Swift 5.0 until the presentation layer moved in — `DeveloperSwitchableLocationProvider`'s `#if DEBUG` default argument depends on SE-0411 isolated default value expressions and does not compile under Swift 5. **`challange-5UITests` is still `SWIFT_VERSION = 5.0`**, and that is the only target that is. The app target also builds with MainActor default isolation, which is why a nonisolated test double (`ContentFixtures.swift`) has to say so explicitly — a `ContentRepository` that could only be read from the main actor would be a different protocol from the one the app uses.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on for the app target, so a type used from `RunEngine` or `DesignSystem` needs that module imported in the file that uses it — a transitive import will not do.
- `.claude/plans/cultural-heritage-quest.plan.md` (Milestone 1, content model) is superseded by `docs/schema.md`.
- `.claude/launch.json` is stale scaffolding pointing at another user's Downloads folder. It has nothing to do with this project.
- The app has no name. "Kultara" appears throughout the code as a working title, but Kultara is a community storyteller organization in Sanur that the team interviewed — a research partner, not a brand. "Hisplora" is the Figma file's name and is used for the visual direction only, not as a product name. This needs resolving before any release.
- **The shipped content is one authored quest over five real places, and it is partly unverified.**
  `badung-empat-wajah` ("Jejak Terakhir Badung" / "The Last Traces of Badung") walks Puri Agung
  Pemecutan → Pura Maospahit → Pasar Kumbasari → Catur Muka → Museum Bali. **The quest id no longer
  matches its title**: the id is the key user data pins (`Run.questID`), so renaming it would orphan
  every completed walk — the title moved to the Ngalcer frame's wording and the id stayed. The
  four-faces reading is still what the quest is *about*, and every lore block, hook and clue still
  says so. The `contoh-*`
  placeholders are gone. What is real: Museum Bali's address and hours, Pura Maospahit's address and
  architecture, Pasar Kumbasari's address, four-storey layout, 1977 founding and market rules, and
  Catur Muka's position relative to the catus patha — each with an openable citation. What is **not**
  verified and must not be read as fact: **every coordinate** (seed values, unwalked), the route
  distance and duration (estimated, though V11 forces the JSON to claim `walking-directions`),
  opening hours at four of five places, all dress codes and photo policies, all entry costs
  (Museum Bali sells a ticket and ships as `0`), and step counts at four of five places. Unverified
  claims carry a `sources` entry whose citation begins `BELUM DIVERIFIKASI`. The full ledger is
  `.claude/plans/Content/c1-badung-single-quest-content.plan.md` §11.0, and
  `docs/field-verification-checklist.md` turns it into the list a person walking the route works
  through — in route order, with the exact value to capture and where it is written back. The
  highest-priority two: Catur Muka's seed coordinate is in the **wrong quadrant** (~293 m out, right
  neighbourhood), and Museum Bali's `entryCost: 0` renders as "Gratis"/"Free" for a museum that
  sells a ticket.
- **The shipped site plan is a generated illustration, and the screen says so.** `Place.siteMap`
  (`{ asset, aspectRatio, sourceRef }`) is new as of `contentBundleVersion` **2026.09.2**, and
  `badung-puri-agung-pemecutan` is the only Place that carries one. The drawing annotates a real puri
  with "171 meters", "158 meters", an entrance gate and an exit gate — none of it surveyed — so it
  ships as content with a third `sources` entry beginning `BELUM DIVERIFIKASI`, which
  `PlaceSiteMapScreen` prints under the plan. V14 checks the asset, V3 checks that the citation
  resolves. Replacing it with a real survey is a content change and nothing else. The frame's three
  marker dots are **not** drawn: nothing authors them, and inventing coordinates would be the app
  asserting where three things stand inside a real puri.
- **The task sheet comes before the task list, and it is where a task is answered.** `1:4592` →
  `1:4711` → `1:4904` on the New Hisplora board: the place notice hands over to the checkpoint's
  **first** task, and the menu is what the walker reaches after resolving it. So `TaskDetailScreen`
  carries the answer field, the save and the skip (`FR-TASK-02`) — a screen the walk opens on and
  cannot resolve would be a dead end. Both controls call `QuestRunViewModel.saveTask`/`skipTask`, the
  same pair `TaskCard` calls on the museum checkpoint screen, so there is one writer of a
  `TaskResult` and two ways to reach it. `TaskCard` stays: a resumed walk lands on `.atCheckpoint`
  and never sees the story stages, and `FR-TASK-07`'s closing reflection is answered there.
  `stageBeforeTaskDetail` remembers which way the sheet was entered so backing out is not ambiguous;
  forwards it always lands on the menu, whose `checkpointDetailContinueToNext` is the one way out of
  the checkpoint. Nothing here gates progression (`AD-2`) — the skip is on the same screen, and an
  empty field saves as a skip.
- **Photo capture ships now, and it owns the capture session rather than borrowing the picker.**
  `1:4681` ("Camera") is `View/Component/QuestPhotoCaptureScreen.swift` over
  `Service/CameraSession.swift` — `AVCaptureSession` + `AVCapturePhotoOutput`, because the frame
  draws its own chrome (titled dark bar with a cross, a 2× badge, a ringed shutter, a flash toggle)
  and `UIImagePickerController` will not let a caller replace Apple's. The sidequest challenge still
  uses the picker (`CameraCaptureView`); that flow has no frame of its own. `1:4827`
  ("Quest_Filled" holding an image) is the same `TaskDetailScreen` in its filled state: an 88-point
  thumbnail with `1:4852`'s cross on its shoulder, and a white Submit pill replacing the map hint.
  Only checkpoint 4 (`badung-catur-muka`) has a `photo` task, and `FR-TASK-06` still drops even that
  one where photography is prohibited.
  Three things about it are load-bearing:
  - **`INFOPLIST_KEY_NSCameraUsageDescription` was missing from both build configurations** and is
    now in `project.pbxproj`. Without it the sidequest picker would have crashed the app on launch;
    that was a live bug, not a new requirement.
  - **The photograph is a draft until Submit.** `QuestRunViewModel.photoDrafts` holds the `UIImage`
    in memory and `saveTask` is the one caller of `PhotoStore.save` — `1:4852`'s cross discards the
    shot, and a file written at the shutter and discarded a second later is an orphan in the
    walker's Documents directory that nothing would ever collect. `RunEngine.recordTaskResult` now
    takes `photoRelativePath`, which finally fills the `TaskResult` field that shipped unused.
  - **Whether a camera exists is asked as `AVCaptureDevice.default(for: .video) != nil`**, not as
    `UIImagePickerController.isSourceTypeAvailable(.camera)`. The Simulator answers `true` to the
    picker's question and has no capture device, so the sheet offered a camera the camera screen
    then had to apologise for. Both screens now ask the same question. On a device with none, the
    sheet says so and the skip is what resolves the task (`AD-2`).
- **Two screens now sit between resolving a task and the task menu.** `1:4609` ("Explanation per
  Quest") is the story behind the task, and `1:4641` ("Quest") is the stamp; `taskDetail` →
  `questExplanation` → `stampAward` → `checkpointDetail`/`atCheckpoint`. Four things worth knowing:
  - **It is reached on a skip as well as on an answer.** `AD-2` and `FR-TASK-02` make the two
    resolutions the same kind of outcome; withholding the story from a walker who skipped would turn
    "offered without apology" into a penalty.
  - **`1:4616` is the same stock plate `293:1630` already is**, names baked in and all — so
    `QuestExplanationScreen` reuses `HisploraPlaquePanel` and `plaque-plate.png` rather than shipping
    a second copy of the same picture. Do not re-export it.
  - **The explanation renders `Place.loreStandalone`, and at a sacred Place that is the same text
    `PlaceNoticeScreen` already printed.** `ContentTask` has no explanation field; adding one is a
    schema change, a validator rule, a `contentBundleVersion` bump and five newly authored sourced
    passages, which is a content decision with an owner. It carries the accuracy label and the
    citation the frame does not, because the Story Reveal's `FR-CP-05` exception is still unsigned
    and `s0` D6 forbids extending one by inference.
  - **The stamp is presented there, not granted there.** `FR-CP-07` awards it on arrival in
    `RunEngine.applyArrival`; `StampAwardScreen` writes nothing. Its artwork comes from
    `StampArtworkResolver`, which must be handed **the active run alongside the finished ones** —
    the resolver builds its stamp → place table from the runs it is given, so finished-only means a
    first-time walker's quest is in no table and the window renders empty.
- **`452:3132` renders one task row and one progress segment, not the frame's three.** The frame is
  titled "Quest 1/3" and invents three tasks ("The Iron Statue", "The Ancient Script", "The Whip
  Bearer") that exist nowhere in the content tree; the shipped checkpoints carry exactly one task
  each. The bar counts the run's own tasks (`AD-4`).
- **The Journal's stamps carry real artwork now, and it is tiered by walking.** Figma exports
  fifteen stamp SVGs (five places × three drawings) whose payload is an embedded base64 PNG — about
  90 MB of files nothing in this app can render, because every package image goes through
  `UIImage(data:)`. What ships is each file's picture **composited the way the file composites it**
  — the topmost `<rect>`'s pattern image, cropped by that pattern's own matrix — at 480 × 519:
  `DesignSystem/Resources/Images/<place>-stamp1…3.png`, 6.4 MB for the set. Taking the embedded PNG
  whole, which is what the first pass did, ships a different picture from the design's. The
  **SVGs live in `docs/design-sources/stamps/` and are `.gitignore`d**; they must never go back into
  `Resources/Images`, because `Package.swift` copies that directory wholesale and the exports would
  ride into the app bundle. `HisploraStampArtwork.tier` holds the rule — one finished quest through a place shows
  the first drawing, two the second, three or more the third, clamped at both ends —
  `StampArtworkResolver` (`Support/StampArtwork.swift`) counts finished walks per place, and place
  id → asset stem is **a table in the app target, not a field on `Place`**. A sixth authored place
  gets an empty window until that table is edited, which is the honest fallback and also the debt.
  `docs/hisplora-tokens.md` has the extraction detail.
- **The Profile tab's Quests surface lists unfinished walks, not sidequests.** It used to list
  `SideQuestRecord`s, which are not quests; it now lists Runs with `state == .active`, most recently
  touched first, and each row resumes its walk (`profileRunDestination`, the third `RunDestination`
  in `KultaraRootView`). Sidequests keep their own surfaces — the collection in the Journal and the
  nearby list. `ActivityPresentation` is now `InProgressQuestPresentation`.
- **Unsealing a letter no longer redirects.** It used to push `runScreen`, which for a finished
  walk lands on the museum-catalogue summary — a second visual direction with a navigation bar,
  reached by an animation that had just spent four seconds saying *this is a letter*.
  `View/JournalLetterView.swift` now opens the letter full screen over the shelf as a scrollable
  page: the same `RunSummaryViewModel` snapshots (lore claims with their accuracy labels and
  citations, the walker's written answers, the pinned content version) set as a paper sheet on the
  printed brown ground, with the earned stamps at the foot. `KultaraRootView.journalRunDestination`
  is gone; `journalLetter: SealedLetterPresentation?` drives a `fullScreenCover`. The lore claims
  are drawn in that file rather than by `LoreClaimList` because that component reads
  `\.kultaraPalette`, which is not this screen's palette.
- **The Journal's opening was clipped and is not any more.** The envelope's last two beats put the
  page two thirds of a card above itself and then grew it 2.1×, all inside a `ScrollView` that
  clips — so the top of the page was cut off mid-zoom. The opening is now drawn as a sibling of the
  scroll view rather than inside it, and the centred card steps aside while it plays. Two smaller
  fixes with it: each beat animates on its own curve and its own length
  (`HisploraEnvelopeSequence.animation(of:)`) instead of one 900 ms ease for all four, and the page
  fades in over 200 ms rather than cross-fading across its whole travel, so it reads as coming out
  of the pocket rather than appearing in front of the envelope.
- **Consent for those five places is a self-grant, not a grant.** D1-b: every `consent/badung-*.json`
  names the project team as `grantingBody`, scoped to inclusion and naming, for a non-public academic
  prototype. None of the five sites has been approached. The signatory fields are still literal
  placeholders (`[NAMA TIM]`, `[NAMA ANGGOTA 1]`, …). Tracking lives in `docs/consent-log.md` and
  `docs/consent/*-prototype-note.md`, and `docs/consent-request-pack.md` sets out per site who to
  approach, what is being asked, and what changes if they decline. This must not survive into
  anything public. Its four cross-cutting blockers — the team name, the signatories, **the app
  having no name**, and whether the build stays non-public — block all five approaches equally and
  are not per-site problems.
- The Figma frames name a real quest (I Gusti Ngurah Made Agung, Puri Agung Pemecutan, the Puputan)
  that still does not exist in the content tree and still cannot be authored without consent records
  and citations. Screens render from `ContentKit` by ID; never bake those names in (`AD-4`,
  `FR-RUN-06`).
- `Support/UIStrings.swift:338` still describes the content as "data contoh dengan tempat fiktif".
  That string is now wrong and needs a product decision, not a content edit.
- **`FR-CP-05` has an undocumented exception, and it is still open.** The Story Reveal pages render lore without the accuracy chip or citation. That was a deliberate product decision (`m8-qa-fixes.plan.md`, Decisions taken, item 2) and is recorded in code comments and `docs/hisplora-tokens.md` — but **not yet in the PRD**, which lists it as outstanding with no owner named (§10). It needs an amendment or a signed exception with an owner. `FR-START-04`'s comparable exception *was* signed on 2026-08-16 (owner af); this one was not, and the two are not a package.
- The story flow has been seen rendering on iPhone 17 / iOS 26.5: story preview, both cutscenes, story reveal, place notice, and — on 2026-08-17 — the task list, the task sheet and the site plan (screenshots in `docs/screenshots/m9-*.png`). The "Simulate arrival anywhere" toggle does not respond to synthesized taps from the simulator MCP; drive arrival with `xcrun simctl location <udid> set -8.6595,115.2077` instead — the start checkpoint of `badung-empat-wajah` (Puri Agung Pemecutan — an unverified seed coordinate), with `ArrivalEvaluator` unmodified. **A resumed walk lands on `.atCheckpoint` and skips every story stage**, so reaching them from a desk needs a fresh install (`xcrun simctl uninstall com.umar.hisplora`), not a relaunch. The transition screen is still unseen.
