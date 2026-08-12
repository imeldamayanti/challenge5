# Milestone 5 — Discovery & Preview

**Milestone:** 5 of `.claude/prds/cultural-heritage-quest.prd.md` — *"A user anywhere in the world can browse both quests and see route, duration, cost, terrain, and timing."*
**Requirement sources:** `.claude/prds/cultural-heritage-quest.full.prd.md`, `docs/system-design.md`, `docs/schema.md`. Requirement IDs are cited per task; this plan does not restate the requirements.
**Method:** TDD per task — failing test first, then implementation, then commit.

---

## Stage 1 — Decisions

### Decision 1 — `IPHONEOS_DEPLOYMENT_TARGET`: 26.5 → **18.0**

**Confirmed, with the recommended value.**

The template default of 26.5 restricts the app to devices running the newest OS. For an app whose primary user is a tourist standing in Denpasar with whatever phone they already own, that is not a reach trade-off — it is a near-total loss of audience. Lowered.

18.0 rather than a lower floor, for three reasons:

1. **SwiftData is the persistence decision in `schema.md` Part B.** SwiftData requires iOS 17+. Any floor below 17 forces the schema onto Core Data and invalidates Part B. `system-design.md` §13 also warns off early SwiftData explicitly: *"Consider iOS 17.4+ as the floor rather than 17.0 — early SwiftData releases had migration rough edges."* 18.0 clears that warning without argument.
2. **The hardware cost of 18.0 over 17.0 is one generation.** iOS 18 runs on iPhone XR / XS (2018) and later. Dropping to 17.0 would add only iPhone X / 8 / 8 Plus (2017). That is a thin gain paid for with a persistence layer the design docs recommend against.
3. **Swift 6 language mode, `@Observable`, and strict concurrency** (`system-design.md` §9) are the assumed baseline throughout the design. They are cleanest at 18.0.

This resolves `NFR-PLAT-01`, which the PRD carries as **TBD**. Recorded as resolved rather than left open.

Also fixed in the same edit, since the template is wrong about them too:
- `TARGETED_DEVICE_FAMILY` `1,2` → `1` (iPhone only, `NFR-PLAT-02`).
- iPhone orientation list → portrait only (`NFR-PLAT-02`).

**Known verification limitation, stated up front:** the only iOS runtime installed on this machine is 26.5 (`xcodebuild -showsdks`: iOS 26.5 / Simulator iOS 26.5). Screenshots and Dynamic Type passes in Stage 4 therefore run on an **iOS 26.5 simulator**, with the app built against a deployment target of 18.0. Layout is verified; the 18.0 floor itself is not, because no iOS 18 runtime exists here to verify it on. Not claimed as tested.

### Decision 2 — Module structure: **local SPM package**, not folder groups in one target

`Packages/Kultara/`, referenced by the app target as a local package.

The deciding factor is that this milestone's hardest constraint is an *import* constraint: `ContentKit` must not import SwiftUI, UIKit, or CoreLocation. A folder group inside the app target cannot enforce that — the app target links all three, so any file in it can import them, and the constraint survives only as long as someone remembers it. A separate SPM target that does not link those frameworks turns the constraint into a compile error. That is the difference between a rule and a comment.

Three further reasons:

1. **Test cost.** `ContentKit` and `DesignSystem` tests run under `swift test` on macOS in seconds, with no simulator boot. The validator (16 rules × ≥1 test) and `LocalizedText` are exactly the suites that must stay cheap enough to run on every edit. Inside an app target they would require a simulator per run.
2. **The CLI validator needs a non-app executable target anyway.** SPM gives it one that shares a single rule implementation with the runtime validator — one rule set, two entry points, no drift. Bolting a command-line tool onto an app-only Xcode project means a second target with duplicated sources or a fragile shared-file arrangement.
3. **The v3 seam.** `system-design.md` §15 makes `CachedRemoteContentRepository` a drop-in swap behind `ContentRepository`. A package boundary is where that swap is enforced; a folder group is where it leaks.

Cost: one manual `project.pbxproj` edit to add the local package reference. Paid once, in T01.

**Package layout:**

| Target | Kind | Links | Notes |
|---|---|---|---|
| `ContentKit` | library | Foundation only | Models, `ContentRepository`, `BundledContentRepository`, loader, validation rules. Fixture content as a resource. |
| `DesignSystem` | library | SwiftUI | Contrast-measured tokens, type scale, accuracy-label chip. Contrast math is pure and testable without SwiftUI. |
| `AppFeatures` | library | SwiftUI, ContentKit, DesignSystem | Onboarding, quest list, preview, settings — views + `@Observable` view models. No UIKit, no CoreLocation. |
| `content-validator` | executable | ContentKit | CLI. Exit code ≠ 0 on any violation. |
| `ContentKitTests`, `DesignSystemTests`, `AppFeaturesTests` | test | — | Swift Testing. |

The app target (`challange-5`) becomes a shell: `@main`, root view from `AppFeatures`, nothing else.

---

## Stage 2 — Scope

### In scope
`FR-ONB-01…06` · `FR-DISC-01…08` · `FR-MAP-01` (preview only) · `FR-SET-01…04`
`NFR-A11Y-01/03/05/06` · `NFR-I18N-01/02/03/04` · `NFR-MAINT-01/02` · `NFR-PLAT-01/02/03/04` · `NFR-CONT-01/02/05/06` · `NFR-GOV-01/02/07` (validator-enforced) · `AD-2`, `AD-3`, `FR-TASK-05/06` and `FR-PROX-11` (validator-enforced only — no runtime feature)

### Out of scope — not touched
Run, arrival, task execution, summary, share, telemetry, proximity alert runtime, kill-switch fetch.

### Two scope edges, resolved explicitly

- **`FR-DISC-08` (suppressed quests hidden) vs. "kill-switch out of scope".** Split at the network boundary. The repository takes a set of suppressed IDs and filters the list — that is the discovery-side behavior `FR-DISC-08` asks for, and it is tested. The *fetch* (`GovernanceKit`, `suppressions.json`, TLS, schema validation, caching) is not built, and the in-progress-Run half of `FR-DISC-08` is not built because Runs do not exist yet. In M5 the suppressed set is always empty at runtime.
- **`FR-SET-02` (delete all local data).** Partially deferred, and it will say so in the UI copy review, not silently. There are no Runs, photos, reflections, awards, or queued telemetry in M5 — nothing exists to delete but preferences. The control is built against a `LocalDataEraser` protocol with a preferences-only implementation; the Run/photo/telemetry implementation lands with M6. Flagged in Stage 5 as an incomplete requirement.

### Deviation from `schema.md` B.9, with reason

`AppStateRecord` is specified as a SwiftData `@Model`. M5 persists only `preferredLanguageRaw` and `onboardingCompletedAt`, and has no other SwiftData entity. Standing up a `ModelContainer` now would write a schema version to disk containing a single singleton row, forcing a migration in M6 when `RunRecord` and its children arrive. M5 therefore persists app state in `UserDefaults` behind an `AppPreferencesStore` protocol, and M6 moves it into `AppStateRecord` behind the same protocol when the store is created for the first time with its real schema.

### Constraints that must not be violated
1. `ContentKit` imports no SwiftUI, UIKit, or CoreLocation — enforced by target linkage **and** by a source-scanning test.
2. No object reference from user data to a content entity — string IDs only.
3. No reachability check anywhere.
4. Every user-facing string goes through `LocalizedText`; no language fallback.

---

## Stage 3 — Tasks

Each task: failing test → implementation → passing test → commit. `[req]` column is the requirement the task discharges.

### Phase 0 — Foundation

| # | Task | Requirements |
|---|---|---|
| T01 | `project.pbxproj`: `IPHONEOS_DEPLOYMENT_TARGET` 26.5 → 18.0 (both configs), `TARGETED_DEVICE_FAMILY` → `1`, iPhone orientations → portrait only. Create `Packages/Kultara` with all six targets as empty shells; add local package reference + product dependency to the app target. Gate: `swift build` and `xcodebuild -destination 'generic/platform=iOS Simulator' build` both succeed. | Decision 1, Decision 2, NFR-PLAT-01/02 |
| T02 | Import-boundary test: scan every `ContentKit` source file, fail on `import SwiftUI` / `UIKit` / `CoreLocation` / `MapKit`. Written before any ContentKit source exists, and proven to fail by temporarily adding a forbidden import. | Constraint 1, system-design §3 |

### Phase 1 — ContentKit

| # | Task | Requirements |
|---|---|---|
| T03 | `ContentLanguage`, `LocalizedText`. Tests: decodes with both languages; **throws** when `id` missing, `en` missing, `id` empty, `en` empty, or either whitespace-only; `value(for:)` returns exactly the requested language and never substitutes. | NFR-I18N-02, NFR-I18N-03, schema A.2 |
| T04 | Enum types from schema Appendix; `Coordinate`, `EntryCost`, `VisitingHours`, `Accessibility`, `Source`, `LoreBlock`, `ContentTask`, `SideQuest`, `Checkpoint`, `Place`, `Quest`, `Manifest`, `ConsentRecord`. Tests: round-trip; unknown enum raw value rejected; `LoreBlock` without `accuracy` rejected. | schema A.3–A.7, NFR-CONT-01 |
| T05 | `ContentRepository` protocol + `BundledContentRepository` over `Bundle.module`. Tests: full quest graph (quest → 5 checkpoints → places → lore → tasks) assembles from the bundle with no network type and no location type anywhere in the call path; repository initialiser takes no location or network collaborator; `quests(suppressing:)` omits suppressed IDs. | FR-DISC-01, FR-OFF-01, FR-DISC-08 (list side), AD-3, NFR-MAINT-01 |
| T06 | `ContentValidator` with rules V1–V16 as individually addressable rules producing `ValidationFinding(rule:path:message:)`. **One test per rule, each constructing content that violates that rule and asserting the finding is produced.** V15 (payload ≤ 200 MB) and V14 (asset paths exist) operate on a directory. | schema A.9 in full — V1↔NFR-I18N-02, V2↔NFR-CONT-02, V3↔NFR-CONT-01, V4↔NFR-GOV-01/03, V5↔NFR-GOV-02/07, V6↔FR-TASK-06, V7↔FR-TASK-05, V8↔AD-2, V9↔FR-CP-01, V10↔FR-CP-02, V11↔NFR-CONT-05, V12↔FR-PROX-11, V13↔FR-ARR-07, V14, V15↔NFR-PERF-07, V16↔FR-DISC-06 |
| T07 | `content-validator` executable: takes a content directory, prints findings as `rule path message`, exits 1 on any finding, 0 on none. Test: run against a violating directory, assert exit 1 and the rule ID in output. | NFR-MAINT-02 |

### Phase 2 — Fixture

| # | Task | Requirements |
|---|---|---|
| T08 | Placeholder content: 1 quest, 5 checkpoints, 5 places, 5 consent records, ID+EN complete on every string, route preview asset, `hardLatestStart` consistent with visiting hours, `proximityRadiusM > arrivalRadiusM`. Enough to drive every M5 screen. Marked unmistakably as placeholder — it has not been field-validated and must not be read as content (`NFR-CONT-03`). Test: validator reports zero findings on it. | NFR-I18N-02, NFR-CONT-02/05/06, NFR-GOV-01/02/07 |

### Phase 3 — DesignSystem

| # | Task | Requirements |
|---|---|---|
| T09 | WCAG relative-luminance + contrast-ratio functions. Tests against known reference pairs (black/white = 21.00, mid-grey pairs) before any token exists. | NFR-A11Y-03 |
| T10 | Aged-paper theme tokens, light and dark. Test: **every** foreground/background pair the theme declares as body text measures ≥ 4.5:1 and every large-text pair ≥ 3:1, in both appearances — the test enumerates the theme rather than a hand-picked list, so a token added later without measuring fails the suite. Written to fail first against the naive sepia-on-sepia palette the "royal letter" direction implies. | NFR-A11Y-03, NFR-PLAT-04 |
| T11 | Type scale mapped onto `Font.TextStyle` (no fixed point sizes), `AccuracyLabel` chip rendering `[Tercatat]`/`[Documented]` and `[Babad/Cerita rakyat]`/`[Oral tradition]` as **text plus shape**, min 44×44 pt tap target constant. Tests: label text resolves per language and differs between accuracy values without reference to colour. | NFR-A11Y-01/05/06, FR-CP-05, schema A.6 |

### Phase 4 — AppFeatures

| # | Task | Requirements |
|---|---|---|
| T12 | `LanguageResolver`: device language `id`/`in` → `.id`, `en` → `.en`, anything else → `.en`; user override from `AppPreferencesStore` wins. Tests per branch. | FR-ONB-05 |
| T13 | `OnboardingViewModel` + views: exactly 4 screens, skip control present on screen index 0, one screen carries the pocket-the-phone model, no location authorisation call and no ATT call anywhere in the module. Tests: screen count ≤ 4; skip available at index 0; source scan asserts no `requestWhenInUseAuthorization` / `ATTrackingManager` in `AppFeatures`. | FR-ONB-01/02/03/04/06 |
| T14 | `QuestListViewModel` + `QuestListView`: per quest — title, region, total distance, walking time, total duration, estimated cost; cost shown on the card whenever `amount > 0`; row navigates to preview in one tap. Tests per field; cost-visible-on-card test with a paid fixture variant. | FR-DISC-02/05/07 |
| T15 | `QuestPreviewViewModel` + `QuestPreviewView`: hook lore, description, ordered checkpoint list with Place official names, route preview image, distance, walking time, total duration, cost with breakdown, terrain/steps summary, recommended start window, safety notice. **Test that the view model exposes no `loreSegment` and no `clueToNext` for any checkpoint** — the negative assertion, not the positive one. | FR-DISC-03/04, FR-MAP-01, NFR-A11Y-07, NFR-I18N-04 |
| T16 | `hardLatestStart` warning: non-blocking, names the closing site and its closing time, shown only when local time is later than `hardLatestStart`. Tests: before / after / exactly at the boundary. | FR-DISC-06 |
| T17 | Route preview renders from the bundled static asset. Source scan test: no `MapKit` import in `AppFeatures`. | FR-MAP-01, FR-OFF-03 |
| T18 | `SettingsViewModel` + `SettingsView`: language picker (persists, re-resolves all strings), location permission status read as text with a link to system Settings and **no authorisation request**, storage used, delete-all-data with confirmation via `LocalDataEraser`, community-source attribution from content, report-an-error path. Tests: language change propagates; permission status is read-only; eraser called only after confirmation. | FR-SET-01/02/03/04, FR-ONB-04, NFR-GOV-05 |
| T19 | App shell: `challange_5App` hosts the `AppFeatures` root, injects `BundledContentRepository` and `UserDefaults`-backed `AppPreferencesStore`, routes first launch to onboarding. Delete `ContentView.swift`. | FR-ONB-01, AD-3 |

### Phase 5 — Verification (Stage 4 below)

| # | Task |
|---|---|
| T20 | Full suite: `swift test` + `xcodebuild test` if an Xcode test target exists. Output pasted verbatim, red or green. |
| T21 | Build, boot simulator, screenshot quest list / quest preview / settings. |
| T22 | Repeat the flow at `UICTContentSizeCategoryAccessibilityXXXL`. Every truncation or overlap reported individually. |
| T23 | Print measured contrast ratios for the final theme — numbers. |
| T24 | `content-validator` on the fixture (expect 0), then on a deliberately corrupted copy (expect non-zero exit and the specific rule IDs). |

---

## Stage 4 — Self-verification gates

1. Whole test suite run, result pasted including failures.
2. Build and run on simulator; three screenshots.
3. Entire flow repeated at the largest Dynamic Type size; every clipped or overlapping label named.
4. Actual contrast ratios reported as numbers per token pair.
5. Validator CLI run on the good fixture and on a broken fixture, both outcomes shown.

Nothing in this milestone is reported complete without its gate having been run.

---

## Stage 5 — Known incomplete on delivery

To be restated in the final report rather than buried here:

- `FR-SET-02` — deletes preferences only; Runs, photos, reflections, awards, telemetry do not exist yet (M6/M7).
- `FR-DISC-08` — list-side filtering only; no kill-switch fetch, no in-Run suppression handling.
- `NFR-A11Y-02` (VoiceOver) — labels are set as encountered, but a full VoiceOver traversal is a release gate on the complete core loop and is not run in M5.
- `NFR-CONT-03` — fixture content is placeholder and field-unvalidated by construction.
- Deployment target 18.0 is not runtime-verified; no iOS 18 simulator runtime is installed on this machine.

---

## Stage 6 — Verification results (executed)

Recorded here rather than only in a chat message, because acceptance criteria 5 and 6 of the PRD
ask for evidence.

### 1. Test suites

```
swift test      → 204 tests in 19 suites, all passing
xcodebuild test → ** TEST SUCCEEDED **, 3 UI tests
                  (iPhone 17 simulator, iOS 26.3 runtime)
```

Nothing red, nothing skipped, no `withKnownIssue`.

### 2. Screenshots — `docs/screenshots/`

`quest-list.png`, `quest-preview.png`, `settings.png`, plus the three `a11y-*` counterparts at
`UICTContentSizeCategoryAccessibilityXXXL`. Captured as XCUITest attachments from the same run
that asserted the flow, so they cannot drift from a passing test.

### 3. Dynamic Type, largest accessibility size

Automated: every `staticText` frame on all three screens is compared to the window bounds; the test
fails and names any label crossing an edge. Result: none on any screen.

By eye, two defects the automated check could not see — both fixed, both with a regression test:

| Defect | Fix |
|---|---|
| Storage row read as the word "Zero" instead of a number | `ByteCountFormatter.allowsNonnumericFormatting = false` |
| Language rows sat flush against their divider — the label outgrows a 44 pt minimum height | vertical padding in addition to `minHeight` |

Remaining observation, not a defect: the preview title wraps mid-word at the largest size
("Example Old-|Town Trail"). It wraps rather than truncates, and the frame stays inside the window.

### 4. Measured contrast on the final theme

Produced by `KultaraThemeTests.reportMeasuredContrastRatios`. Every pair passes.

| | Light | Dark |
|---|---|---|
| Body ink on page / card / inset | 13.22 · 14.54 · 11.43 | 14.52 · 13.03 · 15.53 |
| Secondary ink | 7.57 · 8.32 · 6.54 | 8.54 · 7.66 · 9.13 |
| Seal accent | 8.30 · 9.13 · 7.17 | 8.42 · 7.55 · 9.00 |
| Warning | 6.03 · 6.63 · 5.21 | 9.37 · 8.41 · 10.02 |
| `documented` / `oral` chip ink on chip | 11.43 / 7.39 | 15.53 / 11.35 |
| Text on filled seal button | 9.13 | 6.68 |
| Hairline (needs 3:1) | 3.71 · 4.08 | 4.31 · 3.87 |

Lowest text ratio: **5.21:1** light, **6.68:1** dark. Lowest hairline: **3.71:1** light,
**3.87:1** dark.

The first attempt — the visual direction taken literally — failed 15 of 30 pairs, worst cases
2.76:1 (warning), 2.90:1 (secondary text on a card), 1.50:1 (hairline). The theme was changed, not
the threshold.

### 5. Validator CLI

```
content-validator Sources/ContentKit/Content
  → OK  1 quest(s), 5 place(s), 30805 bytes — all 16 rules pass.     exit 0
```

On deliberately corrupted copies, exit 1 every time. Rules demonstrated firing from the CLI:
**V1, V2, V3, V4, V5, V6, V7, V8, V9, V10, V11, V12, V13, V14, V16** — 15 of 16.

V15 (payload ≤ 200 MB) is covered by unit test only; demonstrating it from the CLI would mean
committing 200 MB of filler.

Worth recording: a V1 translation gap *blocks* the decode-dependent rules rather than merely adding
a finding, and the report says `BLOCKED` rather than reporting a pass. That is the intended
behaviour — V1 and V7 run on raw JSON precisely so a gap is still attributable to a rule — but it
means a run with several faults may need fixing in two passes.

---

## Stage 7 — Home design applied (`Home.svg`)

The design supplied two screens: an illustrated Bali map with quest markers, and a discovery list of
full-bleed photo cards. Both were built. Three things in the design conflicted with P0 requirements
and were resolved in favour of the requirements, not the drawing.

| Design shows | Requirement | Resolution |
|---|---|---|
| No distance, no cost on the card | `FR-DISC-02`, `FR-DISC-05` (cost on the card, not only in preview) | Both kept. The metadata runs to two lines instead of one, and stacks at accessibility sizes rather than dropping a field. |
| One duration, `30 mins` | `NFR-CONT-06` — walking time and total time as separate figures | Two figures, distinct symbols. |
| `5 quests` | Glossary: those are checkpoints; `FR-CP-08` counts progress in them | `5 checkpoints`. A quest containing quests makes both readings ambiguous. |

Each is held by a test, in the unit suite and again in the UI suite against the rendered card.

### Two judgement calls the design implied but the PRD does not specify

- **The fog over parts of the island** implies a progressive-reveal mechanic. Nothing in the PRD
  describes one, and hiding content behind an unspecified mechanic is not a styling decision. Not
  built; every quest's marker is visible. Flagged for the product decision.
- **Photographs of real sites, one showing identifiable people at a ceremony.** Attaching those to
  fictional placeholder Places would tie real imagery to consent records that do not exist, and
  `NFR-GOV-02` treats `scope: imagery` as a separate grant from `inclusion`. The fixture draws its own
  hero art instead. The real photographs remain available for content that has the grant.

### Schema additions, documented in `docs/schema.md`

`Manifest.regionMap`, `Quest.heroImageAsset`, `Place.mapPoint`, and validator rule **V17**.

`mapPoint` is authored rather than projected from `coordinate`, because the map is a drawing — taller
than Bali is, with a stylised coastline — and projecting onto it would place every pin somewhere
wrong while looking precise. V17 checks the range, not the geography, and catches the failure that
would otherwise be silent: a map that quietly drops a stop the list shows.

### Contrast over a photograph

Text on an image has no measurable background, so `NFR-A11Y-03` cannot be satisfied by inspection.
The caption block sits on an opaque scrim and the gradient above it is decoration, which makes the
ratio real again: **inkOnPhoto `#F7F1E4` 16.53:1**, **inkMutedOnPhoto `#CFC2AC` 10.60:1**, both
against the scrim `#17120D`, identical in both appearances — a photograph does not get lighter in
light mode, so the scrim does not flip. Measured by
`KultaraThemeTests.reportMeasuredContrastRatios`, like every other pair. The card's emphasis for a paid quest is weight plus symbol rather than the seal red,
because on a photograph a hue is not a measurable colour and `NFR-A11Y-05` forbids colour carrying
meaning alone.

### Two defects the screenshots caught, and the assertions now holding them

1. **The map opened on empty ocean.** Bali's south coast sits two thirds down a portrait drawing, so
   the scroll origin showed sea and no markers. The UI test had passed, because XCUITest finds and
   taps elements that are scrolled out of view. It now asserts the first marker `isHittable`, not
   merely that it exists.
2. **Marker labels overlapped each other.** Quests in one city sit metres apart, so their labels
   landed in the same strip of map — the `NFR-A11Y-01` overlap failure arriving through placement
   rather than type size. Labels now alternate above and below the pin down the cluster, the map is
   drawn wider, and the test compares every pair of marker frames for intersection.

Known rough edge, not claimed as fixed: the map opens with the cluster in the lower third rather than
centred. Every marker is on screen and hittable; the centring is approximate because `scrollTo`
resolves against a `.position`-ed view's ambiguous layout frame.

---

## Stage 8 — Retheme to the typed page (`image 16.svg`)

A second reference replaced the visual direction: a sheet in a typewriter. Cream stock, one sage
accent, monospaced type, thin rules, headings in tracked caps. It supersedes the aged-paper "royal
letter" palette of Stage 4, and it is a **divergence from the PRD**, which names that direction by
name. Recorded here rather than quietly applied: the palette and the typeface changed, no
requirement did, and every `NFR-A11Y-03` measurement was re-run rather than re-used.

### What was sampled, and what survived

| Sampled from the reference | Shipped | Why the difference |
|---|---|---|
| sheet `#F9F3E5`, card stock `#F1EBDD` | paper `#F7F1E2`, raised `#FCF8EE`, sunken `#EAE2CF` | Three surfaces, because text lands on all three. |
| ink `#362627` | ink `#26231C` | The sampled ink is a red-brown; at body size on cream it reads as faded rather than typed. |
| sage `#8E9574`–`#A8AB8C` | seal `#3D5138` light, `#A9C094` dark | The sage as sampled is 2.4:1 on cream — a painted steel body, not a text or control colour. Same hue, carried to the readable end of each appearance. |

### Measured again, in full

| Pair | Light | Dark |
|---|---|---|
| Body ink on paper / card / inset | 13.91 · 14.78 · 12.15 | 15.52 · 13.71 · 16.41 |
| Secondary ink | 7.15 · 7.60 · 6.25 | 9.04 · 7.99 · 9.56 |
| Sage accent | 7.66 · 8.14 · 6.69 | 9.24 · 8.16 · 9.77 |
| Warning | 6.39 · 6.79 · 5.58 | 9.50 · 8.39 · 10.04 |
| `documented` / `oral` chip ink | 12.15 / 7.18 | 16.41 / 11.67 |
| Text on filled accent button | 8.14 | 9.24 |
| On-photo ink / muted, on scrim `#16170F` | 16.03 / 10.28 | 16.03 / 10.28 |
| Hairline (needs 3:1) | 3.84 · 4.08 | 4.54 · 4.01 |

Lowest text ratio: **5.58:1** light, **7.99:1** dark. Lowest hairline: **3.84:1** light, **4.01:1**
dark. Every pair passes on the first measurement this time, because the accent was chosen against
the surfaces rather than sampled and hoped for.

### Type

Monospaced everywhere except `body` and `lore`, which stay proportional. Monospace sets roughly a
fifth wider per character, and long-form lore is the one place that turns into extra wrapping at the
largest accessibility sizes — the failure `NFR-A11Y-01` exists to prevent. Section headings are set
in tracked caps; quest titles and chip labels are not, because an all-caps title flattens the proper
nouns the content is made of and an all-caps chip risks VoiceOver spelling a short word out.

### The navigation bar, and a bug it caused

SwiftUI's bar was the one surface still using system fonts, so it is styled through the UIKit
appearance proxy, re-applied from `KultaraThemeProvider.body` and therefore following both the
colour scheme and the content size category.

Styling the *large* title there broke the quest list: a monospaced, kerned large title behind a
`.principal` toolbar item laid out to nothing, and the screen's name simply disappeared. The fix is
also the better design — each screen's name is now typed at the top of the page, as on the
reference sheet, and the bar title is inline. `largeTitleTextAttributes` is deliberately unset, with
the reason written where the next person will look.

### Verified

234 package tests and all four XCUITests pass, including the largest-Dynamic-Type flow. Screens
checked by screenshot in both appearances: quest list, quest preview, settings.

---

## Stage 9 — Retheme to the museum catalogue (`image 8.svg`, `image 15.svg`, lofi `IMG_0090`)

A third reference replaced the visual direction again: a museum longread. Uncoated cream stock, one
deep brick red, a display serif for anything that names something, and the platform's sans for
everything a reader reads or operates. Objects are presented as plates — framed, numbered, captioned
in brackets. It supersedes the typed-page palette of Stage 8 and, like it, is a **divergence from the
PRD**, which names the aged-paper "royal letter" direction. Recorded rather than quietly applied: the
palette and both typefaces changed, no requirement did, and every `NFR-A11Y-03` measurement was
re-run rather than re-used.

The lofi wireframe supplied the structure — masthead, plate, entry, then the route and the numbered
stops — and the two reference spreads supplied the treatment.

### Typeface

Instrument Serif (SIL OFL 1.1) ships inside the package, in `DesignSystem/Resources/Fonts`, with its
licence beside it. It is registered at runtime by `KultaraFonts` through
`CTFontManagerRegisterGraphicsFont` rather than declared in the app target's `Info.plist`, because
`DesignSystem` is a package and a host target that forgets the `UIAppFonts` entry would get a silent
fallback to the system serif. `KultaraFontTests` asserts the face actually registers, so a mis-copied
resource fails the suite instead of shipping as a subtly wrong app.

The serif carries `questTitleLarge`, `questTitle` and `sectionHeading` — the roles that name
something — and section names are set in its italic, as on the reference. Everything else is SF Pro.
`body` and `lore` stay sans for the same reason they were never monospaced: Instrument Serif is a
display cut, and long-form lore is where a display face turns into extra wrapping at the largest
accessibility sizes, which is the failure `NFR-A11Y-01` exists to prevent. Caps and tracking are now
confined to one new role, `eyebrow`, the ruled kicker above a heading; the old all-caps section
heading is gone.

### What was sampled, and what survived

| Sampled from the references | Shipped | Why the difference |
|---|---|---|
| stock `#E9E5D9`–`#F9F5E9` | paper `#F6F1E4`, raised `#FCF9F1`, sunken `#E9E1D0` | Three surfaces, because text lands on all three. |
| brick red `#6C2A1A`–`#8B3324` | seal `#8C2F1E` light | Survived close to as sampled — unusual. At 7.33:1 on cream it can carry text *and* fill a control without being pushed around. |
| the same red, dark spread | seal `#E4907B` dark | The sampled red on charcoal is 2.1:1. Same hue, carried to the readable end. |
| charcoal `#1F1F1F` | paper `#1B1A18`, raised `#26241F`, sunken `#121110` | As above: three surfaces, not one. |
| — | warning `#7A4E0C` light | Ochre, not a second red. A warning beside the seal red has to be a different hue, or the page has two accents that mean different things and look the same. |

### Measured again, in full

| Pair | Light | Dark |
|---|---|---|
| Body ink on paper / card / inset | 15.01 · 16.09 · 13.01 | 14.76 · 13.15 · 16.00 |
| Secondary ink | 7.05 · 7.56 · 6.11 | 8.62 · 7.68 · 9.35 |
| Seal accent | 7.33 · 7.86 · 6.36 | 7.10 · 6.33 · 7.70 |
| Warning | 6.37 · 6.83 · 5.52 | 9.07 · 8.09 · 9.84 |
| `documented` / `oral` chip ink | 13.01 / 7.13 | 16.00 / 11.44 |
| Text on filled accent button | 7.86 | 7.10 |
| On-photo ink / muted, on scrim `#17130F` | 16.42 / 10.53 | 16.42 / 10.53 |
| Hairline (needs 3:1) | 4.06 · 4.36 | 4.25 · 3.78 |

Lowest text ratio: **5.52:1** light, **6.33:1** dark. Lowest hairline: **3.78:1** dark. Every pair
passes.

### The quest card moved its type off the photograph

The Stage 7 card laid the title and the facts over the hero on an opaque scrim. The catalogue does
not: it frames the plate and sets the entry beneath it on the page. Adopting that is also the
stronger accessibility position — every ratio on the card is now measured against a surface the theme
owns rather than against a gradient over an arbitrary image. `PhotoScrim`, `PhotoCardFact` and the
on-photo tokens stay, measured, for the map labels and for the preview, and `KultaraFact` is their
on-paper sibling. The two are separate views rather than one with a colour parameter, because that is
how a token measured against the scrim ends up on cream.

Everything `FR-DISC-02` and `FR-DISC-05` require is still on the card, still stacking rather than
truncating at accessibility sizes. The region moved into the plate number's eyebrow — `DENPASAR //
01` — where it is still read out as part of the card's combined label.

### Two layout bugs the retheme caused, both found by the XXXL test

`testTheWholeFlowSurvivesTheLargestDynamicTypeSize` failed on the first run with every label on the
quest list reporting a frame starting at x = −170 in a 402-point window.

1. The hero was a `.fill` image inside a fixed-height frame. Asked for its own width it reports the
   width its aspect ratio wants — at XXXL, roughly 990 points — and the enclosing column adopted it,
   so the whole card was drawn wider than the screen and centred. The photograph is now an overlay on
   a clear box of the plate's size; an overlay cannot affect its parent's size. The plate's height is
   also capped at 300 points, because past about a third of the screen it pushes the required facts
   off the first screenful.
2. `KultaraEyebrow` laid its label and its number side by side in a plain `HStack`. Two short strings
   is a default-size claim; at XXXL the row ran several hundred points past the window. It wraps now,
   and each string wraps within it.

A third, caught by inspection rather than by the test: the section heading's trailing rule needed
`layoutPriority` on the heading, or a long section name at an accessibility size gets squeezed into a
column of single letters while the rule keeps its width.

### Verified

239 package tests and all four XCUITests pass, including the largest-Dynamic-Type flow. Screens
checked by screenshot: quest list, quest preview and settings in light, quest list in dark.

---

## Stage 10 — Home, from `App Design-4`

A fourth reference, and this one is a screen rather than a mood: `Home.svg` is the map surface at
exactly 402 × 874, and the two files beside it (`Home-1`, `Home-2`) are the list surface. They are
one design, so both were built. The catalogue typography and the cream-and-brick-red palette of
Stage 9 carry over unchanged; what changed is the Home screen's structure.

### What the design specifies, and what was built

| In the reference | Built |
|---|---|
| Masthead in the serif, in red | `questListTitle` in `seal`, not `ink` |
| A pill search field, "Find cultural heritage" | `KultaraSearchField`, filtering the rows already in memory |
| A map thumbnail beside it | `MapSurfaceButton`, showing the region illustration itself |
| Photo cards, rounded, title and facts over the image | The card's type moved back onto the photograph, on the measured scrim |
| A filled red arrow on each card | `SealArrowBadge`, unchanged from Stage 7 |
| A floating tab bar | `KultaraTabBar`, with Quests and Settings |
| A full-bleed illustrated map with named places | `RegionMapView`, rewritten |

The Stage 9 card set its type on cream below a framed plate. This design puts it back on the
photograph, so `PhotoScrim` and the on-photo inks — which were kept and kept measured — are load
bearing again. Everything `FR-DISC-02` and `FR-DISC-05` require is still on the card.

### Search

`FR-DISC-01` and `AD-3` mean discovery works in airplane mode, so the field filters `rows`, which
are already in memory, and queries nothing. It matches title and region, folds case and diacritics
because Indonesian place names carry marks a reader will not type, preserves the authored order
rather than ranking by relevance (`FR-DISC-03`), and says so when nothing matched instead of
quietly showing everything.

### Settings moved from a bar button to a tab

The design has no navigation bar on Home, which leaves a gear icon nowhere to live. Settings is a
tab now. The bar is drawn rather than taken from `TabView` — the system bar cannot be given this
theme's face or its stock — and it is attached with `safeAreaInset` rather than stacked on top, so
the space it occupies is exactly the space it has even when its labels grow.

### The map, and the one place the design cannot be followed literally

The shipped illustration is the same artwork as the reference's, and its aspect ratio is within a
percent of the screen's, so it fills the screen with almost no crop. Place names are drawn on it in
the display serif with a hard outline of eight offset copies rather than a shadow — a shadow's
contrast against a parchment coastline is not a number anyone can state, while a hard outline means
the ink sits on a colour the theme owns and measures.

What cannot be followed literally is the opening zoom. The reference has two pins at opposite ends
of Bali; the shipped example content has three quests inside one town, roughly 41 points apart at
island scale. Any faithful whole-island view puts those three markers on top of one another —
`NFR-A11Y-01`'s overlap, and the end of `NFR-A11Y-06`'s 44-point target. So the opening zoom is
derived from the content: `initialZoom(drawnAt:minimumSeparation:maximum:)` returns 1 when the pins
are far enough apart, and otherwise the factor that separates the closest two, capped at 6×. Spread
content opens exactly as the design draws it; clustered content opens on the cluster. Pinch and
double-tap move between the two, and a double tap always returns to the whole island.

Markers are drawn outside the `scaleEffect`, in screen space. Inside it they scaled with the
artwork, so zooming separated two labels and enlarged them by the same factor and never pulled them
apart — the first version of this did exactly that, and the overlap assertion caught it.

### Four bugs, three of them caught by the tests

1. `accessibilityLabel` on the map's container turned the entire map into one accessibility element
   and swallowed every marker inside it. `NFR-A11Y-02` failure; the marker assertions found nothing.
2. The card was a fixed-height photograph with the caption overlaid, so at the largest accessibility
   size the title was clipped off the top of the scrim. The caption now lays out first and the
   photograph is its background — a background cannot shrink its parent, so the card grows to fit
   the words.
3. The import-boundary scan's `Map(` needle matched Swift's own `flatMap(`. The needle now requires
   a word boundary on the left, because a guard that fires on `flatMap` is a guard someone deletes
   rather than fixes.
4. At `AccessibilityXXXL` a card is most of the screen tall and its centre point lands under the
   floating bar — which XCUITest taps, because it always taps the centre. The test taps near the top
   of the card now, which is what a person does. The app itself is fine: the bar reserves its own
   space and the rest of the card scrolls out from under it.

### Verified

246 package tests and all four XCUITests pass, including the largest-Dynamic-Type flow. Screens
checked by screenshot: Home list, the map surface, quest preview, settings, and Home at
`AccessibilityXXXL`.

One environmental note, not a code problem: `xcodebuild test` intermittently fails to launch the
runner on a cloned simulator ("Application failed preflight checks"). Running with
`-parallel-testing-enabled NO` against the booted device avoids the clone entirely.
