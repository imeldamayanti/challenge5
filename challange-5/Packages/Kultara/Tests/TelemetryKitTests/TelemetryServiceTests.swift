import Foundation
import Testing
// For `UUID.v7` alone (`c1` D7). `TelemetryKit` itself does not depend on `RunEngine` — the
// service takes ids from its caller.
import RunEngine
@testable import TelemetryKit

// `c1` §4c — anonymous telemetry. system-design.md §10, NFR-OBS-01, FR-ERR-10, AD-3, c1 D5/D6.

private actor Recorder {
    private(set) var bodies: [Data] = []
    func append(_ data: Data) { bodies.append(data) }
}

private struct StubTransport: TelemetryTransport {
    let status: Int
    let recorder: Recorder
    let throwsInstead: Bool

    init(status: Int, recorder: Recorder = Recorder(), throwsInstead: Bool = false) {
        self.status = status
        self.recorder = recorder
        self.throwsInstead = throwsInstead
    }

    struct Boom: Error {}

    func post(_ body: Data, to url: URL) async throws -> Int {
        await recorder.append(body)
        if throwsInstead { throw Boom() }
        return status
    }
}

private final class MemoryQueueStore: TelemetryQueueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var file = TelemetryQueueFile()

    func load() -> TelemetryQueueFile {
        lock.lock(); defer { lock.unlock() }
        return file
    }

    func save(_ file: TelemetryQueueFile) {
        lock.lock(); defer { lock.unlock() }
        self.file = file
    }
}

private let url = URL(string: "https://example.invalid/functions/v1/ingest")!

private func event(_ name: String = "e", runKey: UUID? = nil) -> TelemetryEvent {
    TelemetryEvent(id: UUID.v7(), name: name, runKey: runKey)
}

struct AccuracyBandTests {

    /// `c1` D5. The band is a token, not punctuation: it goes into JSON, a chart legend and a CSV
    /// without quoting, and `<20` would need escaping in at least two of those.
    @Test func theBandsAreTokensRatherThanPunctuation() {
        for band in AccuracyBand.allCases {
            #expect(band.rawValue.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" },
                    "\(band.rawValue) is not a token")
        }
    }

    @Test func metresMapToTheThreeBandsAtTheirBoundaries() {
        #expect(AccuracyBand(metres: 0) == .lt20)
        #expect(AccuracyBand(metres: 19.9) == .lt20)
        // 20 is the first value that is no longer "good": the boundary belongs to the wider band,
        // so a fix reported as exactly 20 m is never described as better than it was.
        #expect(AccuracyBand(metres: 20) == .b20_75)
        #expect(AccuracyBand(metres: 74.9) == .b20_75)
        #expect(AccuracyBand(metres: 75) == .gt75)
        #expect(AccuracyBand(metres: 5_000) == .gt75)
    }

    /// `c1` D5 — no coordinate leaves the device in any form, and no raw accuracy figure either.
    /// Asserted against the encoded bytes rather than the type, because that is what travels.
    @Test func anArrivalEventCarriesNoCoordinateAndNoRawAccuracy() throws {
        let arrival = TelemetryEvent.arrival(
            id: UUID.v7(), checkpointID: "cp-1", band: AccuracyBand(metres: 8.4),
            method: "gps", runKey: UUID())
        let encoded = String(decoding: try JSONEncoder().encode(arrival), as: UTF8.self)

        #expect(encoded.contains("lt20"))
        #expect(!encoded.contains("8.4"))
        for forbidden in ["lat", "lon", "latitude", "longitude", "coordinate", "accuracyM"] {
            #expect(!encoded.lowercased().contains(forbidden.lowercased()),
                    "\(forbidden) reached the wire: \(encoded)")
        }
    }

    /// `c1` D6 / design §2.4 — no user identifier of any kind, ever. A structural check on the
    /// encoded keys, because the risk is somebody adding a field, not somebody setting one.
    @Test func noEventFieldCanCarryAUserIdentifier() throws {
        let encoded = String(decoding: try JSONEncoder().encode(event()), as: UTF8.self)
        for forbidden in ["user_id", "userID", "device", "email", "install"] {
            #expect(!encoded.lowercased().contains(forbidden.lowercased()),
                    "\(forbidden) reached the wire: \(encoded)")
        }
    }
}

struct TelemetryServiceTests {

    @Test func aTwoHundredMarksRowsSent() async {
        let store = MemoryQueueStore()
        let service = TelemetryService(url: url, transport: StubTransport(status: 200), store: store)
        await service.record(event())
        await service.record(event())
        #expect(await service.queuedEventCount == 2)

        #expect(await service.flush())
        #expect(await service.queuedEventCount == 0)
        #expect(store.load().events.isEmpty)
    }

    /// system-design.md §10, and the rule the whole design rests on: anything that is not a 200
    /// leaves the rows queued. Every status is the same status.
    @Test func anythingOtherThanTwoHundredLeavesRowsQueued() async {
        for status in [0, 400, 401, 429, 500, 502, 503] {
            let service = TelemetryService(
                url: url, transport: StubTransport(status: status), store: MemoryQueueStore())
            await service.record(event())
            #expect(!(await service.flush()), "status \(status) reported success")
            #expect(await service.queuedEventCount == 1, "status \(status) dropped the row")
        }
    }

    /// A thrown error is handled identically to a bad status. Distinguishing them is where a
    /// reachability check would start, and `AD-3` forbids one.
    @Test func aThrownTransportErrorAlsoLeavesRowsQueued() async {
        let service = TelemetryService(
            url: url, transport: StubTransport(status: 200, throwsInstead: true),
            store: MemoryQueueStore())
        await service.record(event())
        #expect(!(await service.flush()))
        #expect(await service.queuedEventCount == 1)
    }

    /// The queue is durable *before* the flush, not after. An event lost because the process died
    /// between "recorded" and "written" is what §10's wording rules out.
    @Test func aRecordedEventIsOnDiskBeforeAnyFlushIsAttempted() {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tel-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileTelemetryQueueStore(directory: directory)

        let service = TelemetryService(
            url: url, transport: StubTransport(status: 500), store: store)
        Task { await service.record(event("arrived")) }

        // Read back through a second store over the same file — a relaunch, in other words.
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline && FileTelemetryQueueStore(directory: directory).load().events.isEmpty {
            usleep(20_000)
        }
        #expect(FileTelemetryQueueStore(directory: directory).load().events.first?.name == "arrived")
    }

    /// `FR-ERR-10`. Events may be pruned at a cap; survey responses may not, ever. A lost event is
    /// a gap in a chart. A lost survey answer is a person's words.
    @Test func surveyResponsesAreNeverPrunedByTheEventCap() async {
        let service = TelemetryService(
            url: url, transport: StubTransport(status: 500), store: MemoryQueueStore())
        await service.record(SurveyResponse(
            id: UUID.v7(), runKey: UUID(), questID: "q", questionID: "q1", response: "ingat"))

        for _ in 0..<(TelemetryService.maxQueuedEvents + 50) {
            await service.record(event())
        }

        #expect(await service.queuedEventCount == TelemetryService.maxQueuedEvents)
        #expect(await service.queuedSurveyCount == 1)
    }

    /// The function returns 400 above 200 rows, so the client never builds a batch it knows will
    /// be refused.
    @Test func aBatchNeverExceedsTheServersCap() async {
        let recorder = Recorder()
        let service = TelemetryService(
            url: url, transport: StubTransport(status: 200, recorder: recorder),
            store: MemoryQueueStore())
        for _ in 0..<(TelemetryService.maxBatchRows + 25) { await service.record(event()) }

        #expect(await service.flush())
        let body = try! JSONSerialization.jsonObject(with: await recorder.bodies[0]) as! [String: Any]
        #expect((body["events"] as! [Any]).count == TelemetryService.maxBatchRows)
        #expect(await service.queuedEventCount == 25)
    }

    @Test func theBatchCarriesTheSchemaVersionTheFunctionDemands() async throws {
        let recorder = Recorder()
        let service = TelemetryService(
            url: url, transport: StubTransport(status: 200, recorder: recorder),
            store: MemoryQueueStore())
        await service.record(event())
        _ = await service.flush()

        let body = try JSONSerialization.jsonObject(
            with: await recorder.bodies[0]) as! [String: Any]
        #expect(body["schema_version"] as? Int == 1)
        #expect(body["survey_responses"] != nil)
    }

    /// `c1` D6. `run_key` groups a walk's events; nothing else about the walker travels.
    @Test func eventsCarryTheRunKeyAndNothingElseAboutTheWalker() async throws {
        let runKey = UUID()
        let recorder = Recorder()
        let service = TelemetryService(
            url: url, transport: StubTransport(status: 200, recorder: recorder),
            store: MemoryQueueStore())
        await service.record(event("started", runKey: runKey))
        _ = await service.flush()

        let body = try JSONSerialization.jsonObject(
            with: await recorder.bodies[0]) as! [String: Any]
        let first = (body["events"] as! [[String: Any]])[0]
        #expect((first["run_key"] as? String)?.lowercased() == runKey.uuidString.lowercased())
        #expect(first["user_id"] == nil)
    }

    @Test func anEmptyQueueFlushesWithoutARequest() async {
        let recorder = Recorder()
        let service = TelemetryService(
            url: url, transport: StubTransport(status: 500, recorder: recorder),
            store: MemoryQueueStore())
        #expect(await service.flush())
        #expect(await recorder.bodies.isEmpty)
    }
}
