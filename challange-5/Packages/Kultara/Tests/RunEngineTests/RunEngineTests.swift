import ContentKit
import Foundation
import Testing
@testable import RunEngine

@MainActor
struct RunEngineTests {

    private func engine(
        store: any RunStore = InMemoryRunStore(),
        repository: StubContentRepository = StubContentRepository()
    ) -> (RunEngine, any RunStore) {
        (RunEngine(repository: repository, store: store), store)
    }

    private func started(_ engine: RunEngine) throws -> Run {
        try engine.start(questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)
    }

    // MARK: - FR-START-01/05

    @Test func startingPinsContentVersionAndLanguage() throws {
        let (engine, _) = engine()
        let run = try started(engine)
        #expect(run.contentVersion == "2026.08.1")
        #expect(run.language == .id)
        #expect(run.state == .active)
        #expect(run.currentCheckpointIndex == 0)
    }

    @Test func aPinnedVersionSurvivesAContentUpdate() throws {
        // AD-4: a content hotfix must not rewrite the story under a walker standing at checkpoint 3.
        let store = InMemoryRunStore()
        let run = try RunEngine(repository: StubContentRepository(), store: store)
            .start(questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)

        let corrected = StubContentRepository(quest: Fixture.quest(contentVersion: "2026.09.9"))
        let reopened = try #require(try RunEngine(repository: corrected, store: store)
            .run(id: run.id))
        #expect(reopened.contentVersion == "2026.08.1")
    }

    // MARK: - FR-START-06

    @Test func aSecondRunOfTheSameQuestIsRefusedRatherThanOpened() throws {
        let (engine, _) = engine()
        let first = try started(engine)
        #expect(throws: RunEngineError.activeRunExists(runID: first.id)) {
            try started(engine)
        }
    }

    @Test func restartingDiscardsTheDraftRatherThanKeepingBoth() throws {
        let (engine, store) = engine()
        let first = try started(engine)
        let second = try engine.restart(
            questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)

        #expect(second.id != first.id)
        #expect(try store.run(id: first.id) == nil)
        #expect(try store.runs().count == 1)
    }

    // MARK: - FR-CP-01, FR-ARR-06

    @Test func arrivingOutOfSequenceChangesNothingAndNamesTheExpectedCheckpoint() throws {
        let (engine, _) = engine()
        let run = try started(engine)

        #expect(throws: RunEngineError.outOfSequence(
            expectedCheckpointID: "cp0", expectedOrderIndex: 0)) {
            try engine.recordArrival(
                runID: run.id, checkpointID: "cp2", method: .gps, accuracyM: 8)
        }

        let unchanged = try #require(try engine.run(id: run.id))
        #expect(unchanged.reachedCount == 1)
        #expect(unchanged.currentCheckpointIndex == 0)
        #expect(unchanged.state == .active)
    }

    @Test func skippingAheadIsNotPossibleEvenAfterAdvancing() throws {
        let (engine, _) = engine()
        let run = try started(engine)
        _ = try engine.advanceToNextCheckpoint(runID: run.id)

        #expect(throws: RunEngineError.outOfSequence(
            expectedCheckpointID: "cp1", expectedOrderIndex: 1)) {
            try engine.recordArrival(
                runID: run.id, checkpointID: "cp2", method: .gps, accuracyM: 8)
        }
    }

    @Test func advancingBeforeArrivingIsRefused() throws {
        let (engine, _) = engine()
        let run = try started(engine)
        _ = try engine.advanceToNextCheckpoint(runID: run.id)
        // Now at index 1 and not yet arrived; advancing again would skip a checkpoint.
        #expect(throws: RunEngineError.self) {
            try engine.advanceToNextCheckpoint(runID: run.id)
        }
    }

    // MARK: - FR-CP-07, FR-DONE-01/02

    @Test func aStampLandsOnArrivalIndependentOfTasks() throws {
        let (engine, _) = engine()
        let run = try started(engine)
        let result = try #require(run.result(forOrderIndex: 0))
        #expect(result.stampAwardedAt != nil)
        #expect(result.taskResults.isEmpty)
        #expect(run.awards.filter { $0.type == .stamp }.count == 1)
    }

    @Test func theWalkCompletesOnArrivalAtTheFinalCheckpointWithNoTaskDone() throws {
        let (engine, _) = engine()
        var run = try started(engine)
        run = try engine.advanceToNextCheckpoint(runID: run.id)
        run = try engine.recordArrival(
            runID: run.id, checkpointID: "cp1", method: .gps, accuracyM: 8)
        run = try engine.advanceToNextCheckpoint(runID: run.id)
        run = try engine.recordArrival(
            runID: run.id, checkpointID: "cp2", method: .manual, accuracyM: nil)

        #expect(run.state == .completed)
        #expect(run.completedAt != nil)
        #expect(run.awards.filter { $0.type == .badge }.count == 1)
        #expect(run.awards.filter { $0.type == .stamp }.count == 3)
        #expect(run.checkpointResults.allSatisfy { $0.taskResults.isEmpty })
    }

    @Test func theClosingReflectionStillReachesACompletedRun() throws {
        // FR-TASK-07: the final checkpoint's reflection flows into the summary — and the walk is
        // already complete by the time it is written, because arrival completed it.
        let (engine, _) = engine()
        var run = try started(engine)
        run = try engine.advanceToNextCheckpoint(runID: run.id)
        run = try engine.recordArrival(
            runID: run.id, checkpointID: "cp1", method: .gps, accuracyM: 8)
        run = try engine.advanceToNextCheckpoint(runID: run.id)
        run = try engine.recordArrival(
            runID: run.id, checkpointID: "cp2", method: .gps, accuracyM: 8)

        run = try engine.recordTaskResult(
            runID: run.id, checkpointID: "cp2", taskID: "t2",
            skipped: false, text: "Gerbangnya lebih rendah dari dugaan saya.")

        let answer = try #require(run.result(forCheckpointID: "cp2")?.taskResults.first)
        #expect(answer.skipped == false)
        #expect(answer.text == "Gerbangnya lebih rendah dari dugaan saya.")
        #expect(run.state == .completed)
    }

    // MARK: - AD-2, FR-TASK-01/02

    @Test func skippingATaskChangesNoStateAndNoAward() throws {
        let (engine, _) = engine()
        var run = try started(engine)
        let before = (run.currentCheckpointIndex, run.state, run.awards.count)

        run = try engine.recordTaskResult(
            runID: run.id, checkpointID: "cp0", taskID: "t0", skipped: true)

        #expect(run.currentCheckpointIndex == before.0)
        #expect(run.state == before.1)
        #expect(run.awards.count == before.2)
        let result = try #require(run.result(forCheckpointID: "cp0")?.taskResults.first)
        #expect(result.skipped)
        #expect(result.text == nil)
    }

    @Test func answeringAfterSkippingReplacesTheSkipRatherThanStacking() throws {
        let (engine, _) = engine()
        var run = try started(engine)
        run = try engine.recordTaskResult(
            runID: run.id, checkpointID: "cp0", taskID: "t0", skipped: true)
        run = try engine.recordTaskResult(
            runID: run.id, checkpointID: "cp0", taskID: "t0", skipped: false, text: "Berubah pikiran")

        let results = try #require(run.result(forCheckpointID: "cp0")?.taskResults)
        #expect(results.count == 1)
        #expect(results[0].text == "Berubah pikiran")
    }

    // MARK: - Snapshot, system-design §4.1

    @Test func arrivalCopiesTheStoryAndItsCitationsIntoTheRun() throws {
        let (engine, _) = engine()
        let run = try started(engine)
        let result = try #require(run.result(forOrderIndex: 0))

        #expect(result.snapshotPlaceName == "Puri Contoh")
        #expect(result.snapshotLore.count == 2)
        #expect(result.snapshotLore[0].accuracy == .documented)
        #expect(result.snapshotLore[1].accuracy == .oral)
        #expect(result.snapshotLore[0].sourceCitations == ["Arsip Kota, 1938"])
        #expect(result.snapshotLore[1].sourceCitations == ["Wawancara pemangku, 2026"])
        #expect(result.snapshotClueToNext == "Petunjuk 0")
        #expect(result.snapshotContentVersion == "2026.08.1")
    }

    @Test func aSummaryStillRendersAfterThePlaceIsWithdrawn() throws {
        // FR-RUN-06 / FR-DONE-05: a suppressed Place cannot erase a walk somebody finished, because
        // rendering it asks content nothing.
        let store = InMemoryRunStore()
        let run = try RunEngine(repository: StubContentRepository(), store: store)
            .start(questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)

        let withoutPlaces = StubContentRepository(places: [])
        let reopened = try #require(try RunEngine(repository: withoutPlaces, store: store)
            .run(id: run.id))
        let result = try #require(reopened.result(forOrderIndex: 0))
        #expect(result.snapshotPlaceName == "Puri Contoh")
        #expect(result.snapshotLore.first?.text == "Klaim tercatat 0")
    }

    @Test func theSnapshotIsInTheRunsPinnedLanguageNotTheAppsCurrentOne() throws {
        // NFR-I18N-03: no mixed-language passage under any condition.
        let (engine, _) = engine()
        let run = try engine.start(
            questID: Fixture.questID, language: .en, method: .gps, accuracyM: 8)
        let result = try #require(run.result(forOrderIndex: 0))
        #expect(result.snapshotLore[0].text == "Documented claim 0")
        #expect(result.snapshotClueToNext == "Clue 0")
    }

    // MARK: - FR-ARR-03/04

    @Test func aManualArrivalIsRecordedAsSuchAndRewardedIdentically() throws {
        let (engine, _) = engine()
        let gps = try started(engine)
        let manualStore = InMemoryRunStore()
        let manual = try RunEngine(repository: StubContentRepository(), store: manualStore)
            .start(questID: Fixture.questID, language: .id, method: .manual, accuracyM: 480)

        #expect(gps.result(forOrderIndex: 0)?.arrivalMethod == .gps)
        #expect(manual.result(forOrderIndex: 0)?.arrivalMethod == .manual)
        // FR-ARR-04 — the override is a legitimate path, so the awards must be indistinguishable.
        #expect(manual.awards.map(\.type) == gps.awards.map(\.type))
        #expect(manual.awards.map(\.sourceID) == gps.awards.map(\.sourceID))
        #expect(manual.result(forOrderIndex: 0)?.gpsAccuracyM == 480)
    }

    // MARK: - FR-RUN-04

    @Test func abandoningKeepsEveryCheckpointAlreadyReached() throws {
        let (engine, _) = engine()
        var run = try started(engine)
        run = try engine.advanceToNextCheckpoint(runID: run.id)
        run = try engine.recordArrival(
            runID: run.id, checkpointID: "cp1", method: .gps, accuracyM: 8)
        run = try engine.abandon(runID: run.id, reason: .userChoice)

        #expect(run.state == .abandoned)
        #expect(run.abandonReason == .userChoice)
        #expect(run.reachedCount == 2)
        #expect(run.awards.filter { $0.type == .stamp }.count == 2)
        #expect(run.awards.filter { $0.type == .badge }.isEmpty)
    }

    @Test func anAbandonedRunIsNoLongerTheActiveDraft() throws {
        let (engine, _) = engine()
        let run = try started(engine)
        _ = try engine.abandon(runID: run.id, reason: .userChoice)
        #expect(try engine.activeRun(questID: Fixture.questID) == nil)
        // FR-START-06 — and starting again is therefore allowed, without a restart warning.
        #expect(throws: Never.self) { try started(engine) }
    }

    // MARK: - FR-CP-08

    @Test func progressCountsCheckpointsReachedNotDistance() throws {
        let (engine, _) = engine()
        var run = try started(engine)
        #expect(run.reachedCount == 1)
        #expect(run.checkpointCount == 3)
        run = try engine.advanceToNextCheckpoint(runID: run.id)
        #expect(run.reachedCount == 1, "Setting off is not arriving.")
    }
}
