# M7 — Restoring the test guards the architecture refactor deleted

**Status:** planned, not executed.
**Scope of requirements:** `.claude/prds/cultural-heritage-quest.full.prd.md`, `docs/system-design.md`,
`.claude/plans/m6-quest-run-vertical-slice.plan.md`.

## What happened

`b597b5b` "Refactor Architecture" moved everything in `Sources/AppFeatures` into the app target as
`Model/` `View/` `ViewModel/` `Service/` `Support/`, removed the `AppFeatures` library and its test
target from `Package.swift`, and deleted the five test files that lived in
`Tests/AppFeaturesTests/` along with it.

| Deleted file | `@Test` functions |
|---|---|
| `OnboardingTests.swift` (two suites: `OnboardingTests`, `PermissionCallBoundaryTests`) | 15 |
| `DiscoveryTests.swift` (`QuestListTests`, `QuestPreviewTests`, `QuestCardAndMapTests`) | 46 |
| `LocalizationTests.swift` (`UIStringsTests`, `LanguageResolverTests`, `AppPreferencesStoreTests`, `ContentFormatterTests`) | 18 |
| `SettingsTests.swift` | 18 |
| `QuestRunTests.swift` | 15 |
| | **112** |

`swift test` went from 297 tests in 28 suites to **184 tests in 17 suites** (measured, 1.7 s wall).
The app target has no unit tests at all; `challange-5UITests` is XCUITest and covers four screen-level
journeys, none of which is a substitute for the deleted guards.

This milestone restores the guards against the code in its new home. It adds no features and moves no
production code.

## What this milestone is not

- Not a re-litigation of the refactor. The MVVM folders in the app target stay exactly where
  `b597b5b` put them.
- Not new tests. Every test named here existed and passed on `973a825`.
- Not a fix for the gaps `m6` already recorded as open (bilingual purpose strings, airplane-mode
  traversal on a device, VoiceOver traversal, the tab-bar inset).

## Findings that change the constraints as written

Three of the facts the task and `CLAUDE.md` state are out of date, and two of them affect the plan:

1. **The app target is Swift 6.0, not 5.0.** `b597b5b` also changed `SWIFT_VERSION` from `5.0` to
   `6.0` in both app configurations, alongside `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
   `SWIFT_APPROACHABLE_CONCURRENCY = YES` which were already there. The new test target must match all
   three or the restored `@MainActor` suites will not compile the same way the code they test does.
   `SWIFT_VERSION = 5.0` remains true of `challange-5UITests` only. `CLAUDE.md` needs correcting.
2. **There are three iOS runtimes installed, not one.** `xcrun simctl list devices available` reports
   iOS 26.3, 26.4 and 26.5, with `iPhone 17` present on all three, plus `iPhone Air`, `iPhone 16e` and
   iPads. A `-destination` that names only `name=iPhone 17` is now ambiguous and will pick whichever
   Xcode prefers; pin `OS=26.5` so a red test means a code change rather than a runtime change.
   The 18.0 deployment floor is still never exercised.
3. **`CLAUDE.md` still describes `AppFeatures` as a layer and a scheme.** It is neither.

None of this weakens a requirement; it corrects the documentation the plan will be read against.

## Decision 1 — Where the tests live

Two homes, split by whether the test needs to *link* the code or only to *read* it.

### 1a. The source-scanning suite stays in the package — it never needed linkage

`PermissionCallBoundaryTests` opens `.swift` files with `FileManager` and matches strings. It imports
nothing it scans. It only ever needed a path, and a path out of the package into
`challange-5/challange-5/` is exactly as available from `Tests/ContentKitTests` as it was from
`Tests/AppFeaturesTests`. `ImportBoundaryTests` already does this walk from `#filePath`, so the
technique is precedented in the file next to it.

So it goes back into `ContentKitTests`, and keeps running under `swift test` on macOS in under two
seconds. This is the cheapest correct option and it is available for free — no new target, no
simulator, no `Package.swift` edit. A separate `BoundaryTests` test target would be tidier by name and
would cost four more lines in `Package.swift` and a second place to look for the same kind of test;
not worth it.

The cost is one hard-coded relative walk out of the package root, which breaks if the package is ever
consumed from elsewhere. The existing vacuity guard (`#expect(!files.isEmpty)`) turns that breakage
into a red test rather than a silent pass, which is the correct failure mode.

### 1b. Everything else needs a new unit-test target in the Xcode project

The other four files construct `QuestRunViewModel`, `SettingsViewModel`, `QuestListViewModel`,
`QuestPreviewViewModel`, `RegionMapViewModel`, `OnboardingViewModel`, `UIStrings`, `ContentFormatter`
and `InMemoryAppPreferencesStore`. All of those are `internal` types in the app target. An SPM test
target cannot see them: SwiftPM cannot depend on an Xcode application target, and a `path:` pointing
outside the package root is rejected by the manifest loader. There is no arrangement of
`Package.swift` that reaches them.

**The alternative was weighed and rejected.** Moving `Model/`, `ViewModel/`, `Support/` and the
protocol halves of `Service/` back into an SPM library would put all 107 of these tests back under
`swift test` in about a second, and the code is nearly ready for it — every file in those three
folders imports only `Foundation`, `ContentKit`, `RunEngine`, `DesignSystem` or `SwiftUI`, all of
which build on macOS. Only `Service/LocationService.swift` and `Service/StorageReporter.swift` import
`CoreLocation`, and only their concrete `CLLocationManager`-backed types actually need it.

It is rejected because it is a second architecture change three commits after the first, it re-splits
the MVVM folders the team just consolidated, and it touches roughly thirty production files to restore
tests that will pass either way. A test-restoration plan that rewrites the architecture it is testing
is the wrong shape. If the package split is wanted, it is its own decision on its own merits, and this
plan is not the argument for it.

A third option — a package target whose `Sources` directory is a symlink to the app's folders — was
considered and rejected outright. It compiles the same files into a second module with a different
name and different default actor isolation (the package has no `SWIFT_DEFAULT_ACTOR_ISOLATION`
setting; adding one needs `swift-tools-version` 6.2 and a `.defaultIsolation` swift setting). Two
module identities for one set of types is a trap that pays for itself in confusing failures.

**Accepted cost, stated plainly:** 107 of the 112 restored tests will run only under `xcodebuild test`
on a simulator, in minutes rather than in the 1.7 s the package suite takes. `swift test` will finish
at 189 tests, not 296. Anyone running only `swift test` will get less coverage than the number
suggests, which is why step 9 writes that fact into `CLAUDE.md` rather than leaving it to be
rediscovered.

### 1c. How the target gets created: `project.pbxproj` is edited by hand

`objectVersion = 77` with `PBXFileSystemSynchronizedRootGroup` makes this the cheap option rather than
the risky one. The synchronized group means the target is described once and then every test file
added to `challange-5Tests/` afterwards needs no project edit at all — which is the whole reason the
file is only 491 lines despite a 46-file app target.

The precedent is already in the file: `challange-5UITests` was hand-authored, with hand-assigned
object IDs in an obvious `A0B0B0B0000000000000B0xx` block. The new target follows the same shape in a
`A0C0C0C0000000000000C0xx` block, which keeps hand-written objects visibly distinct from Xcode's.

Objects to add:

| Section | Object |
|---|---|
| `PBXFileReference` | `challange-5Tests.xctest`, added to the `Products` group |
| `PBXFileSystemSynchronizedRootGroup` | `path = "challange-5Tests"`, added to the main group |
| `PBXNativeTarget` | `challange-5Tests`, `productType = com.apple.product-type.bundle.unit-test`, empty `Sources`/`Frameworks`/`Resources` phases, `fileSystemSynchronizedGroups` = the new group |
| `PBXContainerItemProxy` + `PBXTargetDependency` | test target depends on `challange-5` |
| `XCSwiftPackageProductDependency` ×3 + `PBXBuildFile` ×3 | `ContentKit`, `RunEngine`, `DesignSystem`, so the test files can `import` them |
| `XCConfigurationList` + 2 × `XCBuildConfiguration` | settings below |
| `PBXProject` | new target in `targets`, and a `TargetAttributes` entry with `TestTargetID` |

Build settings that are not boilerplate, and why:

- `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/challange-5.app/challange-5"` and
  `BUNDLE_LOADER = "$(TEST_HOST)"` — this is what makes `@testable import challange_5` resolve. The
  module name is `challange_5`; the hyphen becomes an underscore.
- `SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
  `SWIFT_APPROACHABLE_CONCURRENCY = YES` — matched to the host app per finding 1. A test target with
  different default isolation than the code it tests produces compile errors that look like test bugs.
- `ENABLE_TESTABILITY` is already `YES` in the project-level Debug configuration; nothing to add.
- `DEVELOPMENT_TEAM = YG7T52597K` to match the host app. The project currently carries three different
  team IDs across its configurations (`62ZRZ6VZKC` at project level and on the UI tests, `YG7T52597K`
  on the app). Matching the host is the only one that matters for a hosted bundle; the inconsistency
  itself is noted, not fixed here.
- `PRODUCT_BUNDLE_IDENTIFIER = com.umar.challange-5Tests`, matching the app's `com.umar.` prefix.

Linking the three package products into both the app and the test bundle is correct and not a
duplicate: Xcode builds each SPM product once per configuration, and `-bundle_loader` resolves symbols
already present in the host binary. If duplicate-symbol diagnostics appear anyway, the fallback is to
keep the `XCSwiftPackageProductDependency` entries and drop the `PBXBuildFile` entries from the test
target's Frameworks phase.

**A shared scheme is committed in the same step.** There is no `xcshareddata/xcschemes/` directory
today — `challange-5` is autocreated, and `xcuserdata` holds only a management plist. Autocreation
does normally pick up a unit-test bundle that names the app as its host, but "normally" is not a thing
to hang a test suite on across two developers' machines. A checked-in `challange-5.xcscheme` whose
`TestAction` names both `challange-5Tests` and `challange-5UITests` makes the command in `CLAUDE.md`
mean the same thing everywhere.

## Decision 2 — What is restored, what is rewritten, what is dropped

Every type the deleted tests exercise survived the refactor with its API intact. This was checked
member by member: `OnboardingViewModel.pages/isSkipAvailable/primaryActionKey/isLastPage`,
`QuestListViewModel.visibleRows/hasNoSearchResults/loadFailed/isEmpty`,
`QuestPreviewViewModel.allRenderedText/startState/lateStartWarning/costBreakdownTotalMinor` and its
`runEngine:` init label, `RegionMapViewModel.initialZoom/closestPinSeparation/pins`,
`SettingsViewModel` in full, `QuestRunViewModel.stage/arrival/manualOverrideDelay/taskDrafts`,
`RunSummaryViewModel(run:)`, `UIStrings.table`, `UIStringKey.allCases`,
`LocationAuthorizationSnapshot.allCases`, `InMemoryAppPreferencesStore(safetyNoticeAckedQuestIDs:)`,
`UserDefaultsAppPreferencesStore.preferredLanguageKey`, `LanguageResolver.resolve`, `OnboardingGate`.
`LocationFix` and `InMemoryRunStore` are still in `RunEngine`.

**Nothing was tested that the refactor legitimately removed.** The refactor moved code; it deleted no
behaviour. So no test on this list is dropped as obsolete.

| Suite | Treatment | What changes |
|---|---|---|
| `OnboardingTests` (10) | Restored verbatim | Import only |
| `PermissionCallBoundaryTests` (5) | Rewritten | Scan roots and the confined-file set — see Decision 3 |
| `UIStringsTests` (5) | Restored verbatim | Import only |
| `LanguageResolverTests` (3, one parameterised over 8 cases) | Restored verbatim | Import only |
| `AppPreferencesStoreTests` (5) | Restored verbatim | Import only |
| `ContentFormatterTests` (5) | Restored verbatim | Import only |
| `QuestListTests` (14) | Restored verbatim | Import only |
| `QuestPreviewTests` (18) | Restored verbatim | Import only |
| `QuestCardAndMapTests` (14) | Restored verbatim | Import only |
| `SettingsTests` (18) | Restored verbatim | Import only |
| `QuestRunTests` (15) | Restored verbatim | Import only |

"Import only" means `@testable import AppFeatures` becomes `@testable import challange_5`. The test
doubles that lived in these files — `FakeLocationProvider`, `FailingContentRepository`,
`MapLessContentRepository`, `StubLocationAuthorizationReporter`, `StubStorageReporter`,
`SpyLocalDataEraser` — come back with them, unchanged.

One thing to watch during execution rather than to design around: the app target sets
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and the old package target did not. The suites are already
`@MainActor`-annotated, so this should be invisible; if a non-isolated helper struct (`StubStorageReporter`,
`FailingContentRepository`) fails a `Sendable` check under the new default, the fix is an explicit
`nonisolated` on the type, never a relaxation of the assertion inside it.

## Decision 3 — What the source scan scans now

`Sources/AppFeatures` is gone, so the three ban lists retarget as follows. The lists themselves do not
change; a ban that gets shorter to make a scan pass is not a ban.

| Scan | Old root | New root |
|---|---|---|
| Forbidden calls — `requestAlwaysAuthorization`, `startMonitoringSignificantLocationChanges`, `startMonitoring(for:`, `allowsBackgroundLocationUpdates`, `ATTrackingManager`, `AppTrackingTransparency`, `requestTrackingAuthorization` (`FR-ONB-04`, `FR-ONB-06`, `NFR-BAT-01`) | `Sources/AppFeatures` | `challange-5/challange-5` (whole app target) **and** `Sources/DesignSystem` |
| Confined calls — `requestWhenInUseAuthorization`, `startUpdatingLocation` (`FR-ARR-02`, `NFR-BAT-04`) | `Sources/AppFeatures`, allowed in `LocationService.swift` + `QuestRun.swift` | `challange-5/challange-5`, allowed in `Service/LocationService.swift` + `ViewModel/QuestRunViewModel.swift` |
| Reachability — `NWPathMonitor`, `SCNetworkReachability`, `isReachable` (`AD-3`) | `AppFeatures`, `ContentKit`, `DesignSystem` | `challange-5/challange-5`, `ContentKit`, `RunEngine`, `DesignSystem` |
| Live map tiles — `import MapKit`, `MKMapView`, `Map(` (`FR-MAP-01`) | `Sources/AppFeatures` | `challange-5/challange-5` |

The confined-file set changes because `QuestRun.swift` was split into `View/QuestRunView.swift` and
`ViewModel/QuestRunViewModel.swift`. The current tree matches the new set exactly and with nothing to
spare: `startUpdatingLocation` appears only in `Service/LocationService.swift`;
`requestWhenInUseAuthorization` appears there and at exactly one call site,
`ViewModel/QuestRunViewModel.swift:180`. There are no `MapKit` or reachability hits anywhere.

The confinement is matched on the *file name*, as before, not on the path — so moving
`QuestRunViewModel.swift` between folders keeps the guard green while renaming it turns it red. That
is the right sensitivity: the guard is about which component owns the call, not about the folder
layout, and the folder layout is the thing that just changed.

`theArrivalPathIsActuallyWhereThoseCallsAre` is the load-bearing half and is restored unchanged. The
confinement test filters a found set; if the calls disappear or move out of the app target, the filter
finds nothing and passes. The companion test asserts the found set is non-empty, which is what stops
the guard passing vacuously — including the day someone decides the DEBUG "simulate arrival anywhere"
switch would be simpler if it just called `startUpdatingLocation` from a view. `FR-START-08` says a
quest must not be startable from outside the start radius *by any path*, and this scan is the only
mechanical thing standing between that requirement and a second location call site.

Also restored unchanged: `#expect(!files.isEmpty)` inside the walker, which is the same property one
level down — a scan pointed at a directory that no longer exists must fail, not pass.

## Steps

Each step is independently committable and leaves the tree green.

### 1. Record the baseline

Run `swift test` (expect **184 tests, 17 suites**, ~1.7 s) and
`xcodebuild test -project challange-5.xcodeproj -scheme challange-5 -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`
(expect **TEST SUCCEEDED**, 4 UI tests).

*Proves:* the starting point is green, so every red result after this belongs to this milestone.

### 2. Restore `PermissionCallBoundaryTests` into the package

New file `Packages/Kultara/Tests/ContentKitTests/PermissionCallBoundaryTests.swift`, carrying the
suite from the deleted `OnboardingTests.swift` with the roots of Decision 3. The `occurrences(of:in:)`
helper takes a directory `URL` rather than a target name, since it now scans two trees that are not
siblings. The word-boundary matcher and the comment-skipping stay exactly as they were — the first
exists so `Map(` does not fire on `flatMap(`, the second so the requirement notes in the ban list do
not match themselves.

*Proves:* no background location, no significant-change monitoring, no ATT prompt and no reachability
check exists anywhere in the codebase; foreground sampling and its permission prompt exist and are
confined to the two files that own arrival; the route display draws no live map tiles. All of it
without a simulator. `swift test` should read **189 tests, 18 suites**.

### 3. Create the `challange-5Tests` target

Hand-edit `project.pbxproj` per Decision 1c. Create `challange-5/challange-5Tests/` with the shared
scheme at `challange-5.xcodeproj/xcshareddata/xcschemes/challange-5.xcscheme`.

*Proves:* nothing on its own. Verified by `xcodebuild -list -project challange-5.xcodeproj` naming
both the target and the scheme, and by `xcodebuild build-for-testing` succeeding — which is the check
that the project file is still parseable and the target still links.

### 4. Prove the target is wired before filling it

One file, `challange-5Tests/HostLinkageTests.swift`, with a single test that does
`@testable import challange_5` and asserts `UIStringKey.allCases` is non-empty and
`try BundledContentRepository().quests()` is non-empty.

*Proves:* the test bundle loads the host app, `@testable` reaches internal types, the three package
products are importable, and the content resources are in the built app. Debugging that against one
test is minutes; debugging it against 107 is an afternoon.

### 5. Restore `OnboardingTests`

`challange-5Tests/OnboardingTests.swift`, the `OnboardingTests` suite only.

*Proves:* onboarding is at most four screens and skippable from the first (`FR-ONB-02`); one screen
teaches the pocket-the-phone model (`FR-ONB-03`, `AD-1`); every screen is translated in both languages;
skipping and finishing both mark completion so it does not reappear (`FR-ONB-01`).

### 6. Restore `LocalizationTests`

`challange-5Tests/LocalizationTests.swift` — all four suites.

*Proves:* every `UIStringKey` has an entry and every entry is translated in both languages
(`NFR-I18N-01`, `NFR-I18N-02`); the table has no orphaned entries; Indonesian and English are actually
different text except for the name and the SI unit symbols, which is the check that catches a
copy-pasted English string sitting in the Indonesian slot; lookup returns exactly the requested
language with no fallback (`NFR-I18N-03`); the device language resolves per `FR-ONB-05` and a Settings
override beats it; a corrupt stored language degrades to "no override" rather than crashing at launch;
distance switches to kilometres at 1000 m and uses a comma in Indonesian (`NFR-I18N-05`); a free quest
reads "Gratis"/"Free" rather than "Rp 0"; zero bytes reads as a number rather than "Zero KB".

This is the step that matters most in raw terms. Roughly fifty string keys were added during M6 and
nothing has checked either language since.

### 7. Restore `SettingsTests`

*Proves:* Settings exposes language, location status, storage and deletion (`FR-SET-01`); all five
authorisation states read differently, so "not requested" and "denied" cannot share a string; the
authorisation reporter structurally cannot request permission, which is `FR-ONB-04` held by the type
rather than by a comment; deletion requires confirmation and clears preferences, and a failed deletion
is reported rather than swallowed (`FR-SET-02`); the delete scope note states honestly what this build
does not have to delete; attribution is present, deduplicated and names the content version
(`FR-SET-03`, `NFR-GOV-05`); the report path states the real turnaround and carries the content version
in its destination (`FR-SET-04`, `NFR-CONT-07`).

### 8. Restore `DiscoveryTests`

*Proves:* the list shows every field `FR-DISC-02` requires and the card keeps the distance, the cost
and the two separate time figures that the Home mockup dropped (`FR-DISC-05`, `NFR-CONT-06`); search
filters in memory, ignores case and diacritics, empties the list on no match rather than falling back
to everything, and never reorders the authored sequence (`FR-DISC-03`, `AD-3`); preview shows all
fourteen things `FR-DISC-03` lists and the cost breakdown sums to the total; no checkpoint lore and no
clue text appears anywhere in preview, asserted against the rendered strings rather than against a
property name (`FR-DISC-04`); suppressed quests vanish from both the list and the map (`FR-DISC-08`);
the late-start warning appears strictly after `hard_latest_start`, names the site that closes and its
closing time, and blocks nothing (`FR-DISC-06`); preview offers no start control without a Run store
and offers resume rather than a second Run when a draft exists (`FR-START-06/08`); every map pin sits
inside the image, one per quest at its start Place, drawn from a shipped image with an opening zoom
derived from the content so clustered pins stay separable and tappable (`FR-MAP-01`, `NFR-A11Y-01/06`);
a broken repository leaves the screen usable (`NFR-REL-04`).

### 9. Restore `QuestRunTests`

Last, because it is the one whose failure would be a real finding rather than a wiring problem.

*Proves:* the safety notice precedes everything on a first run and the location explanation precedes
the system prompt, with nothing asked of the system before either (`FR-START-04`, `FR-START-02`,
`FR-ONB-04`); a fix 4 km out starts nothing and shows a live distance, and a fix sitting on top of the
gate with 900 m accuracy starts nothing either (`FR-START-08`, `FR-ARR-01` — the accuracy half, which
is the load-bearing one); a good fix starts the walk, records the lore opening and stops sampling
(`NFR-BAT-04`); the manual override appears only after the delay, and appears at once when permission
is refused without destroying the Run (`FR-ARR-03`, `FR-ERR-02`); the override at the start checkpoint
requires a confirmation that names the Place, and cancelling leaves the quest unstarted
(`FR-START-09`); the whole route completes and the summary renders from the Run's snapshots with no
repository in sight (`FR-DONE-01/03/04`); a written reflection reaches the summary (`FR-TASK-07`);
abandoning keeps what was already walked (`FR-RUN-04`).

The one test here that is timing-sensitive, `theManualOverrideAppearsOnlyAfterTheDelay`, already polls
rather than sleeping once, for the reason its own comment gives. It stays that way.

### 10. Update the documentation and record the result

- `CLAUDE.md`: correct `SWIFT_VERSION` to 6.0 for the app target; remove `AppFeatures` from the
  layering paragraph and the scheme list and describe the app target's MVVM folders instead; correct
  the simulator inventory and pin `OS=26.5` in the `xcodebuild` command; add the `challange-5Tests`
  target, say which suites run under `swift test` and which need the simulator, and say why.
- `.claude/plans/m6-quest-run-vertical-slice.plan.md`: a dated note that Decision 1's
  `PermissionCallBoundaryTests` now lives in `ContentKitTests` and scans the app target.
- This file: append measured counts for `swift test` and `xcodebuild test`.

*Proves:* the next person reading `CLAUDE.md` runs the command that actually covers the code.

## Expected end state

| | Before | After |
|---|---|---|
| `swift test` | 184 tests, 17 suites, 1.7 s | 189 tests, 18 suites |
| `xcodebuild test` | 4 XCUITests | 4 XCUITests + 107 unit tests |
| Total | 188 | 300 |

The total exceeds the pre-refactor 297 because the source-scan suite is counted once in a place it can
actually run.

## Left unguarded when this plan is done

Restoring what was deleted does not make the codebase fully guarded. Named here so the gaps stay
decisions:

1. **The `#if DEBUG` fence around the arrival simulator.** `SimulatedLocationProvider`,
   `DeveloperPreferences` and `DeveloperSwitchableLocationProvider` are inside `#if DEBUG`, and
   `m6` Decision 1 rests on a release build not containing them. Nothing asserts it. A scan that
   fails when those symbols appear outside a `#if DEBUG` block would be cheap and would close the
   last path to `FR-START-08` that the call-site confinement does not cover — but it is a guard that
   never existed, and this plan restores rather than invents. It is the first thing to add next.
2. **`import CoreLocation` is not confined.** Only `Service/LocationService.swift` and
   `Service/StorageReporter.swift` import it today, and nothing keeps it out of `ViewModel/`. Same
   reasoning as above: worth adding, not part of a restoration.
3. **`ContentFormatter`, `UIStrings` and the view models cannot be tested without a simulator.**
   That is the accepted cost of Decision 1b, and it makes ~107 tests roughly two orders of magnitude
   slower to run than they were. If that friction stops people running them, the package split
   rejected in Decision 1b becomes the right answer after all.
4. **The `@State` view-model rule is held by a comment.** `CLAUDE.md` records that building a view
   model inside a `body` orphans anything in flight, and `ScreenHost` exists because of a real bug
   that presented as an arrival screen which never found a fix. No test can see it; it was never
   guarded and still is not.
5. **SwiftUI view bodies.** Only the four XCUITest journeys touch rendered output, and they cover
   discovery, preview, the map and Settings — not the quest run, not the summary, not onboarding
   beyond its Skip button.
6. **`NSLocationWhenInUseUsageDescription` is English only** (`NFR-I18N-02`), unchanged from `m6`.
   The restored `LocalizationTests` covers the app's own strings and structurally cannot cover an
   Info.plist key.
7. **The iOS 18.0 deployment floor has still never been run.** The lowest installed runtime is 26.3.
8. **Airplane-mode traversal on a physical device** (`NFR-REL-03`, `FR-OFF-02`, a release gate) is
   still not done. The reachability scan proves no code asks about connectivity; the requirement asks
   for the test, not the argument.

---

## Execution — 2026-08-16

**Status: the target exists, all 112 guards compile and run, 91 of 109 pass. The remaining 18 are
drift findings, not wiring problems, and they are listed below rather than edited away.**

### Two failures that predate this milestone

Step 1's baseline was supposed to prove the starting point was green. It was not.

1. **The app target did not compile at all.** An uncommitted working-tree edit to
   `project.pbxproj` had removed the `UIStringsKit` package product dependency — all four objects
   (`PBXBuildFile`, the Frameworks entry, `packageProductDependencies`, and the
   `XCSwiftPackageProductDependency` itself) — while 20+ files in `ViewModel/`, `View/`, `Model/`
   and `Support/` import it. Restored; the same uncommitted diff also sets
   `PRODUCT_BUNDLE_IDENTIFIER = com.astungkara.hisplora` and `DEVELOPMENT_TEAM = 62ZRZ6VZKC`, which
   read as deliberate and were left alone.
2. **All four XCUITests fail** once the build succeeds. They had never run, because the compile
   failed first. Not diagnosed here; not caused by this milestone.

### What was built

- **Step 2.** `Tests/ContentKitTests/PermissionCallBoundaryTests.swift`, 5 tests, green under
  `swift test` in 0.08 s. Scans the app target and the package targets, not `Sources/AppFeatures`.
- **Step 3.** `challange-5Tests` unit-test target, hand-written into `project.pbxproj` in an
  `A0C0C0C0…C0xx` block beside the existing `A0B0B0B0…` UI-test block, with a
  `PBXFileSystemSynchronizedRootGroup` so no future test file needs a project edit. Plus the shared
  scheme at `xcshareddata/xcschemes/challange-5.xcscheme` naming both test targets.
- **Step 4.** `HostLinkageTests` — 2 tests, green. `@testable import challange_5` resolves, the four
  package products link, content resources are in the built app.
- **Steps 5–9.** All five suites restored from `b597b5b^`. The import change was
  `@testable import AppFeatures` → `@testable import challange_5` **plus `import UIStringsKit`**,
  which the plan could not have known about: `UIStrings` and `UIStringKey` were extracted into their
  own package target after m7 was written.

### Deviations

1. **The arrival-owning file set is four files, not two.** Decision 3 names `LocationService.swift`
   and `QuestRunViewModel.swift`. `ArrivalSampling.swift` (the sampler extracted out of the view
   model) and `SideQuestFlowViewModel.swift` (sidequest discovery runs the same radius gate,
   `s2` §6) have joined them. Neither is a new *kind* of caller, which is what the guard exists to
   catch; a view or a settings model appearing there still fails it. Stated in the test file itself.
2. **`indonesianAndEnglishAreActuallyDifferentText` gained a third exemption**, by property rather
   than by name: a string containing no letters once printf specifiers are stripped cannot be the
   half-translation the guard exists to catch. Found by the restored test firing on a progress
   counter's `"%1$d / %2$d"`. Exempting by property rather than adding keys to a list is what stops
   the guard getting shorter every time.
3. **`FailingContentRepository` and `MapLessContentRepository` gained the six sidequest methods**
   (`s1` §6 widened `ContentRepository`). The failing double throws from them; the map-less double
   delegates.

### The 18 that fail, and why each is a finding rather than a fix

**A — six tests pinned to content that no longer exists.** The `contoh-*` placeholders are gone,
replaced by `badung-empat-wajah` over five real places. `costIsVisibleOnTheCardWhenTheQuestCostsMoney`
and `previewShowsEveryFieldFRDISC03Requires` assume a paid quest; the shipped one is free.
`theWarningNamesTheSiteThatClosesAndItsClosingTime` asks for `contoh-museum-arsip-kota`.
`noWarningBeforeTheLatestStart` and `exactlyAtTheLatestStartIsStillAllowed` use the fixture's
`hard_latest_start`. `aPlaceWherePhotographyIsProhibitedSaysSoInWords` needs a prohibited-photo place
and no real one has that policy. **These need fixtures of their own rather than assertions against
shipped content** — a test that reads the live content tree changes meaning every time an author
edits a JSON file, which is the wrong dependency for a requirement guard.

**B — nine tests that predate M8's story flow.** `QuestRunViewModel.stage` now begins at
`.storyPreview`; the tests expect `.safetyNotice` or `.awaitingArrival`. **This one is not
bookkeeping.** `FR-START-04` says the safety notice precedes everything on a first run, and the
restored test asserts exactly that. Either the story preview legitimately precedes it — which is a
PRD amendment with an owner's name on it, like the `FR-CP-05` exception m8 already took — or the
ordering is a regression M8 introduced and nothing has been checking. **That question is the single
most valuable thing this restoration has produced, and it is a product decision, not a test edit.**

**C — one map test with nothing to cluster.** `aClusterOfPinsOpensZoomedInFarEnoughToSeparateTheMarkers`
needs two pins; the content ships one quest. Rewrite against a fixture, per A.

**D — `theCheckpointScreenCarriesTheStoryItsLabelsAndItsSources`** collides with m8's undocumented
`FR-CP-05` exception (Story Reveal renders lore without the accuracy chip or citation). Same shape as
B: the exception is recorded in code comments and `docs/hisplora-tokens.md` but **not in the PRD**,
so the test and the product disagree and the PRD does not settle it.

### Verification

```
$ swift test                                        # package, macOS, no simulator
Test run with 342 tests in 39 suites passed after 0.05 seconds.   (was 337 in 38)

$ xcodebuild test -only-testing:challange-5Tests -destination '…iPhone 17,OS=26.5'
Test run with 109 tests in 11 suites failed after 2.99 seconds with 27 issues.
  HostLinkageTests ✔   OnboardingTests ✔   LanguageResolverTests ✔
  AppPreferencesStoreTests ✔   ContentFormatterTests ✔   UIStringsTests ✔
  SettingsTests ✔   QuestListTests ✔   QuestPreviewTests ✘   QuestCardAndMapTests ✘
  QuestRunTests ✘
```

**91 pass, 18 fail.** Every UI string key now has a checked entry in both languages for the first
time since M6 — that alone is step 6's stated purpose, and it passes.

### Not done

- Step 10's `CLAUDE.md` edits, beyond the `supabase/` work already there. Deferred until the 18 are
  resolved, because the honest sentence to write depends on how B and D are decided.
- The four XCUITests remain red for a reason that predates this work.

## Execution — 2026-08-16 (second pass): the 18 resolved

**Status: 110 unit tests, 0 failures. 375 package tests, 0 failures. All five XCUITests pass.**
The count moved from 109 to 110 because one guard was replaced by two.

### Group B — the ordering, and what it turned out to be

The single most valuable thing this restoration produced (previous section, group B) was put to the
user with evidence and **decided rather than edited away**.

**The evidence.** `QuestRunViewModel.initialStage` returns `.storyPreview` for a fresh Run, and
`advanceFromStoryPreview()` then runs safetyNotice → locationNotice → awaitingArrival — its own
comment claiming "The order after it is unchanged: `FR-START-04` before `FR-START-02` before any
sampling". On `.storyPreview` nothing is sampled (`screenAppeared()` guards on `.awaitingArrival`),
no permission is requested and no Run is written. `FR-START-04` reads "before the first Run of a
quest", and acknowledgement does still precede the Run.

**But `m8-qa-fixes.plan.md` line 162 describes the path as "safety notice → location notice →
`awaitingArrival`"** — the pre-M8 order. A grep for `advanceFromStoryPreview` and `initialStage`
across `.claude/plans/` and `docs/` returns nothing. So M8 changed the order during execution and
**no plan, doc or PRD records it**. Not a regression against the requirement's letter; an
undocumented flow change that nothing had been checking.

**Decision: amend the PRD.** Owner **af (afindo.mi01@gmail.com)**, dated 2026-08-16. Written into
`.claude/prds/cultural-heritage-quest.full.prd.md` §5.5 as an amendment block, and split so the
load-bearing half is its own unamendable requirement:

- `FR-START-04` gains "A narrative screen that asks nothing of the user and starts nothing **MAY**
  precede it".
- **`FR-START-04a` is new**: acknowledgement **MUST** precede any location sampling, any permission
  request, and any Run write.

§10's outstanding list records it as closed, alongside the still-open `FR-CP-05` item, with the note
that the *pattern* — a flow change made in execution that no plan records — is the finding rather
than the individual screen.

**The tests got stronger, not shorter.** `theSafetyNoticeComesBeforeAnythingElseOnAFirstRun` asserted
screen order; it is now `theSafetyNoticeComesBeforeAnySamplingPermissionOrRunWrite`, which asserts
`FR-START-04a` directly: on `.storyPreview` nothing samples, nothing is requested, no Run exists —
**and it stays that way after `screenAppeared()`**, which is what a SwiftUI `.onAppear` calls, so a
stage that ignores it is the only safe one. A second test was added,
`aResumedWalkNeverSeesTheNarrativeOpeningAgain`, because the amendment is narrow: the preview is an
opening, not a gate, and a resumed Run must not re-show it.

### Group D — m7's own record was wrong, and this is the correction

`theCheckpointScreenCarriesTheStoryItsLabelsAndItsSources` does **not** collide with M8's
`FR-CP-05` exception. It asserts on `model.checkpoint`, and
`QuestRunViewModel.presentation(forOrderIndex:)` still builds every claim with `accuracyLabel` and
`citations`. The exception is a *view*-level omission on Story Reveal; this test never reaches a
view. It was failing for the group-B cascade — `screenAppeared()` no-ops at `.storyPreview`, so no
arrival, so no checkpoint — and it went green when B was fixed, with neither side edited.

No product decision was needed. The PRD already carries the `FR-CP-05` exception as outstanding
(§10), and it stays outstanding.

### A second ordering drift, found while fixing the first

Arrival no longer lands on `.atCheckpoint`. `arriveAtCurrentCheckpoint()` sets `.cutsceneIntro` on
the first arrival of a walk and `.storyReveal` otherwise; the checkpoint screen is five stages
later. Also undocumented.

Resolved the same way as B rather than by editing the expectation to `.storyReveal`: a
`walkTheStoryStages` helper walks cutscene → reveal → place notice → checkpoint detail → transition
the way a walker does, and the assertion became **"the story stages terminate at `.atCheckpoint`"**
— which also catches a stage that loops or never hands over, and the old assertion did not. The loop
is bounded at 8 rather than `while`, so a self-returning stage fails the suite instead of hanging it.

### Groups A and C — fixtures

New file: `challange-5Tests/ContentFixtures.swift` — `ContentFixture` (5 places, 2 quests) and
`FixtureContentRepository`. Shaped to hold exactly what the seven guards need and nothing else: a
paid quest with a breakdown summing to its total, five checkpoints, a place where photography is
prohibited, a sacred place, `hardLatestStart` 13:30 against an earliest closing of 15:30 at a named
place (120 minutes apart, so V16's derivation actually holds), and two start places a thousandth of
the illustration apart so the region map has something to cluster.

Seven tests retargeted: `costIsVisibleOnTheCardWhenTheQuestCostsMoney`,
`previewShowsEveryFieldFRDISC03Requires`, `aPlaceWherePhotographyIsProhibitedSaysSoInWords`, all four
FR-DISC-06 boundary cases (`aWarningAfterTheLatestStart` joined them for consistency — it was
passing, but on a value an author can change), and
`aClusterOfPinsOpensZoomedInFarEnoughToSeparateTheMarkers`.

**No shipped content was edited.** The fixture place names are deliberately fictional ("Galeri
Fiktif", "Pura Fiktif") — a fixture carrying a real institution's name would be a claim about that
site with no source and no consent record behind it.

`nonisolated` on `ContentFixture`: the app target builds with MainActor default isolation and
`ContentRepository` is not main-actor bound, so a double that could only be read from the main actor
would be a different protocol from the one the app uses.

### Deviations from the previous section's plan for these

1. **Group A's list said six tests; seven were retargeted.** `aWarningAfterTheLatestStart` was
   passing against shipped content by luck of the hour, not by the rule, and leaving one of four
   FR-DISC-06 boundary cases on a different content tree would have made the set incoherent.
2. **Group C's `pinsThatAreAlreadyFarApartOpenTheMapWhole` was left on the bundled repository.** It
   proves the *other* branch by drawing at 40 000 × 87 000 points, which works with one pin, so it
   needed no fixture.

### The four XCUITests — Phase 2

The previous section recorded "all four XCUITests fail". **That was a stale simulator, not a test
defect**, and the count was four of five. After `simctl erase`, four of five passed unchanged: the
launch helper already walks splash → Skip → "Skip for now", the tab bar is already Quests / Journal
/ Profile, and `openSettings` already goes through Profile. There was no navigation drift.

One real failure, and it was real:
`testTheWholeFlowSurvivesTheLargestDynamicTypeSize` — "Settings unreachable at the largest
accessibility size". `openSettings` found the control (`exists`) and tapped it; at
`AccessibilityXXXL` the profile's two controls run past the fold and the lower one sits under the
floating tab bar, so XCUITest's centre tap hit the tab bar and the screen never changed. Exactly the
failure `tapQuestCard`'s own comment documents for the quest card.

Fixed in the test, because a person scrolls: `openSettings` now swipes the scroll view (bounded at
four attempts) until the control is `isHittable`, and asserts hittability with the frame and the
window in the message if it never becomes so. `exists` is not `isHittable`, and this is the second
place in this file where that distinction was load-bearing.

### Verification

```
$ DEVELOPER_DIR=… swift test                      # package, macOS, no simulator
􁁛  Test run with 375 tests in 44 suites passed after 0.131 seconds.     (was 342 in 39)

$ DEVELOPER_DIR=… swift run content-validator Sources/ContentKit/Content
OK  1 quest(s), 5 place(s), 3451352 bytes — all 28 rules pass.

$ xcodebuild test -project challange-5.xcodeproj -scheme challange-5 \
    -destination 'platform=iOS Simulator,id=128624DB-…'   # iPhone 17, iOS 26.5
✔ Test run with 110 tests in 11 suites passed after 0.699 seconds.
Test Case '…testQuestListAndSettingsAreReachable' passed (29.598 seconds).
Test Case '…testStoryPreviewWithholdsEveryCheckpointStoryAndClue' passed (28.757 seconds).
Test Case '…testTappingAQuestCardOpensTheStoryFlow' passed (28.850 seconds).
Test Case '…testTheMapSurfaceShowsAMarkerPerQuestAndOpensTheStoryFlow' passed (29.186 seconds).
Test Case '…testTheWholeFlowSurvivesTheLargestDynamicTypeSize' passed (43.304 seconds).
** TEST SUCCEEDED **
```

The 375 includes 33 new package tests from `c1` (UUIDv7, GovernanceKit, TelemetryKit) and two new
`ImportBoundaryTests` cases, not from this milestone.

### New known gaps

- **The discovery guards no longer see shipped content.** That is the fix, and it has a cost: a
  content mistake in `badung-empat-wajah` will not turn `QuestPreviewTests` red any more.
  `content-validator` (28 rules) and `BundledContentRepositoryTests` are what catch those, and
  `docs/field-verification-checklist.md` §7 step 8 says so where a content author will read it.
- **`testTheWholeFlowSurvivesTheLargestDynamicTypeSize` now passes by scrolling.** The underlying
  layout — a control that lands under the floating tab bar at `AccessibilityXXXL` — is unchanged.
  Reachable, not comfortable. `reportTruncation` reports `A11Y-OK` on all three screens, so nothing
  is clipped; this is an occlusion problem, and it is a design question rather than a test one.
- **Two undocumented M8 ordering changes were found by restoring deleted guards.** One is now a
  signed PRD amendment; the other (arrival → story stages) is recorded here and in the test's own
  comment, but **not** in the PRD, because it does not contradict a requirement — it sits between
  `FR-ARR-01` and `FR-CP-*` rather than against either. If a third turns up, the pattern deserves a
  process answer rather than a third one-off.
