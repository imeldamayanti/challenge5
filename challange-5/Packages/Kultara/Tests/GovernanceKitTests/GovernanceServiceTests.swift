import Foundation
import Testing
@testable import GovernanceKit

// `c1` §4b — the kill-switch client. AD-5, FR-ERR-09, NFR-SEC-02, AD-3.
//
// Every test below is about a FAILURE. That is deliberate: the happy path of "a valid document
// arrives and is used" is one line, and every real risk in this service is on the other side —
// a malformed document replacing a good one, a schema-1 rollback failing validation, a fetch
// failure being distinguished from a decode failure and handled differently.

private struct StubTransport: GovernanceTransport {
    let result: Result<Data, any Error>
    func get(_ url: URL) async throws -> Data { try result.get() }
}

private struct FailingTransport: GovernanceTransport {
    struct Boom: Error {}
    func get(_ url: URL) async throws -> Data { throw Boom() }
}

private final class MemoryStore: GovernanceStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: SuppressionsDocument?

    init(_ initial: SuppressionsDocument? = nil) { stored = initial }

    func loadLastGood() -> SuppressionsDocument? {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    func saveLastGood(_ document: SuppressionsDocument) {
        lock.lock(); defer { lock.unlock() }
        stored = document
    }
}

private let url = URL(string: "https://example.invalid/content/suppressions.json")!

private func data(_ json: String) -> Data { Data(json.utf8) }

private let schema2 = """
{"schemaVersion":2,"updatedAt":"2026-08-16T00:00:00Z",
 "suppressedPlaceIds":["p1"],"suppressedQuestIds":["q1"],"suppressedSideQuestIds":["s1"]}
"""

private let schema1 = """
{"schemaVersion":1,"updatedAt":"2026-08-01T00:00:00Z",
 "suppressedPlaceIds":["p1"],"suppressedQuestIds":["q1"]}
"""

struct SuppressionsDocumentTests {

    @Test func aSchemaTwoDocumentDecodesWithAllThreeArrays() throws {
        let doc = try JSONDecoder().decode(SuppressionsDocument.self, from: data(schema2))
        #expect(doc.schemaVersion == 2)
        #expect(doc.suppressedPlaceIDs == ["p1"])
        #expect(doc.suppressedQuestIDs == ["q1"])
        #expect(doc.suppressedSideQuestIDs == ["s1"])
        #expect(doc.isWellFormed)
    }

    /// `c1` D3, and the single most important test in this target.
    ///
    /// A schema-1 document must decode and carry no sidequests. If `suppressedSideQuestIds` were
    /// required, a rollback or an older publisher would fail validation, the app would fall back to
    /// its last good copy, and a withdrawal would silently stop applying — the exact failure AD-5
    /// exists to prevent, arriving through the mechanism meant to prevent it.
    @Test func aSchemaOneDocumentStillValidatesAndCarriesNoSideQuests() throws {
        let doc = try JSONDecoder().decode(SuppressionsDocument.self, from: data(schema1))
        #expect(doc.schemaVersion == 1)
        #expect(doc.suppressedPlaceIDs == ["p1"])
        #expect(doc.suppressedSideQuestIDs.isEmpty)
        #expect(doc.isWellFormed)
    }

    /// The other direction of the same rule: an unfamiliar *newer* schema is accepted, because the
    /// arrays this client reads still mean what they meant. Refusing it would turn a
    /// forward-compatible addition into a kill-switch outage.
    @Test func aNewerSchemaIsAcceptedRatherThanRefused() throws {
        let doc = try JSONDecoder().decode(SuppressionsDocument.self, from: data("""
        {"schemaVersion":99,"updatedAt":"x","suppressedPlaceIds":["p1"],
         "suppressedQuestIds":[],"suppressedSideQuestIds":[],"somethingNew":{"a":1}}
        """))
        #expect(doc.isWellFormed)
        #expect(doc.suppressedPlaceIDs == ["p1"])
    }

    /// The two arrays that predate schema 2 stay required: their absence is a malformed document,
    /// not an older one, and treating it as older would let a truncated file read as "nothing is
    /// withdrawn".
    @Test func aDocumentMissingThePlaceArrayIsMalformedRatherThanEmpty() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(SuppressionsDocument.self, from: data("""
            {"schemaVersion":2,"updatedAt":"x","suppressedQuestIds":[]}
            """))
        }
    }

    @Test func anEmptyIDMakesTheDocumentMalformed() throws {
        let doc = try JSONDecoder().decode(SuppressionsDocument.self, from: data("""
        {"schemaVersion":2,"updatedAt":"x","suppressedPlaceIds":["  "],
         "suppressedQuestIds":[],"suppressedSideQuestIds":[]}
        """))
        // It decodes — an empty string is a valid string — and is rejected by validation, which is
        // where a rule about content rather than shape belongs.
        #expect(!doc.isWellFormed)
    }
}

struct GovernanceServiceTests {

    @Test func aValidDocumentIsAdoptedAndPersisted() async {
        let store = MemoryStore()
        let service = GovernanceService(
            url: url, transport: StubTransport(result: .success(data(schema2))), store: store)

        let result = await service.refresh()
        #expect(result.suppressedQuestIDs == ["q1"])
        #expect(await service.isSuppressed(questID: "q1"))
        #expect(store.loadLastGood()?.suppressedSideQuestIDs == ["s1"])
    }

    /// `FR-ERR-09`. A fetch that throws — timeout, DNS, TLS, anything — leaves the last good copy
    /// in place. The service never asked whether the network was up (`AD-3`) and does not start now.
    @Test func aFailedFetchKeepsTheLastGoodCopy() async throws {
        let good = try JSONDecoder().decode(SuppressionsDocument.self, from: data(schema2))
        let store = MemoryStore(good)
        let service = GovernanceService(url: url, transport: FailingTransport(), store: store)

        let result = await service.refresh()
        #expect(result.suppressedPlaceIDs == ["p1"])
        #expect(await service.isSuppressed(placeID: "p1"))
    }

    /// The failure that matters more than a network failure: a *successful* fetch of rubbish. A
    /// service that adopted it would un-withdraw everything the moment a publisher misbehaved.
    @Test func malformedBytesDoNotReplaceAGoodDocument() async throws {
        let good = try JSONDecoder().decode(SuppressionsDocument.self, from: data(schema2))
        let store = MemoryStore(good)
        let service = GovernanceService(
            url: url, transport: StubTransport(result: .success(data("<html>502</html>"))),
            store: store)

        let result = await service.refresh()
        #expect(result.suppressedPlaceIDs == ["p1"], "malformed bytes replaced the last good copy")
        #expect(store.loadLastGood()?.suppressedPlaceIDs == ["p1"])
    }

    /// A document that decodes but fails validation is discarded on the same terms as one that does
    /// not decode. Two different-looking failures, one correct response.
    @Test func aDecodableButInvalidDocumentIsDiscardedToo() async throws {
        let good = try JSONDecoder().decode(SuppressionsDocument.self, from: data(schema2))
        let store = MemoryStore(good)
        let service = GovernanceService(
            url: url,
            transport: StubTransport(result: .success(data("""
            {"schemaVersion":2,"updatedAt":"x","suppressedPlaceIds":[""],
             "suppressedQuestIds":[],"suppressedSideQuestIds":[]}
            """))),
            store: store)

        _ = await service.refresh()
        #expect(await service.isSuppressed(placeID: "p1"))
    }

    /// `FR-ERR-09` — nothing waits on a fetch. A first launch with no stored copy and no network
    /// answers "nothing is withdrawn" immediately rather than blocking or throwing.
    @Test func aFirstLaunchWithNoCopyAndNoNetworkStartsEmptyRatherThanFailing() async {
        let service = GovernanceService(
            url: url, transport: FailingTransport(), store: MemoryStore())
        #expect(await service.current == .empty)
        #expect(!(await service.isSuppressed(questID: "anything")))
        _ = await service.refresh()
        #expect(await service.current == .empty)
    }

    @Test func theStoredCopySurvivesARelaunch() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gov-\(UUID().uuidString)")
        let store = FileGovernanceStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let good = try JSONDecoder().decode(SuppressionsDocument.self, from: data(schema2))
        store.saveLastGood(good)

        #expect(FileGovernanceStore(directory: directory).loadLastGood()?.suppressedQuestIDs == ["q1"])
    }

    /// A corrupt file on disk is not a crash and not a fatal error: it is the same "no last good
    /// copy" a first launch has.
    @Test func aCorruptStoredCopyReadsAsAbsent() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gov-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try data("not json").write(to: directory.appendingPathComponent("suppressions.json"))

        #expect(FileGovernanceStore(directory: directory).loadLastGood() == nil)
    }
}
