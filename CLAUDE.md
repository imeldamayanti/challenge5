# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A native iOS app (SwiftUI, iOS 18.0) for story-led cultural heritage walking quests in Bali. Users walk a fixed-order route of physical checkpoints, unlock narrative lore at each one, and finish with a shareable recap.

Milestone 5 (Discovery & Preview) is implemented. The quest execution loop, completion, share, telemetry, and proximity alerts are not yet built.

## Directory layout

The repo root and the Xcode project directory share a name, which is confusing:

```
/                              repo root — specs, research artifacts
├── docs/                      system-design.md, schema.md, screenshots/
├── .claude/prds/              product requirements (the spec)
├── .claude/plans/             implementation plans, including executed verification results
└── challange-5/               Xcode project directory
    ├── challange-5.xcodeproj
    ├── challange-5/           app target — a shell, ~30 lines
    ├── challange-5UITests/    XCUITest, the only tests needing a simulator
    └── Packages/Kultara/      local SPM package — all real code lives here
```

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

Exits 0 when rules V1–V17 pass, 1 on any finding, 2 on bad arguments. Point it at an authored content tree (the directory holding `manifest.json`, `places/`, `quests/`, `assets/`, `consent/`).

UI tests and app build — run from `challange-5/`:

```bash
xcodebuild test -project challange-5.xcodeproj -scheme challange-5 \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Check `xcrun simctl list devices available` before assuming a device name — the installed set here is iPhone 17 / 17 Pro / 17 Pro Max / 17e / 16e, with no iPhone 16.

Schemes: `challange-5` (app + UI tests), plus `ContentKit`, `DesignSystem`, `AppFeatures`, `content-validator` from the package.

## The specs are authoritative

`.claude/prds/cultural-heritage-quest.full.prd.md` is the requirements document. `docs/system-design.md` and `docs/schema.md` are the design. Read the relevant section before changing behavior — these documents contain decisions with stated reasons, and several requirements look like arbitrary constraints until you read why they exist.

Requirement IDs are the working vocabulary and are cited in code comments and test names:

| Prefix | Meaning |
|---|---|
| `FR-*` | functional requirement |
| `NFR-*` | non-functional requirement |
| `AD-1…5` | architectural decisions |
| `V1…V17` | content validation rules (`schema.md` §A.9) |

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

`ContentKit` (Foundation only) → `DesignSystem` → `AppFeatures` (SwiftUI) → app target shell.

`ContentKit` must not import SwiftUI, UIKit, CoreLocation, MapKit, or AppKit. Target linkage enforces this in the app build, but on macOS all those modules exist in the SDK and an import would compile fine — so `ImportBoundaryTests` scans the source tree and is what actually holds the boundary.

## Invariants held by tests, not by review

These are the places where a reasonable-looking change silently breaks a guarantee:

- **`LocalizedText` has no language fallback.** A missing `id` or `en` translation is a decode failure, never a runtime degradation into a mixed-language lore passage (`NFR-I18N-03`).
- **Validator rules live in `ContentKit`**, shared by the CLI and the runtime loader, so the two cannot disagree about what valid content is. Adding a rule means adding it in one place and adding a test that proves violating content is *rejected* — a test that only confirms valid content passes proves nothing.
- **Contrast is measured, not reviewed.** `DesignSystem/Contrast.swift` plus `KultaraThemeTests` assert every theme pair against WCAG ratios (`NFR-A11Y-03`). The aged-paper visual direction fails contrast easily; the theme yields, not the threshold.
- **`mapPoint` is authored, not derived from `coordinate`.** The region map is a hand-drawn illustration with a stylised coastline; projecting real coordinates onto it puts every pin somewhere wrong while looking precise. The validator checks range, not geography.
- **Tasks never gate progression.** `blocksProgression` must be `false` for all content (`AD-2`, rule V8). Photos are keepsakes; the GPS radius is the gate.

## Content

Authored JSON under `Packages/Kultara/Sources/ContentKit/Content/`. `consent/` is excluded from the package resources — it is a build input the validator reads, and shipping named individuals' details in every user's app would serve no purpose the build-time check does not already serve.

Lore is an array of labelled `LoreBlock`s, not prose. Each block carries `accuracy` (`documented` | `oral`) and source references, because `FR-CP-05` requires the epistemic status of each claim to be visible. There is no field for an unlabelled sentence — a writer structurally cannot produce one.

Any change to any content file must bump `contentBundleVersion` in `manifest.json`.

## Known state

- Deployment target is iOS 18.0, but the only simulator runtime on this machine is iOS 26.5. Layout is verified on 26.5; the 18.0 floor itself has never been run. Do not claim otherwise.
- The app target builds with `SWIFT_VERSION = 5.0` while the package is `swift-tools-version: 6.0`. The package targets are in Swift 6 language mode; the app shell is not.
- `.claude/plans/cultural-heritage-quest.plan.md` (Milestone 1, content model) is superseded by `docs/schema.md`.
- The app has no name. "Kultara" appears throughout the code as a working title, but Kultara is a community storyteller organization in Sanur that the team interviewed — a research partner, not a brand. This needs resolving before any release.
