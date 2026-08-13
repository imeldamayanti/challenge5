import Foundation

public enum RunStoreError: Error, Equatable, CustomStringConvertible {
    case unwritable(path: String, reason: String)
    case unreadable(path: String, reason: String)

    public var description: String {
        switch self {
        case .unwritable(let path, let reason): "Could not write \"\(path)\": \(reason)"
        case .unreadable(let path, let reason): "Could not read \"\(path)\": \(reason)"
        }
    }
}

/// The write side of user data.
///
/// A protocol for the same reason `ContentRepository` is one: the storage technology is a decision
/// with a shelf life, and the ordering and award rules above it must not be re-tested when it
/// changes. `schema.md` Part B specifies SwiftData models; this milestone ships a file-backed
/// implementation of the same shape, and a Supabase-backed *sync* layer arrives later underneath
/// the same call — never in front of it, because `AD-3` makes the local store authoritative and
/// `FR-OFF-02` makes the whole loop a release gate in airplane mode.
///
/// `@MainActor` is a deviation from `system-design.md` §9, which puts writes on a background
/// `@ModelActor`. The reason it is acceptable here: a Run is a few kilobytes and a walk produces
/// tens of writes, so the main-thread cost is unmeasurable, and moving it off the main actor later
/// is an implementation change behind this protocol rather than a change to any caller.
@MainActor
public protocol RunStore: AnyObject {
    func runs() throws -> [Run]
    func run(id: UUID) throws -> Run?
    /// `FR-START-06` — at most one active Run per quest.
    func activeRun(questID: String) throws -> Run?
    func save(_ run: Run) throws
    func delete(id: UUID) throws
    /// `FR-SET-02`. Returns how many Runs went, so the confirmation can name what was removed.
    @discardableResult func deleteAll() throws -> Int
}

public extension RunStore {
    /// `FR-RUN-03` — the home screen's resume entry point.
    func mostRecentActiveRun() throws -> Run? {
        try runs()
            .filter { $0.state == .active }
            .max { $0.updatedAt < $1.updatedAt }
    }

    /// `FR-DONE-06` — completed Runs are listed and re-openable before the full Journal exists.
    func completedRuns() throws -> [Run] {
        try runs()
            .filter { $0.state == .completed }
            .sorted { ($0.completedAt ?? $0.updatedAt) > ($1.completedAt ?? $1.updatedAt) }
    }
}

// MARK: - In memory

@MainActor
public final class InMemoryRunStore: RunStore {
    private var storage: [UUID: Run] = [:]

    public init(_ seed: [Run] = []) {
        for run in seed { storage[run.id] = run }
    }

    public func runs() throws -> [Run] { Array(storage.values) }

    public func run(id: UUID) throws -> Run? { storage[id] }

    public func activeRun(questID: String) throws -> Run? {
        storage.values.first { $0.questID == questID && $0.state == .active }
    }

    public func save(_ run: Run) throws { storage[run.id] = run }

    public func delete(id: UUID) throws { storage[id] = nil }

    @discardableResult public func deleteAll() throws -> Int {
        let count = storage.count
        storage.removeAll()
        return count
    }
}

// MARK: - On disk

/// One JSON document per Run under `Application Support/Kultara/runs`.
///
/// One file per Run rather than one file holding all of them: `FR-RUN-01` wants every transition
/// durable within 500 ms, and rewriting every walk the user has ever taken on each arrival is a
/// cost that grows with their history for no reason. A corrupt document costs one Run and leaves
/// the app launchable, which is what `NFR-REL-04` asks for.
@MainActor
public final class FileRunStore: RunStore {

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    /// Read once, kept in step with every write. The disk is the durable copy; this is so the
    /// arrival screen does not re-read the directory to redraw.
    private var cache: [UUID: Run]

    public static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Kultara/runs", isDirectory: true)
    }

    public init(directory: URL = FileRunStore.defaultDirectory()) throws {
        self.directory = directory
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        cache = [:]

        try Self.createDirectoryIfNeeded(directory)
        cache = Self.loadAll(from: directory, decoder: decoder)
    }

    private static func createDirectoryIfNeeded(_ directory: URL) throws {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            throw RunStoreError.unwritable(
                path: directory.path, reason: String(describing: error))
        }
    }

    /// A document that will not decode is skipped, not thrown. `NFR-REL-04`: one partially written
    /// record must not stop the app launching, and the honest cost of a corrupt file is that Run,
    /// not the user's whole history.
    private static func loadAll(from directory: URL, decoder: JSONDecoder) -> [UUID: Run] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return [:]
        }
        var loaded: [UUID: Run] = [:]
        for name in names where name.hasSuffix(".json") {
            let url = directory.appendingPathComponent(name)
            guard let data = FileManager.default.contents(atPath: url.path),
                  let run = try? decoder.decode(Run.self, from: data) else { continue }
            loaded[run.id] = run
        }
        return loaded
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    public func runs() throws -> [Run] { Array(cache.values) }

    public func run(id: UUID) throws -> Run? { cache[id] }

    public func activeRun(questID: String) throws -> Run? {
        cache.values.first { $0.questID == questID && $0.state == .active }
    }

    public func save(_ run: Run) throws {
        let target = url(for: run.id)
        do {
            let data = try encoder.encode(run)
            // Atomic: a force-quit mid-write leaves the previous document intact rather than a
            // half-written one (`NFR-REL-01`).
            try data.write(to: target, options: .atomic)
        } catch {
            throw RunStoreError.unwritable(path: target.path, reason: String(describing: error))
        }
        cache[run.id] = run
    }

    public func delete(id: UUID) throws {
        cache[id] = nil
        let target = url(for: id)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        do {
            try FileManager.default.removeItem(at: target)
        } catch {
            throw RunStoreError.unwritable(path: target.path, reason: String(describing: error))
        }
    }

    @discardableResult public func deleteAll() throws -> Int {
        let count = cache.count
        for id in cache.keys { try delete(id: id) }
        return count
    }
}
