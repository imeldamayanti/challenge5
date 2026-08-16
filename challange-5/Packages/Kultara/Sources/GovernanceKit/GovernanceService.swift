import Foundation

/// Fetches bytes. Abstracted so the tests can exercise every failure the network has without one.
public protocol GovernanceTransport: Sendable {
    /// Returns the response body, or throws. **Never** answers "is the network up?" — see `AD-3`.
    func get(_ url: URL) async throws -> Data
}

/// `URLSession`, with a short timeout because nothing waits on this.
public struct URLSessionGovernanceTransport: GovernanceTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        // The last good copy is on disk, so a stale CDN answer is worse than no answer: it can
        // *replace* a fresher document the app already holds.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GovernanceError.badStatus(http.statusCode)
        }
        return data
    }
}

public enum GovernanceError: Error, Equatable {
    case badStatus(Int)
    case malformed
}

/// Where the last good copy lives between launches.
public protocol GovernanceStore: Sendable {
    func loadLastGood() -> SuppressionsDocument?
    func saveLastGood(_ document: SuppressionsDocument)
}

/// One JSON file beside the app's other support files.
public struct FileGovernanceStore: GovernanceStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public init(directory: URL) {
        self.init(url: directory.appendingPathComponent("suppressions.json"))
    }

    public func loadLastGood() -> SuppressionsDocument? {
        guard let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(SuppressionsDocument.self, from: data),
              document.isWellFormed
        else { return nil }
        return document
    }

    public func saveLastGood(_ document: SuppressionsDocument) {
        guard let data = try? JSONEncoder().encode(document) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Atomic: a half-written file that decodes to a *shorter* list of withdrawals is a
        // withdrawal that stops applying, which is the failure this whole service exists around.
        try? data.write(to: url, options: .atomic)
    }
}

/// The kill-switch client (`AD-5`, `FR-ERR-09`, `NFR-SEC-02`).
///
/// It does one thing: fetch a static, schema-validated JSON file over TLS, and keep the last good
/// copy when the fetch does not produce one.
///
/// **There is no reachability check here and there must never be one** (`AD-3`). The service does
/// not ask whether the network is up; it attempts a fetch and treats every way that can fail —
/// timeout, DNS, 502, truncated body, malformed JSON, an empty id in an array — identically, by
/// keeping what it already had. `PermissionCallBoundaryTests` fails the build if a reachability API
/// appears, which is the point rather than an inconvenience.
///
/// It is also **optional at runtime**: if every call here fails forever, the app behaves exactly as
/// it does today. Nothing in discovery, the run flow or the summary waits on an answer.
public actor GovernanceService {

    private let url: URL
    private let transport: any GovernanceTransport
    private let store: any GovernanceStore

    /// What the app should currently be hiding. Available synchronously, from disk, before any
    /// fetch is attempted — `FR-ERR-09` requires launch not to wait on this, and the cheapest way
    /// to guarantee that is for the fetch to be something that *updates* an answer rather than
    /// something that *produces* one.
    private(set) public var current: SuppressionsDocument

    public init(url: URL, transport: any GovernanceTransport, store: any GovernanceStore) {
        self.url = url
        self.transport = transport
        self.store = store
        self.current = store.loadLastGood() ?? .empty
    }

    /// Attempts one refresh. Returns what the app should be hiding afterwards, which is the new
    /// document on success and the unchanged last good copy on every failure.
    ///
    /// Deliberately returns a document rather than throwing: a caller that has to handle an error
    /// is a caller that can get the handling wrong, and there is exactly one correct behaviour.
    @discardableResult
    public func refresh() async -> SuppressionsDocument {
        guard let data = try? await transport.get(url) else { return current }
        guard let document = try? JSONDecoder().decode(SuppressionsDocument.self, from: data),
              document.isWellFormed
        else {
            // Not logged as an error the user sees, and not retried in a loop. A malformed document
            // is an operator problem; the app's correct response is to carry on with what it had.
            return current
        }
        current = document
        store.saveLastGood(document)
        return document
    }

    public func isSuppressed(placeID: String) -> Bool {
        current.suppressedPlaceIDs.contains(placeID)
    }

    public func isSuppressed(questID: String) -> Bool {
        current.suppressedQuestIDs.contains(questID)
    }

    public func isSuppressed(sideQuestID: String) -> Bool {
        current.suppressedSideQuestIDs.contains(sideQuestID)
    }
}
