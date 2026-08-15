import Foundation

/// Everything one content release contains, decoded. `consentRecords` is a build input and is
/// never shipped to a device (`schema.md` §A.1) — it is present here because the validator needs
/// it and the validator runs at build time.
public struct ContentBundle: Sendable, Equatable {
    public let manifest: Manifest
    public let places: [Place]
    public let quests: [Quest]
    /// Schema 2 (PRD §5.15). Empty for a bundle authored against schema 1.
    public let sideQuests: [SideQuest]
    public let collections: [LetterCollection]
    public let consentRecords: [ConsentRecord]

    public init(
        manifest: Manifest,
        places: [Place],
        quests: [Quest],
        sideQuests: [SideQuest] = [],
        collections: [LetterCollection] = [],
        consentRecords: [ConsentRecord] = []
    ) {
        self.manifest = manifest
        self.places = places
        self.quests = quests
        self.sideQuests = sideQuests
        self.collections = collections
        self.consentRecords = consentRecords
    }

    public func place(id: String) -> Place? {
        places.first { $0.id == id }
    }

    public func quest(id: String) -> Quest? {
        quests.first { $0.id == id }
    }

    public func sideQuest(id: String) -> SideQuest? {
        sideQuests.first { $0.id == id }
    }

    /// Every sidequest sitting at one Place. A Place may carry more than one — nothing in the
    /// schema says otherwise — so this returns a list rather than an optional.
    public func sideQuests(atPlaceID placeID: String) -> [SideQuest] {
        sideQuests.filter { $0.placeId == placeID }
    }

    public func collection(id: String) -> LetterCollection? {
        collections.first { $0.id == id }
    }

    /// Which collection, and which slot, a sidequest fills. Exactly one of each, held by rules
    /// V24 and V26 (`FR-SIDE-05`, `FR-SIDE-08`).
    public func slot(forSideQuestID sideQuestID: String) -> (collection: LetterCollection, slot: LetterSlot)? {
        for collection in collections {
            if let slot = collection.slots.first(where: { $0.sideQuestId == sideQuestID }) {
                return (collection, slot)
            }
        }
        return nil
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
    /// The bytes of one asset, for the rules that have to look inside a file rather than only
    /// check that it is there (V18). Nil when the inventory cannot read it, which is why the
    /// default is nil rather than a crash: a rule that needs bytes does not run without them.
    func data(_ relativePath: String) -> Data?
}

public extension AssetInventory {
    func data(_ relativePath: String) -> Data? { nil }
}
