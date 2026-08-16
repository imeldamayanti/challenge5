// Restored by m7 step 9 from b597b5b^ (Tests/AppFeaturesTests/QuestRunTests.swift).
// Last, because its failure would be a real finding rather than a wiring problem.
// FR-START-02/04/08/09, FR-ARR-01/03, FR-DONE-01/03/04, FR-TASK-07, FR-RUN-04, NFR-BAT-04.
import Foundation
import Testing
@testable import challange_5
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
        overrideDelay: Duration = .milliseconds(20)
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
            manualOverrideDelay: overrideDelay))
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
    /// reveal, a place notice at a sacred Place (`FR-TASK-05`), the checkpoint detail, and the
    /// transition. Walking them is what a walker does, and asserting the walk *terminates* at
    /// `.atCheckpoint` is a stronger guard than asserting arrival lands there: it also catches a
    /// story stage that loops or never hands over.
    @discardableResult
    private func walkTheStoryStages(_ harness: Harness) -> Bool {
        // Bounded rather than `while`: a stage that returns itself would otherwise hang the suite
        // instead of failing it. Six stages is the longest legal path; eight gives it room.
        for _ in 0..<8 {
            switch harness.model.stage {
            case .cutsceneIntro: harness.model.advanceFromCutsceneIntro()
            case .cutscenePortrait: harness.model.advanceFromCutscenePortrait()
            case .storyReveal: harness.model.advanceFromStoryReveal()
            case .placeNotice: harness.model.advanceFromPlaceNotice()
            case .checkpointDetail: harness.model.advanceFromCheckpointDetail()
            case .transition: harness.model.advanceFromTransition()
            default: return harness.model.stage == .atCheckpoint
            }
        }
        return false
    }

    // MARK: - FR-START-02/04/04a

    /// `FR-START-04a` — the load-bearing half, and the half that admits no exception: nothing is
    /// sampled, nothing is asked of the system, and nothing is written to a Run until the safety
    /// notice has been acknowledged. The pre-M8 form of this test asserted the weaker claim that the
    /// notice was the *first screen*; the amendment permits a narrative screen ahead of it, so the
    /// guard moved to what the requirement actually protects.
    @Test func theSafetyNoticeComesBeforeAnySamplingPermissionOrRunWrite() throws {
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
        #expect(harness.model.stage == .safetyNotice)
        #expect(!harness.provider.isSampling)
        #expect(!harness.provider.requestedPermission)
        #expect(harness.model.run == nil)
        #expect(try harness.store.runs().isEmpty)
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

    @Test func theLocationExplanationComesBeforeTheSystemPrompt() throws {
        let harness = try harness(authorization: .notRequested, safetyAcked: false)
        harness.model.advanceFromStoryPreview()
        harness.model.acknowledgeSafetyNotice()
        #expect(harness.model.stage == .locationNotice)
        // FR-ONB-04 — still nothing asked of the system at this point.
        #expect(!harness.provider.requestedPermission)

        harness.model.acknowledgeLocationNoticeAndRequestPermission()
        #expect(harness.model.stage == .awaitingArrival)
        #expect(harness.provider.requestedPermission)
    }

    @Test func anAlreadyAcknowledgedQuestGoesStraightToArrival() throws {
        let harness = try harness()
        // Straight past both notices — but still through the narrative opening, which is the one
        // screen the amendment permits ahead of them.
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

    @Test func aGoodFixAtTheGateStartsTheWalkAndStopsSampling() throws {
        let harness = try harness()
        openArrival(harness)
        harness.provider.emit(offsetMetres: 5, accuracy: 8)

        let run = try #require(harness.model.run)
        #expect(run.state == .active)
        #expect(run.reachedCount == 1)
        // The Run exists the instant the gate opens; the story stages that follow are presentation,
        // and they must hand over to the checkpoint screen rather than dead-end.
        #expect(walkTheStoryStages(harness), "Story stages did not terminate at .atCheckpoint")
        // NFR-BAT-04 — nothing keeps sampling once there is nothing to detect.
        #expect(!harness.provider.isSampling)
        #expect(try harness.store.activeRun(questID: harness.quest.id)?.id == run.id)
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

        for checkpoint in harness.quest.orderedCheckpoints {
            if checkpoint.orderIndex > 0 {
                harness.model.advance()
            }
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
