# Feature-Folder Reorganisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (one fresh subagent per task, review between tasks) or superpowers:executing-plans (inline).
>
> **Each task is self-contained.** A subagent needs only: Global Constraints, Target Structure, the Standard Build Gate, and its own task. Tasks run in order 0→9; each assumes the previous one committed.

**Goal:** Re-shape the app target's 116 Swift files from a layer-first layout (`Model/`, `View/`, `View/Component/`, `ViewModel/`, `Service/`, `Support/`) into a feature-first layout. Files move; nothing else changes.

**Architecture:** All moves use `git mv`. The app target uses Xcode 16 `PBXFileSystemSynchronizedRootGroup`, so the folder tree on disk *is* the project structure — no `project.pbxproj` edit is needed or permitted. The app target is a single Swift module, so moving a file between folders cannot change symbol visibility. That is what makes a reorg of this size mechanically safe.

**Base:** `origin/master` at `af318fd`. Working branch: `rapihin-struktur` (already created and already equal to `origin/master`).

**Repo path:** `/Users/imelda/Documents/Swift/5. Challenge 5/challenge5` — note the spaces; every path in this plan is quoted for that reason. There is a second, stale clone at `/Users/imelda/challenge5` that is 94 commits behind. Do not work in it.

**Tech Stack:** Swift 6.3, SwiftUI, iOS 18.0 target, local SPM package `Kultara` (7 targets), swift-testing.

**Spec:** No PRD covers repo layout. Placement decisions come from a measured reference graph over all 116 files, recorded in Task 0 — not from type names.

## Global Constraints

- **App target only.** `challange-5/Packages/**`, `hisplora Watch App/**`, `challange-5Tests/**`, and `challange-5UITests/**` are not touched by any task in this plan.
- **No `.swift` content changes.** Every Swift file must appear in `git diff` as a rename with zero changed lines. The one permitted exception is deleting an `import` a move makes unused — not expected, since the app target is one module. (Task 9 edits `CLAUDE.md`; that is Markdown and is scoped there.)
- **No type, function, property, or enum-case renames. No file splits or merges. No deletions** — including the two unreferenced files identified in Findings. Record anything you want to fix in the Findings section; do not fix it here.
- **Never hand-edit `project.pbxproj`.** If a build fails with a missing input file, the synchronized-folder assumption is wrong: stop and report.
- **Toolchain:** `xcode-select -p` points at `/Library/Developer/CommandLineTools`, where swift-testing is absent, so bare `swift test` fails with `no such module 'Testing'`. Prefix with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- **Do not rename the `challange-5` typo**, and do not rename anything to `hisplora`. Out of scope.

## Standard Build Gate

Every task's build step is this command. It is the only gate that proves the moves did not break the target.

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5" && xcodebuild build -project challange-5.xcodeproj -scheme challange-5 -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

## Target Structure

```
challange-5/challange-5/
├── App/                      6   shell, composition root, routing
├── Features/
│   ├── Onboarding/           3
│   ├── QuestList/            9
│   ├── QuestPreview/         5
│   ├── QuestRun/            16   largest feature
│   ├── RunSummary/           2
│   ├── SideQuest/           11
│   ├── Letters/              8   the journal surface
│   ├── Explorer/             3
│   ├── Map/                 26   only feature with sub-folders
│   │   ├── Interactive/     10
│   │   ├── Bali/             7
│   │   ├── Tiles/            5
│   │   └── Region/           4
│   └── Settings/             4
├── Shared/
│   ├── Components/           5
│   ├── Lore/                 5
│   ├── Strings/              1
│   └── Wireframe/            3   quarantine — see Findings
├── Services/                 9
└── Assets.xcassets/              unchanged
```

**Placement rule, applied uniformly:** a type lives in the one feature that uses it; in `Shared/` if two or more features use it; in `Services/` if it is a service or only a service's parameter/return type. Decided from the reference graph, not from names.

**MVVM is preserved, not replaced.** Feature-first and MVVM are different axes: MVVM decides which types exist and who talks to whom, folders decide filing. This plan renames zero types and changes zero lines, so the pattern is untouched by construction — `Features/QuestRun/` still holds `QuestRunView`, `QuestRunViewModel`, and its presentation models. What changes is that the three now sit together instead of being spread across `View/`, `ViewModel/`, and `Model/`. Reviewers who ask "did we lose MVVM?" should be pointed at the Task 9 gate: `0 insertions(+), 0 deletions(-)` across every `.swift` file.

**Why feature folders are flat.** Only `Map/` gets sub-folders, because only `Map/` exceeds ~16 files. Adding `View/`/`ViewModel/` inside a 3-file feature would rebuild the layer split at smaller scale and carry no information — the role is already in the filename suffix. This was chosen deliberately over an explicit-subfolder and a hybrid variant.

---

### Task 0: Baseline and branch

- [ ] **Step 1: Confirm a clean tree**

```bash
git status --porcelain -- . ':!.claude/plans/'
```

Expected: no output. Files under `.claude/plans/` are excluded because this plan document itself may be uncommitted — that is fine and is not a dirty tree. Any *other* output means real uncommitted work: stop and ask, do not stash it.

- [ ] **Step 2: Confirm the working branch**

The branch `rapihin-struktur` already exists and already points at `origin/master` (`af318fd`). Do not re-create it.

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git fetch origin && \
  git checkout rapihin-struktur && \
  git rev-list --left-right --count rapihin-struktur...origin/master
```

Expected: `0	0` — the branch is identical to `origin/master`. If the right-hand number is not 0, `origin/master` has moved on: rebase onto it before continuing, then re-check the file count in Step 3.

- [ ] **Step 3: Record the inventory**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  find . -name '*.swift' | sort > "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/.claude/reorg-baseline.txt" && \
  wc -l < "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/.claude/reorg-baseline.txt"
```

Expected: `116`. **If this is not 116, stop.** The branch has moved since this plan was written and the move lists must be re-derived — do not improvise placements.

- [ ] **Step 4: Confirm the build is green before touching anything** — run the Standard Build Gate. A failure here is pre-existing and not caused by this plan; report it and stop.

- [ ] **Step 5: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git add .claude/reorg-baseline.txt && \
  git commit -m "chore: record file inventory before reorg"
```

---
### Task 1: App shell (6 files)

**Files:** create `App`; move 6 files.

App shell and composition root. `SideQuestRouter` lives here because only `KultaraRootView` and `challange_5App` use it — it is wiring, not a side-quest rule.

- [ ] **Step 1: Move**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  mkdir -p App && \
  git mv challange_5App.swift App/challange_5App.swift && \
  git mv View/KultaraRootView.swift App/KultaraRootView.swift && \
  git mv View/Component/ScreenHost.swift App/ScreenHost.swift && \
  git mv Support/KultaraEnvironment.swift App/KultaraEnvironment.swift && \
  git mv View/ContentUnavailableScreen.swift App/ContentUnavailableScreen.swift && \
  git mv Support/SideQuestRouter.swift App/SideQuestRouter.swift
```

- [ ] **Step 2: Verify pure renames**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --cached --stat | tail -3
```

Expected: 6 files changed, `0 insertions(+), 0 deletions(-)`. Any non-zero line count is a plan violation — stop.

- [ ] **Step 3: Build** — run the Standard Build Gate.

- [ ] **Step 4: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git commit -m "chore: move app shell into feature folders"
```

---

### Task 2: Services (9 files)

**Files:** create `Services`; move 9 files.

Services plus the types that are only a service's parameter or return value (`LocationAuthorizationSnapshot`, `ErasureSummary`). `CameraCaptureView` is a UIViewControllerRepresentable wrapper over the capture session, so it stays beside `CameraSession`.

- [ ] **Step 1: Move**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  mkdir -p Services && \
  git mv Service/LocationService.swift Services/LocationService.swift && \
  git mv Service/AppPreferencesStore.swift Services/AppPreferencesStore.swift && \
  git mv Service/DataEraser.swift Services/DataEraser.swift && \
  git mv Service/StorageReporter.swift Services/StorageReporter.swift && \
  git mv Service/PhotoStore.swift Services/PhotoStore.swift && \
  git mv Service/CameraSession.swift Services/CameraSession.swift && \
  git mv View/Component/CameraCaptureView.swift Services/CameraCaptureView.swift && \
  git mv Model/LocationAuthorizationSnapshot.swift Services/LocationAuthorizationSnapshot.swift && \
  git mv Model/ErasureSummary.swift Services/ErasureSummary.swift
```

- [ ] **Step 2: Verify pure renames**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --cached --stat | tail -3
```

Expected: 9 files changed, `0 insertions(+), 0 deletions(-)`. Any non-zero line count is a plan violation — stop.

- [ ] **Step 3: Build** — run the Standard Build Gate.

- [ ] **Step 4: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git commit -m "chore: move services into feature folders"
```

---

### Task 3: Shared (14 files)

**Files:** create `Shared/Components`, `Shared/Lore`, `Shared/Strings`, `Shared/Wireframe`; move 14 files.

Everything measured as used by two or more features. `ContentFormatter` has 11 callers, `LoreClaimPresentation` 10, `BundledImage` 10. `Shared/Wireframe` is quarantine, not a blessing — see Findings.

- [ ] **Step 1: Move**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  mkdir -p Shared/Components Shared/Lore Shared/Strings Shared/Wireframe && \
  git mv View/Component/LabelledValue.swift Shared/Components/LabelledValue.swift && \
  git mv View/Component/BundledImage.swift Shared/Components/BundledImage.swift && \
  git mv View/Component/LocationStatusScreens.swift Shared/Components/LocationStatusScreens.swift && \
  git mv View/Component/CutsceneScreens.swift Shared/Components/CutsceneScreens.swift && \
  git mv View/Component/SystemSettingsLink.swift Shared/Components/SystemSettingsLink.swift && \
  git mv Model/LoreBlockPresentation.swift Shared/Lore/LoreBlockPresentation.swift && \
  git mv Model/LoreClaimPresentation.swift Shared/Lore/LoreClaimPresentation.swift && \
  git mv View/Component/LoreClaimList.swift Shared/Lore/LoreClaimList.swift && \
  git mv View/Component/StoryRevealScreen.swift Shared/Lore/StoryRevealScreen.swift && \
  git mv Support/StampArtwork.swift Shared/Lore/StampArtwork.swift && \
  git mv Support/ContentFormatter.swift Shared/Strings/ContentFormatter.swift && \
  git mv View/WireframeScreens.swift Shared/Wireframe/WireframeScreens.swift && \
  git mv View/Component/WireframeScreen.swift Shared/Wireframe/WireframeScreen.swift && \
  git mv Support/WireframeCatalog.swift Shared/Wireframe/WireframeCatalog.swift
```

- [ ] **Step 2: Verify pure renames**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --cached --stat | tail -3
```

Expected: 14 files changed, `0 insertions(+), 0 deletions(-)`. Any non-zero line count is a plan violation — stop.

- [ ] **Step 3: Build** — run the Standard Build Gate.

- [ ] **Step 4: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git commit -m "chore: move shared into feature folders"
```

---

### Task 4: Small features (12 files)

**Files:** create `Features/Onboarding`, `Features/RunSummary`, `Features/Explorer`, `Features/Settings`; move 12 files.

Four features with no contested members: every type each one uses is used by no other feature.

- [ ] **Step 1: Move**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  mkdir -p Features/Onboarding Features/RunSummary Features/Explorer Features/Settings && \
  git mv View/OnboardingView.swift Features/Onboarding/OnboardingView.swift && \
  git mv ViewModel/OnboardingViewModel.swift Features/Onboarding/OnboardingViewModel.swift && \
  git mv Model/OnboardingPage.swift Features/Onboarding/OnboardingPage.swift && \
  git mv View/RunSummaryView.swift Features/RunSummary/RunSummaryView.swift && \
  git mv ViewModel/RunSummaryViewModel.swift Features/RunSummary/RunSummaryViewModel.swift && \
  git mv View/ExplorerCardView.swift Features/Explorer/ExplorerCardView.swift && \
  git mv ViewModel/ExplorerCardViewModel.swift Features/Explorer/ExplorerCardViewModel.swift && \
  git mv Model/ExplorerCardPresentation.swift Features/Explorer/ExplorerCardPresentation.swift && \
  git mv View/SettingsView.swift Features/Settings/SettingsView.swift && \
  git mv ViewModel/SettingsViewModel.swift Features/Settings/SettingsViewModel.swift && \
  git mv View/Component/SettingsSection.swift Features/Settings/SettingsSection.swift && \
  git mv View/Component/DeveloperToolsSection.swift Features/Settings/DeveloperToolsSection.swift
```

- [ ] **Step 2: Verify pure renames**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --cached --stat | tail -3
```

Expected: 12 files changed, `0 insertions(+), 0 deletions(-)`. Any non-zero line count is a plan violation — stop.

- [ ] **Step 3: Build** — run the Standard Build Gate.

- [ ] **Step 4: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git commit -m "chore: move small features into feature folders"
```

---

### Task 5: Quest list and preview (14 files)

**Files:** create `Features/QuestList`, `Features/QuestPreview`; move 14 files.

`PhotoQuestCard` goes to QuestList because both its callers (`QuestCard`, `PlaceholderQuestCard`) live there. `StoryPreviewScreen` goes to QuestPreview by name and by its only caller being the preview flow.

- [ ] **Step 1: Move**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  mkdir -p Features/QuestList Features/QuestPreview && \
  git mv View/QuestListView.swift Features/QuestList/QuestListView.swift && \
  git mv ViewModel/QuestListViewModel.swift Features/QuestList/QuestListViewModel.swift && \
  git mv Model/QuestListRow.swift Features/QuestList/QuestListRow.swift && \
  git mv View/Component/QuestCard.swift Features/QuestList/QuestCard.swift && \
  git mv View/Component/JournalEntryCard.swift Features/QuestList/JournalEntryCard.swift && \
  git mv Model/RunJournalSummary.swift Features/QuestList/RunJournalSummary.swift && \
  git mv View/Component/PlaceholderQuestCard.swift Features/QuestList/PlaceholderQuestCard.swift && \
  git mv Support/PlaceholderQuestCatalog.swift Features/QuestList/PlaceholderQuestCatalog.swift && \
  git mv View/Component/PhotoQuestCard.swift Features/QuestList/PhotoQuestCard.swift && \
  git mv View/QuestPreviewView.swift Features/QuestPreview/QuestPreviewView.swift && \
  git mv ViewModel/QuestPreviewViewModel.swift Features/QuestPreview/QuestPreviewViewModel.swift && \
  git mv Model/CheckpointPreviewRow.swift Features/QuestPreview/CheckpointPreviewRow.swift && \
  git mv View/Component/SectionContainer.swift Features/QuestPreview/SectionContainer.swift && \
  git mv View/Component/StoryPreviewScreen.swift Features/QuestPreview/StoryPreviewScreen.swift
```

- [ ] **Step 2: Verify pure renames**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --cached --stat | tail -3
```

Expected: 14 files changed, `0 insertions(+), 0 deletions(-)`. Any non-zero line count is a plan violation — stop.

- [ ] **Step 3: Build** — run the Standard Build Gate.

- [ ] **Step 4: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git commit -m "chore: move quest list and preview into feature folders"
```

---

### Task 6: Quest run (16 files)

**Files:** create `Features/QuestRun`; move 16 files.

The largest single feature at 16 files. `ArrivalSampling` is the arrival-decision surface that feeds RunEngine, and belongs with the run rather than with Services.

- [ ] **Step 1: Move**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  mkdir -p Features/QuestRun && \
  git mv View/QuestRunView.swift Features/QuestRun/QuestRunView.swift && \
  git mv ViewModel/QuestRunViewModel.swift Features/QuestRun/QuestRunViewModel.swift && \
  git mv Model/CheckpointPresentation.swift Features/QuestRun/CheckpointPresentation.swift && \
  git mv ViewModel/ArrivalSampling.swift Features/QuestRun/ArrivalSampling.swift && \
  git mv View/Component/TaskCard.swift Features/QuestRun/TaskCard.swift && \
  git mv View/Component/TaskDetailScreen.swift Features/QuestRun/TaskDetailScreen.swift && \
  git mv View/Component/CheckpointDetailScreen.swift Features/QuestRun/CheckpointDetailScreen.swift && \
  git mv View/Component/QuestExplanationScreen.swift Features/QuestRun/QuestExplanationScreen.swift && \
  git mv View/Component/QuestPhotoCaptureScreen.swift Features/QuestRun/QuestPhotoCaptureScreen.swift && \
  git mv View/Component/StampAwardScreen.swift Features/QuestRun/StampAwardScreen.swift && \
  git mv View/Component/PlaceNoticeScreen.swift Features/QuestRun/PlaceNoticeScreen.swift && \
  git mv View/Component/PlaceSiteMapScreen.swift Features/QuestRun/PlaceSiteMapScreen.swift && \
  git mv Model/SiteMapPresentation.swift Features/QuestRun/SiteMapPresentation.swift && \
  git mv View/Component/RunRouteMapView.swift Features/QuestRun/RunRouteMapView.swift && \
  git mv Model/RunRoutePresentation.swift Features/QuestRun/RunRoutePresentation.swift && \
  git mv Support/ExternalMapsLink.swift Features/QuestRun/ExternalMapsLink.swift
```

- [ ] **Step 2: Verify pure renames**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --cached --stat | tail -3
```

Expected: 16 files changed, `0 insertions(+), 0 deletions(-)`. Any non-zero line count is a plan violation — stop.

- [ ] **Step 3: Build** — run the Standard Build Gate.

- [ ] **Step 4: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git commit -m "chore: move quest run into feature folders"
```

---

### Task 7: Side quest and letters (19 files)

**Files:** create `Features/SideQuest`, `Features/Letters`; move 19 files.

`Features/Letters` is the journal surface you asked for — it already exists as sealed letters and a letter collection. `NearbySideQuestList` sits in SideQuest, not QuestList, because it is built entirely on `SideQuestPresentation`.

- [ ] **Step 1: Move**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  mkdir -p Features/SideQuest Features/Letters && \
  git mv View/SideQuestArrivalView.swift Features/SideQuest/SideQuestArrivalView.swift && \
  git mv View/SideQuestChallengeView.swift Features/SideQuest/SideQuestChallengeView.swift && \
  git mv View/SideQuestFlowView.swift Features/SideQuest/SideQuestFlowView.swift && \
  git mv View/SideQuestLetterView.swift Features/SideQuest/SideQuestLetterView.swift && \
  git mv View/SideQuestNoticeView.swift Features/SideQuest/SideQuestNoticeView.swift && \
  git mv View/SideQuestStoryView.swift Features/SideQuest/SideQuestStoryView.swift && \
  git mv ViewModel/SideQuestFlowViewModel.swift Features/SideQuest/SideQuestFlowViewModel.swift && \
  git mv Model/SideQuestPresentation.swift Features/SideQuest/SideQuestPresentation.swift && \
  git mv Service/SideQuestProximityService.swift Features/SideQuest/SideQuestProximityService.swift && \
  git mv View/Component/NearbySideQuestList.swift Features/SideQuest/NearbySideQuestList.swift && \
  git mv ViewModel/NearbySideQuestListViewModel.swift Features/SideQuest/NearbySideQuestListViewModel.swift && \
  git mv View/JournalLetterView.swift Features/Letters/JournalLetterView.swift && \
  git mv View/LetterCollectionView.swift Features/Letters/LetterCollectionView.swift && \
  git mv ViewModel/LetterCollectionViewModel.swift Features/Letters/LetterCollectionViewModel.swift && \
  git mv Model/LetterCollectionPresentation.swift Features/Letters/LetterCollectionPresentation.swift && \
  git mv View/SealedLettersView.swift Features/Letters/SealedLettersView.swift && \
  git mv ViewModel/SealedLettersViewModel.swift Features/Letters/SealedLettersViewModel.swift && \
  git mv Model/SealedLetterPresentation.swift Features/Letters/SealedLetterPresentation.swift && \
  git mv View/Component/SealedLetterEnvelope.swift Features/Letters/SealedLetterEnvelope.swift
```

- [ ] **Step 2: Verify pure renames**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --cached --stat | tail -3
```

Expected: 19 files changed, `0 insertions(+), 0 deletions(-)`. Any non-zero line count is a plan violation — stop.

- [ ] **Step 3: Build** — run the Standard Build Gate.

- [ ] **Step 4: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git commit -m "chore: move side quest and letters into feature folders"
```

---

### Task 8: Map (26 files)

**Files:** create `Features/Map/Interactive`, `Features/Map/Bali`, `Features/Map/Tiles`, `Features/Map/Region`; move 26 files.

26 files — the only feature that gets sub-folders, because it is four separable surfaces: the interactive quest map, the illustrated Bali map, the OpenMapTiles rendering stack, and the older region map.

- [ ] **Step 1: Move**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  mkdir -p Features/Map/Interactive Features/Map/Bali Features/Map/Tiles Features/Map/Region && \
  git mv View/HisploraMapView.swift Features/Map/Interactive/HisploraMapView.swift && \
  git mv ViewModel/HisploraMapViewModel.swift Features/Map/Interactive/HisploraMapViewModel.swift && \
  git mv View/Component/HisploraMapCanvas.swift Features/Map/Interactive/HisploraMapCanvas.swift && \
  git mv View/Component/HisploraMapMarkerViews.swift Features/Map/Interactive/HisploraMapMarkerViews.swift && \
  git mv Model/HisploraMapProjection.swift Features/Map/Interactive/HisploraMapProjection.swift && \
  git mv Model/HisploraGeoData.swift Features/Map/Interactive/HisploraGeoData.swift && \
  git mv Model/HisploraQuestLocation.swift Features/Map/Interactive/HisploraQuestLocation.swift && \
  git mv View/Component/HisploraQuestCard.swift Features/Map/Interactive/HisploraQuestCard.swift && \
  git mv View/Component/HisploraBuildingInspectionCard.swift Features/Map/Interactive/HisploraBuildingInspectionCard.swift && \
  git mv View/HisploraInteractiveMapScreen.swift Features/Map/Interactive/HisploraInteractiveMapScreen.swift && \
  git mv View/HisploraBaliMapScreen.swift Features/Map/Bali/HisploraBaliMapScreen.swift && \
  git mv View/HisploraBaliMapView.swift Features/Map/Bali/HisploraBaliMapView.swift && \
  git mv ViewModel/HisploraBaliMapViewModel.swift Features/Map/Bali/HisploraBaliMapViewModel.swift && \
  git mv View/Component/HisploraBaliMapCanvas.swift Features/Map/Bali/HisploraBaliMapCanvas.swift && \
  git mv View/Component/HisploraBaliRegionCard.swift Features/Map/Bali/HisploraBaliRegionCard.swift && \
  git mv Model/HisploraBaliGeoData.swift Features/Map/Bali/HisploraBaliGeoData.swift && \
  git mv Model/HisploraBaliMapProjection.swift Features/Map/Bali/HisploraBaliMapProjection.swift && \
  git mv Model/OpenMapTilesDataset.swift Features/Map/Tiles/OpenMapTilesDataset.swift && \
  git mv Model/OpenMapTilesSchema.swift Features/Map/Tiles/OpenMapTilesSchema.swift && \
  git mv Model/OpenMapTilesStyleEngine.swift Features/Map/Tiles/OpenMapTilesStyleEngine.swift && \
  git mv View/Component/OpenMapTilesCanvasRenderer.swift Features/Map/Tiles/OpenMapTilesCanvasRenderer.swift && \
  git mv Model/GeoLibreBuildingEngine.swift Features/Map/Tiles/GeoLibreBuildingEngine.swift && \
  git mv View/RegionMapView.swift Features/Map/Region/RegionMapView.swift && \
  git mv ViewModel/RegionMapViewModel.swift Features/Map/Region/RegionMapViewModel.swift && \
  git mv Model/RegionMapPin.swift Features/Map/Region/RegionMapPin.swift && \
  git mv Support/MapLandmarkCatalog.swift Features/Map/Region/MapLandmarkCatalog.swift
```

- [ ] **Step 2: Verify pure renames**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --cached --stat | tail -3
```

Expected: 26 files changed, `0 insertions(+), 0 deletions(-)`. Any non-zero line count is a plan violation — stop.

- [ ] **Step 3: Build** — run the Standard Build Gate.

- [ ] **Step 4: Commit**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git commit -m "chore: move map into feature folders"
```

---
### Task 9: Retire the old folders, verify, document

- [ ] **Step 1: Confirm the old folders are empty and remove them**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && \
  find Model View ViewModel Service Support -type f 2>/dev/null; \
  echo "--- nothing above means empty ---"; \
  rmdir View/Component View Model ViewModel Service Support
```

Expected: no files listed, `rmdir` silent. If it reports "Directory not empty", a file was missed — move it to the folder the Target Structure names, then continue.

- [ ] **Step 2: Confirm every file is accounted for**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/challange-5" && find . -name '*.swift' | wc -l
```

Expected: `116` — same as Task 0.

- [ ] **Step 3: Prove the whole branch changed no Swift content**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git diff -M --stat origin/master...HEAD -- '*.swift' | tail -3
```

Expected: `0 insertions(+), 0 deletions(-)`. Any Swift file with changed lines is a plan violation — investigate before continuing.

- [ ] **Step 4: Build and run every test suite**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5/Packages/Kultara" && \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -3
```

Expected: all suites pass. This package was never touched, so it is a control — a failure means something unexpected happened.

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5/challange-5" && xcodebuild test -project challange-5.xcodeproj -scheme challange-5 -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`. This covers `challange-5Tests` and `challange-5UITests` and is the only gate that exercises the moved code at runtime.

- [ ] **Step 5: Update `CLAUDE.md`**

Replace the app-target tree in `## Directory layout` with the Target Structure above. In the same edit, correct three claims that are now stale: the `AppFeatures` package target does not exist; the app target *does* have unit tests (`challange-5Tests`); and the package has seven targets, not four (add `GovernanceKit`, `TelemetryKit`, `UIStringsKit`). Add the `DEVELOPER_DIR` note to the `swift test` command in `## Commands`.

- [ ] **Step 6: Commit and push**

```bash
cd "/Users/imelda/Documents/Swift/5. Challenge 5/challenge5" && git rm .claude/reorg-baseline.txt && git add CLAUDE.md && \
  git commit -m "docs: describe the feature-first layout" && \
  git push -u origin rapihin-struktur
```

- [ ] **Step 7: Tell the team to rebase**

This branch renames all 116 app-target files. Every open branch must rebase onto it, and the longer they wait the worse the conflicts. Post the branch name and this command:

```bash
git fetch origin && git rebase origin/rapihin-struktur
```

Git follows renames during rebase, so a teammate whose commits only *edit* files will usually rebase cleanly. A teammate who *added* a file will find it in the old folder and must move it into the structure above by hand.

---

## Findings: not fixed here, deliberately

Each of these is real. None belongs in a move-only change.

1. **`QuestPreviewView.swift` is unreachable.** Nothing in the codebase references it. The quest-preview screen appears to have been orphaned by newer navigation. This plan still moves it to `Features/QuestPreview/` — deleting code is not tidying. Decide separately whether the preview flow is still wanted.
2. **`OpenMapTilesCanvasRenderer.swift` is unreferenced** and is the only member of the tiles stack nothing calls. Likely dead, but it is 1 of 5 files in a rendering subsystem — confirm against the map work in flight before removing.
3. **`Shared/Wireframe/` is production code, not scaffolding.** `WireframeCatalog` is referenced by `RunSummaryView`, `SideQuestNoticeView`, and `PlaceholderQuestCatalog`. Shipping screens read from a wireframe catalogue. The folder name is a warning label; either promote this to real content or cut the dependency.
4. **`Features/Map/` is 26 files — a subsystem inside the app target**, with its own geo data, projection maths, and tile-rendering engine, none of which is SwiftUI-specific. It is the strongest candidate to become a package target (like `ContentKit`), which would make the projection maths testable without a simulator. The sub-folders this plan creates are the seam.
5. **`QuestRunViewModel` remains the biggest file** and `Features/QuestRun/` the biggest feature at 16 files. Worth splitting, with tests, as its own change.
6. **No `Profile` feature exists.** You asked for the name only, and no folder was invented for it. `Features/Settings/` is the nearest surface.
7. **The app is now called `hisplora`** in the watch target, while the code says `Kultara` throughout and the folder says `challange-5`. Three names for one product. Worth settling before release; renaming touches schemes and bundle IDs and is not tidying.
