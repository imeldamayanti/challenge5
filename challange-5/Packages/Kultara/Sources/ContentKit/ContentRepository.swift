import Foundation

public enum ContentRepositoryError: Error, Equatable, CustomStringConvertible {
    case resourcesUnavailable
    case missingDocument(String)
    case malformedDocument(path: String, reason: String)

    public var description: String {
        switch self {
        case .resourcesUnavailable:
            "The content resources are not present in the bundle."
        case .missingDocument(let path):
            "Content document \"\(path)\" is missing."
        case .malformedDocument(let path, let reason):
            "Content document \"\(path)\" is malformed: \(reason)"
        }
    }
}

/// The read side of content, protocol-fronted so v3's `CachedRemoteContentRepository` is a new
/// implementation and nothing else (`system-design.md` §5, §15).
///
/// Deliberately absent: any notion of loading, refreshing, connectivity, or freshness. A caller
/// cannot ask whether content is up to date, because in v1 the question has no meaning and in v3
/// answering it in a user-facing path is exactly the mistake `AD-3` exists to prevent.
public protocol ContentRepository: Sendable {
    func manifest() throws -> Manifest
    func contentBundleVersion() throws -> String
    func quests() throws -> [Quest]
    func quest(id: String) throws -> Quest?
    func place(id: String) throws -> Place?

    /// The discovery list minus anything withdrawn (`FR-DISC-08`, list side). The suppressed sets
    /// are passed in rather than fetched: whoever owns the kill-switch owns the fetch, and this
    /// type stays free of it.
    func quests(suppressingQuestIDs: Set<String>, suppressingPlaceIDs: Set<String>) throws -> [Quest]

    /// A URL for a bundled asset path such as `quests/x/route-preview.png`, or nil if absent.
    func assetURL(_ relativePath: String) throws -> URL?
}

/// v1: content ships inside the app bundle, so no download is required to start a quest
/// (`FR-OFF-01`).
///
/// The constructor takes a `Bundle` and nothing else. There is no session, no client, no location
/// manager — which is how `FR-DISC-01` is met rather than merely intended: there is nothing here
/// that could block on a network or a permission, at any location on earth.
public struct BundledContentRepository: ContentRepository {

    private let root: URL
    private let cache: LoadedContent

    /// The bundle carrying the shipped content. `Bundle.module` is internal to the target, so it
    /// is resolved here rather than exposed as a default argument.
    public static var contentBundle: Bundle { .module }

    public init() throws {
        try self.init(bundle: Self.contentBundle)
    }

    public init(bundle: Bundle) throws {
        guard let resourceURL = bundle.resourceURL else {
            throw ContentRepositoryError.resourcesUnavailable
        }
        try self.init(contentRoot: resourceURL)
    }

    /// Also used by the CLI validator, which points at the authored directory rather than a
    /// built resource bundle — one loader, so the validator cannot pass on a tree the app then
    /// fails to read.
    public init(contentRoot: URL) throws {
        root = contentRoot
        cache = try ContentDirectoryLoader.load(from: contentRoot)
    }

    public func bundle() throws -> ContentBundle { cache.bundle }

    public func manifest() throws -> Manifest { cache.bundle.manifest }

    public func contentBundleVersion() throws -> String { cache.bundle.manifest.contentBundleVersion }

    /// Manifest order, not directory order. Directory enumeration order is a filesystem detail
    /// and would reshuffle the discovery list between machines.
    public func quests() throws -> [Quest] {
        cache.bundle.manifest.quests.compactMap { id in cache.bundle.quest(id: id) }
    }

    public func quest(id: String) throws -> Quest? { cache.bundle.quest(id: id) }

    public func place(id: String) throws -> Place? { cache.bundle.place(id: id) }

    public func quests(
        suppressingQuestIDs: Set<String>,
        suppressingPlaceIDs: Set<String>
    ) throws -> [Quest] {
        try quests().filter { quest in
            guard !suppressingQuestIDs.contains(quest.id) else { return false }
            // A quest missing one of its checkpoints is not a shorter quest — it is a quest that
            // cannot be walked. It leaves the list whole rather than silently losing a stop.
            return !quest.checkpoints.contains { suppressingPlaceIDs.contains($0.placeId) }
        }
    }

    public func assetURL(_ relativePath: String) throws -> URL? {
        let url = root.appendingPathComponent("assets").appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// For the validator: V14 and V15 read the asset tree that this repository would serve.
    public func assetInventory() throws -> any AssetInventory {
        DirectoryAssetInventory(root: root)
    }

    /// The raw documents, for the two rules that must run before decoding (V1, V7).
    public func rawDocuments() throws -> [String: Data] { cache.rawDocuments }
}

// MARK: - Loading

struct LoadedContent: Sendable {
    let bundle: ContentBundle
    /// Path relative to the content root → bytes, retained so V1 and V7 can be checked on the
    /// text the writer actually typed.
    let rawDocuments: [String: Data]
}

enum ContentDirectoryLoader {

    static func load(from root: URL) throws -> LoadedContent {
        let decoder = JSONDecoder()
        var raw: [String: Data] = [:]

        func read(_ relativePath: String) throws -> Data {
            let url = root.appendingPathComponent(relativePath)
            guard let data = FileManager.default.contents(atPath: url.path) else {
                throw ContentRepositoryError.missingDocument(relativePath)
            }
            raw[relativePath] = data
            return data
        }

        func decode<T: Decodable>(_ type: T.Type, _ relativePath: String) throws -> T {
            let data = try read(relativePath)
            do {
                return try decoder.decode(type, from: data)
            } catch {
                throw ContentRepositoryError.malformedDocument(
                    path: relativePath, reason: String(describing: error))
            }
        }

        let manifest = try decode(Manifest.self, "manifest.json")
        let places = try manifest.places.map { try decode(Place.self, "places/\($0).json") }
        let quests = try manifest.quests.map { try decode(Quest.self, "quests/\($0).json") }

        // Consent is a build input. When the directory is absent — which is the case in every
        // shipped app — the bundle simply carries none, and rules V4/V5 are not judged at
        // runtime (`schema.md` §A.1).
        var consentRecords: [ConsentRecord] = []
        if FileManager.default.fileExists(atPath: root.appendingPathComponent("consent").path) {
            for placeID in manifest.places {
                let relativePath = "consent/\(placeID).json"
                guard FileManager.default.fileExists(
                    atPath: root.appendingPathComponent(relativePath).path) else { continue }
                consentRecords.append(try decode(ConsentRecord.self, relativePath))
            }
        }

        return LoadedContent(
            bundle: ContentBundle(
                manifest: manifest, places: places, quests: quests, consentRecords: consentRecords),
            rawDocuments: raw)
    }
}

struct DirectoryAssetInventory: AssetInventory {
    let root: URL

    func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(
            atPath: root.appendingPathComponent("assets").appendingPathComponent(relativePath).path)
    }

    /// Every byte the content release costs the app: JSON documents and assets together
    /// (`NFR-PERF-07`).
    func totalPayloadBytes() -> Int {
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { return 0 }

        var total = 0
        for case let url as URL in walker {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            total += values?.fileSize ?? 0
        }
        return total
    }
}
