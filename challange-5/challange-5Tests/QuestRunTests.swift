// Restored by m7 step 9 from b597b5b^ (Tests/AppFeaturesTests/QuestRunTests.swift).
// Last, because its failure would be a real finding rather than a wiring problem.
// FR-START-08/09, FR-ARR-01/03, FR-DONE-01/03/04, FR-TASK-07, FR-RUN-04, NFR-BAT-04.
// FR-START-02's location rationale and FR-START-04's safety notice were both removed from this
// flow by request. `FR-START-02` is unaffected for the sidequest flow, which never had a safety
// notice of its own to begin with (`s0` D3).
import Foundation
import Testing
@testable import challange_5
import UIKit
import UIStringsKit
@testable import ContentKit
@testable import RunEngine

/// A provider whose fixes the test writes, so the arrival rule can be exercised without a device.
@MainActor
final class FakeLocationProvider: LocationProviding {
    var onFix: ((LocationFix) -> Void)?
    var onAuthorizationChange: ((LocationAuthorizationSnapshot) -> Void)?
    var authorization: LocationAuthorizationSnapshot
    private(set) var target: Coordinate?
    private(set) var isSampling = false
    private(set) var requestedPermission = false

    init(authorization: LocationAuthorizationSnapshot = .whenInUse) {
        self.authorization = authorization
    }

    func requestWhenInUseAuthorization() { requestedPermission = true }

    func start(target: Coordinate) {
        self.target = target
        isSampling = true
    }

    func stop() { isSampling = false }

    func emit(offsetMetres: Double, accuracy: Double) {
        guard let target else { return }
        // Roughly `offsetMetres` due north — enough to be inside or outside a radius on purpose.
        let latitudeDelta = offsetMetres / 111_000
        onFix?(LocationFix(
            coordinate: Coordinate(lat: target.lat + latitudeDelta, lon: target.lon),
            horizontalAccuracyM: accuracy,
            timestamp: Date()))
    }
}

@MainActor
struct QuestRunTests {

    private struct Harness {
        let model: QuestRunViewModel
        let provider: FakeLocationProvider
        let store: any RunStore
        let quest: Quest
    }

    private func harness(
        authorization: LocationAuthorizationSnapshot = .whenInUse,
        safetyAcked: Bool = true,
        overrideDelay: Duration = .milliseconds(20),
        photoStore: (any PhotoStore)? = nil
    ) throws -> Harness {
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        let store = InMemoryRunStore()
        let provider = FakeLocationProvider(authorization: authorization)
        let preferences = InMemoryAppPreferencesStore(
            safetyNoticeAckedQuestIDs: safetyAcked ? [quest.id] : [])

        let model = try #require(QuestRunViewModel(
            engine: RunEngine(repository: repository, store: store),
            repository: repository,
            preferences: preferences,
            locationProvider: provider,
            questID: quest.id,
            language: .id,
            manualOverrideDelay: overrideDelay,
            photoStore: photoStore))
        return Harness(model: model, provider: provider, store: store, quest: quest)
    }

    /// The walker's own door onto the arrival screen.
    ///
    /// A fresh walk opens on the narrative story preview — `FR-START-04` as amended 2026-08-16
    /// (owner: af). Reaching past it to `screenAppeared()` would test a state no walker can be in.
    /// `advanceFromStoryPreview` begins sampling itself once there is nothing left to acknowledge,
    /// so this deliberately does *not* also call `screenAppeared()`: that would restart the
    /// `FR-ARR-03` override countdown and make `theManualOverrideAppearsOnlyAfterTheDelay` measure
    /// the wrong interval.
    private func openArrival(_ harness: Harness) {
        if harness.model.stage == .storyPreview { harness.model.advanceFromStoryPreview() }
        if harness.model.stage == .awaitingArrival, !harness.provider.isSampling {
            harness.model.screenAppeared()
        }
    }

    /// Arrival no longer lands on the checkpoint screen directly. M8's story flow puts the Hisplora
    /// stages between them — cutscene intro and portrait on the first arrival, then the paged story
    /// reveal, the transition, a place notice at a sacred Place (`FR-TASK-05`), and the checkpoint
    /// detail. Walking them is what a walker does, and asserting the walk *terminates* somewhere
    /// real is a stronger guard than asserting arrival lands there: it also catches a story stage
    /// that loops or never hands over.
    ///
    /// **The menu's own exit no longer stops at `.atCheckpoint`.** Since `197:148` replaced
    /// `452:3194`'s single button, `advanceFromCheckpointDetail` leaves straight for the next place
    /// or the summary (see its own doc comment), so the walk this helper simulates now runs one hop
    /// further than it used to — to `.awaitingArrival` (there is a next checkpoint to walk to) or
    /// `.finished` (there is not). `.atCheckpoint` is still accepted: `stampAwardNextLocation`
    /// still reaches it from the stamp screen, on the path this helper's `.taskDetail` case does not
    /// take (it simulates leaving the sheet unresolved, not resolving it).
    @discardableResult
    private func walkTheStoryStages(_ harness: Harness) -> Bool {
        // Bounded rather than `while`: a stage that returns itself would otherwise hang the suite
        // instead of failing it. Nine stages is the longest legal path — `1:4458`'s arrival
        // confirmation added one, `187:1103`'s map added another, and `921:3851`'s
        // quest-availability sheet a third — thirteen gives it room.
        for _ in 0..<13 {
            // `921:3851` is a sheet, not a `Stage`, so it is checked ahead of the switch below.
            if harness.model.isPresentingQuestAvailability {
                harness.model.advanceFromQuestAvailability()
                continue
            }
            switch harness.model.stage {
            case .locationVerified: harness.model.advanceFromLocationVerified()
            case .arrivalNotice: harness.model.advanceFromArrivalNotice()
            case .cutsceneIntro: harness.model.advanceFromCutsceneIntro()
            case .cutscenePortrait: harness.model.advanceFromCutscenePortrait()
            case .approachTransition: harness.model.advanceFromApproachTransition()
            case .storyReveal: harness.model.advanceFromStoryReveal()
            case .placeNotice: harness.model.advanceFromPlaceNotice()
            // The checkpoint's first task now sits between the notice and the menu (`1:4592` →
            // `1:4711` → `1:4904`), so the walk passes through it on the way to the menu.
            case .taskDetail: harness.model.advanceFromTaskDetail()
            case .checkpointDetail: harness.model.advanceFromCheckpointDetail()
            case .transition: harness.model.advanceFromTransition()
            default:
                return harness.model.stage == .atCheckpoint
                    || harness.model.stage == .awaitingArrival
                    || harness.model.stage == .finished
            }
        }
        return false
    }

    // MARK: - Preflight (FR-START-02, FR-START-04 removed)

    /// Both the location rationale (`FR-START-02`) and the safety notice (`FR-START-04`) were
    /// removed from this flow by request. What is left of them: the story preview stays inert —
    /// nothing sampled, nothing asked of the system, no Run written — until the walker leaves
    /// it, and the screen behind the system permission prompt stays put — `.storyPreview` here —
    /// until the walker actually answers it (simulated here by the provider firing
    /// `onAuthorizationChange`), rather than jumping to `.awaitingArrival` underneath the dialog.
    @Test func theStoryPreviewStaysInertUntilTheSystemPromptIsAnswered() throws {
        let harness = try harness(authorization: .notRequested, safetyAcked: false)

        // The opening screen is narrative. It asks nothing and starts nothing.
        #expect(harness.model.stage == .storyPreview)
        #expect(!harness.provider.isSampling)
        #expect(!harness.provider.requestedPermission)
        #expect(harness.model.run == nil)

        // And it stays inert even when the screen reports itself as appeared — `screenAppeared()`
        // is what a SwiftUI `.onAppear` calls, so a stage that ignores it is the only safe one.
        harness.model.screenAppeared()
        #expect(!harness.provider.isSampling)
        #expect(!harness.provider.requestedPermission)

        harness.model.advanceFromStoryPreview()
        #expect(harness.model.stage == .storyPreview)
        #expect(harness.provider.requestedPermission)
        #expect(harness.model.run == nil)
        #expect(try harness.store.runs().isEmpty)

        harness.provider.authorization = .whenInUse
        harness.provider.onAuthorizationChange?(.whenInUse)
        #expect(harness.model.stage == .awaitingArrival)
    }

    /// The amendment is narrow: it licenses a screen that asks nothing, not a general permission to
    /// put screens before the notice. A resumed walk never sees the preview at all — it is an
    /// opening, not a gate — so the notice cannot be re-shown as a dialog people learn to dismiss.
    @Test func aResumedWalkNeverSeesTheNarrativeOpeningAgain() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)
        let run = try #require(harness.model.run)

        let resumed = try #require(QuestRunViewModel(
            engine: RunEngine(repository: try BundledContentRepository(),
                              store: harness.store),
            repository: try BundledContentRepository(),
            preferences: InMemoryAppPreferencesStore(safetyNoticeAckedQuestIDs: [harness.quest.id]),
            locationProvider: FakeLocationProvider(),
            questID: harness.quest.id,
            language: .id,
            existingRun: run))
        #expect(resumed.stage != .storyPreview)
    }

    @Test func anAlreadyAcknowledgedQuestGoesStraightToArrival() throws {
        let harness = try harness()
        // Straight to arrival — but still through the narrative opening, the one screen ahead of
        // the gate. Authorization is already granted here, so there is no prompt to wait on.
        harness.model.advanceFromStoryPreview()
        #expect(harness.model.stage == .awaitingArrival)
    }

    // MARK: - FR-START-08

    @Test func aFixOutsideTheStartRadiusStartsNothing() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 4_000, accuracy: 5)

        #expect(harness.model.run == nil)
        #expect(try harness.store.runs().isEmpty)
        #expect(harness.model.stage == .awaitingArrival)
        if case .approaching = harness.model.arrival {} else {
            Issue.record("Expected a live distance, got \(harness.model.arrival)")
        }
    }

    @Test func aVagueFixOnTopOfTheGateStartsNothingEither() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 0, accuracy: 900)

        #expect(harness.model.run == nil)
        if case .accuracyInsufficient = harness.model.arrival {} else {
            Issue.record("Expected the accuracy guard to hold, got \(harness.model.arrival)")
        }
    }

    // MARK: - FR-START-01, FR-ARR-01/02

    @Test func aGoodFixAtTheGateStartsTheWalkAndHandsOverToTheNextLeg() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)

        let run = try #require(harness.model.run)
        #expect(run.state == .active)
        #expect(run.reachedCount == 1)
        // The Run exists the instant the gate opens; the story stages that follow are presentation,
        // and they must hand over to the walk's next leg rather than dead-end.
        #expect(walkTheStoryStages(harness), "Story stages did not hand over cleanly")
        // `197:148`'s own exit leaves the checkpoint straight for the next place, which begins
        // sampling again at once (`beginSampling` inside `advance()`) — there is no longer an idle
        // rest at `.atCheckpoint` on this path for `NFR-BAT-04` to hold still against.
        #expect(harness.model.stage == .awaitingArrival)
        #expect(harness.provider.isSampling)
        #expect(try harness.store.activeRun(questID: harness.quest.id)?.id == run.id)
    }

    /// `1:4458` — arrival lands on its own confirmation screen, and the cutscene is what its
    /// Continue reaches. Before this stage existed the walk went from the arrival screen to the
    /// cutscene in one step and `LocationState.verified` was drawn by nothing a walker could see.
    @Test func aGoodFixConfirmsTheLocationBeforeTheStoryStarts() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)

        #expect(harness.model.stage == .locationVerified)
        harness.model.advanceFromLocationVerified()
        #expect(harness.model.stage == .cutsceneIntro)
    }

    /// `98:1588`'s back chevron goes back. It fell through `retreatFromStoryStage`'s `default: break`
    /// and did nothing at all, which left the cutscene the one story stage with a control that was
    /// drawn and dead. Going back and forward again lands on the same screen: the arrival stored
    /// where its Continue leads, so returning to it cannot change the answer.
    @Test func backingOutOfTheCutsceneReturnsToTheArrivalConfirmation() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)
        harness.model.advanceFromLocationVerified()
        #expect(harness.model.stage == .cutsceneIntro)

        harness.model.retreatFromStoryStage()
        #expect(harness.model.stage == .locationVerified)

        harness.model.advanceFromLocationVerified()
        #expect(harness.model.stage == .cutsceneIntro)
    }

    /// `187:1103` — the cutscene hands over to the map with the beating dot, not straight to the
    /// reveal, and the map hands over to the reveal.
    ///
    /// The order is the whole point of the screen: the cutscene names a story and this says where
    /// it starts, so a reveal reached before it would be the walk telling the story of a place it
    /// had not yet pointed at.
    @Test func theCutsceneHandsOverToTheApproachMapAndTheMapToTheStory() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)
        harness.model.advanceFromLocationVerified()
        harness.model.advanceFromCutsceneIntro()
        #expect(harness.model.stage == .cutscenePortrait)

        harness.model.advanceFromCutscenePortrait()
        #expect(harness.model.stage == .approachTransition)

        harness.model.advanceFromApproachTransition()
        #expect(harness.model.stage == .storyReveal)
    }

    /// The screen leaves on its own, and the guard is that it only leaves *itself*.
    ///
    /// `ApproachTransitionScreen` runs the clock in a `.task`, which cancellation is meant to take
    /// with it — but a late tick that outlives the back-out would otherwise push a walker from
    /// wherever they went onto the reveal. The stage check inside `advanceFromApproachTransition`
    /// is what makes that harmless, and this is what pins it.
    @Test func theApproachMapsTimerCannotAdvanceAStageItIsNotOn() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)
        harness.model.advanceFromLocationVerified()
        harness.model.advanceFromCutsceneIntro()
        harness.model.advanceFromCutscenePortrait()
        #expect(harness.model.stage == .approachTransition)

        harness.model.retreatFromStoryStage()
        #expect(harness.model.stage == .cutscenePortrait)

        harness.model.advanceFromApproachTransition()
        #expect(harness.model.stage == .cutscenePortrait)
    }

    /// Backing out of the reveal on the walk's first checkpoint returns to the map, which is now
    /// the screen before it. Nine stages of walk are easy to reorder by accident; this is the seam
    /// that reordering would break silently.
    @Test func backingOutOfTheFirstStoryRevealReturnsToTheApproachMap() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)
        harness.model.advanceFromLocationVerified()
        harness.model.advanceFromCutsceneIntro()
        harness.model.advanceFromCutscenePortrait()
        harness.model.advanceFromApproachTransition()
        #expect(harness.model.stage == .storyReveal)

        harness.model.retreatFromStoryStage()
        #expect(harness.model.stage == .approachTransition)
    }

    /// The map screen is drawn on the Hisplora ground and carries its own header, so the museum
    /// navigation bar must go away over it — the rule `isStoryFlow` holds for every other story
    /// stage, and a new stage left out of it gets a cream-on-brown bar clipping its heading.
    @Test func theApproachMapIsAStoryFlowStage() {
        #expect(QuestRunViewModel.isStoryFlow(.approachTransition))
    }

    /// `5:1608` — the second checkpoint does **not** get `1:4458` again. It arrives onto the
    /// walking map's arrival card, and that card's one control reaches the story reveal.
    ///
    /// The confirmation screen is an explanation of what the app does with a walker's position, and
    /// an explanation is worth a screen the first time it is needed and not the fourth. This is the
    /// seam that would break silently if `usesNavigationMap` were ever widened to every checkpoint
    /// (the first arrival would lose the explanation) or narrowed away (every arrival would get it
    /// back).
    @Test func alaterArrivalAnnouncesItselfOnTheMapAndGoesStraightToTheStory() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)
        // The menu's own exit already leaves for the next place (`advanceFromCheckpointDetail`),
        // so `walkTheStoryStages` lands on `.awaitingArrival` with sampling already aimed at the
        // second checkpoint — no separate `advance()` call is needed here any more.
        #expect(walkTheStoryStages(harness), "Story stages did not hand over cleanly")
        #expect(harness.model.stage == .awaitingArrival)
        // The waiting screen is the live map from here on, not `223:2004`.
        #expect(harness.model.usesNavigationMap)

        harness.provider.emit(offsetMetres: 5, accuracy: 8)

        #expect(harness.model.stage == .arrivalNotice)
        harness.model.advanceFromArrivalNotice()
        #expect(harness.model.stage == .storyReveal)
    }

    /// The walk's *first* checkpoint keeps both original screens — it is the one place the walker
    /// is told what a fix means at all.
    @Test func theFirstCheckpointDoesNotUseTheWalkingMap() throws {
        let harness = try harness()
        openArrival(harness)

        #expect(!harness.model.usesNavigationMap)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)
        #expect(harness.model.stage == .locationVerified)
    }

    /// The map and its card are drawn on the Hisplora ground and carry their own header, so the
    /// museum navigation bar must go away over them — the same rule every other story stage is
    /// held to, and the one a new stage is easiest to leave out of.
    @Test func theWalkingMapIsAStoryFlowStage() {
        #expect(QuestRunViewModel.isStoryFlow(.arrivalNotice))
    }

    @Test func theCheckpointScreenCarriesTheStoryItsLabelsAndItsSources() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)

        let checkpoint = try #require(harness.model.checkpoint)
        #expect(!checkpoint.claims.isEmpty)
        // FR-CP-05 — every claim carries a visible label, as text.
        #expect(checkpoint.claims.allSatisfy { !$0.block.accuracyLabel.isEmpty })
        // FR-CP-06 — and its citations are right there to render.
        #expect(checkpoint.claims.contains { !$0.citations.isEmpty })
    }

    @Test func loreOpeningIsRecordedOnceOnArrival() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)

        let run = try #require(harness.model.run)
        #expect(run.orderedCheckpointResults.first?.loreFirstOpenedAt != nil)
    }

    // MARK: - FR-ARR-03, FR-START-09/10, FR-ERR-02

    @Test func theManualOverrideAppearsOnlyAfterTheDelay() async throws {
        let harness = try harness(overrideDelay: .milliseconds(50))
        openArrival(harness)
        #expect(!harness.model.manualOverrideAvailable)

        // Polled rather than slept-through once: a single fixed wait turns a loaded machine into a
        // red test, and a flaky guard is one somebody eventually deletes.
        for _ in 0..<100 where !harness.model.manualOverrideAvailable {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(harness.model.manualOverrideAvailable)
    }

    @Test func arefusedPermissionOffersTheOverrideAtOnceAndKeepsTheRunPossible() throws {
        // FR-ERR-02 — explain, offer a way on, and never destroy the walk over it.
        let harness = try harness(authorization: .denied)
        openArrival(harness)
        #expect(harness.model.arrival == .permissionDenied)
        #expect(harness.model.manualOverrideAvailable)
    }

    @Test func theOverrideAtTheStartCheckpointAsksTheWalkerToConfirmWhereTheyAre() throws {
        // FR-START-09 — the override exists for GPS failure, not for remote starting.
        let harness = try harness(authorization: .denied)
        openArrival(harness)
        harness.model.useManualOverride()

        #expect(harness.model.isConfirmingPresence)
        #expect(harness.model.run == nil, "Nothing starts until the walker confirms.")
        // The confirmation has to name the Place, or it is a yes/no about nothing.
        let startPlaceID = try #require(harness.quest.startCheckpoint).placeId
        let startPlace = try #require(
            try BundledContentRepository().place(id: startPlaceID))
        #expect(harness.model.presenceConfirmationTitle
            .contains(startPlace.nameOfficial.value(for: .id)))

        harness.model.confirmPresence()
        let run = try #require(harness.model.run)
        #expect(run.result(forOrderIndex: 0)?.arrivalMethod == .manual)
    }

    @Test func cancellingTheConfirmationLeavesTheQuestUnstarted() throws {
        let harness = try harness(authorization: .denied)
        openArrival(harness)
        harness.model.useManualOverride()
        harness.model.cancelPresenceConfirmation()

        #expect(!harness.model.isConfirmingPresence)
        #expect(harness.model.run == nil)
        #expect(try harness.store.runs().isEmpty)
    }

    // MARK: - Progression and completion

    @Test func walkingTheWholeRouteCompletesItAndTheSummaryNeedsNoContent() throws {
        let harness = try harness()
        openArrival(harness)

        // No separate `advance()` between checkpoints any more: the menu's own exit
        // (`advanceFromCheckpointDetail`) already leaves for the next place — or, at the last
        // checkpoint, for the summary — as part of `walkTheStoryStages` itself.
        for checkpoint in harness.quest.orderedCheckpoints {
            harness.provider.emit(offsetMetres: 2, accuracy: 6)
            #expect(walkTheStoryStages(harness),
                    "Failed to arrive at checkpoint \(checkpoint.orderIndex)")
        }

        let run = try #require(harness.model.run)
        #expect(run.state == .completed)
        #expect(run.reachedCount == harness.quest.checkpointCount)
        #expect(harness.model.isCompleted)

        // FR-DONE-04/05 — the summary is built from the Run alone.
        let summary = RunSummaryViewModel(run: run)
        #expect(summary.stops.count == harness.quest.checkpointCount)
        #expect(summary.badges.count == 1)
        #expect(summary.stamps.count == harness.quest.checkpointCount)
        #expect(summary.stops.allSatisfy { !$0.claims.isEmpty })
    }

    @Test func aWrittenReflectionReachesTheSummary() throws {
        // FR-TASK-07.
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 2, accuracy: 6)

        let checkpoint = try #require(harness.model.checkpoint)
        guard let task = checkpoint.tasks.first(where: { $0.type != .photo }) else { return }
        harness.model.taskDrafts[task.id] = "Pintunya lebih tua dari yang saya kira."
        harness.model.saveTask(task)

        let summary = RunSummaryViewModel(run: try #require(harness.model.run))
        #expect(summary.stops.first?.writtenAnswers.first?.text
                == "Pintunya lebih tua dari yang saya kira.")
    }

    /// Replaces the `createJournal` wireframe: the walk's closing journal entry, written from the
    /// Summary screen once the walk has already reached `.finished`.
    @Test func savingAJournalEntryReachesTheSummary() throws {
        let photoStore = InMemoryPhotoStore()
        let harness = try harness(photoStore: photoStore)
        openArrival(harness)
        for checkpoint in harness.quest.orderedCheckpoints {
            harness.provider.emit(offsetMetres: 2, accuracy: 6)
            #expect(walkTheStoryStages(harness),
                    "Failed to arrive at checkpoint \(checkpoint.orderIndex)")
        }
        #expect(harness.model.isCompleted)

        let place = UIImage()
        let selfie = UIImage()
        let updated = try #require(harness.model.saveJournalEntry(
            text: "Hari yang luar biasa.", placePhoto: place, selfiePhoto: selfie))

        let entry = try #require(updated.journalEntry)
        #expect(entry.text == "Hari yang luar biasa.")
        #expect(entry.placePhotoRelativePath != nil)
        #expect(entry.selfiePhotoRelativePath != nil)
        #expect(photoStore.savedCount == 2)
        // Persisted, not just held in memory — the same store `RunSummaryViewModel` and the
        // Journal shelf both read from.
        let stored = try #require(try harness.store.run(id: updated.id))
        #expect(stored.journalEntry?.text == "Hari yang luar biasa.")
    }

    @Test func endingAWalkKeepsWhatWasAlreadyWalked() throws {
        // FR-RUN-04.
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 2, accuracy: 6)
        harness.model.requestAbandon()
        harness.model.confirmAbandon()

        let run = try #require(harness.model.run)
        #expect(run.state == .abandoned)
        #expect(run.reachedCount == 1)
        #expect(harness.model.stage == .finished)
        #expect(RunSummaryViewModel(run: run).stops.count == 1)
    }
}
