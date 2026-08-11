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
        mapPoint: MapPoint? = nil
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
            mapPoint: mapPoint)
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
        tasks: [ContentTask] = [task()]
    ) -> Checkpoint {
        Checkpoint(
            id: id,
            orderIndex: orderIndex,
            placeId: placeId,
            role: role,
            loreSegment: [lore()],
            clueToNext: clueToNext,
            tasks: tasks,
            sideQuests: [],
            stampId: "stamp-\(id)")
    }

    static func quest(
        id: String = "quest-a",
        distanceSource: DistanceSource = .walkingDirections,
        proximityRadiusM: Int = 200,
        hardLatestStart: TimeOfDay = TimeOfDay(hour: 15, minute: 15),
        totalDurationMin: Int = 105,
        estimatedCost: EstimatedCost = EstimatedCost(amount: 0, currency: "IDR", breakdown: []),
        heroImageAsset: String? = nil,
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

    /// A bundle with two places and one two-checkpoint quest, valid against every rule.
    static func bundle(
        places: [Place]? = nil,
        quests: [Quest]? = nil,
        consentRecords: [ConsentRecord]? = nil
    ) -> ContentBundle {
        let resolvedPlaces = places ?? [place(id: "place-a", consentRecordId: "place-a"),
                                        place(id: "place-b", consentRecordId: "place-b")]
        let resolvedQuests = quests ?? [quest()]
        return ContentBundle(
            manifest: Manifest(
                schemaVersion: 1,
                contentBundleVersion: "2026.08.1",
                languages: [.id, .en],
                places: resolvedPlaces.map(\.id),
                quests: resolvedQuests.map(\.id),
                regionMap: nil),
            places: resolvedPlaces,
            quests: resolvedQuests,
            consentRecords: consentRecords ?? [consent(placeId: "place-a"), consent(placeId: "place-b")])
    }

    static let today = CalendarDay(year: 2026, month: 8, day: 10)

    /// Every asset the default bundle references, at a size well under the payload budget.
    static func assets(
        present: Set<String>? = nil,
        totalBytes: Int = 12 * 1024 * 1024
    ) -> StubAssetInventory {
        StubAssetInventory(
            present: present ?? ["quests/quest-a/route.geojson", "quests/quest-a/route-preview.png"],
            totalBytes: totalBytes)
    }
}

struct StubAssetInventory: AssetInventory {
    let present: Set<String>
    let totalBytes: Int

    func exists(_ relativePath: String) -> Bool { present.contains(relativePath) }
    func totalPayloadBytes() -> Int { totalBytes }
}
