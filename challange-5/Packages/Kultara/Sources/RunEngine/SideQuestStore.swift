import Foundation

/// The write side of sidequest user data.
///
/// A protocol for the same reason `RunStore` is one: the storage technology is a decision with a
/// shelf life, and the letter and idempotency rules above it must not be re-tested when it changes.
///
/// **Lookup is by `sideQuestID`, not by UUID.** There is at most one record per sidequest, which is
/// `FR-SIDE-05`'s idempotency rule expressed in the store's shape rather than in a guard somebody
/// can forget to write: re-entering a place that is already completed finds the existing record.
///
/// `@MainActor` for the reasons `RunStore` states: a record is a few kilobytes, a sidequest produces
/// a handful of writes, and moving this off the main actor later is an implementation change behind
/// the protocol rather than a change to any caller.
@MainActor
public protocol SideQuestStore: AnyObject {
    func records() throws -> [SideQuestRecord]
    func record(sideQuestID: String) throws -> SideQuestRecord?
    func save(_ record: SideQuestRecord) throws
    func delete(sideQuestID: String) throws
    /// `FR-SET-02`. Returns how many records went, so the confirmation can name what was removed.
    @discardableResult func deleteAll() throws -> Int
}

public extension SideQuestStore {
    /// The records that fill a collection's slots, most recently completed first.
    func records(collectionID: String) throws -> [SideQuestRecord] {
        try records()
            .filter { $0.collectionID == collectionID }
            .sorted { $0.slotIndex < $1.slotIndex }
    }

    /// `FR-SIDE-12`, `s0` D9 — a completed sidequest is deregistered, the same way a completed
    /// quest's start region is.
    func completedSideQuestIDs() throws -> Set<String> {
        Set(try records().filter(\.isCompleted).map(\.sideQuestID))
    }
}

// MARK: - In memory

@MainActor
public final class InMemorySideQuestStore: SideQuestStore {
    private var storage: [String: SideQuestRecord] = [:]

    public init(_ seed: [SideQuestRecord] = []) {
        for record in seed { storage[record.sideQuestID] = record }
    }

    public func records() throws -> [SideQuestRecord] { Array(storage.values) }

    public func record(sideQuestID: String) throws -> SideQuestRecord? { storage[sideQuestID] }

    public func save(_ record: SideQuestRecord) throws { storage[record.sideQuestID] = record }

    public func delete(sideQuestID: String) throws { storage[sideQuestID] = nil }

    @discardableResult public func deleteAll() throws -> Int {
        let count = storage.count
        storage.removeAll()
        return count
    }
}

// MARK: - On disk

/// One JSON document per record under `Application Support/Kultara/sidequests`.
///
/// Directly mirrors `FileRunStore`, and for the same stated reasons: one file per record rather
/// than one file holding all of them, written atomically so a force-quit mid-write leaves the
/// previous document intact (`NFR-REL-01`), and a corrupt document skipped at load rather than
/// thrown — one bad file costs one place, not the app's launch (`NFR-REL-04`).
///
/// Documents are named by UUID rather than by `sideQuestID` so that a content id is never required
/// to be a legal filename; the id lives inside the document and indexes the cache.
@MainActor
public final class FileSideQuestStore: SideQuestStore {

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    /// Read once, kept in step with every write. The disk is the durable copy.
    private var cache: [String: SideQuestRecord]

    public static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Kultara/sidequests", isDirectory: true)
    }

    public init(directory: URL = FileSideQuestStore.defaultDirectory()) throws {
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

    /// A document that will not decode is skipped, not thrown (`NFR-REL-04`).
    private static func loadAll(
        from directory: URL, decoder: JSONDecoder
    ) -> [String: SideQuestRecord] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return [:]
        }
        var loaded: [String: SideQuestRecord] = [:]
        for name in names where name.hasSuffix(".json") {
            let url = directory.appendingPathComponent(name)
            guard let data = FileManager.default.contents(atPath: url.path),
                  let record = try? decoder.decode(SideQuestRecord.self, from: data)
            else { continue }
            loaded[record.sideQuestID] = record
        }
        return loaded
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    public func records() throws -> [SideQuestRecord] { Array(cache.values) }

    public func record(sideQuestID: String) throws -> SideQuestRecord? { cache[sideQuestID] }

    public func save(_ record: SideQuestRecord) throws {
        let target = url(for: record.id)
        do {
            let data = try encoder.encode(record)
            try data.write(to: target, options: .atomic)
        } catch {
            throw RunStoreError.unwritable(path: target.path, reason: String(describing: error))
        }
        cache[record.sideQuestID] = record
    }

    public func delete(sideQuestID: String) throws {
        guard let record = cache[sideQuestID] else { return }
        cache[sideQuestID] = nil
        let target = url(for: record.id)
        guard FileManager.default.fileExists(atPath: target.path) else { return }
        do {
            try FileManager.default.removeItem(at: target)
        } catch {
            throw RunStoreError.unwritable(path: target.path, reason: String(describing: error))
        }
    }

    @discardableResult public func deleteAll() throws -> Int {
        let count = cache.count
        for id in cache.keys { try delete(sideQuestID: id) }
        return count
    }
}
