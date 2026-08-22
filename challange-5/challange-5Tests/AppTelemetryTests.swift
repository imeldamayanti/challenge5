// `c2` phase 0. Design §2.4, §6.2, `schema.md` §B.7, `NFR-OBS-01`, `NFR-PRIV-02`.
import Foundation
import Testing
@testable import challange_5
import TelemetryKit

/// What the app actually puts on the wire.
///
/// `TelemetryKitTests` already covers the queue, the batch caps and the flush contract. This suite
/// covers the layer above: that each catalogue row is built with the name and parameters
/// `schema.md` §B.7 specifies, that no payload carries an identifier, and that a raw accuracy
/// figure is turned into a band before it can leave.
///
/// `quest_completed` and `quest_abandoned` are here rather than only in a walk on a device: the two
/// events that end a walk are the expensive ones to reach by hand and the easy ones to get wrong,
/// and a arithmetic slip in the duration is not something a row in a chart makes obvious.
@MainActor
struct AppTelemetryTests {

    /// Records every batch it is handed and answers with whatever status the test asks for.
    final class RecordingTransport: TelemetryTransport, @unchecked Sendable {
        private let lock = NSLock()
        private var bodies: [Data] = []
        let status: Int

        init(status: Int = 200) { self.status = status }

        func post(_ body: Data, to url: URL) async throws -> Int {
            lock.withLock { bodies.append(body) }
            return status
        }

        var batches: [[String: Any]] {
            lock.withLock { bodies }.compactMap {
                try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
            }.compactMap { $0 }
        }
    }

    final class MemoryQueueStore: TelemetryQueueStore, @unchecked Sendable {
        private let lock = NSLock()
        private var file = TelemetryQueueFile()

        func load() -> TelemetryQueueFile { lock.withLock { file } }

        func save(_ file: TelemetryQueueFile) { lock.withLock { self.file = file } }
    }

    private static let configuration = BackendConfiguration(
        baseURL: URL(string: "https://example.invalid")!, publishableKey: "sb_publishable_test")

    private func telemetry(
        transport: RecordingTransport, store: MemoryQueueStore
    ) -> AppTelemetry {
        AppTelemetry(
            configuration: Self.configuration,
            store: store,
            transport: transport,
            runKeys: RunKeyStore(url: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("run-keys-\(UUID().uuidString).json")))
    }

    /// Waits for the fire-and-forget work `AppTelemetry` hands to its actor. The hop is the point
    /// of it — a screen transition must not wait on a disk write — so a test has to give it up too.
    private func settle(_ telemetry: AppTelemetry) async {
        await telemetry.settled()
    }

    private func events(in batch: [String: Any]) -> [[String: Any]] {
        (batch["events"] as? [[String: Any]]) ?? []
    }

    @Test func aWalkProducesTheCatalogueRowsWithTheParametersTheSchemaNames() async throws {
        let transport = RecordingTransport()
        let store = MemoryQueueStore()
        let telemetry = telemetry(transport: transport, store: store)
        let runID = UUID()

        telemetry.questStarted(
            questID: "q", contentVersion: "2026.09.0", language: "en", runID: runID)
        telemetry.checkpointArrived(
            checkpointID: "cp1", accuracyMetres: 12, arrivalMethod: "gps", runID: runID)
        telemetry.questCompleted(
            questID: "q", durationMinutes: 42, manualOverrideCount: 1, runID: runID)
        telemetry.questAbandoned(
            questID: "q", lastOrderIndex: 2, reason: "placeSuppressed", runID: runID)
        await settle(telemetry)
        telemetry.flush()
        await settle(telemetry)

        let batch = try #require(transport.batches.first)
        #expect(batch["schema_version"] as? Int == 1)
        let rows = events(in: batch)
        #expect(rows.count == 4)

        let byName = Dictionary(uniqueKeysWithValues: rows.map { ($0["name"] as? String ?? "", $0) })
        let started = try #require(byName["quest_started"]?["params"] as? [String: String])
        #expect(started == ["questID": "q", "contentVersion": "2026.09.0", "language": "en"])

        let arrived = try #require(byName["checkpoint_arrived"]?["params"] as? [String: String])
        // 12 m is `lt20`. The figure itself is gone by the time it reaches here (`NFR-PRIV-02`).
        #expect(arrived == ["checkpointID": "cp1", "accuracyBand": "lt20", "method": "gps"])
        #expect(!arrived.values.contains("12"))

        let completed = try #require(byName["quest_completed"]?["params"] as? [String: String])
        #expect(completed == ["questID": "q", "durationMin": "42", "manualOverrideCount": "1"])

        let abandoned = try #require(byName["quest_abandoned"]?["params"] as? [String: String])
        #expect(abandoned == ["questID": "q", "lastOrderIndex": "2", "reason": "placeSuppressed"])
    }

    /// Design §2.4 — the wire carries no identifier of any kind, only the per-walk key.
    @Test func noPayloadCarriesAnythingThatIdentifiesAWalker() async throws {
        let transport = RecordingTransport()
        let telemetry = telemetry(transport: transport, store: MemoryQueueStore())
        telemetry.questStarted(questID: "q", contentVersion: "v", language: "en", runID: UUID())
        await settle(telemetry)
        telemetry.flush()
        await settle(telemetry)

        let batch = try #require(transport.batches.first)
        let row = try #require(events(in: batch).first)
        let banned = ["user_id", "userID", "account_id", "session_id", "device_id", "deviceID"]
        for key in row.keys { #expect(!banned.contains(key)) }
        for key in (row["params"] as? [String: String] ?? [:]).keys {
            #expect(!banned.contains(key))
        }
        #expect(row["run_key"] != nil)
    }

    /// Two walks are two keys, and one walk is one key across every event it produces. That is the
    /// whole property §2.4 buys: a funnel stays analysable, and nothing joins two walks together.
    @Test func eachWalkGetsItsOwnKeyAndKeepsIt() async throws {
        let transport = RecordingTransport()
        let telemetry = telemetry(transport: transport, store: MemoryQueueStore())
        let first = UUID()
        let second = UUID()
        telemetry.questStarted(questID: "q", contentVersion: "v", language: "en", runID: first)
        telemetry.checkpointArrived(
            checkpointID: "cp1", accuracyMetres: 30, arrivalMethod: "gps", runID: first)
        telemetry.questStarted(questID: "q", contentVersion: "v", language: "en", runID: second)
        await settle(telemetry)
        telemetry.flush()
        await settle(telemetry)

        let rows = events(in: try #require(transport.batches.first))
        let keys = rows.map { $0["run_key"] as? String }
        #expect(Set(keys.compactMap { $0 }).count == 2)
        let firstWalk = rows.filter { ($0["params"] as? [String: String])?["checkpointID"] != nil }
        #expect(firstWalk.count == 1)
    }

    /// A flush the server did not take leaves every row queued (`system-design.md` §10). Anything
    /// other than a 200 is the same event — distinguishing them is where a reachability check
    /// starts (`AD-3`).
    @Test func aRefusedFlushKeepsEveryRowQueued() async throws {
        let store = MemoryQueueStore()
        let telemetry = telemetry(transport: RecordingTransport(status: 503), store: store)
        telemetry.questStarted(questID: "q", contentVersion: "v", language: "en", runID: UUID())
        await settle(telemetry)
        telemetry.flush()
        await settle(telemetry)
        #expect(store.load().events.count == 1)
    }

    /// `FR-SET-02` — "delete all local data" reaches the queue too, and says how much it took.
    @Test func erasingLocalDataEmptiesTheQueueAndCountsWhatWent() async throws {
        let store = MemoryQueueStore()
        let telemetry = telemetry(transport: RecordingTransport(), store: store)
        telemetry.questStarted(questID: "q", contentVersion: "v", language: "en", runID: UUID())
        await settle(telemetry)
        #expect(telemetry.eraseQueue() == 1)
        #expect(store.load().events.isEmpty)
    }

    /// With nothing configured the app is a normal app: every call is a no-op and nothing is
    /// queued for a flush that can never happen.
    @Test func withNoBackendConfiguredNothingIsQueued() async throws {
        let store = MemoryQueueStore()
        let telemetry = AppTelemetry(
            configuration: nil, store: store, transport: RecordingTransport(),
            runKeys: RunKeyStore(url: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("run-keys-\(UUID().uuidString).json")))
        telemetry.questStarted(questID: "q", contentVersion: "v", language: "en", runID: UUID())
        await settle(telemetry)
        #expect(store.load().events.isEmpty)
    }
}
