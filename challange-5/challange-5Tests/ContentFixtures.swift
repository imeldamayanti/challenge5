// Fixture content for the discovery guards — m7 execution record, groups A and C.
//
// Six FR-DISC guards and one region-map guard used to assert against `BundledContentRepository`.
// That made them change meaning every time an author edited a JSON file: replacing the `contoh-*`
// placeholders with `badung-empat-wajah` turned them red without any requirement changing. A
// requirement guard must not depend on what happens to be authored this week, and the shipped
// content must not be bent to satisfy a test — so the content each rule needs is written here
// instead.
//
// What this tree is shaped to contain, and why each shape exists:
//
// - a quest that costs money, with a breakdown that sums to its total   FR-DISC-05
// - five checkpoints, a hero image, a route preview image               FR-DISC-03, FR-MAP-01
// - a place where photography is prohibited                             FR-TASK-05 disclosure
// - a sacred place                                                      FR-TASK-05
// - a known `hardLatestStart` (13:30) and a known earliest closing
//   (15:30, at a named place), 120 minutes apart so the derivation
//   V16 describes actually holds                                        FR-DISC-06
// - two quests whose start places sit a fraction of the illustration
//   apart, so the map has something to cluster                          NFR-A11Y-01/06
//
// Nothing here is real. The place names are deliberately not the names of real institutions: this
// file must never be mistaken for content, and a fixture carrying a real site's name would be a
// claim about that site with no source and no consent record behind it (FR-CP-05, NFR-GOV).
import Foundation
@testable import ContentKit

// `nonisolated`: the app target builds with MainActor default isolation, and `ContentRepository`
// is not main-actor bound — a repository that could only be read from the main actor would be a
// different protocol from the one the app uses, which is the one thing a double must not be.
nonisolated enum ContentFixture {

    static let paidQuestID = "fixture-paid-quest"
    static let secondQuestID = "fixture-second-quest"

    /// The place the FR-DISC-06 warning must name: it shuts at 15:30, earlier than anything else
    /// on the route, so it is the one that decides whether the walk can finish.
    static let earliestClosingPlaceID = "fixture-galeri"
    static let earliestClosing = TimeOfDay(hour: 15, minute: 30)

    /// 15:30 minus the quest's 120-minute total duration (`schema.md` §A.5, validator rule V16).
    static let hardLatestStart = TimeOfDay(hour: 13, minute: 30)

    static func text(_ indonesian: String, _ english: String) -> LocalizedText {
        LocalizedText(id: indonesian, en: english)
    }

    private static func hours(open: TimeOfDay, close: TimeOfDay) -> VisitingHours {
        VisitingHours(
            notes: text("Tutup hari raya.", "Closed on public holidays."),
            weekly: (1...7).map { OpeningHours(weekday: $0, open: open, close: close) })
    }

    private static let sources = [
        Source(kind: .documented, citation: "Fixture source, not a real citation.", url: nil)
    ]

    static let places: [Place] = [
        Place(
            id: "fixture-puri",
            nameOfficial: text("Puri Fiktif", "Fictional Puri"),
            type: .puri,
            isSacred: false,
            coordinate: Coordinate(lat: -8.6600, lon: 115.2100),
            arrivalRadiusM: 75,
            address: text("Jalan Fiktif 1", "1 Fictional Street"),
            visitingHours: hours(open: TimeOfDay(hour: 8, minute: 0),
                                 close: TimeOfDay(hour: 17, minute: 0)),
            dressCode: text("Pakaian sopan.", "Modest dress."),
            photoPolicy: PhotoPolicy(level: .allowed,
                                     notes: text("Bebas memotret.", "Photography is fine.")),
            entryCost: Money(amount: 0, currency: "IDR"),
            accessibility: AccessibilityInfo(
                hasSteps: true, stepCount: 12, surface: "batu",
                notes: text("Ada tangga di gerbang.", "Steps at the gate.")),
            loreStandalone: [],
            sources: sources,
            consentRecordId: "fixture-consent",
            // Deliberately within a thousandth of the next pin: this is the cluster the map has to
            // open zoomed into (NFR-A11Y-01, NFR-A11Y-06).
            mapPoint: MapPoint(x: 0.500, y: 0.600)),

        Place(
            id: "fixture-pura",
            nameOfficial: text("Pura Fiktif", "Fictional Pura"),
            type: .pura,
            isSacred: true,
            coordinate: Coordinate(lat: -8.6610, lon: 115.2110),
            arrivalRadiusM: 60,
            address: text("Jalan Fiktif 2", "2 Fictional Street"),
            visitingHours: hours(open: TimeOfDay(hour: 7, minute: 0),
                                 close: TimeOfDay(hour: 18, minute: 0)),
            dressCode: text("Wajib kain dan selendang.", "Sarong and sash required."),
            photoPolicy: PhotoPolicy(level: .restricted,
                                     notes: text("Jangan memotret upacara.", "No photographs of ceremonies.")),
            entryCost: Money(amount: 10_000, currency: "IDR"),
            accessibility: AccessibilityInfo(
                hasSteps: true, stepCount: 6, surface: "batu",
                notes: text("Undakan rendah.", "Low steps.")),
            loreStandalone: [],
            sources: sources,
            consentRecordId: "fixture-consent",
            mapPoint: MapPoint(x: 0.502, y: 0.601)),

        Place(
            id: earliestClosingPlaceID,
            nameOfficial: text("Galeri Fiktif", "Fictional Gallery"),
            type: .museum,
            isSacred: false,
            coordinate: Coordinate(lat: -8.6620, lon: 115.2120),
            arrivalRadiusM: 50,
            address: text("Jalan Fiktif 3", "3 Fictional Street"),
            // The earliest closing on the route. FR-DISC-06's warning names this place and this time.
            visitingHours: hours(open: TimeOfDay(hour: 9, minute: 0), close: earliestClosing),
            dressCode: text("Bebas.", "No restrictions."),
            // The one place where photography is prohibited. No real place on the shipped route has
            // this policy, and inventing one there would be a claim about a real institution.
            photoPolicy: PhotoPolicy(level: .prohibited,
                                     notes: text("Dilarang memotret koleksi.", "No photography of the collection.")),
            entryCost: Money(amount: 25_000, currency: "IDR"),
            accessibility: AccessibilityInfo(
                hasSteps: false, stepCount: nil, surface: "ubin",
                notes: text("Datar seluruhnya.", "Step-free throughout.")),
            loreStandalone: [],
            sources: sources,
            consentRecordId: "fixture-consent",
            mapPoint: MapPoint(x: 0.510, y: 0.610)),

        Place(
            id: "fixture-pasar",
            nameOfficial: text("Pasar Fiktif", "Fictional Market"),
            type: .pasar,
            isSacred: false,
            coordinate: Coordinate(lat: -8.6630, lon: 115.2130),
            arrivalRadiusM: 75,
            address: text("Jalan Fiktif 4", "4 Fictional Street"),
            visitingHours: hours(open: TimeOfDay(hour: 6, minute: 0),
                                 close: TimeOfDay(hour: 17, minute: 0)),
            dressCode: text("Bebas.", "No restrictions."),
            photoPolicy: PhotoPolicy(level: .allowed,
                                     notes: text("Tanya penjual dulu.", "Ask the seller first.")),
            entryCost: Money(amount: 15_000, currency: "IDR"),
            accessibility: AccessibilityInfo(
                hasSteps: true, stepCount: 30, surface: "beton",
                notes: text("Empat lantai, tangga saja.", "Four floors, stairs only.")),
            loreStandalone: [],
            sources: sources,
            consentRecordId: "fixture-consent",
            mapPoint: MapPoint(x: 0.520, y: 0.620)),

        Place(
            id: "fixture-monumen",
            nameOfficial: text("Monumen Fiktif", "Fictional Monument"),
            type: .monumen,
            isSacred: false,
            coordinate: Coordinate(lat: -8.6640, lon: 115.2140),
            arrivalRadiusM: 60,
            address: text("Jalan Fiktif 5", "5 Fictional Street"),
            visitingHours: hours(open: TimeOfDay(hour: 0, minute: 0),
                                 close: TimeOfDay(hour: 23, minute: 59)),
            dressCode: text("Bebas.", "No restrictions."),
            photoPolicy: PhotoPolicy(level: .allowed,
                                     notes: text("Bebas memotret.", "Photography is fine.")),
            entryCost: Money(amount: 0, currency: "IDR"),
            accessibility: AccessibilityInfo(
                hasSteps: false, stepCount: nil, surface: "aspal",
                notes: text("Trotoar lebar.", "Wide pavement.")),
            loreStandalone: [],
            sources: sources,
            consentRecordId: "fixture-consent",
            mapPoint: MapPoint(x: 0.530, y: 0.630)),
    ]

    private static func lore(_ indonesian: String, _ english: String,
                            _ accuracy: AccuracyLabel) -> LoreBlock {
        LoreBlock(text: text(indonesian, english), accuracy: accuracy, sourceRefs: [0])
    }

    private static func checkpoint(
        _ index: Int, place: String, role: CheckpointRole, last: Bool = false
    ) -> Checkpoint {
        Checkpoint(
            id: "fixture-cp-\(index)",
            orderIndex: index,
            placeId: place,
            role: role,
            loreSegment: [
                lore("Lore titik \(index), tercatat.", "Checkpoint \(index) lore, documented.",
                     .documented),
                lore("Lore titik \(index), lisan.", "Checkpoint \(index) lore, oral.", .oral),
            ],
            // V10 — non-null everywhere but the last.
            clueToNext: last ? nil : text("Petunjuk titik \(index).", "Clue for checkpoint \(index)."),
            tasks: [
                ContentTask(id: "fixture-task-\(index)", type: .reflection,
                            prompt: text("Apa yang berubah?", "What has changed?"),
                            blocksProgression: false)
            ],
            stampId: "fixture-stamp-\(index)")
    }

    private static let route = RouteInfo(
        totalDistanceM: 2_400,
        distanceSource: .walkingDirections,
        walkingTimeMin: 45,
        // 15:30 − 120 min = 13:30, which is `hardLatestStart` above.
        totalDurationMin: 120,
        geometryAsset: "fixture-route.geojson",
        previewImageAsset: "fixture-route.png")

    static let quests: [Quest] = [
        Quest(
            id: paidQuestID,
            contentVersion: "fixture-1",
            title: text("Rute Fiktif Berbayar", "Fictional Paid Route"),
            region: "Fiktif",
            city: "Kota Fiktif",
            hookLore: [lore("Kail cerita.", "The story hook.", .documented)],
            description: text("Deskripsi rute fiktif.", "A fictional route description."),
            route: route,
            // FR-DISC-05 — a total the card must show, and a breakdown that sums to it.
            estimatedCost: EstimatedCost(
                amount: 50_000, currency: "IDR",
                breakdown: [
                    CostBreakdownEntry(placeId: earliestClosingPlaceID, amount: 25_000),
                    CostBreakdownEntry(placeId: "fixture-pasar", amount: 15_000),
                    CostBreakdownEntry(placeId: "fixture-pura", amount: 10_000),
                ]),
            terrainSummary: text("Trotoar datar dan beberapa tangga.", "Flat pavement and some steps."),
            recommendedStartWindow: StartWindow(from: TimeOfDay(hour: 9, minute: 0),
                                                to: TimeOfDay(hour: 11, minute: 0)),
            hardLatestStart: hardLatestStart,
            proximityRadiusM: 200,
            safetyNotes: text("Perhatikan lalu lintas.", "Watch the traffic."),
            badgeId: "fixture-badge",
            heroImageAsset: "fixture-hero.jpg",
            checkpoints: [
                checkpoint(0, place: "fixture-puri", role: .start),
                checkpoint(1, place: "fixture-pura", role: .middle),
                checkpoint(2, place: earliestClosingPlaceID, role: .middle),
                checkpoint(3, place: "fixture-pasar", role: .middle),
                checkpoint(4, place: "fixture-monumen", role: .finish, last: true),
            ]),

        // Exists only so the region map has two pins to cluster. Its start place sits a thousandth
        // of the illustration from the first quest's.
        Quest(
            id: secondQuestID,
            contentVersion: "fixture-1",
            title: text("Rute Fiktif Kedua", "Second Fictional Route"),
            region: "Fiktif",
            city: "Kota Fiktif",
            hookLore: [lore("Kail kedua.", "The second hook.", .oral)],
            description: text("Deskripsi rute kedua.", "A second route description."),
            route: route,
            estimatedCost: EstimatedCost(amount: 0, currency: "IDR", breakdown: []),
            terrainSummary: text("Datar.", "Flat."),
            recommendedStartWindow: StartWindow(from: TimeOfDay(hour: 9, minute: 0),
                                                to: TimeOfDay(hour: 11, minute: 0)),
            hardLatestStart: TimeOfDay(hour: 16, minute: 0),
            proximityRadiusM: 200,
            safetyNotes: text("Perhatikan lalu lintas.", "Watch the traffic."),
            badgeId: "fixture-badge-2",
            heroImageAsset: "fixture-hero-2.jpg",
            checkpoints: [checkpoint(0, place: "fixture-pura", role: .start, last: true)]),
    ]
}

/// Serves `ContentFixture`. Read-only, in memory, and it knows nothing about the app bundle — the
/// point of it is that no authored JSON file can change what these guards mean.
struct FixtureContentRepository: ContentRepository {

    func manifest() throws -> Manifest {
        Manifest(
            schemaVersion: 2,
            contentBundleVersion: "fixture-1",
            languages: [.id, .en],
            places: ContentFixture.places.map(\.id),
            quests: ContentFixture.quests.map(\.id),
            regionMap: RegionMapAsset(asset: "fixture-region-map.png", aspectRatio: 0.46))
    }

    func contentBundleVersion() throws -> String { try manifest().contentBundleVersion }

    func quests() throws -> [Quest] { ContentFixture.quests }

    func quest(id: String) throws -> Quest? { ContentFixture.quests.first { $0.id == id } }

    func place(id: String) throws -> Place? { ContentFixture.places.first { $0.id == id } }

    func quests(suppressingQuestIDs: Set<String>,
                suppressingPlaceIDs: Set<String>) throws -> [Quest] {
        ContentFixture.quests.filter { quest in
            !suppressingQuestIDs.contains(quest.id)
                && !quest.checkpoints.contains { suppressingPlaceIDs.contains($0.placeId) }
        }
    }

    /// A path, not a file. Nothing in these guards decodes an image; they assert that the screen
    /// has *somewhere* to draw from, which is what `FR-MAP-01` is about.
    func assetURL(_ relativePath: String) throws -> URL? {
        URL(fileURLWithPath: "/fixture-content").appendingPathComponent(relativePath)
    }

    // The sidequest half of the protocol (s1 §6). This tree ships none; a quest guard has no
    // business depending on one either way.
    func sideQuests() throws -> [SideQuest] { [] }
    func sideQuest(id: String) throws -> SideQuest? { nil }
    func sideQuests(atPlaceID placeID: String) throws -> [SideQuest] { [] }
    func collections() throws -> [LetterCollection] { [] }
    func collection(id: String) throws -> LetterCollection? { nil }
    func sideQuests(suppressingSideQuestIDs: Set<String>,
                    suppressingPlaceIDs: Set<String>) throws -> [SideQuest] { [] }
}
