# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native iOS app (SwiftUI, iOS 18.0) for story-led cultural heritage walking quests in Bali. Users walk a fixed-order route of physical checkpoints, unlock narrative lore at each one, and finish with a shareable recap.

Milestone 5 (Discovery & Preview) is implemented, and Milestone 6 ships the quest run as a vertical slice: start, arrival at each checkpoint, lore, written tasks, clue, completion, and a summary rendered from the Run's own snapshots. Photo tasks, the share card, the recall survey, telemetry, proximity alerts, and the kill-switch are not built. See `.claude/plans/m6-quest-run-vertical-slice.plan.md`.

Milestone 8 (`.claude/plans/m8-qa-fixes.plan.md`) then did two things: fixed six QA findings, and put the run flow on a second visual direction ("Hisplora") taken from Figma. Both are shipped. `.claude/plans/m7-restore-test-guards.plan.md` — restoring the 112 tests commit `b597b5b` deleted — is planned and **not** done.

## Directory layout

The repo root and the Xcode project directory share a name, which is confusing:

```
/                              repo root — CLAUDE.md and .gitignore only
├── docs/                      system-design.md, schema.md, hisplora-tokens.md,
│                              backend-supabase.md (design only — nothing built)
│   ├── screenshots/           captured UI verification screenshots
│   └── research/              field research artifacts — interview summary,
│                              affinity diagram, tourist-findings and
│                              top-insights photos, the team research deck
├── .claude/prds/              product requirements (the spec)
├── .claude/plans/             implementation plans, including executed verification results
└── challange-5/               Xcode project directory
    ├── challange-5.xcodeproj
    ├── challange-5/           app target — Model/ ViewModel/ View/ Service/ Support/
    ├── challange-5UITests/    XCUITest, the only tests needing a simulator
    └── Packages/Kultara/      local SPM package — ContentKit, RunEngine,
                               DesignSystem, content-validator
```

**The app target has no unit-test target** — `challange-5UITests` is XCUITest only. So a guard for
anything in `ViewModel/` or `View/` has nowhere to live as written. The way through is to push the
rule being guarded down into a package target as a pure value and test it there: the arrival
countdown became `RunEngine.ManualOverrideSchedule`, the map-marker tap threshold became
`DesignSystem.MapMarkerGesture`, the route maths became `RunEngine.RouteProjection`. That is a better
shape anyway, but it is a constraint rather than a preference — do not assume you can write a
view-model test.

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

## Invariants no longer held by anything

The presentation layer has **zero automated tests**. `AppFeaturesTests` (~1,400 lines, 112 tests) was deleted by `b597b5b` when `AppFeatures` stopped being a package target, and the app target has no unit-test bundle to receive it. The suites are recoverable from git history at `b597b5b^`, and restoring them is what `.claude/plans/m7-restore-test-guards.plan.md` is for — that plan is **not** done.

Treat these as review-only until a unit-test target exists — they read as guaranteed but are not:

- **UI string ID/EN parity** (`NFR-I18N-01/02`). `everyKeyHasAnEntry`, `everyEntryIsTranslatedInBothLanguages` and `indonesianAndEnglishAreActuallyDifferentText` are gone. Adding a `UIStringKey` case without a `UIStrings.table` entry now fails silently at runtime — `UIStrings.string` returns the raw key name, and its own comment still cites the test that would have caught it. The `LocalizedText` no-fallback rule still protects *content*, not the interface.
- **`FR-START-08` at the view-model level.** `aFixOutsideTheStartRadiusStartsNothing` and `aVagueFixOnTopOfTheGateStartsNothingEither` are gone. `RunEngineTests` still covers `ArrivalEvaluator` itself, so the rule is tested — the wiring through `QuestRunViewModel` is not.
- **`FR-ONB-02/04`** — skip available from the first screen, and the Settings authorization reporter being structurally unable to request permission.
- **The summary model takes no `ContentRepository`.** `RunSummaryViewModel` renders from snapshots alone, which is how `FR-DONE-04/05` and `FR-RUN-06` are guaranteed rather than intended. Handing it a repository would make a withdrawn Place able to blank a walk somebody finished. Now enforced only by the initializer's signature.
- **A screen's view model belongs in `@State`.** Building one inside a `body` rebuilds it on every redraw, which orphans anything in flight — see `View/Component/ScreenHost.swift`. This presented as an arrival screen that never found a fix.

## Two visual directions, split at a screen boundary

The museum-catalogue theme (`KultaraPalette`, light/dark) carries the quest list, region map, preview, checkpoint, summary and settings. The Hisplora direction (`HisploraPalette`, a fixed brown/cream editorial pairing that does **not** flip with the system appearance) carries the run's story flow: story preview → location states → cutscene → story reveal → transition.

Two rules keep that from rotting:

- **The seam falls between screens, never inside one.** A half-restyled screen is not survivable; a boundary between two whole screens is. `QuestRunView.isOnStoryFlow` is the switch, and it also hides the museum navigation bar on those stages.
- **Museum-inked components must not be dropped onto a Hisplora ground.** They are measured against paper. `RunRouteMapView` takes `showsChrome:` for exactly this reason — its heading is `palette.seal`, which falls to about 2:1 on brown. This shipped as a real contrast bug before it was caught on device.

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
- The app target and the package are both Swift 6 language mode. The app target was Swift 5.0 until the presentation layer moved in — `DeveloperSwitchableLocationProvider`'s `#if DEBUG` default argument depends on SE-0411 isolated default value expressions and does not compile under Swift 5. `challange-5UITests` is still `SWIFT_VERSION = 5.0`.
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on for the app target, so a type used from `RunEngine` or `DesignSystem` needs that module imported in the file that uses it — a transitive import will not do.
- `.claude/plans/cultural-heritage-quest.plan.md` (Milestone 1, content model) is superseded by `docs/schema.md`.
- `.claude/launch.json` is stale scaffolding pointing at another user's Downloads folder. It has nothing to do with this project.
- The app has no name. "Kultara" appears throughout the code as a working title, but Kultara is a community storyteller organization in Sanur that the team interviewed — a research partner, not a brand. "Hisplora" is the Figma file's name and is used for the visual direction only, not as a product name. This needs resolving before any release.
- **The shipped content is one authored quest over five real places, and it is partly unverified.**
  `badung-empat-wajah` ("Empat Wajah Kota Badung" / "The Four Faces of Badung") walks Puri Agung
  Pemecutan → Pura Maospahit → Pasar Kumbasari → Catur Muka → Museum Bali. The `contoh-*`
  placeholders are gone. What is real: Museum Bali's address and hours, Pura Maospahit's address and
  architecture, Pasar Kumbasari's address, four-storey layout, 1977 founding and market rules, and
  Catur Muka's position relative to the catus patha — each with an openable citation. What is **not**
  verified and must not be read as fact: **every coordinate** (seed values, unwalked), the route
  distance and duration (estimated, though V11 forces the JSON to claim `walking-directions`),
  opening hours at four of five places, all dress codes and photo policies, all entry costs
  (Museum Bali sells a ticket and ships as `0`), and step counts at four of five places. Unverified
  claims carry a `sources` entry whose citation begins `BELUM DIVERIFIKASI`. The full ledger is
  `.claude/plans/Content/c1-badung-single-quest-content.plan.md` §11.0.
- **Consent for those five places is a self-grant, not a grant.** D1-b: every `consent/badung-*.json`
  names the project team as `grantingBody`, scoped to inclusion and naming, for a non-public academic
  prototype. None of the five sites has been approached. The signatory fields are still literal
  placeholders (`[NAMA TIM]`, `[NAMA ANGGOTA 1]`, …). Tracking lives in `docs/consent-log.md` and
  `docs/consent/*-prototype-note.md`. This must not survive into anything public.
- The Figma frames name a real quest (I Gusti Ngurah Made Agung, Puri Agung Pemecutan, the Puputan)
  that still does not exist in the content tree and still cannot be authored without consent records
  and citations. Screens render from `ContentKit` by ID; never bake those names in (`AD-4`,
  `FR-RUN-06`).
- `Support/UIStrings.swift:338` still describes the content as "data contoh dengan tempat fiktif".
  That string is now wrong and needs a product decision, not a content edit.
- **`FR-CP-05` has an undocumented exception.** The Story Reveal pages render lore without the accuracy chip or citation. That was a deliberate product decision (`m8-qa-fixes.plan.md`, Decisions taken, item 2) and is recorded in code comments and `docs/hisplora-tokens.md` — but **not yet in the PRD**. It needs an amendment or a signed exception with an owner.
- The story flow has been seen rendering on iPhone 17 / iOS 26.5 (story preview, both cutscenes, story reveal). The "Simulate arrival anywhere" toggle does not respond to synthesized taps from the simulator MCP; drive arrival with `xcrun simctl location <udid> set -8.6595,115.2077` instead — the start checkpoint of `badung-empat-wajah` (Puri Agung Pemecutan — an unverified seed coordinate), with `ArrivalEvaluator` unmodified. The transition screen is still unseen.
