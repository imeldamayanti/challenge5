import Foundation

/// Everything one content release contains, decoded. `consentRecords` is a build input and is
/// never shipped to a device (`schema.md` §A.1) — it is present here because the validator needs
/// it and the validator runs at build time.
public struct ContentBundle: Sendable, Equatable {
    public let manifest: Manifest
    public let places: [Place]
    public let quests: [Quest]
    public let consentRecords: [ConsentRecord]

    public init(
        manifest: Manifest,
        places: [Place],
        quests: [Quest],
        consentRecords: [ConsentRecord] = []
    ) {
        self.manifest = manifest
        self.places = places
        self.quests = quests
        self.consentRecords = consentRecords
    }

    public func place(id: String) -> Place? {
        places.first { $0.id == id }
    }

    public func quest(id: String) -> Quest? {
        quests.first { $0.id == id }
    }

    public func consentRecord(id: String) -> ConsentRecord? {
        consentRecords.first { $0.placeId == id }
    }

    /// The Places a quest visits, in checkpoint order. Missing ids are dropped here and reported
    /// by validator rule V9 — a renderer must not have to reason about a dangling reference.
    public func places(for quest: Quest) -> [Place] {
        quest.orderedCheckpoints.compactMap { place(id: $0.placeId) }
    }
}

/// What the validator needs to know about the asset tree without reading it into memory.
/// A protocol rather than a directory path so the rule tests do not need a filesystem.
public protocol AssetInventory: Sendable {
    func exists(_ relativePath: String) -> Bool
    /// Total bytes of the content payload — JSON plus assets (V15).
    func totalPayloadBytes() -> Int
}
