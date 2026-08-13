import ContentKit
import Foundation
import Testing
@testable import RunEngine

/// `NFR-REL-01` / `FR-RUN-02` — a Run survives force-quit, termination and restart.
///
/// Force-quit is simulated the way `system-design.md` §14 describes: the store object is discarded
/// after each transition and a fresh one is opened over the same directory. A test that kept the
/// same instance would be testing the in-memory cache and calling it durability.
@MainActor
struct FileRunStoreTests {

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kultara-run-store-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func everyTransitionSurvivesTheStoreBeingDiscardedAndReopened() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = StubContentRepository()

        let run = try RunEngine(repository: repository, store: try FileRunStore(directory: directory))
            .start(questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)

        // Each step opens a brand-new store, as a relaunched app would.
        _ = try RunEngine(repository: repository, store: try FileRunStore(directory: directory))
            .advanceToNextCheckpoint(runID: run.id)
        _ = try RunEngine(repository: repository, store: try FileRunStore(directory: directory))
            .recordArrival(runID: run.id, checkpointID: "cp1", method: .gps, accuracyM: 12)
        _ = try RunEngine(repository: repository, store: try FileRunStore(directory: directory))
            .recordTaskResult(runID: run.id, checkpointID: "cp0", taskID: "t0",
                              skipped: true)

        let reopened = try #require(
            try FileRunStore(directory: directory).run(id: run.id))
        #expect(reopened.reachedCount == 2)
        #expect(reopened.currentCheckpointIndex == 1)
        #expect(reopened.state == .active)
        #expect(reopened.result(forOrderIndex: 1)?.arrivalMethod == .gps)
    }

    @Test func snapshotTextRoundTripsThroughJSONUnchanged() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let run = try RunEngine(
            repository: StubContentRepository(),
            store: try FileRunStore(directory: directory))
            .start(questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)

        let reopened = try #require(try FileRunStore(directory: directory).run(id: run.id))
        #expect(reopened.result(forOrderIndex: 0)?.snapshotLore
                == run.result(forOrderIndex: 0)?.snapshotLore)
        // ISO-8601 stores whole seconds. Sub-second precision on "when this walk began" is not
        // something any requirement asks for, and a readable timestamp on disk is worth more when
        // somebody has to look at a Run file to work out what went wrong.
        #expect(abs(reopened.startedAt.timeIntervalSince(run.startedAt)) < 1)
    }

    @Test func aCorruptDocumentCostsOneRunNotTheWholeHistory() throws {
        // NFR-REL-04 — a partially written record must not stop the app opening.
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try FileRunStore(directory: directory)
        let good = try RunEngine(repository: StubContentRepository(), store: store)
            .start(questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)
        try Data("{ not json".utf8).write(
            to: directory.appendingPathComponent("\(UUID().uuidString).json"))

        let reopened = try FileRunStore(directory: directory)
        #expect(try reopened.runs().count == 1)
        #expect(try reopened.run(id: good.id) != nil)
    }

    @Test func deletingAllLocalDataLeavesNothingBehind() throws {
        // FR-SET-02.
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try FileRunStore(directory: directory)
        _ = try RunEngine(repository: StubContentRepository(), store: store)
            .start(questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)

        #expect(try store.deleteAll() == 1)
        #expect(try FileRunStore(directory: directory).runs().isEmpty)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(remaining.filter { $0.hasSuffix(".json") }.isEmpty)
    }

    @Test func theHomeScreenSeesTheMostRecentDraftAndTheFinishedWalks() throws {
        // FR-RUN-03, FR-DONE-06.
        let store = InMemoryRunStore()
        let now = Date()
        let older = Run(
            questID: "a", contentVersion: "1", language: .id, snapshotQuestTitle: "A",
            checkpointCount: 2, state: .active, startedAt: now.addingTimeInterval(-3600),
            updatedAt: now.addingTimeInterval(-3600))
        let newer = Run(
            questID: "b", contentVersion: "1", language: .id, snapshotQuestTitle: "B",
            checkpointCount: 2, state: .active, startedAt: now, updatedAt: now)
        let done = Run(
            questID: "c", contentVersion: "1", language: .id, snapshotQuestTitle: "C",
            checkpointCount: 2, state: .completed, startedAt: now, updatedAt: now,
            completedAt: now)
        for run in [older, newer, done] { try store.save(run) }

        #expect(try store.mostRecentActiveRun()?.id == newer.id)
        #expect(try store.completedRuns().map(\.id) == [done.id])
    }
}
