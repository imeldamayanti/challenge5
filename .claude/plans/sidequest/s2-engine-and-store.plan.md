# S2 — Records, store, engine, and the pure values that hold the rules

Phase A. Package: `Packages/Kultara/Sources/RunEngine`. Foundation + ContentKit only.

Everything a reviewer would want to be sure of lives here, because here is the only place it can be
tested: `swift test` on macOS, no simulator, no device (`s0` D10).

## 1. `SideQuestRecord` — the user-data aggregate

`Sources/RunEngine/SideQuestRecords.swift`. Same rule as `Run`: no object reference into content,
ever. String ids and snapshots.

```swift
public enum SideQuestState: String, Codable, Sendable, CaseIterable {
    /// Entered the radius and opened the notice. The story may or may not have been read.
    case discovered
    /// The challenge is done and the letter is awarded. Terminal.
    case completed
}

public struct SideQuestChallengeResult: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case quiz, photo }
    public let kind: Kind
    /// The question as it was asked, so the record still reads back after the wording is edited.
    public let promptSnapshot: String
    /// Every attempt, right or wrong. Kept because a question everyone gets wrong three times is a
    /// badly written question, and this is the only place that would show it.
    public let attempts: Int
    public let chosenOptionSnapshot: String?
    public let isCorrect: Bool?
    /// Whether the answer was revealed after three attempts (`s0` D5) rather than found.
    public let wasRevealed: Bool
    /// Relative to the app container, never absolute (`NFR-REL-05`).
    public let photoRelativePath: String?
    public let answeredAt: Date
}

public struct SideQuestRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let sideQuestID: String
    public let placeID: String
    public let collectionID: String
    public let slotIndex: Int
    /// The letter, copied. A collection is a record of where somebody has been, and it has to
    /// survive the content that described those places (`s0` D8).
    public let letter: String

    public let language: ContentLanguage
    /// `manifest.contentBundleVersion`, pinned at discovery.
    public let contentVersion: String

    public let discoveredAt: Date
    public let arrivalMethod: ArrivalMethod
    public let gpsAccuracyM: Double?

    // ── Content snapshot, captured at discovery ──
    public let snapshotPlaceName: String
    public let snapshotTitle: String
    public let snapshotSynopsis: String
    public let snapshotLore: [LoreBlockSnapshot]

    public var state: SideQuestState
    public var loreFirstOpenedAt: Date?
    public var challenge: SideQuestChallengeResult?
    public var completedAt: Date?
    public var updatedAt: Date
}
```

`ArrivalMethod`, `LoreBlockSnapshot` and `Award` are reused unchanged. `AwardType` gains a case:

```swift
public enum AwardType: String, Codable, Sendable, CaseIterable {
    case stamp, badge, letter
}
```

Adding a case to a raw-`String` enum is safe for stored data; adding one to a raw-`Int` enum is not,
which is why `schema.md`'s Appendix requires string raws in the first place.

A letter award and a collection-completion badge are both `Award`s, held on the record and on the
collection progress respectively. `Award.sourceID` is the slot's `sideQuestId` for a letter and the
collection's `badgeId` for the badge.

## 2. `SideQuestStore`

```swift
@MainActor
public protocol SideQuestStore: AnyObject {
    func records() throws -> [SideQuestRecord]
    func record(sideQuestID: String) throws -> SideQuestRecord?
    func save(_ record: SideQuestRecord) throws
    func delete(sideQuestID: String) throws
    @discardableResult func deleteAll() throws -> Int
}
```

`InMemorySideQuestStore` for tests, `FileSideQuestStore` for the app: one JSON document per record
under `Application Support/Kultara/sidequests`, written atomically, a corrupt document skipped at load
rather than thrown (`NFR-REL-04` — one bad file costs one place, not the app's launch). Directly
mirrors `FileRunStore`, and for the same stated reasons.

**Lookup is by `sideQuestID`, not by UUID.** There is at most one record per sidequest, which is the
idempotency rule from `FR-SIDE-05` expressed in the store's shape rather than in a guard somebody can
forget to write. Re-entering a place that is already completed finds the existing record.

`DataEraser` (`FR-SET-02`) and `StorageReporter` both gain this directory. Erasure that leaves the
letters behind would be a lie told by a confirmation dialog.

## 3. `SideQuestEngine`

`@MainActor`, mirrors `RunEngine`: it is the only thing that writes sidequest data, and it takes
arrival as a decided fact — a method and an accuracy, never a `CLLocation`.

```swift
@MainActor
public struct SideQuestEngine {
    public init(repository: any ContentRepository,
                store: any SideQuestStore,
                now: @escaping @Sendable () -> Date = { Date() })

    // Queries
    public func record(sideQuestID: String) throws -> SideQuestRecord?
    public func records() throws -> [SideQuestRecord]
    public func progress(collectionID: String) throws -> LetterCollectionProgress

    // Writes
    @discardableResult
    public func discover(sideQuestID: String, language: ContentLanguage,
                         method: ArrivalMethod, accuracyM: Double?) throws -> SideQuestRecord
    @discardableResult
    public func markLoreOpened(sideQuestID: String) throws -> SideQuestRecord
    @discardableResult
    public func answerQuiz(sideQuestID: String, optionIndex: Int) throws -> QuizOutcome
    @discardableResult
    public func completePhoto(sideQuestID: String, relativePath: String) throws -> SideQuestRecord
}
```

Behaviour worth stating:

- `discover` is **idempotent**. Called on a record that exists, it returns it untouched — no second
  snapshot, no re-pinned version, no duplicate letter. A walker who passes a place twice on the same
  afternoon must not get two rows.
- `answerQuiz` is the only place a letter is awarded, and it awards at most one, ever. It works on a
  `completed` record too, returning the stored outcome rather than throwing — the same reason
  `markLoreOpened` accepts a completed `Run`: the user is still standing there and may reopen the
  screen.
- Nothing here touches `Run`, `RunStore`, or `RunEngine`. `FR-SIDE-01` is held by there being no call
  that could.

```swift
public struct QuizOutcome: Sendable, Equatable {
    public let isCorrect: Bool
    public let attempts: Int
    /// True once the answer is shown after three wrong attempts (`s0` D5).
    public let isRevealed: Bool
    public let correctOptionText: String?
    public let explanationText: String?
    public let awardedLetter: String?
}
```

## 4. `SideQuestQuiz` — grading as a pure value

```swift
public enum SideQuestQuiz {
    public static let revealAfterAttempts = 3

    public static func grade(chosenIndex: Int, correctIndex: Int, priorAttempts: Int)
        -> (isCorrect: Bool, attempts: Int, isRevealed: Bool)
}
```

Three lines of logic, and worth its own type for one reason: the "reveal after three" rule is a
product promise about how forgiving the app is, and a promise made in an `if` inside a view model is
a promise nobody can check.

## 5. `LetterCollectionProgress` — what the collection screen renders

```swift
public struct LetterCollectionProgress: Sendable, Equatable {
    public struct Slot: Sendable, Equatable, Identifiable {
        public var id: Int { index }
        public let index: Int
        public let sideQuestID: String
        /// `nil` until earned. A place the walker has never been to must not reveal its letter
        /// (`FR-SIDE-08`) — the blank is the whole game.
        public let letter: String?
        public let placeName: String?
        public let completedAt: Date?
    }
    public let collectionID: String
    public let phrase: String
    public let slots: [Slot]
    public var earnedCount: Int
    public var totalCount: Int
    public var isComplete: Bool
    /// `B _ L I   T H _   _ _ _ _ _ _ _ _`, spaces preserved from the phrase.
    public func maskedPhrase(placeholder: String = "_") -> String
}
```

Computed from the content collection plus the records — never stored. Storing it would create a
second source of truth for "how far am I", and the two would drift the first time a record was
deleted by erasure.

`maskedPhrase` must not leak the answer: an unearned slot renders the placeholder, not a dimmed
letter, and the accessibility label spells out earned letters and says "blank" for the rest rather
than reading the underscores (`NFR-A11Y-01`).

## 6. `ProximityGate` and `RegionBudget` — the notification rules, without CoreLocation

These are the two values that make Phase C testable. Both live here; the service in `s3` is an
adapter over them.

```swift
/// Whether an alert may be posted right now, and if not, why (`FR-PROX-08/09/10`).
public struct ProximityGate: Sendable {
    public struct Limits: Sendable, Equatable {
        public var quietFrom = TimeOfDay(hour: 22, minute: 0)
        public var quietUntil = TimeOfDay(hour: 7, minute: 0)
        public var perTargetCooldown: TimeInterval = 24 * 3600
        public var maxPerDay = 3
    }
    public enum Decision: Sendable, Equatable {
        case allow
        case blockedByActiveRun
        case blockedByQuietHours
        case blockedByCooldown(secondsRemaining: TimeInterval)
        case blockedByDailyCap
        case blockedByCompletion
    }
    public static func decide(targetID: String,
                              now: Date,
                              calendar: Calendar,
                              alerts: [ProximityAlert],
                              hasActiveRun: Bool,
                              isTargetCompleted: Bool,
                              limits: Limits = .init()) -> Decision
}

/// The only thing persisted about a region entry: which target, and when (`schema.md` §B.8).
/// No coordinates, no dwell, no trajectory — a movement history is what `NFR-PRIV-09` forbids.
public struct ProximityAlert: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let targetID: String
    public let shownAt: Date
}
```

```swift
/// iOS monitors 20 regions per app, shared across quests and sidequests (`FR-PROX-14`).
public enum RegionBudget {
    public static let iosRegionLimit = 20

    public struct Candidate: Sendable, Equatable {
        public let id: String
        public let coordinate: Coordinate
        public let radiusM: Int
        /// Quest starts outrank sidequests: a quest is the thing the app is for.
        public let priority: Int
    }

    /// Nearest-first within priority, capped. Deterministic ties by id, so two runs of the same
    /// input register the same regions and the app does not churn registrations on every launch.
    public static func select(candidates: [Candidate],
                              near coordinate: Coordinate?,
                              limit: Int = iosRegionLimit) -> [Candidate]
}
```

`near: nil` — no coarse position yet — returns the first `limit` candidates in authored order rather
than nothing. Registering nothing because location has not warmed up is the failure mode that reads
as "the feature doesn't work".

## 7. Quiet hours are local wall time, and that is deliberate

`ProximityGate` takes a `Calendar` and compares `TimeOfDay` values, not `Date`s in UTC. A walker in
Denpasar at 22:30 must not be notified, whatever the phone's region settings say about anything else.
`TimeOfDay` already exists for exactly this: opening hours are wall times at the site, never instants.

Midnight wrap is the case to get right and to test: `quietFrom = 22:00`, `quietUntil = 07:00` means
the blocked window crosses a date boundary, and the naive `from <= t && t < until` comparison blocks
nothing at all.

## 8. Tests — `Tests/RunEngineTests/SideQuestEngineTests.swift` and friends

Named as the existing suites are: sentences about behaviour, not method names.

| Test | Holds |
|---|---|
| `discoveringCopiesTheStoryAndItsCitationsIntoTheRecord` | `s0` D8 |
| `aSecondDiscoveryOfTheSamePlaceChangesNothing` | idempotency, `FR-SIDE-05` |
| `theLetterIsAwardedOnceEvenWhenTheQuizIsReopened` | `FR-SIDE-05` |
| `aWrongAnswerAwardsNothingAndBlocksNothing` | `s0` D4 |
| `theAnswerIsRevealedOnTheThirdAttemptAndTheLetterIsStillAwarded` | `s0` D5 |
| `aRecordStillRendersAfterThePlaceIsWithdrawn` | `FR-SIDE-10` |
| `theSnapshotIsInTheRecordsPinnedLanguageNotTheAppsCurrentOne` | `NFR-I18N-04` |
| `completingASidequestChangesNoRun` | `FR-SIDE-01` |
| `anUnearnedSlotRendersABlankAndNotItsLetter` | `FR-SIDE-08` |
| `theCollectionBadgeIsAwardedOnTheLastLetterAndNotBefore` | `FR-SIDE-09` |
| `anAlertIsBlockedInsideQuietHoursAcrossMidnight` | `FR-PROX-10` |
| `aSecondAlertForTheSamePlaceWithin24HoursIsBlocked` | `FR-PROX-09` |
| `aFourthAlertInOneDayIsBlockedEvenForDifferentPlaces` | `FR-PROX-09` |
| `noAlertIsAllowedWhileARunIsActive` | `FR-PROX-08` |
| `aCompletedSidequestIsNotACandidateForMonitoring` | `s0` D9 |
| `regionSelectionPrefersQuestStartsThenNearestSidequests` | `FR-PROX-14` |
| `regionSelectionIsStableForTheSameInput` | avoids re-registration churn |
| `regionSelectionWithNoPositionStillReturnsRegions` | §6 |

Plus `SideQuestStoreTests` mirroring `RunStoreTests`: durability across instances, a corrupt document
costing one record, `deleteAll` returning a count.

## 9. Files touched

| File | Change |
|---|---|
| `Sources/RunEngine/SideQuestRecords.swift` | new |
| `Sources/RunEngine/SideQuestStore.swift` | new |
| `Sources/RunEngine/SideQuestEngine.swift` | new |
| `Sources/RunEngine/SideQuestQuiz.swift` | new |
| `Sources/RunEngine/LetterCollectionProgress.swift` | new |
| `Sources/RunEngine/Proximity.swift` | new — `ProximityGate`, `ProximityAlert`, `RegionBudget` |
| `Sources/RunEngine/RunRecords.swift` | `AwardType.letter` |
| `Tests/RunEngineTests/SideQuest*Tests.swift`, `ProximityTests.swift` | new |
| `Tests/RunEngineTests/RunFixtures.swift` | sidequest and collection fixtures |
| `docs/schema.md` | Part B: `SideQuestRecord`, `SideQuestChallengeResult`; §B.8 reused as authored |

---

## Execution — 2026-08-15

**Status: built and green.** Phase A, engine-and-store half. Nothing from `s3`–`s7` was started.

### A blocker cleared first, which was not this plan's

Commit `fc5cb8e` on `Sidequest` **had committed, unresolved merge-conflict markers** in three files —
`Sources/ContentKit/Content/manifest.json`, `Sources/ContentKit/Content/quests/badung-empat-wajah.json`
and `Tests/ContentKitTests/BundledContentRepositoryTests.swift`. The package did not compile as
committed, so neither gate below could run at all. Both sides of all three hunks were the same pair of
lines — `s1`'s `schemaVersion: 2` / `contentBundleVersion: "2026.09.0"` against the merged master's
`1` / `"2026.08.4"` — and the `s1` side was kept, which is the only resolution that does not delete
shipped work. The content version is therefore still `2026.09.0` and no further bump was needed: no
content file changed in this plan.

### What was built

- `Sources/RunEngine/SideQuestRecords.swift` — `SideQuestState`, `SideQuestChallengeResult`,
  `SideQuestRecord` as §1 writes them, plus `awards: [Award]` and `letterAward` (§1's prose requires
  the letter to be an `Award` held on the record; the struct listing omitted the field).
- `Sources/RunEngine/SideQuestStore.swift` — the protocol as §2 writes it, `InMemorySideQuestStore`,
  `FileSideQuestStore` under `Application Support/Kultara/sidequests`, atomic writes, corrupt document
  skipped at load (`NFR-REL-04`). Documents are named by UUID and the cache is keyed by
  `sideQuestID`, so a content id is never required to be a legal filename. Protocol extension adds
  `records(collectionID:)` and `completedSideQuestIDs()`.
- `Sources/RunEngine/SideQuestEngine.swift` — `SideQuestEngineError`, `QuizOutcome`, and the engine.
  `discover` idempotent, `answerQuiz` awarding at most one letter ever and returning the stored
  outcome on a completed record, `completePhoto` the same, `markLoreOpened` accepting a completed
  record. Plus `monitoringCandidates(...)`, which is where `s0` D9's "a completed sidequest is
  deregistered" actually lives — `RegionBudget.select` takes candidates, so something has to build
  them, and record state is this engine's to know.
- `Sources/RunEngine/SideQuestQuiz.swift` — `revealAfterAttempts = 3` and `grade`.
- `Sources/RunEngine/LetterCollectionProgress.swift` — the value, `make(collection:records:…)`,
  `maskedPhrase(placeholder:)` and `spelledOutPhrase(blankWord:separator:)` for `NFR-A11Y-01`.
- `Sources/RunEngine/Proximity.swift` — `ProximityAlert`, `ProximityGate` (+`Limits`, `Decision`,
  `isQuiet`), `RegionBudget` (+`Candidate`, `select`, `questStartPriority`/`sideQuestPriority`).
- `Sources/RunEngine/RunRecords.swift` — `AwardType.letter`; `Award.sourceID`'s comment widened; and
  `RunEngine.snapshot` moved to `LoreBlockSnapshot.snapshot(_:place:language:)` so both aggregates
  share it **without `SideQuestEngine` calling into `RunEngine`**. §3's "nothing here touches `Run`,
  `RunStore` or `RunEngine`" is literally true only because of that move.
- `docs/schema.md` — §B.1 entity map, §B.5 `letter` case and the derived-collection-badge note, §B.8
  reused as authored with the shared target-id namespace spelled out, §B.10 two query paths, §B.11
  retention row, and new §B.12 `SideQuestRecord` / §B.13 `SideQuestChallengeResult`. Numbered after
  B.11 rather than inserted at B.9 so nothing renumbers.

### Deviations from the plan text, and why

1. **`progress(collectionID:)` → `progress(collectionID:language:)`.** `FR-SIDE-08` and PRD §5.15
   decision 3 require an unearned slot to *name its place*, and a place name is a `LocalizedText`.
   Earned slots ignore the parameter and use their own snapshot (`NFR-I18N-04`), which one test
   asserts directly.
2. **`LetterCollectionProgress` gained `badge: Award?`.** §8's test table demands
   `theCollectionBadgeIsAwardedOnTheLastLetterAndNotBefore` and §1's prose says the collection badge
   is an `Award` held on the progress, but the §5 struct listing had no field for it. It is derived,
   not stored, with an id derived deterministically from `badgeId` — so "awarded once" holds by
   construction and two computations of the same progress compare equal instead of churning the view.
3. **`RegionBudget.select(near: nil)` sorts by priority before taking the first `limit`,** rather
   than taking authored order flat as §6's sentence reads. Authored order is preserved *within* a
   priority. Dropping quest starts because whichever sidequests were authored first filled the budget
   is a different silent failure from the one §6 is guarding against.

### Verification

```
$ cd challange-5/Packages/Kultara && DEVELOPER_DIR=… swift test
􁁛  Test run with 334 tests in 37 suites passed after 0.057 seconds.

$ cd challange-5/Packages/Kultara && DEVELOPER_DIR=… swift run content-validator Sources/ContentKit/Content
OK  1 quest(s), 5 place(s), 3451352 bytes — all 28 rules pass.
```

334 tests, up from `s1`'s 281 — 44 of the increase is this plan (`SideQuestEngineTests` 20 +
`SideQuestQuizTests` 3 = 23, `FileSideQuestStoreTests` 7, `ProximityGateTests` 9 +
`RegionBudgetTests` 5 = 14); the rest arrived with the master merge in `fc5cb8e`. Every row of §8's
table is present under its stated name. Validator rule count is unchanged at 28 — this plan adds no
content rule, and touches no content file.

`ImportBoundaryTests.runEngineImportsNoUIOrLocationFramework` passes: nothing new imports SwiftUI,
UIKit, CoreLocation, MapKit or AppKit, and there is no reachability check anywhere (`AD-3`).

`xcodebuild` was **not** run. This plan touches no app-target file and adds no public API the app
target consumes yet.

### Left out, deliberately

- **The app target's `DataEraser` does not yet clear the sidequest directory,** despite §2 saying it
  should. `RunAndPreferencesDataEraser` takes a `RunStore`; giving it a `SideQuestStore` means
  `KultaraEnvironment` has to hold one, and that assembly is `s4`'s. §9's files-touched table lists no
  app-target file, and nothing writes a `SideQuestRecord` until `s4` exists, so today the directory is
  never created. **This is a required step in `s4` and is listed as a gap below.**
  `StorageReporter` needs no change — `ContainerStorageReporter` already walks all of Application
  Support, so it counts `Kultara/sidequests` as authored.
- **No proximity service, no notification, no region registration.** `ProximityGate` and
  `RegionBudget` are the values `s3`'s adapter sits on; `UNUserNotificationCenter`, `CLLocationManager`
  and the alert-row store are `s3`.
- **No photo capture.** `completePhoto` records a relative path and awards the letter; writing the
  file, the camera, and `FR-TASK-06`'s runtime check are Phase D (`s4` §7).
- **No pruning of `ProximityAlert` rows.** `schema.md` §B.11 keeps them 7 days; the store that would
  prune them is `s3`'s, and a pruning rule with no store to prune is a rule with nowhere to live.
- **No authored sidequest or collection content.** Every test runs on fixtures. `s5`/Phase E needs
  consent records and openable citations that do not exist.
- **No UI, no view models, no strings.** `s4`.

### New known gaps

1. **`FR-SET-02` is incomplete until `s4` wires `FileSideQuestStore` into `LocalDataEraser`.** Nothing
   catches this — the app target has no unit-test bundle, and `SideQuestStoreTests.deletingAllLocalDataLeavesNoLettersBehind`
   proves only that the *store* erases. Do it in the same commit that first constructs a
   `FileSideQuestStore` in `KultaraEnvironment`.
2. **`monitoringCandidates` is not in `s3`'s plan text.** `s3` should adapt it rather than rebuild the
   completed/suppressed filter, or the "a completed sidequest is deregistered" rule will exist twice.
3. **The quest-start half of `RegionBudget` has no producer.** `RegionBudget.questStartPriority`
   exists and is tested, but nothing builds quest-start candidates yet; until `s3` does, the 20-region
   budget is only enforced over sidequests. `FR-SIDE-16` is not met by this plan alone.
4. **The `FR-SIDE` block is still `PROPOSED — NOT ACCEPTED`.** Every requirement cited above is
   reserved and stable but unsigned (`s0` §4, `s7`). If it is rejected, all six new source files go
   with it.
5. **The merge in `fc5cb8e` should be checked by whoever made it.** The conflict resolution above was
   mechanical and is the only one that compiles, but nobody has confirmed that `2026.08.4`'s content
   changes are fully present in the `2026.09.0` tree — the validator passing says the tree is
   internally consistent, not that nothing was lost.
