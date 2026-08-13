import ContentKit
import Foundation
@testable import RunEngine

/// A three-checkpoint quest with two places, built in memory.
///
/// Written out rather than read from the shipped bundle so these tests assert the *rules* and not
/// the current example content: a checkpoint added to `contoh-tiga-gerbang` must not turn an
/// ordering test red.
enum Fixture {

    static let questID = "quest-fixture"

    static func place(
        id: String,
        name: String,
        lat: Double,
        lon: Double,
        radiusM: Int = 75,
        isSacred: Bool = false,
        photoPolicy: PhotoPolicyLevel = .allowed,
        citations: [String] = ["Arsip Kota, 1938", "Wawancara pemangku, 2026"]
    ) -> Place {
        Place(
            id: id,
            nameOfficial: LocalizedText(id: name, en: name),
            type: .puri,
            isSacred: isSacred,
            coordinate: Coordinate(lat: lat, lon: lon),
            arrivalRadiusM: radiusM,
            address: LocalizedText(id: "Alamat", en: "Address"),
            visitingHours: VisitingHours(
                notes: LocalizedText(id: "Catatan", en: "Notes"),
                weekly: [OpeningHours(
                    weekday: 1,
                    open: TimeOfDay(hour: 8, minute: 0),
                    close: TimeOfDay(hour: 17, minute: 0))]),
            dressCode: LocalizedText(id: "Kain dan selendang", en: "Sarong and sash"),
            photoPolicy: PhotoPolicy(
                level: photoPolicy, notes: LocalizedText(id: "Catatan", en: "Notes")),
            entryCost: Money(amount: 0, currency: "IDR"),
            accessibility: AccessibilityInfo(
                hasSteps: false, stepCount: nil, surface: "aspal",
                notes: LocalizedText(id: "Datar", en: "Level")),
            sources: citations.map { Source(kind: .documented, citation: $0) },
            consentRecordId: "consent-\(id)")
    }

    static func checkpoint(
        index: Int,
        placeID: String,
        role: CheckpointRole,
        hasClue: Bool = true,
        tasks: [ContentTask] = []
    ) -> Checkpoint {
        Checkpoint(
            id: "cp\(index)",
            orderIndex: index,
            placeId: placeID,
            role: role,
            loreSegment: [
                LoreBlock(
                    text: LocalizedText(id: "Klaim tercatat \(index)", en: "Documented claim \(index)"),
                    accuracy: .documented,
                    sourceRefs: [0]),
                LoreBlock(
                    text: LocalizedText(id: "Tutur \(index)", en: "Oral account \(index)"),
                    accuracy: .oral,
                    sourceRefs: [1]),
            ],
            clueToNext: hasClue
                ? LocalizedText(id: "Petunjuk \(index)", en: "Clue \(index)")
                : nil,
            tasks: tasks,
            stampId: "stamp-\(index)")
    }

    static func reflectionTask(_ id: String) -> ContentTask {
        ContentTask(
            id: id,
            type: .reflection,
            prompt: LocalizedText(id: "Tulis satu hal", en: "Write one thing"),
            blocksProgression: false)
    }

    static func quest(contentVersion: String = "2026.08.1") -> Quest {
        Quest(
            id: questID,
            contentVersion: contentVersion,
            title: LocalizedText(id: "Rute Uji", en: "Test Route"),
            region: "Denpasar",
            hookLore: [],
            description: LocalizedText(id: "Deskripsi", en: "Description"),
            route: RouteInfo(
                totalDistanceM: 1200,
                distanceSource: .walkingDirections,
                walkingTimeMin: 20,
                totalDurationMin: 60,
                geometryAsset: "route.geojson",
                previewImageAsset: "route.png"),
            estimatedCost: EstimatedCost(amount: 0, currency: "IDR", breakdown: []),
            terrainSummary: LocalizedText(id: "Datar", en: "Level"),
            recommendedStartWindow: StartWindow(
                from: TimeOfDay(hour: 8, minute: 0), to: TimeOfDay(hour: 12, minute: 0)),
            hardLatestStart: TimeOfDay(hour: 16, minute: 0),
            proximityRadiusM: 200,
            safetyNotes: LocalizedText(id: "Hati-hati", en: "Take care"),
            badgeId: "badge-fixture",
            checkpoints: [
                checkpoint(index: 0, placeID: "place-a", role: .start,
                           tasks: [reflectionTask("t0")]),
                checkpoint(index: 1, placeID: "place-b", role: .middle),
                checkpoint(index: 2, placeID: "place-a", role: .finish, hasClue: false,
                           tasks: [reflectionTask("t2")]),
            ])
    }

    static let places: [Place] = [
        place(id: "place-a", name: "Puri Contoh", lat: -8.6570, lon: 115.2160),
        place(id: "place-b", name: "Pasar Contoh", lat: -8.6600, lon: 115.2200, radiusM: 40),
    ]
}

/// Content read from memory. Implements the same protocol the bundle does, which is the point of
/// the protocol existing.
struct StubContentRepository: ContentRepository {
    var quest: Quest = Fixture.quest()
    var places: [Place] = Fixture.places

    func manifest() throws -> Manifest {
        Manifest(
            schemaVersion: 1,
            contentBundleVersion: quest.contentVersion,
            languages: [.id, .en],
            places: places.map(\.id),
            quests: [quest.id])
    }

    func contentBundleVersion() throws -> String { quest.contentVersion }
    func quests() throws -> [Quest] { [quest] }
    func quest(id: String) throws -> Quest? { id == quest.id ? quest : nil }
    func place(id: String) throws -> Place? { places.first { $0.id == id } }

    func quests(
        suppressingQuestIDs: Set<String>, suppressingPlaceIDs: Set<String>
    ) throws -> [Quest] {
        suppressingQuestIDs.contains(quest.id) ? [] : [quest]
    }

    func assetURL(_ relativePath: String) throws -> URL? { nil }
}
