import Foundation

/// What has already landed, so an unchanged walk is not re-sent.
///
/// **A timestamp, not a boolean and not a revision number.** `Run.updatedAt` is maintained on every
/// write inside `RunEngine` (five call sites), so "changed since it last landed" is a comparison
/// rather than a flag somebody has to remember to set. A flag has to be set by every writer; this
/// has to be set by nobody.
///
/// It is deliberately **not** `revision`: that column exists to resolve conflicts between two
/// writers, and C2 has one (`c2` phase 2's cut list). This is a local record of what this device has
/// already sent, which is a different thing wearing a similar shape.
protocol SyncStateStore: Sendable {
    // `nonisolated` on every member: the app target builds with MainActor default isolation, and
    // the only caller is an actor that is not the main one.
    nonisolated func needsPush(runID: UUID, updatedAt: Date) -> Bool
    nonisolated func markPushed(runID: UUID, updatedAt: Date)
    nonisolated func forgetAll()
}

/// One small JSON document beside the Runs, holding `runID -> the updatedAt that landed`.
///
/// Losing this file is survivable and costs one redundant push per walk: every write is an upsert on
/// the row's own id, so re-sending is a no-op on the server. That is why it is not in the Keychain,
/// not in `UserDefaults`, and not something erasure has to be careful about.
/// A lock rather than an actor, because `needsPush` has to answer **synchronously**: it is called
/// while choosing what to send, before any `await`, and an actor would make that a hop per walk for
/// a dictionary lookup.
nonisolated final class FileSyncStateStore: SyncStateStore, @unchecked Sendable {

    private let url: URL
    private let lock = NSLock()
    private var pushed: [UUID: Date]

    init(url: URL? = nil) {
        let resolved = url ?? FileSyncStateStore.defaultURL()
        self.url = resolved
        pushed = FileSyncStateStore.read(from: resolved)
    }

    func needsPush(runID: UUID, updatedAt: Date) -> Bool {
        lock.withLock {
            guard let landed = pushed[runID] else { return true }
            // A second's tolerance: `timestamptz` round-trips at microsecond precision but a `Date`
            // re-read from JSON can differ in the last bit, and a walk that re-pushed forever
            // because of floating point would be both invisible and constant.
            return updatedAt.timeIntervalSince(landed) > 1
        }
    }

    func markPushed(runID: UUID, updatedAt: Date) {
        let snapshot: [UUID: Date] = lock.withLock {
            pushed[runID] = updatedAt
            return pushed
        }
        FileSyncStateStore.write(snapshot, to: url)
    }

    func forgetAll() {
        lock.withLock { pushed = [:] }
        try? FileManager.default.removeItem(at: url)
    }

    private static func write(_ pushed: [UUID: Date], to url: URL) {
        let encoded = pushed.reduce(into: [String: Double]()) {
            $0[$1.key.uuidString] = $1.value.timeIntervalSince1970
        }
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static func read(from url: URL) -> [UUID: Date] {
        guard let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: Double].self, from: data)
        else { return [:] }
        return raw.reduce(into: [UUID: Date]()) { result, entry in
            guard let id = UUID(uuidString: entry.key) else { return }
            result[id] = Date(timeIntervalSince1970: entry.value)
        }
    }

    private static func defaultURL() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("Kultara", isDirectory: true)
            .appendingPathComponent("backend", isDirectory: true)
            .appendingPathComponent("sync-state.json")
    }
}

/// For tests, and for the no-backend case where nothing is ever pushed.
nonisolated final class InMemorySyncStateStore: SyncStateStore, @unchecked Sendable {
    private let lock = NSLock()
    private var pushed: [UUID: Date] = [:]

    init() {}

    func needsPush(runID: UUID, updatedAt: Date) -> Bool {
        lock.withLock {
            guard let landed = pushed[runID] else { return true }
            return updatedAt.timeIntervalSince(landed) > 1
        }
    }

    func markPushed(runID: UUID, updatedAt: Date) {
        lock.withLock { pushed[runID] = updatedAt }
    }

    func forgetAll() {
        lock.withLock { pushed = [:] }
    }

    /// What the tests assert against.
    var pushedRunIDs: Set<UUID> { lock.withLock { Set(pushed.keys) } }
}
