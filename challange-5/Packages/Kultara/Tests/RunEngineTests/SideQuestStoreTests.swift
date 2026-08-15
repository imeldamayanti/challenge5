import ContentKit
import Foundation
import Testing
@testable import RunEngine

/// `NFR-REL-01` / `NFR-REL-04` — a letter survives force-quit, termination and restart, and one
/// corrupt document costs one place rather than the app's launch.
///
/// Force-quit is simulated the way `FileRunStoreTests` does it: the store object is discarded after
/// each transition and a fresh one is opened over the same directory. A test that kept the same
/// instance would be testing the in-memory cache and calling it durability.
@MainActor
struct FileSideQuestStoreTests {

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kultara-sidequest-store-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func everyTransitionSurvivesTheStoreBeingDiscardedAndReopened() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SideQuestFixture.repository()

        try SideQuestEngine(
            repository: repository, store: try FileSideQuestStore(directory: directory))
            .discover(sideQuestID: SideQuestFixture.quizID, language: .id,
                      method: .gps, accuracyM: 9)
        _ = try SideQuestEngine(
            repository: repository, store: try FileSideQuestStore(directory: directory))
            .markLoreOpened(sideQuestID: SideQuestFixture.quizID)
        _ = try SideQuestEngine(
            repository: repository, store: try FileSideQuestStore(directory: directory))
            .answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)

        let reopened = try #require(
            try FileSideQuestStore(directory: directory)
                .record(sideQuestID: SideQuestFixture.quizID))
        #expect(reopened.state == .completed)
        #expect(reopened.letter == "A")
        #expect(reopened.loreFirstOpenedAt != nil)
        #expect(reopened.awards.count == 1)
        #expect(reopened.challenge?.isCorrect == true)
    }

    @Test func theSnapshotAndItsCitationsRoundTripThroughJSONUnchanged() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let record = try SideQuestEngine(
            repository: SideQuestFixture.repository(),
            store: try FileSideQuestStore(directory: directory))
            .discover(sideQuestID: SideQuestFixture.quizID, language: .id,
                      method: .gps, accuracyM: 9)

        let reopened = try #require(
            try FileSideQuestStore(directory: directory)
                .record(sideQuestID: SideQuestFixture.quizID))
        #expect(reopened.snapshotLore == record.snapshotLore)
        #expect(reopened.contentVersion == record.contentVersion)
        // ISO-8601 stores whole seconds, as it does for a Run.
        #expect(abs(reopened.discoveredAt.timeIntervalSince(record.discoveredAt)) < 1)
    }

    @Test func aCorruptDocumentCostsOnePlaceNotTheWholeCollection() throws {
        // NFR-REL-04.
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try FileSideQuestStore(directory: directory)
        try SideQuestEngine(repository: SideQuestFixture.repository(), store: store)
            .discover(sideQuestID: SideQuestFixture.quizID, language: .id,
                      method: .gps, accuracyM: 9)
        try Data("{ not json".utf8).write(
            to: directory.appendingPathComponent("\(UUID().uuidString).json"))

        let reopened = try FileSideQuestStore(directory: directory)
        #expect(try reopened.records().count == 1)
        #expect(try reopened.record(sideQuestID: SideQuestFixture.quizID) != nil)
    }

    @Test func deletingAllLocalDataLeavesNoLettersBehind() throws {
        // FR-SET-02 — erasure that left the letters behind would be a lie told by a confirmation
        // dialog.
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try FileSideQuestStore(directory: directory)
        let engine = SideQuestEngine(repository: SideQuestFixture.repository(), store: store)
        try engine.discover(sideQuestID: SideQuestFixture.quizID, language: .id,
                            method: .gps, accuracyM: 9)
        try engine.discover(sideQuestID: SideQuestFixture.photoID, language: .id,
                            method: .gps, accuracyM: 9)

        #expect(try store.deleteAll() == 2)
        #expect(try FileSideQuestStore(directory: directory).records().isEmpty)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(remaining.filter { $0.hasSuffix(".json") }.isEmpty)
    }

    @Test func deletingOneSidequestLeavesTheOtherAlone() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try FileSideQuestStore(directory: directory)
        let engine = SideQuestEngine(repository: SideQuestFixture.repository(), store: store)
        try engine.discover(sideQuestID: SideQuestFixture.quizID, language: .id,
                            method: .gps, accuracyM: 9)
        try engine.discover(sideQuestID: SideQuestFixture.photoID, language: .id,
                            method: .gps, accuracyM: 9)

        try store.delete(sideQuestID: SideQuestFixture.quizID)
        let reopened = try FileSideQuestStore(directory: directory)
        #expect(try reopened.record(sideQuestID: SideQuestFixture.quizID) == nil)
        #expect(try reopened.record(sideQuestID: SideQuestFixture.photoID) != nil)
    }

    @Test func thereIsAtMostOneRecordPerSidequest() throws {
        // `FR-SIDE-05` in the store's shape rather than in a guard somebody can forget to write.
        let store = InMemorySideQuestStore()
        let engine = SideQuestEngine(repository: SideQuestFixture.repository(), store: store)
        let first = try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)

        var duplicate = first
        duplicate.state = .completed
        try store.save(duplicate)

        #expect(try store.records().count == 1)
        #expect(try store.record(sideQuestID: SideQuestFixture.quizID)?.state == .completed)
    }

    @Test func theCompletedSetIsWhatMonitoringDeregisters() throws {
        // `s0` D9 — the query the proximity service reads.
        let store = InMemorySideQuestStore()
        let engine = SideQuestEngine(repository: SideQuestFixture.repository(), store: store)
        try engine.discover(sideQuestID: SideQuestFixture.quizID, language: .id,
                            method: .gps, accuracyM: 9)
        try engine.discover(sideQuestID: SideQuestFixture.photoID, language: .id,
                            method: .gps, accuracyM: 9)
        #expect(try store.completedSideQuestIDs().isEmpty)

        _ = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)
        #expect(try store.completedSideQuestIDs() == [SideQuestFixture.quizID])
        #expect(try store.records(collectionID: SideQuestFixture.collectionID).map(\.slotIndex)
                == [0, 1])
    }
}
