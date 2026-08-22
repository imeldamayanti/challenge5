// `c2` phase 7. `00-scope.md` §6, `AD-4`, `NFR-PRIV-02`, `FR-RUN-06`.
import ContentKit
import Foundation
import RunEngine
import Testing
@testable import challange_5

/// Restore is only safe because it refuses to merge, so that refusal is the first thing guarded
/// here — and it is guarded by a test rather than by the comment above the `guard`.
///
/// The reassembly is the other half: a restored walk renders from its own snapshots (`AD-4`), and
/// the two things that were never sent must come back **absent** rather than invented.
@MainActor
struct RestoreTests {

    private func runRow(id: UUID = UUID(), state: String = "completed") -> RunRow {
        var run = Run(
            id: id,
            questID: "badung-empat-wajah",
            contentVersion: "2026.09.8",
            language: .en,
            snapshotQuestTitle: "The Last Traces of Badung",
            checkpointCount: 5,
            state: .completed,
            currentCheckpointIndex: 4,
            startedAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 500))
        run.completedAt = Date(timeIntervalSince1970: 500)
        if state == "abandoned" {
            run.state = .abandoned
            run.completedAt = nil
            run.abandonedAt = Date(timeIntervalSince1970: 400)
            run.abandonReason = .placeSuppressed
        }
        return RunRow(run, userID: UUID(), stamp: SyncStamp(
            deviceID: UUID(), createdAt: run.startedAt, updatedAt: run.updatedAt))
    }

    private func checkpointRow(runID: UUID, id: UUID = UUID()) -> CheckpointResultRow {
        CheckpointResultRow(
            CheckpointResult(
                id: id,
                checkpointID: "cp1",
                orderIndex: 0,
                arrivedAt: Date(timeIntervalSince1970: 10),
                arrivalMethod: .gps,
                gpsAccuracyM: 12,
                snapshotPlaceName: "Puri Agung Pemecutan",
                snapshotLore: [LoreBlockSnapshot(
                    text: "The gate is still in use.",
                    accuracy: .documented,
                    sourceCitations: ["Museum Bali, 2019"])],
                snapshotClueToNext: "walk north",
                snapshotContentVersion: "2026.09.8"),
            runID: runID, userID: UUID(), deviceID: UUID())
    }

    // MARK: The guard

    /// **The whole safety argument.** Empty means no second writer, which means no conflict can
    /// exist — not "conflicts are handled". The day this stops being true, `revision` comes back
    /// and so does a screen, and it is not this phase any more.
    @Test func restoreRefusesToRunWhenTheDeviceAlreadyHasAWalk() async throws {
        let store = InMemoryRunStore()
        try store.save(Run(
            questID: "badung-empat-wajah", contentVersion: "2026.09.8", language: .en,
            snapshotQuestTitle: "A walk this device already has", checkpointCount: 5,
            startedAt: Date(), updatedAt: Date()))

        let restorer = RunRestorer(
            loadRuns: { try store.runs() },
            saveRun: { try store.save($0) },
            session: UnconfiguredSupabaseSession(),
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://example.invalid")!,
                publishableKey: "sb_publishable_test"),
            state: InMemorySyncStateStore())

        // Nil, not an outcome: it did not run at all, which is different from running and
        // finding nothing.
        #expect(await restorer.restoreIfLocalStoreIsEmpty() == nil)
        #expect(try store.runs().count == 1)
    }

    /// With no backend there is nothing to restore from, and that must look the same as a device
    /// that already has walks: nothing happens and nothing is said.
    @Test func withNoBackendRestoreDoesNothing() async {
        #expect(await NoRunRestoring().restoreIfLocalStoreIsEmpty() == nil)
    }

    // MARK: Reassembly

    @Test func aRestoredWalkKeepsItsIdentityAndItsSnapshots() throws {
        let id = UUID()
        let run = runRow(id: id)
        let checkpoint = checkpointRow(runID: id)
        let assembled = try #require(RunAssembly.runs(
            from: [run], checkpoints: [checkpoint], tasks: [], awards: []).first)

        #expect(assembled.id == id)
        #expect(assembled.questID == "badung-empat-wajah")
        #expect(assembled.contentVersion == "2026.09.8")
        #expect(assembled.language == .en)
        #expect(assembled.state == .completed)
        #expect(assembled.completedAt != nil)
        // `AD-4` — the snapshots are why a restored walk renders correctly against content that has
        // since changed or been withdrawn.
        #expect(assembled.orderedCheckpointResults.first?.snapshotPlaceName == "Puri Agung Pemecutan")
        #expect(assembled.orderedCheckpointResults.first?.snapshotLore.first?.sourceCitations
            == ["Museum Bali, 2019"])
    }

    /// The two values that were never sent must come back **absent**, not guessed.
    @Test func whatWasNeverSentComesBackEmptyRatherThanInvented() throws {
        let id = UUID()
        let assembled = try #require(RunAssembly.runs(
            from: [runRow(id: id)], checkpoints: [checkpointRow(runID: id)],
            tasks: [], awards: []).first)
        let checkpoint = try #require(assembled.orderedCheckpointResults.first)

        // `NFR-PRIV-02`: only the band ever left the device, and turning a band back into a number
        // would put a fiction into a restored record.
        #expect(checkpoint.gpsAccuracyM == nil)
        // No server column, by phase 2's decision. It is what the *next* screen prints during a
        // walk, and a finished walk never shows it.
        #expect(checkpoint.snapshotClueToNext == nil)
    }

    /// `runs_abandoned_has_reason` survives the round trip, so a walk the kill-switch ended still
    /// says why after a reinstall.
    @Test func anAbandonedWalkKeepsItsReason() throws {
        let assembled = try #require(RunAssembly.runs(
            from: [runRow(state: "abandoned")], checkpoints: [], tasks: [], awards: []).first)
        #expect(assembled.state == .abandoned)
        #expect(assembled.abandonReason == .placeSuppressed)
    }

    /// Children land under the right parents, and nothing crosses between two walks.
    @Test func childrenAreAttachedToTheirOwnWalk() throws {
        let first = UUID()
        let second = UUID()
        let firstCheckpoint = UUID()
        let assembled = RunAssembly.runs(
            from: [runRow(id: first), runRow(id: second)],
            checkpoints: [
                checkpointRow(runID: first, id: firstCheckpoint),
                checkpointRow(runID: second),
            ],
            tasks: [TaskResultRow(
                TaskResult(
                    taskID: "t1", type: .reflection, promptSnapshot: "Q",
                    skipped: false, text: "an answer",
                    completedAt: Date(timeIntervalSince1970: 20)),
                checkpointResultID: firstCheckpoint, runID: first, userID: UUID(),
                deviceID: UUID(), photoID: nil)],
            awards: [AwardRow(
                Award(type: .stamp, sourceID: "s1", snapshotName: "Puri Agung",
                      awardedAt: Date(timeIntervalSince1970: 30)),
                runID: second, userID: UUID(), deviceID: UUID())])

        let one = try #require(assembled.first { $0.id == first })
        let two = try #require(assembled.first { $0.id == second })
        #expect(one.orderedCheckpointResults.first?.taskResults.first?.text == "an answer")
        #expect(one.awards.isEmpty)
        #expect(two.orderedCheckpointResults.first?.taskResults.isEmpty == true)
        #expect(two.awards.first?.sourceID == "s1")
    }

    // MARK: Photographs (B9)

    /// A restored `TaskResult` **names** its photograph before the bytes exist, because
    /// `photo_id` is the task's own id and `PhotoStore` derives its path from exactly that. Without
    /// this the record would have no way to point at the file once it arrived.
    @Test func aRestoredTaskNamesItsPhotographBeforeTheBytesArrive() throws {
        let runID = UUID()
        let checkpointID = UUID()
        let taskID = UUID()
        let assembled = try #require(RunAssembly.runs(
            from: [runRow(id: runID)],
            checkpoints: [checkpointRow(runID: runID, id: checkpointID)],
            tasks: [TaskResultRow(
                TaskResult(
                    id: taskID, taskID: "t-photo", type: .photo, promptSnapshot: "P",
                    skipped: false, photoRelativePath: "sidequest-photos/\(taskID.uuidString).jpg",
                    completedAt: Date(timeIntervalSince1970: 20)),
                checkpointResultID: checkpointID, runID: runID, userID: UUID(),
                deviceID: UUID(), photoID: taskID)],
            awards: []).first)

        let task = try #require(assembled.orderedCheckpointResults.first?.taskResults.first)
        #expect(task.photoRelativePath == FilePhotoStore.relativePath(forRecordID: taskID))
    }

    /// And a task that never had one comes back with none, rather than a path to nothing.
    @Test func aRestoredTaskWithNoPhotographNamesNoFile() throws {
        let runID = UUID()
        let checkpointID = UUID()
        let assembled = try #require(RunAssembly.runs(
            from: [runRow(id: runID)],
            checkpoints: [checkpointRow(runID: runID, id: checkpointID)],
            tasks: [TaskResultRow(
                TaskResult(
                    taskID: "t1", type: .reflection, promptSnapshot: "Q",
                    skipped: false, text: "an answer",
                    completedAt: Date(timeIntervalSince1970: 20)),
                checkpointResultID: checkpointID, runID: runID, userID: UUID(),
                deviceID: UUID(), photoID: nil)],
            awards: []).first)
        #expect(assembled.orderedCheckpointResults.first?.taskResults.first?.photoRelativePath == nil)
    }

    /// `save` and `place` must agree on where a photograph lives, or a restored record points at a
    /// file the download wrote somewhere else.
    @Test func placeAndSaveAgreeOnThePath() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("photos-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FilePhotoStore(directory: directory)
        let id = UUID()
        #expect(!store.hasImage(forRecordID: id))

        let bytes = Data("not really a jpeg".utf8)
        let placed = try store.place(bytes, recordID: id)
        #expect(placed == FilePhotoStore.relativePath(forRecordID: id))
        #expect(store.hasImage(forRecordID: id))
    }

    /// A restore that lands must not make the next foreground push every walk straight back.
    @Test func restoredWalksAreMarkedAsAlreadyLanded() {
        let state = InMemorySyncStateStore()
        let id = UUID()
        let landed = Date(timeIntervalSince1970: 500)
        state.markPushed(runID: id, updatedAt: landed)
        #expect(!state.needsPush(runID: id, updatedAt: landed))
    }
}
