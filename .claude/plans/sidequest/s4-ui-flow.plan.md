# S4 — Screens, view models, presentation models

Phase B (everything but photo), Phase D (photo). App target: `Model/`, `ViewModel/`, `View/`,
`Support/`.

## 1. The flow

```
notification tap  ─┐
in-app entry      ─┤→  SideQuestNoticeView        synopsis + "wanna see the story?"
debug trigger     ─┘        │  no → dismiss, nothing recorded but the alert row
                            │  yes
                            ▼
                    SideQuestArrivalView          the FR-ARR-01 gate, 60 s override
                            │  arrived (gps | manual) → discover(), snapshot taken
                            ▼
                    SideQuestStoryView            one page per LoreBlock, labelled
                            │
                            ▼
                    SideQuestChallengeView        quiz options, or photo prompt
                            │  completed
                            ▼
                    SideQuestLetterView           the letter, and the phrase so far
                            │
                            ▼
                    LetterCollectionView          (also reachable from Journal)
```

Backing out of any stage leaves the record where it is. An incomplete sidequest is re-openable at the
place forever (`FR-SIDE-07`) and from the collection screen's slot, which is why nothing here is a
one-shot presentation.

## 2. Theme seam

Two visual directions, split at a screen boundary, never inside one. The seam here:

| Screen | Direction | Why |
|---|---|---|
| Notice, Arrival, Story, Challenge, Letter | **Hisplora** | it is a story flow, and it is the same flow the run's story stages already use |
| Collection, the Journal entry point, Settings toggle | **Kultara** (museum) | they are catalogue surfaces, and they sit inside chrome that is already museum |

`SideQuestFlowView.isOnStoryFlow` mirrors `QuestRunView.isOnStoryFlow`, hides the museum navigation
bar for those stages, and hides the floating tab bar the same way a Run does — a bar over a
full-screen story sits on the control the screen is asking for.

**Museum-inked components must not be dropped onto a Hisplora ground.** They are measured against
paper. Anything reused from the run flow inside these screens takes the same `showsChrome:` treatment
`RunRouteMapView` does, and any new colour pair goes through `DesignSystem/Contrast.swift` and the
palette's `contrastPairs` before it renders — a colour that is not in a measured pair fails the
suite rather than shipping (`NFR-A11Y-03`).

## 3. Presentation models — `Model/`

`Sendable` value types, strings already resolved, distances already formatted. Not the domain model:
no `SideQuest`, no `SideQuestRecord`, no repository, no palette.

```swift
struct SideQuestPresentation: Sendable, Identifiable {
    let id: String
    let placeName: String
    let title: String
    let synopsis: String
    let isSacred: Bool
    let dressCodeText: String
    let photoPolicyText: String
    let claims: [LoreClaimPresentation]     // reused from the checkpoint screen
    let challenge: ChallengePresentation
    let heroImageURL: URL?
    let triggerRadiusM: Int
    let coordinate: Coordinate
}

enum ChallengePresentation: Sendable {
    case quiz(QuizPresentation)
    case photo(prompt: String)
}

struct QuizPresentation: Sendable {
    let question: String
    let options: [QuizOptionPresentation]   // id + text; correctness never crosses this boundary
    let explanation: String
}

struct LetterSlotPresentation: Sendable, Identifiable {
    let id: Int
    let letter: String?                     // nil while unearned — the blank is the game
    let placeName: String?
    let dateText: String?
    let isEarned: Bool
}

struct LetterCollectionPresentation: Sendable {
    let title: String
    let caption: String
    let maskedPhrase: String
    let progressText: String                // "7 / 15"
    let slots: [LetterSlotPresentation]
    let isComplete: Bool
}
```

`QuizOptionPresentation` deliberately carries no `isCorrect`. Grading happens in `SideQuestQuiz`
behind the engine; a correctness flag sitting in a value the view holds is a flag some future layout
change will render.

## 4. View models — `ViewModel/`

One `@MainActor @Observable` class per screen, no SwiftUI import, held in `@State` via `ScreenHost`.
A view model built inside a `body` is rebuilt on every redraw and takes its location provider with
it — that is the bug that presented as an arrival screen which never found a fix.

### `SideQuestFlowViewModel`

Owns the whole flow, as `QuestRunViewModel` owns the run.

```swift
enum Stage: Equatable {
    case notice, locationNotice, awaitingArrival, story, challenge, letter, done
}
```

Reused wholesale from `QuestRunViewModel`, and worth reusing rather than reinventing:

- the sampling lifecycle — `screenAppeared` / `screenDisappeared`, `locationProvider.stop()` when the
  screen goes away (`NFR-BAT-04`);
- `ManualOverrideSchedule` for the bounded 60-second wait, the countdown text, and the determinate
  progress (`FR-ARR-05`: a number that moves, never an indefinite spinner);
- the `ArrivalStatus` → `LocationState` mapping, where "inside the radius but the fix is too coarse"
  draws *Not Quite There*, not *Verified*;
- `.permissionDenied` making the override immediate, because waiting a minute for a fix that cannot
  arrive is a minute of pretending to look (`FR-ERR-02`).

Refactor note: those five behaviours are currently private to `QuestRunViewModel`. Extract them into
an `ArrivalSampling` helper in the app target that both view models own, rather than copying them.
Copying is how the two screens end up disagreeing about what arrival means.

New surface:

```swift
var quizSelection: Int?
func selectOption(_ index: Int)
func submitQuiz()               // → engine.answerQuiz, then stage = .letter on success
var quizFeedback: QuizFeedback? // wrong / correct / revealed, with the explanation
func attachPhoto(_ relativePath: String)   // Phase D
func openCollection()
```

### `LetterCollectionViewModel`

Reads `SideQuestEngine.progress(collectionID:)` and maps it to `LetterCollectionPresentation`. It
takes the engine, not the repository plus the store — one caller, one rule set.

### `NearbySideQuestListViewModel` (Phase B only)

Before notifications exist, there has to be a way in. A "Places nearby" list in the Quests tab, sorted
by straight-line distance from the last known fix, each row opening the notice. It survives Phase C as
the manual browse path — a walker who dismissed a notification needs a way back, and
`FR-SIDE-07` promises one.

## 5. Views — `View/`

| File | Notes |
|---|---|
| `SideQuestNoticeView.swift` | Hisplora. Synopsis, place name, the yes/no question. **Sacred-place notices come first**: dress code and photo policy are shown before any challenge is offered (`FR-TASK-05`), exactly as `CheckpointScreen` does. |
| `SideQuestArrivalView.swift` | Hisplora. Reuses `LocationStatusScreens` — checking / not-there / denied — and the override sheet (`FR-START-10`: a control the walker needs when GPS has failed cannot be the quietest line on a scrolling screen). |
| `SideQuestStoryView.swift` | Hisplora. Reuses `StoryRevealScreen`'s pager, **plus** the accuracy chip and citations (`s0` D6). That is a change to `StoryRevealScreen`: it gains a `showsProvenance: Bool`, defaulting false so the run flow's signed exception is untouched. |
| `SideQuestChallengeView.swift` | Hisplora. Quiz: options as large targets, one column, min 44 pt (`NFR-A11Y-06`). Feedback in text as well as colour (`NFR-A11Y-05`). |
| `SideQuestLetterView.swift` | Hisplora. The letter, big; the phrase so far below it; "keep exploring" and "see the collection". |
| `LetterCollectionView.swift` | Kultara. The masked phrase as a grid of slots, then a list of places — earned rows open the read-back, unearned rows say only "not yet found" and never the place name **or** the letter. |
| `Component/NearbySideQuestList.swift` | Kultara, in the Quests tab. |

The unearned row hiding the place name is a real decision: showing it turns the collection into a
checklist of addresses and removes the reason to be surprised by a notification. Product may overrule
it; if they do, it is a line in `s7`, not a quiet change here.

## 6. Root wiring

`KultaraRootView` gains:

- `pendingSideQuestID: String?` — set by the notification delegate, consumed to present the flow,
  cleared after. Presented as a full-screen cover over whatever tab is showing, since it arrives from
  outside the navigation stacks.
- a Journal-tab destination for `LetterCollectionView`.
- suppression of both entry paths while `runDestination != nil` (`FR-PROX-08`, belt and braces over
  `ProximityGate`).

`KultaraEnvironment` gains `sideQuestStore`, `sideQuestEngine`, and `proximity` alongside the existing
members, assembled once.

## 7. Photo challenge — Phase D

The app has no photo pipeline at all today. What this adds:

- `Service/PhotoStore.swift` — writes a JPEG into `Documents/sidequest-photos/<recordID>.jpg`, returns
  the **relative** path. An absolute path resolves to nothing after a restore from backup and the
  user's photographs appear to have vanished (`NFR-REL-05`). `TaskResult.photoRelativePath` already
  exists with this exact comment on it and no writer; this is the writer.
- Camera and library via `PHPickerViewController` / `UIImagePickerController`, with
  `NSCameraUsageDescription` and no photo-library **write** access requested.
- Downscale to a sane long edge before writing. Fifteen full-resolution photographs is a storage
  report nobody expects (`FR-SET-03` shows the number).
- Runtime policy gate: a photo challenge is not offered where `photoPolicy.level == .prohibited`,
  mirroring what `QuestRunViewModel.presentation` already does for photo tasks. Validator rule V23 is
  the build-time half; this is the half that matters when content is corrected after a build.
- The photograph never leaves the device (`NFR-PRIV-01`) and is deleted by `FR-SET-02` erasure along
  with its record.

Until Phase D lands, a photo challenge renders its prompt, says photos are not in this build, and the
letter is awarded on acknowledgement — the same shape M6 used for photo tasks. Content authored before
Phase D should prefer quizzes.

## 8. Strings

New `UIStringKey` cases, all bilingual (`NFR-I18N-01/02`):

```
sideQuestNoticeTitle, sideQuestNoticeQuestion, sideQuestNoticeYes, sideQuestNoticeNo,
sideQuestNearbyHeading, sideQuestNearbyEmpty, sideQuestDistanceAway,
sideQuestStoryHeading, sideQuestChallengeHeading, sideQuestQuizSubmit,
sideQuestQuizWrong, sideQuestQuizCorrect, sideQuestQuizRevealed, sideQuestQuizExplanation,
sideQuestPhotoPrompt, sideQuestPhotoTake, sideQuestPhotoChoose, sideQuestPhotoNotInThisBuild,
sideQuestLetterAwarded, sideQuestLetterProgress, sideQuestCollectionOpen,
collectionHeading, collectionProgress, collectionSlotLocked, collectionComplete,
collectionBadgeAwarded,
settingsNearbyAlertsHeading, settingsNearbyAlertsToggle, settingsNearbyAlertsExplanation,
settingsNearbyAlertsNeedsAlways, settingsNearbyAlertsNeedsNotifications,
devSimulatePassingTitle, devSimulatePassingNote
```

**Warning that must not be skipped.** UI-string ID/EN parity is currently held by nothing:
`everyKeyHasAnEntry`, `everyEntryIsTranslatedInBothLanguages` and
`indonesianAndEnglishAreActuallyDifferentText` were deleted with `AppFeaturesTests` at `b597b5b`, and
the app target has no unit-test bundle to receive them. Adding ~30 keys without those guards means a
missing entry renders the raw key name at runtime and nothing fails.

Do one of these before Phase B merges:

1. land `m7-restore-test-guards.plan.md` (a unit-test target for the app), or
2. move `UIStrings.table` into a package target so `swift test` can assert over it. It depends only on
   `ContentKit.LocalizedText`, so this is mechanical — a `UIStringsKit` target between `ContentKit` and
   `DesignSystem`, imported by the app.

Option 2 is the smaller change and unblocks every future screen too.

Also delete `WireframeCatalog.nearbyNotice` and `WireframeCatalog.nearbyStory` in the same commit that
ships their real screens, and remove them from `WireframeScreens.swift` (`s0` D12).

## 9. Accessibility checklist for these screens

| Requirement | What it means here |
|---|---|
| `NFR-A11Y-01` | every slot, option and letter has a spoken label; the masked phrase reads "B, blank, L, I…", not underscores |
| `NFR-A11Y-02` | largest Dynamic Type: quiz options wrap rather than truncate; the letter grid reflows |
| `NFR-A11Y-03` | every Hisplora pair used here is in `contrastPairs` and measured |
| `NFR-A11Y-05` | right/wrong is text plus shape, never colour alone |
| `NFR-A11Y-06` | 44 pt minimum on options and slots |
| reduce motion | the typewriter reveal and the letter animation respect `accessibilityReduceMotion`, as `HisploraMotion` already does |
