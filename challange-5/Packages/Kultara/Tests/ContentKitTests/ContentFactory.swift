import Foundation
@testable import ContentKit

/// Builders for content that is valid in every respect, so each validator test can break
/// exactly one thing and attribute the finding to exactly one rule.
enum ContentFactory {

    static func text(_ s: String = "Teks") -> LocalizedText {
        LocalizedText(id: s, en: s)
    }

    static func lore(sourceRefs: [Int] = [0], accuracy: AccuracyLabel = .documented) -> LoreBlock {
        LoreBlock(text: text("Klaim"), accuracy: accuracy, sourceRefs: sourceRefs)
    }

    static func place(
        id: String = "place-a",
        isSacred: Bool = false,
        arrivalRadiusM: Int = 75,
        photoPolicy: PhotoPolicyLevel = .allowed,
        sources: [Source] = [Source(kind: .documented, citation: "Sumber", url: nil)],
        consentRecordId: String = "place-a",
        entryCost: Money = Money(amount: 0, currency: "IDR"),
        close: TimeOfDay = TimeOfDay(hour: 17, minute: 0),
        mapPoint: MapPoint? = nil,
        siteMap: PlaceSiteMap? = nil,
        approachMap: PlaceApproachMap? = nil,
        storyArtwork: PlaceStoryArtwork? = nil
    ) -> Place {
        Place(
            id: id,
            nameOfficial: text(id),
            type: .puri,
            isSacred: isSacred,
            coordinate: Coordinate(lat: -8.65, lon: 115.21),
            arrivalRadiusM: arrivalRadiusM,
            address: text("Alamat"),
            visitingHours: VisitingHours(
                notes: text("Catatan"),
                weekly: (1...7).map { OpeningHours(weekday: $0, open: TimeOfDay(hour: 8, minute: 0), close: close) }),
            dressCode: text("Kamen"),
            photoPolicy: PhotoPolicy(level: photoPolicy, notes: text("Catatan foto")),
            entryCost: entryCost,
            accessibility: AccessibilityInfo(hasSteps: false, stepCount: nil, surface: "paving", notes: text("Rata")),
            loreStandalone: [lore()],
            sources: sources,
            consentRecordId: consentRecordId,
            mapPoint: mapPoint,
            siteMap: siteMap,
            approachMap: approachMap,
            storyArtwork: storyArtwork)
    }

    static func task(
        id: String = "t1",
        type: TaskType = .reflection,
        blocksProgression: Bool = false
    ) -> ContentTask {
        ContentTask(id: id, type: type, prompt: text("Prompt"), blocksProgression: blocksProgression)
    }

    static func checkpoint(
        id: String = "cp1",
        orderIndex: Int = 0,
        placeId: String = "place-a",
        role: CheckpointRole = .start,
        clueToNext: LocalizedText? = text("Petunjuk"),
        tasks: [ContentTask] = [task()],
        narration: [ContentLanguage: CheckpointNarration] = [:]
    ) -> Checkpoint {
        Checkpoint(
            id: id,
            orderIndex: orderIndex,
            placeId: placeId,
            role: role,
            loreSegment: [lore()],
            clueToNext: clueToNext,
            tasks: tasks,
            bonusPrompts: [],
            stampId: "stamp-\(id)",
            narration: narration)
    }

    static func quest(
        id: String = "quest-a",
        distanceSource: DistanceSource = .walkingDirections,
        proximityRadiusM: Int = 200,
        hardLatestStart: TimeOfDay = TimeOfDay(hour: 15, minute: 15),
        totalDurationMin: Int = 105,
        estimatedCost: EstimatedCost = EstimatedCost(amount: 0, currency: "IDR", breakdown: []),
        heroImageAsset: String? = nil,
        languages: [ContentLanguage] = [.id, .en],
        checkpoints: [Checkpoint]? = nil
    ) -> Quest {
        Quest(
            id: id,
            contentVersion: "2026.08.1",
            title: text("Kuis"),
            region: "Denpasar",
            city: "Denpasar",
            hookLore: [lore()],
            description: text("Deskripsi"),
            route: RouteInfo(
                totalDistanceM: 2200,
                distanceSource: distanceSource,
                walkingTimeMin: 35,
                totalDurationMin: totalDurationMin,
                geometryAsset: "quests/\(id)/route.geojson",
                previewImageAsset: "quests/\(id)/route-preview.png"),
            estimatedCost: estimatedCost,
            terrainSummary: text("Trotoar"),
            recommendedStartWindow: StartWindow(from: TimeOfDay(hour: 8, minute: 0), to: TimeOfDay(hour: 14, minute: 0)),
            hardLatestStart: hardLatestStart,
            proximityRadiusM: proximityRadiusM,
            safetyNotes: text("Hati-hati"),
            languages: languages,
            badgeId: "badge-\(id)",
            heroImageAsset: heroImageAsset,
            checkpoints: checkpoints ?? [
                checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start),
                checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish, clueToNext: nil),
            ])
    }

    static func consent(
        placeId: String = "place-a",
        status: ConsentStatus = .granted,
        expiresAt: CalendarDay = CalendarDay(year: 2030, month: 1, day: 1),
        grantedByName: String = "I Gusti Ngurah Contoh",
        grantedByRole: String = "Penglingsir",
        regionOwner: String = "Alief Fauzan"
    ) -> ConsentRecord {
        ConsentRecord(
            placeId: placeId,
            grantingBody: "Badan Pengelola",
            grantedByName: grantedByName,
            grantedByRole: grantedByRole,
            grantedAt: CalendarDay(year: 2026, month: 7, day: 14),
            expiresAt: expiresAt,
            scope: [.inclusion, .naming],
            documentRef: "consent/2026/\(placeId).pdf",
            status: status,
            regionOwner: regionOwner)
    }

    // MARK: - Sidequests and letter collections (PRD §5.15)

    static func quiz(
        options: [LocalizedText]? = nil,
        correctIndex: Int = 1
    ) -> SideQuestChallenge {
        .quiz(QuizChallenge(
            question: text("Siapa yang membangun gerbang ini?"),
            options: options ?? [text("Opsi A"), text("Opsi B"), text("Opsi C")],
            correctIndex: correctIndex,
            explanation: text("Penjelasan")))
    }

    static func sideQuest(
        id: String = "sq-a",
        placeId: String = "place-a",
        lore: [LoreBlock]? = nil,
        challenge: SideQuestChallenge? = nil,
        triggerRadiusM: Int = 75,
        noticeRadiusM: Int = 200,
        heroImageAsset: String? = nil
    ) -> SideQuest {
        SideQuest(
            id: id,
            placeId: placeId,
            title: text("Sidequest"),
            synopsis: text("Sinopsis pendek"),
            lore: lore ?? [self.lore()],
            challenge: challenge ?? quiz(),
            triggerRadiusM: triggerRadiusM,
            noticeRadiusM: noticeRadiusM,
            heroImageAsset: heroImageAsset)
    }

    /// A collection whose phrase is exactly as long as its slot list, so a test can break one
    /// thing at a time. `AB` is two letters and therefore two sidequests.
    static func collection(
        id: String = "collection-a",
        phrase: String = "AB",
        slots: [LetterSlot]? = nil,
        badgeId: String = "badge-collection-a"
    ) -> LetterCollection {
        LetterCollection(
            id: id,
            region: "Denpasar",
            phrase: phrase,
            title: text("Koleksi"),
            caption: text("Kumpulkan satu huruf di setiap tempat."),
            badgeId: badgeId,
            slots: slots ?? [
                LetterSlot(index: 0, letter: "A", sideQuestId: "sq-a"),
                LetterSlot(index: 1, letter: "B", sideQuestId: "sq-b"),
            ])
    }

    /// A bundle with two places and one two-checkpoint quest, valid against every rule.
    ///
    /// Sidequests and collections default to empty, which is a schema-1 bundle: the rules that
    /// judge them must stay silent on content that ships none.
    static func bundle(
        places: [Place]? = nil,
        quests: [Quest]? = nil,
        sideQuests: [SideQuest] = [],
        collections: [LetterCollection] = [],
        consentRecords: [ConsentRecord]? = nil
    ) -> ContentBundle {
        let resolvedPlaces = places ?? [place(id: "place-a", consentRecordId: "place-a"),
                                        place(id: "place-b", consentRecordId: "place-b")]
        let resolvedQuests = quests ?? [quest()]
        return ContentBundle(
            manifest: Manifest(
                schemaVersion: 2,
                contentBundleVersion: "2026.08.1",
                languages: [.id, .en],
                places: resolvedPlaces.map(\.id),
                quests: resolvedQuests.map(\.id),
                sideQuests: sideQuests.map(\.id),
                collections: collections.map(\.id),
                regionMap: nil),
            places: resolvedPlaces,
            quests: resolvedQuests,
            sideQuests: sideQuests,
            collections: collections,
            consentRecords: consentRecords ?? [consent(placeId: "place-a"), consent(placeId: "place-b")])
    }

    /// Two sidequests filling the two slots of one collection — valid against V19–V28, so each
    /// test can break exactly one rule.
    static func sideQuestBundle(
        sideQuests: [SideQuest]? = nil,
        collections: [LetterCollection]? = nil,
        places: [Place]? = nil
    ) -> ContentBundle {
        bundle(
            places: places,
            sideQuests: sideQuests ?? [
                sideQuest(id: "sq-a", placeId: "place-a"),
                sideQuest(id: "sq-b", placeId: "place-b"),
            ],
            collections: collections ?? [collection()])
    }

    static let today = CalendarDay(year: 2026, month: 8, day: 10)

    /// Every asset the default bundle references, at a size well under the payload budget.
    static func assets(
        present: Set<String>? = nil,
        totalBytes: Int = 12 * 1024 * 1024,
        contents: [String: Data] = [:]
    ) -> StubAssetInventory {
        StubAssetInventory(
            present: present ?? ["quests/quest-a/route.geojson", "quests/quest-a/route-preview.png"],
            totalBytes: totalBytes,
            contents: contents)
    }

    /// A minimal two-point route, for the rules that read the geometry rather than only its
    /// presence (V18).
    static func routeGeometryJSON(
        coordinates: String = "[[115.2085, -8.6570], [115.2101, -8.6552]]"
    ) -> Data {
        Data("""
        { "type": "FeatureCollection", "features": [
          { "type": "Feature", "properties": { "role": "route" },
            "geometry": { "type": "LineString", "coordinates": \(coordinates) } } ] }
        """.utf8)
    }
}

struct StubAssetInventory: AssetInventory {
    let present: Set<String>
    let totalBytes: Int
    var contents: [String: Data] = [:]

    func exists(_ relativePath: String) -> Bool { present.contains(relativePath) }
    func totalPayloadBytes() -> Int { totalBytes }
    func data(_ relativePath: String) -> Data? { contents[relativePath] }
}
