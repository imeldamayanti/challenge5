// `c2` phase 3. `schema.md` Part B, `NFR-PRIV-02`, `FR-SET-02`, `AD-2`.
import ContentKit
import Foundation
import RunEngine
import Testing
@testable import challange_5

/// What goes on the wire, and what decides whether anything goes at all.
///
/// The transport itself is `PostgrestClient`'s and is tested upstream; isolation is proved over
/// real HTTP with real tokens rather than here (`b3` §4). What is worth guarding in-process is the
/// projection — every column phase 2's table names — and the two rules that keep a push cheap and
/// safe: idempotence, and not sending what has not changed.
@MainActor
struct SyncTests {

    private func run(
        updatedAt: Date = Date(timeIntervalSince1970: 1_000),
        state: RunState = .completed
    ) -> Run {
        let started = Date(timeIntervalSince1970: 0)
        return Run(
            questID: "badung-empat-wajah",
            contentVersion: "2026.09.8",
            language: .en,
            snapshotQuestTitle: "The Last Traces of Badung",
            checkpointCount: 5,
            state: state,
            currentCheckpointIndex: 0,
            startedAt: started,
            updatedAt: updatedAt,
            completedAt: state == .completed ? updatedAt : nil,
            checkpointResults: [checkpoint()],
            awards: [Award(
                type: .stamp, sourceID: "stamp-1", snapshotName: "Puri Agung",
                awardedAt: started)])
    }

    private func checkpoint(accuracyM: Double? = 12) -> CheckpointResult {
        CheckpointResult(
            checkpointID: "cp1",
            orderIndex: 0,
            arrivedAt: Date(timeIntervalSince1970: 10),
            arrivalMethod: .gps,
            gpsAccuracyM: accuracyM,
            snapshotPlaceName: "Puri Agung Pemecutan",
            snapshotLore: [
                LoreBlockSnapshot(text: "A", accuracy: .documented, sourceCitations: ["one", "two"]),
                LoreBlockSnapshot(text: "B", accuracy: .oral, sourceCitations: ["two", "three"]),
            ],
            snapshotClueToNext: "walk north",
            snapshotContentVersion: "2026.09.8",
            taskResults: [TaskResult(
                taskID: "t1", type: .reflection, promptSnapshot: "What did you notice?",
                skipped: false, text: "The gate is still in use.",
                completedAt: Date(timeIntervalSince1970: 20))])
    }

    // MARK: The projection

    @Test func aRunCarriesEveryColumnTheSchemaDemands() throws {
        let device = UUID()
        let user = UUID()
        let subject = run()
        let row = RunRow(subject, userID: user, stamp: SyncStamp(
            deviceID: device, createdAt: subject.startedAt, updatedAt: subject.updatedAt))

        #expect(row.id == subject.id)
        #expect(row.user_id == user)
        #expect(row.device_id == device)
        #expect(row.quest_id == "badung-empat-wajah")
        #expect(row.content_version == "2026.09.8")
        #expect(row.language == "en")
        #expect(row.state == "completed")
        #expect(row.completed_at == subject.updatedAt)
        #expect(row.abandon_reason == nil)
        // Phase 2's finding: created_at and updated_at are projected from fields the record already
        // has, rather than being new stored state.
        #expect(row.created_at == subject.startedAt)
        #expect(row.updated_at == subject.updatedAt)
    }

    /// `runs_abandoned_has_reason` takes both or neither, so a row that carries one without the
    /// other is rejected on the walker's device with nothing to explain it.
    @Test func anAbandonedRunCarriesBothItsTimestampAndItsReason() throws {
        var subject = run(state: .abandoned)
        subject.abandonedAt = Date(timeIntervalSince1970: 900)
        subject.abandonReason = .placeSuppressed
        let row = RunRow(subject, userID: UUID(), stamp: SyncStamp(
            deviceID: UUID(), createdAt: subject.startedAt, updatedAt: subject.updatedAt))
        #expect(row.state == "abandoned")
        #expect(row.abandoned_at != nil)
        #expect(row.abandon_reason == "placeSuppressed")
    }

    /// `NFR-PRIV-02`. The metre value never leaves the device; three bands do, and they are the
    /// three strings the column's check constraint accepts.
    @Test func accuracyLeavesAsABandAndNeverAsAFigure() throws {
        func band(_ metres: Double?) -> String? {
            CheckpointResultRow(
                checkpoint(accuracyM: metres), runID: UUID(), userID: UUID(), deviceID: UUID()
            ).gps_accuracy_bucket
        }
        #expect(band(19.9) == "lt20")
        #expect(band(20) == "b20_75")
        #expect(band(74.9) == "b20_75")
        // **75.0 exactly is `gt75`**, because `AccuracyBand` splits on `..<75`. The `c2` phase 2
        // plan text said `b20_75` for this boundary; the shipped enum disagrees and the shipped
        // enum wins — it has been producing `ops.events` rows on prod since phase 0, and moving the
        // boundary now would make two generations of telemetry mean different things by the same
        // token. Asserted here so the disagreement is recorded rather than rediscovered.
        #expect(band(75) == "gt75")
        #expect(band(75.1) == "gt75")
        // No fix at all is not a band. A manual arrival indoors legitimately has none, and
        // inventing one would be worse than the column being null.
        #expect(band(nil) == nil)
    }

    /// Projected from the lore, order preserved, each citation once — so a citation three blocks
    /// share does not appear three times in a column nobody queries.
    @Test func sourcesAreProjectedFromTheLoreAndDeduplicated() throws {
        let row = CheckpointResultRow(
            checkpoint(), runID: UUID(), userID: UUID(), deviceID: UUID())
        #expect(row.snapshot_sources == ["one", "two", "three"])
        #expect(row.snapshot_lore.count == 2)
    }

    /// `AD-2`. A skip is a resolution, and the row says so rather than looking like an absence.
    @Test func aSkippedTaskIsARowWithSkippedTrueAndNoAnswer() throws {
        let skipped = TaskResult(
            taskID: "t2", type: .question, promptSnapshot: "Which direction?",
            skipped: true, text: nil, completedAt: Date(timeIntervalSince1970: 30))
        let row = TaskResultRow(
            skipped, checkpointResultID: UUID(), runID: UUID(), userID: UUID(),
            deviceID: UUID(), photoID: nil)
        #expect(row.skipped)
        #expect(row.answer_text == nil)
        #expect(row.type == "question")
        // Phase 4 fills this. Until then null, and the column's `on delete set null` is what lets a
        // photograph be removed later without taking the answer with it.
        #expect(row.photo_id == nil)
    }

    /// A `Date` encoded by the default strategy is a float, and PostgREST would take it and store
    /// something nobody meant.
    @Test func timestampsGoOverTheWireAsISO8601() throws {
        let row = RunRow(run(), userID: UUID(), stamp: SyncStamp(
            deviceID: UUID(),
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)))
        let encoded = try SyncWireFormat.encoder.encode(row)
        let text = try #require(String(data: encoded, encoding: .utf8))
        #expect(text.contains("1970-01-01T00:00:00.000Z"))
    }

    // MARK: What gets sent

    /// The rule that keeps a foreground push cheap: `Run.updatedAt` is maintained by `RunEngine` on
    /// every write, so "changed since it landed" is a comparison rather than a flag somebody has to
    /// remember to set.
    @Test func anUnchangedWalkIsNotSentTwice() {
        let state = InMemorySyncStateStore()
        let subject = run()
        #expect(state.needsPush(runID: subject.id, updatedAt: subject.updatedAt))

        state.markPushed(runID: subject.id, updatedAt: subject.updatedAt)
        #expect(!state.needsPush(runID: subject.id, updatedAt: subject.updatedAt))

        // A run that is written again — the closing reflection answered after completion
        // (`FR-TASK-07`) — becomes dirty again.
        let later = subject.updatedAt.addingTimeInterval(60)
        #expect(state.needsPush(runID: subject.id, updatedAt: later))
    }

    /// `FR-SET-02`. Without this, a walk written after erasure could be judged "already sent"
    /// against a row that no longer exists.
    @Test func erasureForgetsWhatHasAlreadyBeenPushed() {
        let state = InMemorySyncStateStore()
        let id = UUID()
        state.markPushed(runID: id, updatedAt: Date(timeIntervalSince1970: 5))
        state.forgetAll()
        #expect(state.needsPush(runID: id, updatedAt: Date(timeIntervalSince1970: 5)))
    }

    /// Losing the file costs one redundant push per walk and nothing else, because every write is
    /// an upsert on the row's own id. That is why it is an ordinary file.
    @Test func theFileStoreRemembersAcrossInstances() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sync-state-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let id = UUID()
        let landed = Date(timeIntervalSince1970: 7)
        FileSyncStateStore(url: url).markPushed(runID: id, updatedAt: landed)
        #expect(!FileSyncStateStore(url: url).needsPush(runID: id, updatedAt: landed))
    }

    // MARK: Erasure

    final class SpyAccountDeleter: AccountDeleting, @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0
        let answer: Bool

        init(answer: Bool) { self.answer = answer }
        var callCount: Int { lock.withLock { calls } }

        @discardableResult func deleteAccount() async -> Bool {
            lock.withLock { calls += 1 }
            return answer
        }
    }

    /// The one place `01-architecture.md` R4's silence is wrong: a walker told their data is gone,
    /// while it is not, cannot act on something only they can decide about.
    @Test func aFailedServerDeletionIsInTheSummaryRatherThanSwallowed() async throws {
        let deleter = SpyAccountDeleter(answer: false)
        let summary = try await RunAndPreferencesDataEraser(
            store: InMemoryRunStore(),
            accountDeleter: deleter,
            preferences: InMemoryAppPreferencesStore()
        ).eraseAllLocalData()

        #expect(deleter.callCount == 1)
        #expect(summary.serverDataDeleted == false)
    }

    /// And `nil` rather than `true` when there was nothing on a server to delete. The difference
    /// between "we did not need to" and "we tried and could not" is the whole reason it is optional.
    @Test func withNoBackendTheServerOutcomeIsUnknownRatherThanSuccess() async throws {
        let summary = try await RunAndPreferencesDataEraser(
            store: InMemoryRunStore(),
            preferences: InMemoryAppPreferencesStore()
        ).eraseAllLocalData()
        #expect(summary.serverDataDeleted == nil)
    }
}
