# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native iOS app (SwiftUI, iOS 18.0) for story-led cultural heritage walking quests in Bali. Users walk a fixed-order route of physical checkpoints, unlock narrative lore at each one, and finish with a shareable recap.

Milestone 5 (Discovery & Preview) is implemented, and Milestone 6 ships the quest run as a vertical slice: start, arrival at each checkpoint, lore, written tasks, clue, completion, and a summary rendered from the Run's own snapshots. The share card, the recall survey and proximity alerts are not built; photo tasks are, as of 2026-08-19. **The app is wired to the backend as of 2026-08-21** (`.claude/plans/supabase/c2-wiring/`). It signs in anonymously, applies the kill-switch, sends anonymous telemetry, pushes a walk to `app.*`, uploads a photograph's two derivatives, and restores a walker's walks onto a device that has none. Sign in with Apple is enabled on prod (blocker B8, closed) and the share card's serve function is deployed and switched on — both unverified end to end on a real device, since the Simulator can produce neither a real Apple identity token nor exercise a shared link the way a stranger would. See also `.claude/plans/m6-quest-run-vertical-slice.plan.md`.

Milestone 8 (`.claude/plans/m8-qa-fixes.plan.md`) then did two things: fixed six QA findings, and put the run flow on a second visual direction ("Hisplora") taken from Figma. Both are shipped. `.claude/plans/m7-restore-test-guards.plan.md` — restoring the 112 tests commit `b597b5b` deleted — **is done**: 110 tests in `challange-5Tests`, all passing, plus the two source-scanning guards in the package. `.claude/plans/supabase/b0`–`b3` built and deployed a Supabase backend, `c1-client-phase0.plan.md` added the kill-switch publisher, `GovernanceKit` and `TelemetryKit`, and **`c2-wiring/` connected all of it to the app**. Phases 0–4 and 7 are `COMPLETE`; phase 6's provider is live but unverified on device; phase 5 (share card) is deployed at the owner's explicit instruction over an unresolved consent question — `docs/consent-log.md` did not change. `c2-wiring/PROGRESS.md` is the file to read first.

**The app's bundle id changed mid-session: `com.umar.hisplora` → `com.astungkara.hisplora`**, to match the Apple Sign in Services ID. Every `simctl launch`/`simctl install` example anywhere in this file's history used the old id.

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
    ├── challange-5/           app target — feature-first layout
    │   ├── App/                      6   shell, composition root, routing
    │   ├── Features/
    │   │   ├── Onboarding/           3
    │   │   ├── Auth/                  4   sign up, sign in, guest
    │   │   ├── QuestList/            9
    │   │   ├── QuestPreview/         5
    │   │   ├── QuestRun/            18   largest feature
    │   │   ├── RunSummary/           2
    │   │   ├── SideQuest/           11
    │   │   ├── Letters/              8   the journal surface
    │   │   ├── Explorer/             3
    │   │   ├── Map/                 26   only feature with sub-folders
    │   │   │   ├── Interactive/     10
    │   │   │   ├── Bali/             7
    │   │   │   ├── Tiles/            5
    │   │   │   └── Region/           4
    │   │   └── Settings/             4
    │   ├── Shared/
    │   │   ├── Components/           5
    │   │   ├── Lore/                 5
    │   │   ├── Strings/              1
    │   │   └── Wireframe/            3   quarantine, despite the name — see note below
    │   ├── Services/                 9
    │   └── Assets.xcassets/              unchanged
    ├── challange-5UITests/    XCUITest, the only tests needing a simulator
    ├── challange-5Tests/       unit tests for the app target — view models,
    │                           presentation models, UI strings
    └── Packages/Kultara/      local SPM package — ContentKit, RunEngine,
                               UIStringsKit, DesignSystem, GovernanceKit,
                               TelemetryKit, content-validator
```

`Shared/Wireframe/` is production code, not scaffolding, despite its name — it's read by
`RunSummaryView`, `SideQuestNoticeView` and `PlaceholderQuestCatalog`.

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
needs the app target — SwiftUI-adjacent view models, `Features/<Name>/` presentation types, `@testable import
challange_5`.

### Which suites run where

| Command | Runs | Needs a simulator |
|---|---|---|
| `swift test` (from `Packages/Kultara`) | 592 tests / 74 suites — `ContentKit`, `RunEngine`, `UIStringsKit`, `DesignSystem`, `GovernanceKit`, `TelemetryKit`, and the two source-scanning guards | **No** — macOS |
| `xcodebuild test -only-testing:challange-5Tests` | 238 tests / 23 suites — view models, presentation, UI strings, host linkage | Yes |
| `xcodebuild test -only-testing:challange-5UITests` | 5 XCUITests — the flow, and `AccessibilityXXXL` | Yes |

**Four `swift test` failures are pre-existing on this branch and are not yours.** None is in a
file the Figma port touched, and the first three reproduce in a clean worktree (the fourth is
newer — observed only on this branch's manifest state, not separately re-verified against a clean
worktree, but it is pure content-version drift unrelated to any Swift code, so there is no reason
to expect it's branch-specific):

- `PlaqueGeometryTests.theCornerIsAScoopArcedAboutTheCornerPointItself` — 2 issues, the plate's corner
  geometry in `PlaquePanel.swift`.
- `PermissionCallBoundaryTests.theAppUsesNoBackgroundLocationAndNoTrackingPrompt` — `SideQuestProximityService.swift`
  calls `requestAlwaysAuthorization` and `startMonitoring(for:)`, which that guard bans. A real
  finding about the sidequest proximity work, unrelated to the run flow.
- `BundledContentRepositoryTests.theBundleShipsFiveSidequestsFillingOneCollection` and
  `suppressingAPlaceRemovesOnlyItsOwnSidequest` — 4 issues. The bundle grew a sixth place
  (`park23`), its sidequest and a second collection at `2026.09.3`; the assertions still say five
  and one. Stale expectations about a content change, not a defect.
- `BundledContentRepositoryTests.exposesTheContentBundleVersionAQuestRunWouldPin` — 1 issue, same
  family as the two above: it asserts `contentBundleVersion == "2026.09.4"`, but the manifest has
  since moved to `"2026.09.5"`. Fix the assertion (or bump-document it), not the manifest.

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

Run from `challange-5/Packages/Kultara` unless noted. On this machine `swift test` needs the
`DEVELOPER_DIR` prefix below — see "This machine's toolchain is misconfigured" further down for why.

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test   # all pure-logic suites, macOS, no simulator
swift test --filter ContentValidatorTests     # one suite
swift test --filter "ContentValidatorTests/rejectsMissingConsent"   # one test
swift build
```

Content validation — the build-time gate:

```bash
swift run content-validator Sources/ContentKit/Content
```

Exits 0 when rules V1–V18 pass, 1 on any finding, 2 on bad arguments. Point it at an authored content tree (the directory holding `manifest.json`, `places/`, `quests/`, `assets/`, `consent/`).

The region map's tile pyramid — run from the repository root, needs `brew install gdal`:

```bash
scripts/build-map-tiles.sh
```

Rewrites `Content/assets/maps/bali-illustrated-tiles/` from the drawing named by
`manifest.regionMap.asset` (or from a path given as the one argument). Everything it writes is
generated; bump `contentBundleVersion` afterwards.

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

Schemes: `challange-5` (app + UI tests), plus `ContentKit`, `RunEngine`, `DesignSystem`,
`GovernanceKit`, `TelemetryKit`, `UIStringsKit` and `content-validator` from the package — the
package has seven targets, not four. No `.xcscheme` is tracked in Git — schemes are generated
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
code path with a different input. The switch (`Services/LocationService.swift`), its provider, and the
Settings section (`Features/Settings/DeveloperToolsSection.swift`) are all inside `#if DEBUG`; a release
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

`ContentKit` (Foundation only) → `RunEngine` (Foundation + ContentKit) → `DesignSystem` → the app target's `Features/`/`Shared/` (SwiftUI).

The app target is not a shell — since `b597b5b` it holds every screen and view model. `DesignSystem` is the last package layer, and it knows nothing about `ContentKit`: every string is passed in by the caller (`NFR-I18N-01`), which is why components take `String` rather than `LocalizedText`.

`ContentKit` and `RunEngine` must not import SwiftUI, UIKit, CoreLocation, MapKit, or AppKit. Target linkage enforces this in the app build, but on macOS all those modules exist in the SDK and an import would compile fine — so `ImportBoundaryTests` scans the source tree and is what actually holds the boundary.

`RunEngine` owns the Run lifecycle and the rules that write user data: ordering, arrival acceptance, awards, snapshot-on-complete. Arrival reaches it as a decided fact — a method and an accuracy, never a `CLLocation` — which is what keeps those rules testable without a simulator. `RunStore` fronts persistence; `FileRunStore` writes one JSON document per Run today, and SwiftData or a Supabase-backed sync layer is a swap behind the protocol, never a call in front of it.

## The presentation layer lives in the app target

The SwiftUI layer used to be an `AppFeatures` package target, then a layer-first `Model/`/`ViewModel/`/`View/`/`Service/`/`Support/` split in the app target. The feature-folder reorg replaced that split with feature-first grouping:

| Folder | Holds | Rule |
|---|---|---|
| `App/` | shell, composition root, routing | |
| `Features/<Name>/` | one screen's view, view model, and presentation models, filed together | presentation models `Sendable` value types only; view models no SwiftUI import |
| `Shared/` | components, lore, strings, and (quarantined) wireframe types used by two or more features | |
| `Services/` | platform edges — location, preferences, erasure, storage reporting | |

The placement rule the reorg used, and that new files should keep following: a type lives in the one feature that uses it; in `Shared/` if two or more features use it; in `Services/` if it is a service or only a service's parameter/return type.

**A `Features/<Name>/` presentation model is not the domain model.** Domain types live in `ContentKit` and `RunEngine`; these are resolved snapshots ready to render — strings already localized, distances already formatted. Do not mirror a `Quest` or a `Run` here.

The `Sendable` conformance on every presentation model is a deliberate constraint, not concurrency plumbing — most never cross an isolation boundary. It makes it structurally impossible to store a repository, a palette, or a location provider in a presentation type. `LoreBlockPresentation.Ink` is the visible consequence: it is a two-case enum rather than the obvious `KeyPath<KultaraPalette, SRGBColor>` so the model stays ignorant of the palette, and the view does the lookup.

## Invariants held by tests, not by review

These are the places where a reasonable-looking change silently breaks a guarantee:

- **`LocalizedText` has no language fallback.** A missing `id` or `en` translation is a decode failure, never a runtime degradation into a mixed-language lore passage (`NFR-I18N-03`).
- **Validator rules live in `ContentKit`**, shared by the CLI and the runtime loader, so the two cannot disagree about what valid content is. Adding a rule means adding it in one place and adding a test that proves violating content is *rejected* — a test that only confirms valid content passes proves nothing.
- **Contrast is measured, not reviewed.** `DesignSystem/Contrast.swift` plus `KultaraThemeTests` and `HisploraThemeTests` assert every pair of **both** palettes against WCAG ratios (`NFR-A11Y-03`). A palette exposes `contrastPairs`, and a second test asserts that every token appears in at least one pair — so adding a colour without measuring it fails the suite rather than shipping. Where a sampled design value fails, *the theme yields and the deviation is recorded* (`docs/hisplora-tokens.md` lists the two that moved and why).
- **`mapPoint` is authored, not derived from `coordinate`.** The region map is a hand-drawn illustration with a stylised coastline; projecting real coordinates onto it puts every pin somewhere wrong while looking precise. The validator checks range, not geography. Since `2026.09.4` the points are fitted to the *illustration's own* geometry — features read off the drawing at known real coordinates give 960 px per degree of longitude and 1206 per degree of latitude, because the picture is stretched about 1.24× vertically against true scale — and every point was looked at on the drawing before it was written down. That is the rule being followed, not bent: a real projection would still be wrong, and swapping the artwork means re-authoring every point again (`docs/hisplora-tokens.md`, `275:2309`).
- **Tasks never gate progression.** `blocksProgression` must be `false` for all content (`AD-2`, rule V8). Photos are keepsakes; the GPS radius is the gate.
- **Arrival needs the accuracy check, not just the distance check.** `FR-ARR-01` is two conditions, and the second is the load-bearing one: without `horizontalAccuracy <= radius`, a 500 m cell-tower fix unlocks a 75 m checkpoint from the next neighbourhood. It is also why the manual override is mandatory rather than a nicety (`FR-START-10`) — inside a covered market the accuracy test fails legitimately and often.
- **A completed Run stays writable for reading and answering.** The final checkpoint completes the walk the instant it is reached (`FR-DONE-01`), while the walker is still standing there with the closing reflection unanswered. `markLoreOpened` and `recordTaskResult` therefore accept `completed` as well as `active`; gating them on `active` makes completion swallow the ending that `FR-TASK-07` requires.
- **The *run* map is drawn, never tiled.** `FR-MAP-01`/`FR-OFF-03` rule out live map tiles during a
  walk, so there is no `MKMapView` under `Features/QuestRun/` and there must never be one.
  **The *discovery* map has one as of 2026-08-20**, and that is a scoped deviation with an
  unsigned amendment — see the Known state bullet and
  `docs/prd-amendments/fr-map-01-discovery-basemap.md`.
  `PermissionCallBoundaryTests` now names the three files allowed to touch MapKit and fails on a
  fourth, asserts separately that `Features/QuestRun/` touches none, and asserts that no package
  target does either. `RunRouteMapView` projects the authored `route.geojson` onto a `Canvas` via `RunEngine.RouteProjection`, which shares `Geo.earthRadiusM` with `Geo.distanceM` so the drawn length and the printed distance cannot disagree. `Place.mapPoint` is *not* usable here — it is authored against the stylised island illustration and means nothing at street scale.

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
- **Twelve of thirteen XCUITests pass as of 2026-08-21**, up from ten. Two of the three
  long-standing red ones are fixed; the third turned out to be a different and more interesting
  failure once the navigation bug in front of it was cleared — see below. Re-verified 2026-08-20 in a clean
  worktree at `65f9465`, which is the only reason they can be called pre-existing rather than
  assumed to be:
  - **They were fixed on 2026-08-21, and the cause was none of the things this note spent weeks
    guessing at.** The dump that solved it printed what was actually on screen at the assertion:
    `"Language"`, `"Delete all local data"`, a `"Back"` button, and `"Settings"` present only as a
    **static text**. The app was still *on the Settings screen*.
    `resetAppData` deletes local data and then taps `app.buttons["Quests"]` to get back — but
    Settings is pushed **over** the tab bar, so that tap hit a bar behind it and did nothing. Every
    later tap in the test landed behind the same screen, and `openSettings` then looked for a
    *button* called "Settings" on the Settings screen, where it is the title. It leaves by the Back
    button now.
    Three earlier theories were tested and are all wrong, which is worth keeping so nobody re-tries
    them: it is not a mistimed tap (the one-retry changed nothing), not the accessibility label
    (`ExplorerCardView` uses `UIStrings.settingsTitle` = `"Settings"` in EN), and not XCUITest
    centre-tapping a padded control (a coordinate tap changed nothing). `KultaraTabBar` is a real
    `Button` with a `contentShape` and a minimum tap target, and it works — it was simply not on
    top.
    **The lesson worth carrying: a guarded tap (`if x.waitForExistence { x.tap() }`) hides a
    navigation failure completely.** Both defects found here — this one and the stale
    `"Skip for now"` label — were invisible for exactly that reason. When a test asserts on
    something missing, print what *is* there before theorising.
  - **`testTheWholeFlowSurvivesTheLargestDynamicTypeSize` is still red, and it is an XCUITest
    problem rather than an app one.** With the Settings-on-top bug cleared it gets further and then
    XCUITest retries the Profile tap three times over sixty seconds, never sees the app go idle,
    and it is terminated — "application is not running" with **no crash report**.
    **Driving the same path by hand at `AccessibilityXXXL` does not reproduce it**: the app
    launches, onboarding and Home render, the Profile tab switches, and the process sits at 0% CPU.
    So the app is not hanging; XCUITest's *wait-for-idle* never settles, which points at a
    ever-running animation somewhere in the hierarchy — the Journal's idle envelope turn is the
    obvious candidate, since `HisploraEnvelopeFlip`'s idle cycle is explicitly designed to have
    nowhere to arrive, and `HisploraPulsingMapMarker` breathes on a loop as well. **The hypothesis
    is untested.** Whoever picks it up: quiescence, not performance, is the thing to look at.
  - `testTheMapSurfaceShowsAMarkerPerQuestAndOpensTheStoryFlow` fails at
    `DiscoveryFlowUITests.swift:227` — "A map marker did not open the story flow".
  - `SideQuestFlowUITests.testReopeningACompletedSidequestReplaysWithoutAwardingAgain` is **flaky,
    not red**: it failed once on "The delete confirmation dialog did not appear" and passed on a
    re-run of the same build. Do not treat a single failure of it as a regression without a re-run.
- **`JournalPapersTests.openingWhileTurnedReturnsTheCardToItsFrontFirst` was flaky and is fixed.**
  It failed five times on 2026-08-21 and passed on every re-run, because it slept a fixed 400 ms
  and then asserted a callback had fired — the turn is wall-clock work, and under a parallel suite
  on a busy machine it overruns. It polls to a five-second deadline now. **The general lesson,
  since this codebase has several animation-adjacent tests: a test that asserts "eventually" should
  wait for the thing, not for the clock.**

## Two visual directions, split at a screen boundary

The museum-catalogue theme (`KultaraPalette`, light/dark) carries the quest list, region map, preview, checkpoint, summary and settings. The Hisplora direction (`HisploraPalette`, a fixed brown/cream editorial pairing that does **not** flip with the system appearance) carries the run's story flow: story preview → location states → cutscene → story reveal → place notice → **task sheet → task list → site plan** → transition — and, since 2026-08-18, **onboarding** — plus, since 2026-08-21, the three **entry screens** (sign up, sign in, guest) that follow it. Those four are the first Hisplora surfaces the app shows, and all of them are reached before the museum theme is ever seen. Onboarding is the one Hisplora screen that is *not* brown: since 2026-08-20 it stands on the cream `paperSheet`, which is a re-paint of the same direction and not a third one.

The last three landed 2026-08-17 from Figma `452:3132` ("Quest 1/3"), `447:1880` ("Quest_Filled") and `452:3028` ("Site Map"): `CheckpointDetailScreen` (restyled from the earlier `51:201`), the new `TaskDetailScreen`, and the new `PlaceSiteMapScreen`. `452:3028` is the **one story-flow screen on paper rather than brown** — `mapGround`, its own token — because a plan is a document. Five new palette tokens, four new New York type roles, and four recorded deviations came with them; `docs/hisplora-tokens.md` has all of it.

Two rules keep that from rotting:

- **The seam falls between screens, never inside one.** A half-restyled screen is not survivable; a boundary between two whole screens is. `QuestRunView.isOnStoryFlow` is the switch, and it also hides the museum navigation bar on those stages.
- **Museum-inked components must not be dropped onto a Hisplora ground.** They are measured against paper. `RunRouteMapView` takes `showsChrome:` for exactly this reason — its heading is `palette.seal`, which falls to about 2:1 on brown. This shipped as a real contrast bug before it was caught on device.

Onboarding came from `523:1946`, `523:1973` and `523:1999` on 2026-08-18 and was **re-drawn from
`702:2068`, `702:1999` and `702:1980` on 2026-08-20**. Both boards draw the same three subjects in
the same order — Explore / Quest / Collection — and the app now ships exactly those three.

**`FR-ONB-03` is not met by onboarding any more.** A fourth screen carrying the pocket-the-phone
model (`AD-1`) stood second from the first board until 2026-08-20, when the owner asked for exact
frame parity and it was removed on that instruction. Two halves of what that means:

- **The words survive, the timing does not.** `QuestRunView.safetyNotice` — the `FR-START-04` screen
  shown before the first Run of every quest, with an "I understand" nobody can walk past — already
  printed that screen's paragraph under the quest's authored `safetyNotes` and still does. The
  string was renamed `onboardingPocketBody` → **`safetyPocketBody`** to say where it is now read;
  the title had no second caller and went, along with `OnboardingIllustration.symbol`. So a walker
  who starts a quest is told in the same words; a walker who never starts one is not.
- **The PRD still carries `FR-ONB-03` as a P0 MUST**, so this wants an amendment or a signed
  exception with an owner, the way `FR-START-04`'s was signed on 2026-08-16. It has neither yet.
  `OnboardingTests.onboardingIsTheBoardsThreeScreensAndNoLongerTeachesThePocketModel` is the
  inverted guard that keeps this visible instead of the deletion being silent.

What the second board changed is the paint and the escape hatch:

- **The ground went from `brownMid` to `paperSheet`**, so every ink on the screen flipped —
  `inkCream` type became `buttonFill`, and `trackDim` was **re-sampled** from `#926954` to
  `#C3BAAB` because the bar's 25% wash now composites over cream. One new token, `inkQuiet`.
- **The pill drops its hairline.** `HisploraPillButtonStyle` takes `ring:` now and onboarding passes
  `nil`: near-black measures 16.71:1 on this cream so the fill is its own boundary, while
  `buttonRing` — measured on the browns — is 2.47:1 here, under the 3:1 a boundary wants, so it
  would outline the edge with something fainter than the edge. `.hisploraPillOnPaper` is that
  case.
- **Skip moved from a footer pill to an underlined top-right link, and is now on every screen.** In
  the footer it could not appear on the last screen, where it and "Begin Your First Quest" do the
  same thing. It is a `Button` (`.hisploraTextLink`) rather than a tapped label, so VoiceOver
  announces it, and the frames' zero-opacity Skip pill beside Next is reproduced as what it looks
  like — a half-width Next — rather than as an invisible control VoiceOver would still find.

**The three PNGs are 3× now, and their alpha is computed rather than exported.** Figma will only
give an opaque 3× export (the frame's cream fill baked in, one unit off the screen's own) or a
transparent render it refuses to upscale past 1× — re-tested 2026-08-20, `maxDimension` does not
lift it. Each file is the 3× export's colour with the 1× render's alpha resampled over it and the
cream divided back out. Two things about that are load-bearing and easy to undo by accident:
**alpha must not be quantised** — the octree merges transparent into an entry at alpha 1–2, which
prints a visible rectangle of slightly darker cream, so the `tRNS` chunk is floored to 0 — and
`onboarding-quest.png` is deliberately **not** palette-reduced, because it is a smooth gradient and
256 colours band it.

On 2026-08-19 the run flow gained four more from the same board: `1:4681` (the camera), `1:4827`
(the task sheet holding a photograph), `1:4609` (the story behind a task) and `1:4641` (the stamp).
They introduced **no new palette tokens, no new type roles and no new packaged art** — the plate
`1:4616` draws on is `plaque-plate.png`, already shipped for `293:1630`, and the stamp is
`HisploraStampCard` at the size `1:4647` sets it. The camera is the one screen on neither visual
direction: it is a full-bleed preview under a translucent black bar, which is the system camera's
own language rather than this app's.

`docs/hisplora-tokens.md` records where each token was sampled, every measured ratio, and — importantly — the frames' content that was deliberately **not** built: the AI-generated portrait of a named historical figure (a `FR-CP-05` claim with no source or consent record), the external-maps handoff (`AD-3`), and the map screenshot (`FR-MAP-01`).

## The backend, from the app's side

Nine files under `challange-5/Services/` are the whole of it, and **nothing above them
knows they exist**. Deleting any one removes a capability and breaks nothing else.

| File | Does |
|---|---|
| `BackendConfiguration.swift` | Where the project is. Read from `Backend.plist`, written by a build phase from `Config/Backend.xcconfig` |
| `GovernanceGate.swift` | The kill-switch (`AD-5`). Last good document from disk at construction, refreshed on launch and every foreground |
| `AppTelemetry.swift` | Four anonymous events, per-walk random keys, no identifier of any kind |
| `SupabaseSession.swift` | The anonymous session. Keychain-stored, refreshed inside a 60 s margin |
| `DeviceIdentity.swift` | One UUID per install. Not a device identifier; erasure resets it |
| `SyncRecords.swift` | The wire shapes. `nonisolated`, in `Services/`, never in `RunEngine` |
| `SyncCoordinator.swift` | Pushes a walk. Idempotent upserts, backoff, and `EdgeFunctionAccountDeleter` |
| `SyncStateStore.swift` | `runID -> the updatedAt that landed`, so an unchanged walk is not re-sent |
| `PhotoUploader.swift` | Two objects per photograph, and structurally unable to see a sidequest's |
| `RunRestorer.swift` | Brings walks back, **only into an empty store** |
| `CredentialLinking.swift` | Sign in with Apple and `merge-anonymous` |

Six rules hold the shape, and each cost something to learn:

- **Nothing waits on the network.** Every call is fire-and-forget except one:
  `delete-account` during `FR-SET-02` erasure, which is awaited because a walker told
  their data is gone while it is not cannot act on something only they can decide about.
- **No reachability check anywhere** (`AD-3`). `noModuleChecksReachability` scans for it.
- **Two silences are broken deliberately**, and only two: a failed account deletion and a
  failed restore. Both are shown; everything else is `try?`.
- **The service-role key never enters the app.** Operator credentials live in `.env.local`
  (gitignored) and `supabase/scripts/publish-suppressions.sh` reads them.
- **`revision`, tombstones and conflict resolution were cut**, because there is one writer
  and restore only ever runs into an empty store. `c2-wiring/phases/phase-2-sync-identity.md`
  says what brings each back.
- **The simulator lies twice.** Its unified log renders every message from this process as
  `<compose failure>` — read `Library/Application Support/supabase-trace.log` instead
  (debug builds only) — and its **Keychain survives `simctl uninstall`**, so
  delete-and-relaunch is not a cold install for session purposes.

## Content

Authored JSON under `Packages/Kultara/Sources/ContentKit/Content/`. `consent/` is excluded from the package resources — it is a build input the validator reads, and shipping named individuals' details in every user's app would serve no purpose the build-time check does not already serve.

Lore is an array of labelled `LoreBlock`s, not prose. Each block carries `accuracy` (`documented` | `oral`) and source references, because `FR-CP-05` requires the epistemic status of each claim to be visible. There is no field for an unlabelled sentence — a writer structurally cannot produce one.

Any change to any content file must bump `contentBundleVersion` in `manifest.json`.

**There is one ground for the whole app.** `275:2179`'s printed sheet (`home-ground.png`,
`KultaraGround`) is drawn over `KultaraPalette.paper` on every museum screen and over
`HisploraPalette.paperSheet` on the three Journal screens. It replaced two earlier grounds —
`paper-texture.png` and `hisplora-ground.png` — and both are deleted. The Journal's type is
`inkDark`/`inkMuted` accordingly; `inkCream` still belongs to the brown story flow.

A museum screen that needs its own opaque ground — anything reachable as a `sheet` or a
`fullScreenCover`, which is presented outside the theme provider's tree — uses
**`.kultaraGround()`**, never `.background(palette.paper.color)`. The flat token is the same colour
with the sheet's printing painted over it, which is exactly how the catalogue ended up looking
different from the Journal.

**Never put an SVG in `DesignSystem/Resources/Images`.** `Package.swift` copies that directory
wholesale, so anything left there ships in every user's app bundle — this is how eighty-nine
megabytes of base64 stamp exports once rode into the build. Vector sources live in
`docs/design-sources/`, and the render is what goes in `Resources/Images`.

## The app-flow chart, and the wireframes standing in for it

The team's flow chart draws nodes the app does not have: splash, login/register, a Journal branch
(visited places → trip summary → share → template preview), a Profile branch (account settings →
app preferences), the create/save-journal loop, the next-adventure recommendation, and the
passing-by notification branch. Each is reachable in the running app as a **wireframe** —
`Shared/Wireframe/WireframeScreens.swift` around `Shared/Wireframe/WireframeScreen.swift`, with all copy in
`Shared/Wireframe/WireframeCatalog.swift`.

They are drawings, not features: dashed empty boxes, a `WIREFRAME // NOT BUILT` stamp, and a note
on each saying what has to be decided before it can be built. Nothing behind them works, and
nothing in them is persisted. Deleting one means deleting its `WireframeCatalog` entry with it.
Wireframe copy is deliberately kept out of `UIStrings` so the real string table never carries
strings for screens that do not exist.

**The login/register pair is no longer among them.** `AuthWireframeView` and its two catalogue
entries were deleted on 2026-08-21 when `Features/Auth/` shipped the real screens — this file's own
rule, the same way `createJournal` and `NearbyNoticeWireframeView` went.

Two structural consequences: the tab bar is Quests / Journal / Profile (settings is no longer a
tab — the chart reaches it as Profile → App preferences, and `DiscoveryFlowUITests.openSettings`
follows that path), and launch goes splash → onboarding → sign up / sign in / guest before Home,
with the splash still auto-advancing and still a drawing.

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
- **The discovery map is one map with two grounds, and the wand swaps them.** `275:2309` and
  `276:2520` are not two screens: `Features/Map/Real/QuestMapScreen.swift` stands the illustrated
  chart over a live `MKMapView` as an `MKOverlay`, and `wand.and.sparkles` adds and removes that
  overlay. The camera, the markers and the user's own position are shared, so the toggle changes the
  ground and nothing else. Six things about it:
  - **`FR-MAP-01` bans a live MapKit view for in-quest use and this is not that**, but the amendment
    scoping it that way is **drafted and unsigned** —
    `docs/prd-amendments/fr-map-01-discovery-basemap.md`, no owner named. Until it is signed this is
    shipped code without a requirement behind it, and the guard above is the only record of how far
    it reaches.
  - **Live location is real, not projected.** `showsUserLocation` on the basemap is the whole reason
    the basemap is there — a dot placed by projecting a coordinate onto a stylised drawing is the
    thing `MapPoint`'s rule forbids, and this sidesteps it rather than bending it. `Place.mapPoint`
    stays authored and stays what the offline surface draws by.
  - **The chart is placed by `RunEngine.IllustratedMapGeoreference`**, which solves the drawing's
    lat/lon box from the authored `mapPoint`s at the rates `docs/hisplora-tokens.md` measured — 960
    px/°lon, 1206 px/°lat. It fits the *origin* only: five of the shipped places sit inside Denpasar,
    so a two-variable regression over that cluster would be unstable. The five agree on one origin to
    within fourteen metres, and `IllustratedMapGeoreferenceTests` asserts residuals under twenty.
    Places no drawn quest reaches are excluded from the *fit*, which was originally a workaround:
    five carried `mapPoint`s predating this artwork, **34 to 40 km out**, that would have dragged the
    overlay across the Java Sea. **Those five are fixed as of `contentBundleVersion` 2026.09.8** —
    `bebek-tepi-sawah`, `citra-minang`, `mahen-living`, `sovereign-bali-hotel`, `taman-ngurah-rai`,
    all of them Kuta and Tuban addresses that now sit on the isthmus beside `park23`, where they
    belong. `IllustratedMapGeoreferenceTests.everyAuthoredMapPointSitsWhereThePlaceIs` scans the
    shipped bundle at a 1.5 km tolerance — about thirteen pixels of longitude on the drawing, enough
    headroom to nudge a pin off a label and nowhere near enough to hide a point that was never placed
    against this artwork. It reads live content deliberately: it is a *content* guard, the family
    `BundledContentRepositoryTests` belongs to, not a requirement guard.
  - **Geography is right and the art is squashed, deliberately.** The drawing is stretched ~1.25×
    vertically against true scale, so placing its features at their real coordinates draws it at a
    different aspect ratio than the file's. Preserving the drawing's proportions instead puts the
    coastline up to eleven kilometres out at the island's ends, which is the error a reader sees.
  - **The two controls are `UIButton`s inside the map's own container, not a SwiftUI layer over it.**
    A `UIViewRepresentable` puts a real `UIView` in the hosting view, UIKit hit-tests it before
    SwiftUI resolves anything drawn above, and a map view carries a great many greedy recognizers.
    The symptom was exact: **the wand only worked if you held it**, and two taps in one place became
    the map's own double-tap-to-zoom. Three attempts, and the two that failed are named in
    `QuestMapControls.swift` so they are not tried again — one full-screen `UIHostingController`
    (a lid: a SwiftUI hosting view hit-tests as itself across its whole bounds, so the map stopped
    panning) and two small per-button hosting controllers (single taps worked, repeats still leaked).
    `UIButton` has nothing to negotiate. The cost is that the liquid glass and the seal-filled circle
    are re-made in UIKit — `UIVisualEffectView` with `UIGlassEffect` on iOS 26 and `UIBlurEffect`
    below — rather than shared with the SwiftUI chrome. `PassthroughView` returns `nil` for anything
    that is not one of the two buttons, or the container is a lid of its own.
  - **The overlay is added once and never removed; the wand changes its opacity.** Adding and
    removing it made the button feel like it was refusing taps — each toggle threw away every
    rendered tile of a 1469 × 1071 drawing and rebuilt them, and a tap arriving during that work
    waited for it. `canDraw` returns false at zero alpha, so keeping the layer costs the real mode
    nothing. **A toggle now does no camera work whatsoever** — it sets the renderer's alpha and calls
    `setNeedsDisplay`, and that is the entire operation, which is what makes it spammable.
  - **Three MapKit details are load-bearing and were each a visible bug first.** The overlay goes on
    at `.aboveLabels`, or Apple's own place names print across the chart. `IllustratedMapOverlay` and
    its renderer are `nonisolated`, or VectorKit reads `boundingMapRect` off its tile queue and the
    app dies on the way into the map. And the map sets `insetsLayoutMarginsFromSafeArea = false` and
    is positioned with `edgePadding: .zero`, or MapKit fits the region into the *unobscured* area and
    leaves a band of bare basemap the height of the home indicator's inset.
  - **The chart was replaced at `contentBundleVersion` 2026.09.11, and that re-measured
    everything.** `maps/bali-illustrated.png` is now a **1536 × 1024** watercolour chart of Bali,
    Nusa Penida and Lembongan — `aspectRatio` **1.5**, in place of the sepia 1469 × 1071 drawing at
    1.3716. A new drawing invalidates every number that was read off the old one, and all of them
    moved together:
    - **All eleven `mapPoint`s were re-authored**, and `RegionMapArtwork.seaEdge` was re-sampled
      from the new corners (**#9FD0DC**, where the old sea was a grey-green #8B9999 — letterboxing
      the new chart with the old token printed a band of the previous map's colour beside it).
    - **`IllustratedMapGeoreference`'s two rates were re-measured off the new coastline**: **1126.82**
      px/°lon from the drawn island's west and east extremities (x 56 and 1499) against Bali's real
      114.4327°E and 115.7133°E, and **983.33** px/°lat from the north coast (y 58, −8.0611) and the
      Bukit isthmus (y 760, −8.7750).
    - **Latitude is anchored on the isthmus, not on the Bukit's tip, and that is load-bearing.**
      This drawing runs the Bukit about twice its true length. Binding the drawn south extremity to
      Bali's real southernmost latitude stretches the scale and drags every inland point south —
      built, seen, and reverted: the five Denpasar places landed *on* the isthmus and the six Kuta
      ones landed on the Bukit. Anchored on the neck instead, the strip the shipped quests occupy
      lands where it belongs and Bali's real southern tip falls at y≈833 on a drawing that runs to
      y=940. The exaggeration stays where it was drawn.
    - **The distortion reversed and shrank.** The old chart was stretched 1.256× vertically against
      true scale; this one is compressed **0.873×**, so placed for correct geography it is drawn
      about 1.15× taller than its own proportions rather than 1.25× wider.
    - **Coverage is tighter.** The old chart ran to Java's tip and Lombok; this one stops just past
      Bali's east cape. `IllustratedMapGeoreferenceTests.theFittedImageCoversTheIsland` asserts
      115.72 rather than 115.75 for exactly that reason — widening it back would assert coverage the
      artwork does not have.
    - **Verified against the live basemap on device**, which is the only real test of a fit: at the
      same camera the wand swaps to MapKit and the coastlines line up, with the marker on Denpasar
      — `docs/screenshots/m15-map-new-chart.png`.
  - **The chart is a `gdal2tiles` pyramid over a 4× super-resolution pass.**
    `contentBundleVersion` **2026.09.9** added `assets/maps/bali-illustrated-tiles/`, **2026.09.10**
    rebuilt it from an upscaled source, and **2026.09.11** rebuilt it again from the new drawing:
    `--profile=raster --xyz`, 256-pixel **WebP** tiles, levels 0–5, **513 files, 9.7 MB**, declared
    as `manifest.regionMap.tiles` and described by its own `tiles.json`. 6144 × 4096 is an exact
    multiple of 256, so this pyramid has no padded edge tiles at all —
    `RasterTilePyramidTests.edgeTilesOverhang` asserts that *and* keeps the overhang rule guarded on
    a ragged synthetic pyramid, because the tidy case is the one that stops being true the moment
    the artwork is re-cut.
    `scripts/build-map-tiles.sh` is the generator and **nothing under that directory is authored by
    hand**; re-run it whenever the drawing changes. `RunEngine.RasterTilePyramid` holds the
    geometry (raster profile puts the source at each level's *top-left*, `--xyz` counts rows down
    from there, level `maxZoom` is 1:1, edge tiles are padded with transparency rather than
    cropped), `RasterTileImageStore` decodes and caches, and both surfaces draw through them.
    Four things worth knowing:
    - **What this fixes is the *magnification*, not the resolution.** `RegionMapView` framed one
      `Image` at the resting size and then `scaleEffect`-ed it, so pinching to 6× stretched a
      ~1200-pixel layer to 7200 and never consulted the 1469-pixel source at all. It draws a
      `Canvas` now, re-rendered each frame at the size actually on screen. The MapKit overlay's
      gain is different: it stops compositing the whole 1469 × 1071 drawing into every one of
      MapKit's tile passes.
    - **The pixels come from Upscayl, and the upscale changes nothing on the paper.** The authored
      1536 × 1024 chart is 10.2 px/km, so it is 1:1 only at a **118 km** viewport — the whole island
      — and the opening camera (~22 km) magnifies it 5.4×. `remacri-4x` at scale 4 gives
      6144 × 4096, 41 px/km, 1:1 at **29.5 km**, so the opening camera now magnifies 1.3×. A pure
      scale is the point: `aspectRatio`, the measured px-per-degree rates and every authored
      `mapPoint` survive it untouched, which is exactly what *replacing the drawing* does not — see
      the bullet above for what that costs.
      **`remacri-4x` rather than a sharper model, deliberately.** `ultrasharp-4x` and
      `high-fidelity-4x` reconstruct crisper ink but hallucinate a regular fabric weave across the
      sea; `digital-art-4x` is cleanest of all and flattens away the paper grain the Hisplora
      direction is built on. All four were compared on the same crop before choosing —
      `docs/hisplora-tokens.md` has the detail. The 45 MB upscaled master is **not** in the
      repository: it is regenerable, and the command is in the script's header.
    - **Past `maxZoom` there is still nothing left to descend into.** 29.5 km is the ceiling,
      not infinity — a reader who pinches to street level gets smooth blur, and no tiling scheme
      invents pixels. `RasterTilePyramidTests.stopsAtNativeResolution` is where that is written
      down rather than assumed away. Going further means either a genuinely higher-resolution
      drawing or handing over to the live basemap past the chart's resolution; neither is built.
    - **Tiles are WebP at quality 90, and that is a tens-of-megabytes decision.** The 543 tiles of
      the previous chart were 43 MB as PNG against 6.2 MB as WebP; this drawing's 513 are 9.7 MB,
      the texture costing what the sepia chart's flat washes did not. A q90 tile was compared against its PNG at 1:1 before the switch, not assumed
      equivalent. ImageIO has decoded WebP since iOS 14 and the target is 18.0, so
      `UIImage(contentsOfFile:)` reads them with no extra code; `tiles.json` states `tileFormat`
      so nothing in Swift hardcodes the extension.
    - **The overlay is still gated on the decoded whole image, deliberately.** Adding it is also
      what applies `cameraBoundary`, `cameraZoomRange` and the opening `correct`, and `correct`
      refuses an un-laid-out map — so the asynchronous decode is what puts all three after layout.
      Gating on `tiles != nil` instead fires them on the first `updateUIView` and the map opens on a
      camera the correction never gets to fix, which shows as a band of bare basemap under the south
      coast. That was built, seen and reverted; the whole-image decode is the price.
    - **Tile seams are closed differently on each surface.** The `Canvas` snaps shared edges onto
      the device pixel grid (both neighbours round the same value, so there is no overlap); the
      MapKit renderer has no fixed pixel grid to snap to and grows neighbours into each other by
      half a device pixel instead. Seen on iPhone 17 Pro / iOS 26.5 —
      `docs/screenshots/m14-map-tiled-pyramid.png`.
  - **The map is never unmounted, and there is no reachability check.** A failed tile load only
    forces the chart on — the illustration needs no network, covers the viewport by construction and
    is projected by arithmetic, so `FR-OFF-03` is met by what is drawn rather than by which screen is
    mounted. **This replaced a real bug**: the screen used to swap the whole surface to
    `RegionMapView`, which destroyed the `MKMapView`, so nothing could ever report a load succeeding
    and the reader was stuck on the fallback for the session with the wand gone with it. `AD-3` is
    intact — nothing predicts the network and `noModuleChecksReachability` still passes.
  - **The dot is the app's own, and the map asks for permission to draw it.** `MKUserLocation` is
    rendered by `UserLocationAnnotationView` hosting `HisploraPulsingMapMarker` at 18 points — the
    seal-red dot in a cream ring with a breathing halo — because Apple's blue disc is the one object
    on the chart belonging to a different picture, and is easy to lose on a map of a whole regency.
    MapKit will not ask on the app's behalf, so `QuestMapViewModel.prepareLocation` requests
    when-in-use **from `.notRequested` only**. That is a second in-context permission moment and
    `FR-ONB-04` names one; it is a deviation, it is in the amendment doc, and it is unsigned.
    `PermissionCallBoundaryTests` admits `QuestMapViewModel.swift` by name with the reason written
    out. The map never calls `startUpdatingLocation` — that is arrival's (`NFR-BAT-04`).
  - **Bali and nothing else, in *both* modes, set once and never touched again.** `cameraBoundary`
    holds the centre on the paper, `cameraZoomRange` (derived from the chart's own width in metres)
    stops a pinch pulling Java and Lombok into frame, and a correction on `regionDidChangeAnimated`
    slides the last of the edge out of sight. The correction measures **how much basemap shows past
    the paper**, not how far the rect moved — MapKit fits rather than adopts a rectangle, so
    comparing rects never converges and the map twitches against itself.
    **These were briefly applied and lifted per mode, and that was a bug**: three things moved the
    camera on the way back to the chart, so a reader who had panned on the real map tapped the wand
    and watched a zoom animation instead of a toggle — "it zooms like there's no toggle". Confining
    both grounds is what leaves the toggle as *nothing but* a change of opacity. It costs the real
    map its freedom to show Java and Lombok, which is deliberate and a one-line revert: this app is
    a walk around Bali, and the basemap is here to say where in Bali a quest is. Seen on iPhone 17 /
    iOS 26.5 — `docs/screenshots/m13-map-illustrated-over-basemap.png`, `m13-map-real-basemap.png`.
- **The region map is a wide fantasy island, and it scrolls both ways.** As of
  `contentBundleVersion` **2026.09.11** `maps/bali-illustrated.png` is a 1536 × 1024 landscape chart
  (`aspectRatio` 1.5); it was `275:2309`'s 1469 × 1071 sepia drawing at 1.3716 from **2026.09.4** in place of the 853 × 1844 portrait one. `RegionMapView` fills the
  viewport, so it is drawn ~1199 points wide on a 402-point screen — the frame's own layout — which
  is where the horizontal pan comes from; vertical pan appears above fill, and **fill is the
  zoom-out limit** — pinching out stops where the drawing still covers the screen, so seeing the
  rest of the island is a pan, not a zoom. The map opens centred on the pins rather than on the
  artwork, and returning to fill keeps the pan rather than resetting it. Markers are `275:2309`'s own illustrated
  buildings standing in fog (`MapLandmarkFigure`, three drawings, quest-id table in
  `Features/Map/Region/MapLandmarkCatalog.swift`) with a 44-point square target hung on the building — the
  figure is 120 points wide and mostly transparent fog, so its bounds are not the target.
- **The shipped site plan is a generated illustration, and the screen says so.** `Place.siteMap`
  (`{ asset, aspectRatio, sourceRef }`) is new as of `contentBundleVersion` **2026.09.2**, and
  `badung-puri-agung-pemecutan` is the only Place that carries one. The drawing annotates a real puri
  with "171 meters", "158 meters", an entrance gate and an exit gate — none of it surveyed — so it
  ships as content with a third `sources` entry beginning `BELUM DIVERIFIKASI`, which
  `PlaceSiteMapScreen` prints under the plan. V14 checks the asset, V3 checks that the citation
  resolves. Replacing it with a real survey is a content change and nothing else. The frame's three
  marker dots are **not** drawn: nothing authors them, and inventing coordinates would be the app
  asserting where three things stand inside a real puri.
- **The `approachTransition` wiring was missing from this branch and has been restored.** As of
  2026-08-20 the app target did not compile: the `d7b02e0` merge kept `QuestRunViewModel.Stage`'s
  `approachTransition` case and both screens that render it, but lost
  `advanceFromApproachTransition`, `approachTransitionDuration`, the `cutscenePortrait` →
  `approachTransition` hand-off, the back case, `isStoryFlow` and `opensOnStoryFlow`. The same merge
  left `initialStage` with three parameters its body never reads while the call site still passed
  one, and left `QuestRunView` carrying a second copy of the story-flow switch. All of it is put
  back from `f88eb4c` (`origin/FE`), with `isOnStoryFlow` now delegating to the model's one rule
  rather than keeping a duplicate. None of this is new behaviour — it is what the bullet below
  already described, restored so the target builds.
- **`isStoryFlow` and `opensOnStoryFlow` live on `QuestRunViewModel`, and the second is derived from
  the first.** Merge `2160796` dropped both — along with `approachTransitionDuration`,
  `advanceFromApproachTransition()` and `initialStage`'s signature — and the app target stopped
  compiling, because `KultaraRootView.RunDestination` has to know whether a pushed run screen lands
  on a story stage *before* the model exists (a museum bar that appears for one frame and vanishes
  under the story preview is worse than no bar). They were then restored twice, on two branches, and
  merging left the file with two copies of each. The pair that survives is
  `opensOnStoryFlow(existingRun:) = isStoryFlow(initialStage(run:))` — one rule, read two ways. A
  second copy that restates the rule is exactly how the two drift apart, so do not add one.
- **The cutscene's two pages are one view, and that is what makes the frame move rather than
  cross-fade.** `98:1588` and `187:866` draw the same gilded portrait ~100 points apart and at
  slightly different widths. As two screens swapped by `model.stage` the hand-over was the run
  flow's own cross-fade dissolving one picture of that object into another, which reads as a cut
  rather than as one thing moving — the most visible seam on the story flow.
  `CutsceneIntroScreen`/`CutscenePortraitScreen` are now `CutsceneSequenceScreen(phase:)`, and
  `QuestRunView` routes `.cutsceneIntro` **and** `.cutscenePortrait` to one `case`, so the view
  keeps its identity and SwiftUI animates the layout. Four things about it:
  - **The reveal stays mounted on `.portrait`.** That is what makes the frame one object across the
    change rather than two. It costs nothing there — the cover is either rubbed off or was never
    drawn — but it must not keep the gesture, or a drag over the picture is swallowed instead of
    scrolling the page (`allowsHitTesting(isLegend)`).
  - **Stepping back re-covers the picture, and it has to.** Two screens meant backing out of
    `187:866` threw the intro away and built a fresh one. One view keeps its state, so without
    `revealGeneration` the walker returns to a page whose gesture can never complete again and
    which therefore has no way forward at all.
  - **The spring is the screen's own, not `QuestRunView`'s.** The stage animation there is the
    cross-fade curve every *other* stage change runs on; this one is not a cross-fade. Under Reduce
    Motion the frame must not travel, so it falls back to a short fade.
  - **The words are staggered, not dissolved.** Outgoing text leaves in 0.16 s, the incoming set
    arrives after 0.16 s and rises 12 points, so the page settles and *then* reads.
  Seen on iPhone 17 / iOS 26.5, both directions — `docs/screenshots/m16-cutscene-legend.png`,
  `m16-cutscene-portrait.png`.
- **A map with a beating dot stands between the cutscene and the story, and it leaves on its own.**
  `187:1103` is back as `approachTransition` — `cutscenePortrait` → `approachTransition` →
  `storyReveal`, on the walk's first checkpoint only, since it is the cutscene that it lands. It is
  `1:4458`'s own open scroll (`HisploraMapScroll`) holding the Place's authored `approachMap`, with
  the quest's region in the eyebrow and the place's name under it. Four things about it:
  - **The dot's position is authored, not projected.** `PlaceApproachMap.marker` is a `MapPoint` in
    fractions of the *drawing*, new at `contentBundleVersion` **2026.09.7** and carried only by
    `badung-puri-agung-pemecutan` — read off the illustration's own pin for that Place. Projecting
    `coordinate` onto a stylised street grid would land it on the wrong road while looking exact,
    which is `Place.mapPoint`'s rule applied one scale down. V14 range-checks it; absent means no
    dot at all, never a fallback to the middle of the paper.
  - **It has no control, so the back chevron is load-bearing.** The wait is a `.task` on the screen
    rather than a timer on the model: backing out cancels it, and
    `advanceFromApproachTransition` additionally refuses to move a stage it is not on. Five seconds
    with no way out would be five seconds a walker cannot leave.
  - **Under VoiceOver the clock does not run and a Continue appears instead.** A screen that reads
    itself out and then vanishes mid-sentence has no right duration; `CutsceneIntroScreen` draws its
    button under the same rule.
  - **No new palette token and no new art.** The dot is `mapMarker`, already measured against
    `paperCream`, wearing the cream ring the site plan's markers wear (`NFR-A11Y-05`) — and the map
    accessibility label names the dot, so colour and motion never carry it alone.
    `HisploraPulsingMapMarker` stops the ring rather than the dot under Reduce Motion.
  `1:4586`'s sealed scroll (`transition`) is untouched and still sits between `storyReveal` and the
  checkpoint's own screens at every checkpoint.
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
  `1:4681` ("Camera") is `Features/QuestRun/QuestPhotoCaptureScreen.swift` over
  `Services/CameraSession.swift` — `AVCaptureSession` + `AVCapturePhotoOutput`, because the frame
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
- **`452:3132` renders one row and one segment per authored task, never the frame's fixed three.**
  The frame is titled "Quest 1/3" and invents three tasks ("The Iron Statue", "The Ancient Script",
  "The Whip Bearer") that exist nowhere in the content tree. The bar counts the run's own tasks
  (`AD-4`) — since `contentBundleVersion` **2026.09.14** that happens to be three per checkpoint,
  and the guard reads the checkpoint's list rather than the literal number, which is what stopped
  `theProgressLabelCountsTheRunsOwnTasksAndNotTheFramesThree` going red on a content edit.
- **Every checkpoint carries three tasks now, and the single placeholder each shipped with is
  gone.** `2026.09.14` re-authored all fifteen from the owner's own wording (2026-08-24), named in
  the prompt's first sentence because the task rows and the sheet's masthead both print the *type*
  as the title and content has no title field — three rows reading "Photo" with no other difference
  would be unreadable. Four things about them:
  - **Eleven of the fifteen are photo tasks**, which is fine at all five places (`FR-TASK-06`/V9:
    none of the five is `prohibited`, four are `restricted`) — but it means **the start checkpoint
    now has no written task at all**. Two `TaskDetailTests` had assumed the checkpoint's first task
    took words and silently resolved a photo task as a *skip* when handed a written draft; they
    answer by the task's own mechanic now (`answer(_:on:words:)`).
    `QuestRunTests.aWrittenReflectionReachesTheSummary` still guards with a `first(where: != .photo)`
    and now passes **vacuously** at the first stop — worth knowing before trusting it.
  - **The two temple notes ride in the task prompt**, because `ContentTask` has one authored field
    and no notes: whoever is ritually unable to enter, menstruation included, does not enter the
    closed areas. Same for the market's "bring cash" and the museum's ticket money.
  - **`FR-TASK-05` is intact and V7 checks it**: `photo`, `reflection` and `question` are the whole
    of `TaskType`, and both sacred places take only those. Nothing gained `blocksProgression`
    (`AD-2`, V8).
  - **The Maospahit answer is a fill-in clue (`c _ n _ _ _`) and nothing verifies it.** `question`
    tasks are recorded, never marked — the app has no answer key and `AD-2` means it could not gate
    on one anyway.
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
  `StampArtworkResolver` (`Shared/Lore/StampArtwork.swift`) counts finished walks per place, and place
  id → asset stem is **a table in the app target, not a field on `Place`**. A sixth authored place
  gets an empty window until that table is edited, which is the honest fallback and also the debt.
  `docs/hisplora-tokens.md` has the extraction detail.
- **The Profile tab's Quests surface lists walks — both kinds — behind a filter, and never
  sidequests.** It listed `SideQuestRecord`s once, which are not quests; then Runs with
  `state == .active` only. `705:2824` lists *finished* walks instead, and both readings are right
  about a different reader, so as of 2026-08-20 the list carries both and a three-way filter (All /
  Unfinished / Done, `HisploraFilterChips`) says which. Four things about it:
  - **`all` puts the unfinished ones first**, because a walk still open is the thing a reader opens
    their own card to act on and a finished one is a record.
  - **Only an unfinished row resumes.** Profile is the only route back into a walk in progress
    (`profileRunDestination`, the third `RunDestination` in `KultaraRootView`); a finished walk's
    record is its letter and its badge, so its row is not a button at all.
  - **A finished row reads "You completed this quest at <region>"**, and the region is content
    rather than a snapshot — no `Run` carries one. A withdrawn quest leaves it empty, and the row
    prints "Completed" rather than a sentence ending in "at".
  - **The row is `705:2827`'s object now**: white 50% over the sheet (`paperRow`), a square
    `brownMid` hairline instead of a corner radius, and the wax seal (`quest-seal.png`, `737:3971`)
    at the foot-right where the checkmark symbol used to be at the head-left. `ActivityPresentation`
    became `InProgressQuestPresentation` and is now `QuestRowPresentation`.
- **The Profile tab's stamps are `705:2767`'s object.** White paper (`paperStamp`), the franking in
  two new caps roles (`stampFranking`, `stampFrankingDetail`), the window and the caption placed by
  fractions of the die rather than by points, and `705:2769`'s drop shadow — which the envelope's
  26-point franking deliberately does not get. The perforation is still drawn rather than exported,
  for the reason `HisploraStampShape` gives.
- **The Journal's envelope turns itself over, holds two papers, and hands over to a modal.**
  Four frames from the New Hisplora board landed 2026-08-20: `791:5637` (the flip), `791:5585` (the
  open envelope with both sheets), `791:5533` (the sheets rising) and `791:5551` (the modal). Five
  things about it are load-bearing:
  - **The franking moved to the back.** The sealed card on the shelf is bare paper and a wax seal
    (`791:5601`); the stamps and the handwritten address are on the other side, which is what the
    idle turn exists to show. Drawing them on both faces would make the turn say nothing.
  - **Tapping open mid-turn returns the card to its front first.** The designer's rule, and not a
    nicety: the flap and the wax are drawn on the front, so an opening that started on the back
    would swing a flap the reader cannot see. `HisploraEnvelopeFlip.returningToFront` is the
    shortest way home from each of the four beats, and `unseal` awaits it before the first beat of
    the opening.
  - **Reduce Motion stops the turn rather than collapsing it.** Every other sequence here runs its
    beats in zero time so the screen still arrives where it was going; an idle turn has nowhere to
    arrive, and collapsed to a cut it is a card that snaps to its back and stays there.
  - **The back needs no new export.** It is `envelope-inner` at 180° and nothing else — drawing
    `envelope-body` as well printed the pocket's flap cutout as a bright trapezoid across the
    address.
  - **An open envelope is the whole body export, not a band cut out of it.** The export carries the
    pocket's own V — two wings to the top corners, a notch between them — so drawn whole it is what
    a real envelope shows with its flap off the front, and the papers are occluded by its alpha.
    Masking it to a straight band, which is what shipped first, printed a horizontal seam no
    envelope has. `pocketTopRatio` is gone; `pocketNotchVertexRatio` describes the notch instead.
    The open flap is drawn shaded (`brightness(-0.14)`), because past the fold the reader is looking
    at its back.
  - **The sheets in the pocket are whole `HisploraJournalPaperCard`s.** `791:5595`'s 172.5 × 113.5
    is the *head* of a 344 × 321 card — the export stops where the pocket covers the sheet — so
    cropping the view there too shipped a card with its picture and its control sliced off, visibly
    so the moment the sheets rose clear. The envelope hides the rest, which is the pocket's job.
  - **The shelf's gutter is padding, not a content margin.** As
    `contentMargins(_:for: .scrollContent)` the one envelope sat 42 points left of centre: the
    margin moves the content, the resting offset is still taken from the content's origin, and a
    shelf with one card cannot scroll to correct it.
  - **The sealed card's nudge is not gated on there being a shelf worth swiping.** It was gated on
    `showsSwipeHint` (false with one letter), so the first walk a reader finished sat still. The
    rock and the turn ride on top of each other — one is 2D, the other is about the vertical axis.
  - **The shelf is `791:5601`'s order now, and there is no Unseal button.** The letter's title
    stands *above* the envelope in the display serif's italic, "Tap envelope to open" under it, the
    card, then a row of 8-point dots for the shelf's position. Removing the pill is an accessibility
    change before it is a layout one: a picture with a tap gesture is not a control VoiceOver can
    announce or activate, so the card is a `Button` carrying the pill's old label
    (`journalUnsealAction`) and `journalSwipeHint` survives as its hint on a shelf worth swiping
    (`NFR-A11Y-05`). The collections button stays in the header — `FR-SIDE-08`, and the frame's
    hidden `791:5630` sits in exactly that slot.
  - **The opening plays where the card stands, and `791:5585` is not a keyframe of it.** That
    frame draws the open envelope 1.172× the sealed one and 73.8 points lower, with the title risen
    to y 119 and no header. Animating the card into it was built and reverted: three things moving
    at once, one of them the object just tapped, reads as the envelope lurching out from under the
    reader's finger. The frame is a still of an open envelope on a headerless screen. The card holds
    still, the flap swings, and the words step back.
  - **The swung flap is pushed back down onto the card, and that is not a fudge.** `anchor: .top`
    does not hold the hinge: at 168° with `perspective: 0.45` the plane is displaced about
    `height · sin(12°) · perspective` — ten points at the shipped size — and the page showed between
    the flap and the body as a bright line across the object. `flapHingeOverlapRatio` (12 of the
    card's 174) closes it; the envelope's own paper is drawn after the flap and hides the overlap.
    The flap's shadow also belongs *after* the rotation rather than before it.
  - **The shelf's scroll view must not clip (`.scrollClipDisabled()`).** The turn is a
    `rotation3DEffect` with perspective, so a card at 90° draws wider than its own frame, and the
    content is exactly as wide as the viewport — the addressed side lost a strip off its right edge
    every time it came round.
  - **The envelope is one sheet of paper on every face.** `envelope-body` and `envelope-flap` are
    photographed much darker than `envelope-inner` (means `#8A6E47`/`#5A472D` against `#D6C1A1`), so
    a card that turned over changed colour halfway round. The front is drawn as `envelope-inner`
    masked to the body's and the flap's alpha (`paperLayer(shapedBy:)`) rather than by re-grading
    two exports, which would clip every highlight. The fold's shadow, the pocket lip's shadow and a
    shade on the inside are what keep the object readable once every surface matches.
  - **`clipped()` clips drawing, not touches.** The paper cards' torn sheet is drawn far larger than
    the card, and the second card's copy of it swallowed every tap meant for the first card's
    button — "Read Summary" did nothing while "Read History" worked. Decorative layers in
    `HisploraJournalCard.swift` are `allowsHitTesting(false)`; a new one that forgets will
    reintroduce the same defect.
  The two papers are drawn, never exported: `JournalPaperPresentation` carries the eyebrow, the
  title, the action and an artwork *name*, so a walk's own snapshots name it (`AD-4`, `FR-RUN-06`).
  The two shipped artworks (`journal-summary-emblem`, `journal-history-plate`) are defaults in a
  table in the app target, the same debt `StampArtworkResolver`'s place table is — and the history
  plate is a photograph of a real painting with **no provenance recorded**, which is a content
  decision with an owner before anything public.
- **Unsealing a letter no longer redirects.** It used to push `runScreen`, which for a finished
  walk lands on the museum-catalogue summary — a second visual direction with a navigation bar,
  reached by an animation that had just spent four seconds saying *this is a letter*.
  `KultaraRootView.journalRunDestination` is gone; `journalLetter: SealedLetterPresentation?` drives
  a full-screen overlay over the shelf.
- **The letter is two pages now, and `JournalLetterView` is only the switch between them.**
  `791:6414` ("Trip Summary") and `791:6537` ("History") landed 2026-08-20 as
  `Features/Letters/TripSummaryScreen.swift` and `TripHistoryScreen.swift`, with `TripPageChrome.swift`
  (bar, counter tile, place card, gilt medallion) and `TripFrameLayout.swift` (the frame canvas)
  beside them. Before those frames existed both paper cards opened one page at two scroll offsets;
  the board drew each half as its own screen, so the split is now real. Nine things about them:
  - **Every ground on both pages is speckled, and the scroll's underlay is two-tone.**
    `TripFrameBand` takes an `SRGBColor` token and paints it through `kultaraSpeckledGround`, so no
    band is the one rectangle on the page without the grain every other Hisplora screen has. And
    because a scroll view overscrolls past its content, `overscrollBleed(top:bottom:)` hangs a
    rectangle of each end's token above and below the *content* — one colour behind the whole scroll
    printed a cream strip under the closing band, and a two-tone one behind the *viewport* stayed
    put while the page moved, repainting the counters' ground halfway down a scroll.
  - **They are set at the frames' point sizes, not at type roles, and neither responds to Dynamic
    Type.** The owner asked for the frames reproduced exactly, and a role that scales cannot hold a
    15-point label beside a 21-point figure at the drawn ratio. `journalBandHeading` and
    `journalStatValue` exist for the reflowing fallback page, not for these two.
  - **The History page is drawn at the frame's 402-point coordinates and scaled**, band by band,
    rather than composed out of stacks (`TripFrame`, `TripFrameBand`, `TripFramePage`). It is an
    editorial spread — cut-outs behind paragraphs at chosen angles, a portrait bleeding off the left
    margin with an arrow drawn at it — and as stacks it becomes *a* layout, not *this* one. The
    canvas carries a spoken label with every word in reading order, because the composition says
    nothing to a reader who cannot see it. The Trip Summary still reflows: its contents are the
    walk's.
  - **The History page's prose is `QuestHistoryText`, a per-quest table in the app target.** Same
    shape and same debt as `StampArtworkResolver.slugsByPlaceID`: a second quest gets no History
    page until somebody edits that file, and falls back to `TripHistoryChapters` — the walk's own
    lore snapshots with their accuracy labels and citations.
  - **The Badung page's nine paragraphs carry no citations, and the portrait no consent record.**
    That page breaks `FR-CP-05` and `FR-CP-06`, deliberately, at the owner's instruction of
    2026-08-20 — the reasoning being that History is the quest's own story rather than something the
    walker collects. Three things have to happen before anything public and they are listed in
    `docs/hisplora-tokens.md`: citations for every sentence, a licence record for `history-king` and
    `history-plate`, and a decision about `sticker-3-32`, a plaque with one quest's title printed
    into it. This sits beside the `docs/consent-log.md` blockers, not instead of them.
  - **The three counts on the summary are the Run's.** `RunSummaryViewModel` gained
    `placesExploredCount`, `memoriesCount` and `durationMinutes`; a skip is a resolution and not a
    memory (`AD-2`), an empty field is not one either, and the duration floors at one minute.
    `TripPagesTests` holds all three.
  - **The Trip Collection is the quest's legend plus the walker's own photographs.** The frames draw
    five medallions of one painted portrait captioned with invented object names; what ships keeps
    the mounts and changes their contents — `791:6482`'s portrait in the featured slot (from
    `QuestHistoryText.legend`, per quest), then one medallion per photograph the walk actually
    produced, captioned with the place. Three photographs give three medallions; none gives the
    legend alone. `RunSummaryViewModel.capturedPhotos` carries paths and
    `PhotoStore.image(atRelativePath:)` reads them back against `Documents`, returning `nil` for a
    photograph deleted from Settings (`FR-SET-02`).
  - **The share control is a real `ShareLink` handing over plain text.** The recap card
    (`FR-DONE-06`) is still unbuilt; the glyph both frames draw would otherwise be a promise the
    screen cannot keep. When the card exists it replaces the `item` and the bar does not change.
  - **The walker's written answers are on the summary's place cards**, where the frames draw only a
    count of "memories". Dropping the one thing on the page nobody authored would have been the
    silent loss in this redesign.
  - **Back goes to the papers modal, not to the shelf.** Both pages are reached through `791:5551`,
    so the way back from one is the choice that opened it — otherwise a reader who finished the
    summary has to unseal the envelope again to reach the history.
- **Eighteen paper cut-outs and eight page illustrations ship, about 7 MB.** `791:6917` is a hundred
  stickers; `DesignSystem/HisploraSticker.swift` packages the eighteen the two pages place
  (`sticker-N-NN.png`, keeping the section's own numbering) plus `HisploraTripArtwork`'s plate,
  portrait, torn scrap, pen rule, arrow, emblem and two medallion frames.
  `HisploraStickerTests` pins the count so the set cannot drift silently. Two extraction notes: a
  Figma **node export is not the layer** — `791:6577`'s torn scrap exports with the section's cream
  baked in and prints as a rectangle across the painting, so the layer's raw image is what ships —
  and the medallion windows are the frames' own insets, with the stamp set into them and the gilt
  frame drawn over.
- **The Journal's opening was clipped and is not any more.** The envelope's last two beats put the
  page two thirds of a card above itself and then grew it 2.1×, all inside a `ScrollView` that
  clips — so the top of the page was cut off mid-zoom. The opening is now drawn as a sibling of the
  scroll view rather than inside it, and the centred card steps aside while it plays. Two smaller
  fixes with it: each beat animates on its own curve and its own length
  (`HisploraEnvelopeSequence.animation(of:)`) instead of one 900 ms ease for all four, and the page
  fades in over 200 ms rather than cross-fading across its whole travel, so it reads as coming out
  of the pocket rather than appearing in front of the envelope.
- **The proximity notification is a teaser now, and it opens a card and a page rather than the
  sidequest flow.** `670:1826`, `670:1832`, `1108:2636`, `1108:2780` and `949:2461` landed
  2026-08-23 as one journey: watch notification → tap → `NewDiscoveryPopup` over Home → "Read Story"
  → `SideQuestDiscoveryScreen`. Six things about it:
  - **`SideQuestRouter` carries two fields, not one.** `pendingSideQuestID` is a deliberate tap in
    the nearby list and still opens `SideQuestFlowView` — notice, story, challenge — unchanged.
    `discoveredSideQuestID` is a proximity event (a notification tap, or a region firing with the
    app open) and opens the card. Folding them back together turns one journey silently into the
    other.
  - **The notification's title and body are fixed teaser copy** (`discoveryNotificationTitle`/`Body`),
    and the sidequest's synopsis rides in `userInfo["synopsis"]` for the watch's long look to print.
    Still no coordinates in the payload (`FR-PROX-15`).
  - **The page is drawn, not composed**, on `TripFrame`/`TripFrameBand`/`TripFramePage` — the same
    machinery and the same trade as `TripHistoryScreen`, Dynamic Type included. Its prose is
    `SideQuestDiscoveryText`, keyed by **sidequest** id, with `sq-park23` the one entry; anything
    else falls back to `SideQuestDiscoveryLore`, which prints that sidequest's own lore with the
    accuracy labels and citations. Same shape and same debt as `QuestHistoryText`.
  - **The drawn page's nine sentences are unsourced and its two photographs have no provenance.**
    Same footing as the History page, recorded in `docs/hisplora-tokens.md`, and a pre-public
    blocker.
  - **`670:1832` reverses `s14` D1/D2 for the long look.** The radar disc is gone; the notification
    now wears `91:182`'s gold frame, whose nine measured fractions moved to `OrnateFramedSlot` so
    the two watch surfaces share the drawing and nothing else. **It has not been seen** — a
    standalone watch simulator cannot present it, because the watch app never requests notification
    authorization (on a real pair the notification is forwarded from the phone).
  - **Developer tools gained "Simulate passing a place (in-app card)".** The original button forces
    the OS notification and therefore can never reach the card, which only appears when the app is
    foregrounded. The new one raises `onSideQuestNearby` directly. Both `#if DEBUG`, both skip
    `ProximityGate`.
- **A walker's name from Sign in with Apple is kept before the network, not after it, and it is
  the whole name.** Both changed 2026-08-24. Apple issues a name exactly once per Apple ID per app;
  `AuthViewModel.signInWithApple` used to write it only on a successful `CredentialOutcome`, so any
  failure downstream discarded the only copy that would ever exist and left the Explorer's Card
  reading "Explorer" for good. It now writes `store.explorerDisplayName` before the call and lets
  the credential decide only whether the *entry* completes. Three notes:
  - **The card carries given + family**, where it used to head its reader by the given name alone.
    `AuthViewModel.wholeName` is the join, `CredentialLinking` writes the same string to
    `display_name` as to `full_name`, and `storedDisplayName()` reads `full_name` → `name` →
    the two parts → `display_name` rather than `display_name` only — an account whose metadata
    Supabase populated from the identity token answered nil under the old single-key read.
  - **The failure that made this visible was configuration, not code.** The Apple provider's
    `client_id` must equal the app's `PRODUCT_BUNDLE_IDENTIFIER`; a mismatch makes
    `signInWithIdToken` fail, which reaches the app as `.failed` and nothing else.
    `supabase/config.toml` holding the right value is not enough — it is applied by
    `supabase config push`, and until that runs the deployed project keeps the old one.
  - **A build with no `Backend.plist` answers `.failed` for every Apple sign-in**
    (`NoCredentialLinking`), which is a normal working app and not a defect — but it is
    indistinguishable on screen from the mismatch above. `Library/Application Support/supabase-trace.log`
    is where the two separate.
- **The three entry screens ship, and there is still no account behind them.** `791:5145`
  (Sign Up), `791:5109` (Sign In) and `822:2235` (Guest) landed 2026-08-21 as `Features/Auth/`,
  replacing `AuthWireframeView`. Six things about them:
  - **What a walker types builds a local profile and nothing else.** No credential is stored,
    transmitted or checked — the email and password are validated for *shape* and discarded. What
    survives is `AppPreferencesStore.explorerDisplayName`, which is the promise `822:2249` makes
    ("This name will appear on your Explorer's Card and journal") kept locally.
    `ExplorerCardViewModel` reads it and falls back to naming the reader by role, which is what the
    card did before the field existed. `AD-3` is intact: nothing here touches the network.
  - **Apple and Google are drawn and disabled**, and a line under them says so. A control labelled
    "Continue with Apple" that does not call `AuthenticationServices` is a false claim, and a false
    Sign in with Apple is one App Review declines besides. They are deliberately *not* faded —
    `HisploraProviderButtonStyle` takes `dimsWhenDisabled:` and both pass `false`, because fading
    composites near-black into cream and the measured pairs stop describing what is on screen.
  - **`google-mark.png` is a pre-public blocker, not a settled asset.** Google's brand terms allow
    the "G" on a real Google Sign-In control and nowhere else. It sits beside the
    `docs/consent-log.md` blockers, and `docs/hisplora-tokens.md` has it written down.
  - **Two new tokens, one of them a deviation.** `brownSeal` `#6E2D26` (the masthead, the primary
    pill, the closing line's link) and `fieldRing` `#8F8B88` — **moved** from the drawn `#918D8A`,
    which measures 2.97:1 on `paperSheet` against the 3:1 a control's boundary wants. Placeholders
    are `inkMuted` rather than the ring, which as text would be 2.97:1 as well. One new type role,
    `authDisplay` — New York **Bold** at 34, the one bold display role in the table.
  - **Sign Up and Sign In are one screen in two configurations.** The frames are one page drawn
    twice; two views would be two places to fix the next layout change in.
  - **The entry is persisted where the wireframe was not.** `accountEntryCompletedAt` is a stored
    date read by `AccountEntryGate`, so a walker is asked once; `removeAll` clears it with the name
    (`FR-SET-02`), which is the only way back to these screens short of a reinstall. The **splash
    is still a wireframe** and still `@State`, for the reason it always was.
- **The story flow is narrated, in English only, and nothing plays unasked.** As of
  `contentBundleVersion` **2026.09.13** each of the five checkpoints carries an English reading of
  its own `loreSegment` — `Checkpoint.narration`, `assets/quests/badung-empat-wajah/narration/cp{1…5}-en.mp3`,
  1.9 MB for the set — and `StoryRevealScreen` draws a play/pause circle with a progress ring in the
  footer's empty corner opposite Next. Seven things about it:
  - **The field is on `Checkpoint`, not on `Place`.** The recording reads *this quest's* passage at
    that stop, not a fact about the site; two quests visiting one place would narrate different
    words. Same division `loreSegment` already draws against `Place.loreStandalone`, and the reason
    `narration.sourceRef` indexes the owning **Place's** `sources` — so does every
    `LoreBlock.sourceRefs` in a `loreSegment`.
  - **It is keyed by language with no fallback, and the gap is guarded rather than assumed.** Only
    the English readings exist; an Indonesian walker gets the passage on the page and no control at
    all. Playing an English narrator over Indonesian prose is the exact failure `LocalizedText`'s
    missing fallback exists to prevent (`NFR-I18N-03`), arriving through a different door.
    `BundledNarrationTests.noCheckpointShipsAnIndonesianReading` is the inverted guard; recording the
    Indonesian set is what turns it red.
  - **The voice is synthesised and each Place says so.** A fifth (or fourth) `sources` entry per
    place begins `BELUM DIVERIFIKASI` and names the text-to-speech, the same habit every generated
    illustration here follows. The Story Reveal does not print it — that screen's `FR-CP-05`
    deviation covers the whole page — so content review is where it is read.
    `theShippedNarrationCitesTheSyntheticVoiceOnEachPlace` keeps audio and citation from parting.
  - **The reading starts when the passage starts, and that is why there are two audio-session
    categories.** `StoryRevealScreen` calls `NarrationPlayer.autoplay()` when `reveal` first reaches
    `.passage` — keyed on the reveal rather than on `onAppear`, so the voice tracks the words on the
    one surface that types a lead sentence first. That makes the reading unrequested, so it is
    started under **`.ambient`**, which the ring/silent switch silences: two of the five places are
    `isSacred`, and a walker who muted their phone at a temple gate has already said what they want.
    A reading the walker *taps* runs under **`.playback`** with `.duckOthers`, which ignores the
    switch, because a play button that honours it reads as broken. The category is set per call, so
    an autoplayed reading the walker pauses and restarts changes hands correctly.
    **Under VoiceOver nothing starts by itself** — a narrator over a screen reader is two voices at
    once — and the control is still there to be tapped.
    `autoplay()` is one shot per recording (a walker who pauses has said something) and tolerates
    arriving before `load(_:)`, which it can: SwiftUI does not order a body's `onAppear` against a
    child's `task`, and dropping the intent there would make the narration work on most launches
    rather than all of them. Seen autoplaying at Museum Bali on iPhone 17 Pro / iOS 26.5 —
    `docs/screenshots/m17-story-narration-autoplay.png`.
  - **`Checkpoint.narration` wears a `LocalizedText`'s shape without being one**, and V1 names the
    exception rather than being loosened: `{"en": {"asset": …}}` is keys drawn from `id`/`en`
    carrying non-strings, which is precisely the defect V1 catches everywhere else.
    `ContentValidator.languageKeyedNonTranslationFields` is the one-element set, and
    `NarrationValidationTests` proves the rule still bites on any other field. `ContentLanguage` is
    `CodingKeyRepresentable` for the same field, or the dictionary would encode as a flat array.
  - **An unknown language key fails the decode; the validator never sees it.** Content shipping
    `"jv"` has claimed a language this build cannot render, and swallowing the key would hide it
    behind a screen that quietly draws no control. What the validator does check is V14 (the file is
    there), V3 (the citation resolves) and a recording in a language outside `Quest.languages` —
    a file no state of the app could ever play.
  - **`NarrationPlayer` is a tenth file under `Services/` and nothing above it knows it exists.**
    `AVAudioPlayer` over a bundled file URL, never `AVPlayer` over something streamable (`AD-3`); a
    file that will not decode lands on `.unavailable`, which draws no control and interrupts
    nothing. The screen owns it as `@State`, so leaving the page stops the reading without anything
    having to remember to. Seen on iPhone 17 Pro / iOS 26.5 —
    `docs/screenshots/m17-story-narration-playing.png`.
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
- `Packages/Kultara/Sources/UIStringsKit/UIStrings.swift:557` still describes the content as "data contoh dengan tempat fiktif".
  That string is now wrong and needs a product decision, not a content edit.
- **`FR-CP-05` has an undocumented exception, and it is still open.** The Story Reveal pages render lore without the accuracy chip or citation. That was a deliberate product decision (`m8-qa-fixes.plan.md`, Decisions taken, item 2) and is recorded in code comments and `docs/hisplora-tokens.md` — but **not yet in the PRD**, which lists it as outstanding with no owner named (§10). It needs an amendment or a signed exception with an owner. `FR-START-04`'s comparable exception *was* signed on 2026-08-16 (owner af); this one was not, and the two are not a package.
- **The redesigned onboarding has been seen on iPhone 17 / iOS 26.5**, all three screens, from a
  fresh install — `docs/screenshots/m12-onboarding-*.png`. Reaching it needs
  `xcrun simctl uninstall com.umar.hisplora`, not a relaunch: `OnboardingGate` reads
  `onboardingCompletedAt`, which survives one.
- The story flow has been seen rendering on iPhone 17 / iOS 26.5: story preview, both cutscenes, story reveal, place notice, and — on 2026-08-17 — the task list, the task sheet and the site plan (screenshots in `docs/screenshots/m9-*.png`). The "Simulate arrival anywhere" toggle does not respond to synthesized taps from the simulator MCP; drive arrival with `xcrun simctl location <udid> set -8.6595,115.2077` instead — the start checkpoint of `badung-empat-wajah` (Puri Agung Pemecutan — an unverified seed coordinate), with `ArrivalEvaluator` unmodified. **A resumed walk lands on `.atCheckpoint` and skips every story stage**, so reaching them from a desk needs a fresh install (`xcrun simctl uninstall com.umar.hisplora`), not a relaunch. The transition screen is still unseen.
