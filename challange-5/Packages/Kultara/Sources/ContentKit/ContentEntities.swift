import Foundation

// The authored, read-only content model (`schema.md` §A.3–A.7). Every type is a value type and
// every user-facing string is a `LocalizedText`, so the ID/EN parity rule is structural rather
// than a review habit (`NFR-I18N-01/02`).
//
// Nothing here references a user record, and nothing in the user store will hold one of these
// objects: the link runs the other way, by string id plus pinned content version
// (`system-design.md` §4).

// MARK: - Shared value objects

public struct Coordinate: Codable, Sendable, Equatable, Hashable {
    public let lat: Double
    public let lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

/// Where a Place sits on the region map, as a fraction of the image: `{0,0}` top-left,
/// `{1,1}` bottom-right.
///
/// Authored, not derived. The region map is an illustration — hand-drawn, taller than the island
/// is, with a stylised coastline — so projecting `coordinate` onto it would place every pin
/// somewhere wrong while looking precise. A drawing's pin positions are a drawing decision.
public struct MapPoint: Codable, Sendable, Equatable, Hashable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public var isInsideImage: Bool { (0...1).contains(x) && (0...1).contains(y) }
}

/// The illustrated map the discovery screen draws on. Ships as an asset, so the map screen works
/// with no network and no tile cache (`FR-MAP-01`, `FR-OFF-03`).
public struct RegionMapAsset: Codable, Sendable, Equatable, Hashable {
    public let asset: String
    /// Width ÷ height of the image, so the layout can reserve the right space before decoding it.
    public let aspectRatio: Double

    public init(asset: String, aspectRatio: Double) {
        self.asset = asset
        self.aspectRatio = aspectRatio
    }
}

public struct Money: Codable, Sendable, Equatable, Hashable {
    public let amount: Int
    public let currency: String

    public init(amount: Int, currency: String) {
        self.amount = amount
        self.currency = currency
    }

    public var isFree: Bool { amount == 0 }
}

public struct Source: Codable, Sendable, Equatable, Hashable {
    public let kind: SourceKind
    public let citation: String
    public let url: String?

    public init(kind: SourceKind, citation: String, url: String? = nil) {
        self.kind = kind
        self.citation = citation
        self.url = url
    }
}

/// One factual claim with its epistemic status attached. Lore is an array of these rather than
/// a paragraph, because `FR-CP-05` requires the label to be visible per claim — a writer cannot
/// produce an unlabelled sentence, as there is no field for one.
public struct LoreBlock: Codable, Sendable, Equatable, Hashable {
    public let text: LocalizedText
    public let accuracy: AccuracyLabel
    /// Indices into the owning Place's `sources` array.
    public let sourceRefs: [Int]

    public init(text: LocalizedText, accuracy: AccuracyLabel, sourceRefs: [Int]) {
        self.text = text
        self.accuracy = accuracy
        self.sourceRefs = sourceRefs
    }
}

// MARK: - Place

public struct OpeningHours: Codable, Sendable, Equatable, Hashable {
    /// ISO weekday, 1 = Monday … 7 = Sunday.
    public let weekday: Int
    public let open: TimeOfDay
    public let close: TimeOfDay

    public init(weekday: Int, open: TimeOfDay, close: TimeOfDay) {
        self.weekday = weekday
        self.open = open
        self.close = close
    }
}

public struct VisitingHours: Codable, Sendable, Equatable, Hashable {
    public let notes: LocalizedText
    public let weekly: [OpeningHours]

    public init(notes: LocalizedText, weekly: [OpeningHours]) {
        self.notes = notes
        self.weekly = weekly
    }
}

public struct PhotoPolicy: Codable, Sendable, Equatable, Hashable {
    public let level: PhotoPolicyLevel
    public let notes: LocalizedText

    public init(level: PhotoPolicyLevel, notes: LocalizedText) {
        self.level = level
        self.notes = notes
    }
}

/// `NFR-A11Y-07` — preview must disclose steps, surface and terrain honestly enough for a user
/// with mobility limitations to self-assess. These fields are what that disclosure reads from.
public struct AccessibilityInfo: Codable, Sendable, Equatable, Hashable {
    public let hasSteps: Bool
    public let stepCount: Int?
    public let surface: String
    public let notes: LocalizedText

    public init(hasSteps: Bool, stepCount: Int?, surface: String, notes: LocalizedText) {
        self.hasSteps = hasSteps
        self.stepCount = stepCount
        self.surface = surface
        self.notes = notes
    }
}

public struct Place: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    /// `NFR-I18N-04` — a Place name renders in its official local form in both languages.
    /// The pair exists so the field is uniform, not so the name gets translated.
    public let nameOfficial: LocalizedText
    public let nameVariants: [String]
    public let type: PlaceType
    public let isSacred: Bool
    public let coordinate: Coordinate
    public let arrivalRadiusM: Int
    public let address: LocalizedText
    public let visitingHours: VisitingHours
    public let dressCode: LocalizedText
    public let photoPolicy: PhotoPolicy
    public let entryCost: Money
    public let accessibility: AccessibilityInfo
    public let loreStandalone: [LoreBlock]
    public let sources: [Source]
    public let consentRecordId: String
    /// Position on the region map, when content ships one (validator rule V17).
    public let mapPoint: MapPoint?

    public init(
        id: String,
        nameOfficial: LocalizedText,
        nameVariants: [String] = [],
        type: PlaceType,
        isSacred: Bool,
        coordinate: Coordinate,
        arrivalRadiusM: Int,
        address: LocalizedText,
        visitingHours: VisitingHours,
        dressCode: LocalizedText,
        photoPolicy: PhotoPolicy,
        entryCost: Money,
        accessibility: AccessibilityInfo,
        loreStandalone: [LoreBlock] = [],
        sources: [Source],
        consentRecordId: String,
        mapPoint: MapPoint? = nil
    ) {
        self.id = id
        self.nameOfficial = nameOfficial
        self.nameVariants = nameVariants
        self.type = type
        self.isSacred = isSacred
        self.coordinate = coordinate
        self.arrivalRadiusM = arrivalRadiusM
        self.address = address
        self.visitingHours = visitingHours
        self.dressCode = dressCode
        self.photoPolicy = photoPolicy
        self.entryCost = entryCost
        self.accessibility = accessibility
        self.loreStandalone = loreStandalone
        self.sources = sources
        self.consentRecordId = consentRecordId
        self.mapPoint = mapPoint
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nameOfficial = try c.decode(LocalizedText.self, forKey: .nameOfficial)
        nameVariants = try c.decodeIfPresent([String].self, forKey: .nameVariants) ?? []
        type = try c.decode(PlaceType.self, forKey: .type)
        isSacred = try c.decode(Bool.self, forKey: .isSacred)
        coordinate = try c.decode(Coordinate.self, forKey: .coordinate)
        arrivalRadiusM = try c.decode(Int.self, forKey: .arrivalRadiusM)
        address = try c.decode(LocalizedText.self, forKey: .address)
        visitingHours = try c.decode(VisitingHours.self, forKey: .visitingHours)
        dressCode = try c.decode(LocalizedText.self, forKey: .dressCode)
        photoPolicy = try c.decode(PhotoPolicy.self, forKey: .photoPolicy)
        entryCost = try c.decode(Money.self, forKey: .entryCost)
        accessibility = try c.decode(AccessibilityInfo.self, forKey: .accessibility)
        loreStandalone = try c.decodeIfPresent([LoreBlock].self, forKey: .loreStandalone) ?? []
        sources = try c.decode([Source].self, forKey: .sources)
        consentRecordId = try c.decode(String.self, forKey: .consentRecordId)
        mapPoint = try c.decodeIfPresent(MapPoint.self, forKey: .mapPoint)
    }
}

// MARK: - Quest

public struct RouteInfo: Codable, Sendable, Equatable, Hashable {
    public let totalDistanceM: Int
    public let distanceSource: DistanceSource
    /// `NFR-CONT-06` — walking time and total quest time are separate figures, both shown.
    public let walkingTimeMin: Int
    public let totalDurationMin: Int
    public let geometryAsset: String
    /// `FR-MAP-01` — a pre-rendered image, so preview never depends on live map tiles.
    public let previewImageAsset: String

    public init(
        totalDistanceM: Int,
        distanceSource: DistanceSource,
        walkingTimeMin: Int,
        totalDurationMin: Int,
        geometryAsset: String,
        previewImageAsset: String
    ) {
        self.totalDistanceM = totalDistanceM
        self.distanceSource = distanceSource
        self.walkingTimeMin = walkingTimeMin
        self.totalDurationMin = totalDurationMin
        self.geometryAsset = geometryAsset
        self.previewImageAsset = previewImageAsset
    }
}

public struct CostBreakdownEntry: Codable, Sendable, Equatable, Hashable {
    public let placeId: String
    public let amount: Int

    public init(placeId: String, amount: Int) {
        self.placeId = placeId
        self.amount = amount
    }
}

/// `FR-DISC-05` — a quest that costs money shows its total on the list card, with the breakdown
/// available in preview.
public struct EstimatedCost: Codable, Sendable, Equatable, Hashable {
    public let amount: Int
    public let currency: String
    public let breakdown: [CostBreakdownEntry]

    public init(amount: Int, currency: String, breakdown: [CostBreakdownEntry]) {
        self.amount = amount
        self.currency = currency
        self.breakdown = breakdown
    }

    public var isFree: Bool { amount == 0 }
}

public struct StartWindow: Codable, Sendable, Equatable, Hashable {
    public let from: TimeOfDay
    public let to: TimeOfDay

    public init(from: TimeOfDay, to: TimeOfDay) {
        self.from = from
        self.to = to
    }
}

/// An optional suggestion at a Checkpoint, decoded and tracked by nothing (`FR-TASK-08/09`).
///
/// Called `SideQuest` until the `FR-SIDE` amendment (PRD §5.15) claimed that word for a different
/// entity — a single-place activity outside any Run. The concept and its requirement IDs are
/// unchanged; only the name moved, so that *sidequest* names one thing (`s0` D2). The JSON key
/// moved with it: `sideQuests` → `bonusPrompts`.
public struct BonusPrompt: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let prompt: LocalizedText

    public init(id: String, prompt: LocalizedText) {
        self.id = id
        self.prompt = prompt
    }
}

public struct ContentTask: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let type: TaskType
    public let prompt: LocalizedText
    /// `AD-2` — must be `false` for every v1 task. The field exists so the rule is auditable
    /// by a script (V8) rather than by memory.
    public let blocksProgression: Bool

    public init(id: String, type: TaskType, prompt: LocalizedText, blocksProgression: Bool) {
        self.id = id
        self.type = type
        self.prompt = prompt
        self.blocksProgression = blocksProgression
    }
}

public struct Checkpoint: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let orderIndex: Int
    public let placeId: String
    public let role: CheckpointRole
    public let loreSegment: [LoreBlock]
    /// `null` for the final checkpoint, non-null everywhere else (V10).
    public let clueToNext: LocalizedText?
    public let tasks: [ContentTask]
    public let bonusPrompts: [BonusPrompt]
    public let stampId: String

    public init(
        id: String,
        orderIndex: Int,
        placeId: String,
        role: CheckpointRole,
        loreSegment: [LoreBlock],
        clueToNext: LocalizedText?,
        tasks: [ContentTask] = [],
        bonusPrompts: [BonusPrompt] = [],
        stampId: String
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.placeId = placeId
        self.role = role
        self.loreSegment = loreSegment
        self.clueToNext = clueToNext
        self.tasks = tasks
        self.bonusPrompts = bonusPrompts
        self.stampId = stampId
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        orderIndex = try c.decode(Int.self, forKey: .orderIndex)
        placeId = try c.decode(String.self, forKey: .placeId)
        role = try c.decode(CheckpointRole.self, forKey: .role)
        loreSegment = try c.decode([LoreBlock].self, forKey: .loreSegment)
        clueToNext = try c.decodeIfPresent(LocalizedText.self, forKey: .clueToNext)
        tasks = try c.decodeIfPresent([ContentTask].self, forKey: .tasks) ?? []
        bonusPrompts = try c.decodeIfPresent([BonusPrompt].self, forKey: .bonusPrompts) ?? []
        stampId = try c.decode(String.self, forKey: .stampId)
    }
}

public struct Quest: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    /// Pinned to a Run at start (`AD-4`). Read here, never written.
    public let contentVersion: String
    public let title: LocalizedText
    public let region: String
    public let city: String?
    public let hookLore: [LoreBlock]
    public let description: LocalizedText
    public let route: RouteInfo
    public let estimatedCost: EstimatedCost
    public let terrainSummary: LocalizedText
    public let recommendedStartWindow: StartWindow
    /// Derived: earliest checkpoint closing time − `totalDurationMin` (V16).
    public let hardLatestStart: TimeOfDay
    /// `FR-PROX-11` — must exceed the start checkpoint's `arrivalRadiusM` (V12).
    public let proximityRadiusM: Int
    public let safetyNotes: LocalizedText
    public let languages: [ContentLanguage]
    public let badgeId: String
    /// The photograph the discovery card is built around. Optional: a quest with no hero still
    /// lists, it just reads as type on paper rather than type on an image.
    public let heroImageAsset: String?
    public let checkpoints: [Checkpoint]

    public init(
        id: String,
        contentVersion: String,
        title: LocalizedText,
        region: String,
        city: String? = nil,
        hookLore: [LoreBlock],
        description: LocalizedText,
        route: RouteInfo,
        estimatedCost: EstimatedCost,
        terrainSummary: LocalizedText,
        recommendedStartWindow: StartWindow,
        hardLatestStart: TimeOfDay,
        proximityRadiusM: Int,
        safetyNotes: LocalizedText,
        languages: [ContentLanguage] = [.id, .en],
        badgeId: String,
        heroImageAsset: String? = nil,
        checkpoints: [Checkpoint]
    ) {
        self.id = id
        self.contentVersion = contentVersion
        self.title = title
        self.region = region
        self.city = city
        self.hookLore = hookLore
        self.description = description
        self.route = route
        self.estimatedCost = estimatedCost
        self.terrainSummary = terrainSummary
        self.recommendedStartWindow = recommendedStartWindow
        self.hardLatestStart = hardLatestStart
        self.proximityRadiusM = proximityRadiusM
        self.safetyNotes = safetyNotes
        self.languages = languages
        self.badgeId = badgeId
        self.heroImageAsset = heroImageAsset
        self.checkpoints = checkpoints
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        contentVersion = try c.decode(String.self, forKey: .contentVersion)
        title = try c.decode(LocalizedText.self, forKey: .title)
        region = try c.decode(String.self, forKey: .region)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        hookLore = try c.decode([LoreBlock].self, forKey: .hookLore)
        description = try c.decode(LocalizedText.self, forKey: .description)
        route = try c.decode(RouteInfo.self, forKey: .route)
        estimatedCost = try c.decode(EstimatedCost.self, forKey: .estimatedCost)
        terrainSummary = try c.decode(LocalizedText.self, forKey: .terrainSummary)
        recommendedStartWindow = try c.decode(StartWindow.self, forKey: .recommendedStartWindow)
        hardLatestStart = try c.decode(TimeOfDay.self, forKey: .hardLatestStart)
        proximityRadiusM = try c.decode(Int.self, forKey: .proximityRadiusM)
        safetyNotes = try c.decode(LocalizedText.self, forKey: .safetyNotes)
        languages = try c.decodeIfPresent([ContentLanguage].self, forKey: .languages) ?? [.id, .en]
        badgeId = try c.decode(String.self, forKey: .badgeId)
        heroImageAsset = try c.decodeIfPresent(String.self, forKey: .heroImageAsset)
        checkpoints = try c.decode([Checkpoint].self, forKey: .checkpoints)
    }

    public var startCheckpoint: Checkpoint? {
        checkpoints.first { $0.role == .start } ?? checkpoints.min { $0.orderIndex < $1.orderIndex }
    }

    public var orderedCheckpoints: [Checkpoint] {
        checkpoints.sorted { $0.orderIndex < $1.orderIndex }
    }

    /// What the discovery card counts. The Home mockup labels this "5 quests"; the glossary calls
    /// them checkpoints, and `FR-CP-08` counts progress in them — a quest containing quests would
    /// make both readings ambiguous for no gain.
    public var checkpointCount: Int { checkpoints.count }
}

// MARK: - Manifest

public struct Manifest: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    /// What a Run pins (`AD-4`). Any change to any content file must bump it.
    public let contentBundleVersion: String
    public let languages: [ContentLanguage]
    public let places: [String]
    public let quests: [String]
    /// Schema 2 (PRD §5.15). Decoded with a default so a bundle authored against schema 1 still
    /// loads and simply has no sidequests — which is what a content rollback has to be able to do.
    public let sideQuests: [String]
    public let collections: [String]
    /// Absent when content ships no illustrated map; the map screen then has nothing to draw and
    /// says so rather than showing an empty frame.
    public let regionMap: RegionMapAsset?

    public init(
        schemaVersion: Int,
        contentBundleVersion: String,
        languages: [ContentLanguage],
        places: [String],
        quests: [String],
        sideQuests: [String] = [],
        collections: [String] = [],
        regionMap: RegionMapAsset? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.contentBundleVersion = contentBundleVersion
        self.languages = languages
        self.places = places
        self.quests = quests
        self.sideQuests = sideQuests
        self.collections = collections
        self.regionMap = regionMap
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        contentBundleVersion = try c.decode(String.self, forKey: .contentBundleVersion)
        languages = try c.decode([ContentLanguage].self, forKey: .languages)
        places = try c.decode([String].self, forKey: .places)
        quests = try c.decode([String].self, forKey: .quests)
        sideQuests = try c.decodeIfPresent([String].self, forKey: .sideQuests) ?? []
        collections = try c.decodeIfPresent([String].self, forKey: .collections) ?? []
        regionMap = try c.decodeIfPresent(RegionMapAsset.self, forKey: .regionMap)
    }
}

// MARK: - ConsentRecord

/// A build input, never shipped (`schema.md` §A.1). Putting named individuals' details in every
/// user's app would serve no purpose the validator does not already serve at build time.
public struct ConsentRecord: Codable, Sendable, Equatable {
    public let placeId: String
    public let grantingBody: String
    public let grantedByName: String
    public let grantedByRole: String
    public let grantedAt: CalendarDay
    public let expiresAt: CalendarDay
    public let scope: [ConsentScope]
    public let documentRef: String
    public let status: ConsentStatus
    /// `NFR-GOV-07` — a named individual, because "the team" owning a relationship means nobody does.
    public let regionOwner: String

    public init(
        placeId: String,
        grantingBody: String,
        grantedByName: String,
        grantedByRole: String,
        grantedAt: CalendarDay,
        expiresAt: CalendarDay,
        scope: [ConsentScope],
        documentRef: String,
        status: ConsentStatus,
        regionOwner: String
    ) {
        self.placeId = placeId
        self.grantingBody = grantingBody
        self.grantedByName = grantedByName
        self.grantedByRole = grantedByRole
        self.grantedAt = grantedAt
        self.expiresAt = expiresAt
        self.scope = scope
        self.documentRef = documentRef
        self.status = status
        self.regionOwner = regionOwner
    }
}
