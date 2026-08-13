import Foundation
import Testing
@testable import AppFeatures
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

    // MARK: - FR-START-02/04

    @Test func theSafetyNoticeComesBeforeAnythingElseOnAFirstRun() throws {
        let harness = try harness(authorization: .notRequested, safetyAcked: false)
        #expect(harness.model.stage == .safetyNotice)
        #expect(!harness.provider.isSampling)
        #expect(!harness.provider.requestedPermission)
    }

    @Test func theLocationExplanationComesBeforeTheSystemPrompt() throws {
        let harness = try harness(authorization: .notRequested, safetyAcked: false)
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
        #expect(harness.model.stage == .awaitingArrival)
    }

    // MARK: - FR-START-08

    @Test func aFixOutsideTheStartRadiusStartsNothing() throws {
        let harness = try harness()
        harness.model.screenAppeared()
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
        harness.model.screenAppeared()
        harness.provider.emit(offsetMetres: 0, accuracy: 900)

        #expect(harness.model.run == nil)
        if case .accuracyInsufficient = harness.model.arrival {} else {
            Issue.record("Expected the accuracy guard to hold, got \(harness.model.arrival)")
        }
    }

    // MARK: - FR-START-01, FR-ARR-01/02

    @Test func aGoodFixAtTheGateStartsTheWalkAndStopsSampling() throws {
        let harness = try harness()
        harness.model.screenAppeared()
        harness.provider.emit(offsetMetres: 5, accuracy: 8)

        let run = try #require(harness.model.run)
        #expect(run.state == .active)
        #expect(run.reachedCount == 1)
        #expect(harness.model.stage == .atCheckpoint)
        // NFR-BAT-04 — nothing keeps sampling once there is nothing to detect.
        #expect(!harness.provider.isSampling)
        #expect(try harness.store.activeRun(questID: harness.quest.id)?.id == run.id)
    }

    @Test func theCheckpointScreenCarriesTheStoryItsLabelsAndItsSources() throws {
        let harness = try harness()
        harness.model.screenAppeared()
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
        harness.model.screenAppeared()
        harness.provider.emit(offsetMetres: 5, accuracy: 8)

        let run = try #require(harness.model.run)
        #expect(run.orderedCheckpointResults.first?.loreFirstOpenedAt != nil)
    }

    // MARK: - FR-ARR-03, FR-START-09/10, FR-ERR-02

    @Test func theManualOverrideAppearsOnlyAfterTheDelay() async throws {
        let harness = try harness(overrideDelay: .milliseconds(50))
        harness.model.screenAppeared()
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
        harness.model.screenAppeared()
        #expect(harness.model.arrival == .permissionDenied)
        #expect(harness.model.manualOverrideAvailable)
    }

    @Test func theOverrideAtTheStartCheckpointAsksTheWalkerToConfirmWhereTheyAre() throws {
        // FR-START-09 — the override exists for GPS failure, not for remote starting.
        let harness = try harness(authorization: .denied)
        harness.model.screenAppeared()
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
        harness.model.screenAppeared()
        harness.model.useManualOverride()
        harness.model.cancelPresenceConfirmation()

        #expect(!harness.model.isConfirmingPresence)
        #expect(harness.model.run == nil)
        #expect(try harness.store.runs().isEmpty)
    }

    // MARK: - Progression and completion

    @Test func walkingTheWholeRouteCompletesItAndTheSummaryNeedsNoContent() throws {
        let harness = try harness()
        harness.model.screenAppeared()

        for checkpoint in harness.quest.orderedCheckpoints {
            if checkpoint.orderIndex > 0 {
                harness.model.advance()
            }
            harness.provider.emit(offsetMetres: 2, accuracy: 6)
            #expect(harness.model.stage == .atCheckpoint,
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
        harness.model.screenAppeared()
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
        harness.model.screenAppeared()
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
