import ContentKit
import Foundation
@testable import RunEngine

/// A three-checkpoint quest with two places, built in memory.
///
/// Written out rather than read from the shipped bundle so these tests assert the *rules* and not
/// the shipped authored content: a checkpoint added to `badung-empat-wajah` must not turn an
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

/// Sidequest fixtures (PRD §5.15). Separate from `Fixture` because the two aggregates are
/// separate — a test that shared a quest fixture with a sidequest fixture would make it easy to
/// write a rule that reads across `FR-SIDE-01`.
enum SideQuestFixture {

    static let collectionID = "collection-fixture"
    static let quizID = "sq-quiz"
    static let photoID = "sq-photo"

    /// Two letters, two sidequests: the smallest collection that can be half done, which is what
    /// `FR-SIDE-08` and `FR-SIDE-09` are about.
    static let phrase = "AB"

    static func quiz(correctIndex: Int = 1) -> QuizChallenge {
        QuizChallenge(
            question: LocalizedText(id: "Berapa wajah?", en: "How many faces?"),
            options: [
                LocalizedText(id: "Dua", en: "Two"),
                LocalizedText(id: "Empat", en: "Four"),
                LocalizedText(id: "Delapan", en: "Eight"),
            ],
            correctIndex: correctIndex,
            explanation: LocalizedText(
                id: "Catur Muka berarti empat wajah.", en: "Catur Muka means four faces."))
    }

    static func sideQuest(
        id: String = quizID,
        placeID: String = "place-a",
        challenge: SideQuestChallenge? = nil,
        triggerRadiusM: Int = 75,
        noticeRadiusM: Int = 200
    ) -> SideQuest {
        SideQuest(
            id: id,
            placeId: placeID,
            title: LocalizedText(id: "Judul \(id)", en: "Title \(id)"),
            synopsis: LocalizedText(id: "Sinopsis \(id)", en: "Synopsis \(id)"),
            lore: [
                LoreBlock(
                    text: LocalizedText(id: "Klaim tercatat", en: "Documented claim"),
                    accuracy: .documented,
                    sourceRefs: [0]),
                LoreBlock(
                    text: LocalizedText(id: "Tutur setempat", en: "Oral account"),
                    accuracy: .oral,
                    sourceRefs: [1]),
            ],
            challenge: challenge ?? .quiz(quiz()),
            triggerRadiusM: triggerRadiusM,
            noticeRadiusM: noticeRadiusM)
    }

    static let sideQuests: [SideQuest] = [
        sideQuest(id: quizID, placeID: "place-a"),
        sideQuest(
            id: photoID, placeID: "place-b",
            challenge: .photo(PhotoChallenge(
                prompt: LocalizedText(id: "Foto gerbangnya.", en: "Photograph the gateway.")))),
    ]

    static func collection(phrase: String = phrase) -> LetterCollection {
        LetterCollection(
            id: collectionID,
            region: "Denpasar",
            phrase: phrase,
            title: LocalizedText(id: "Koleksi Uji", en: "Test Collection"),
            caption: LocalizedText(
                id: "Kumpulkan satu huruf di tiap tempat.",
                en: "Collect one letter at each place."),
            badgeId: "badge-collection-fixture",
            slots: [
                LetterSlot(index: 0, letter: "A", sideQuestId: quizID),
                LetterSlot(index: 1, letter: "B", sideQuestId: photoID),
            ])
    }
}

/// Content read from memory. Implements the same protocol the bundle does, which is the point of
/// the protocol existing.
struct StubContentRepository: ContentRepository {
    var quest: Quest = Fixture.quest()
    var places: [Place] = Fixture.places
    /// Empty by default, so every `RunEngine` test keeps proving that the Run rules do not read
    /// them. The sidequest suites supply their own.
    var sideQuestList: [SideQuest] = []
    var collectionList: [LetterCollection] = []

    func manifest() throws -> Manifest {
        Manifest(
            schemaVersion: sideQuestList.isEmpty && collectionList.isEmpty ? 1 : 2,
            contentBundleVersion: quest.contentVersion,
            languages: [.id, .en],
            places: places.map(\.id),
            quests: [quest.id],
            sideQuests: sideQuestList.map(\.id),
            collections: collectionList.map(\.id))
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

    // PRD §5.15. `RunEngine` knows nothing about sidequests and must keep knowing nothing —
    // `FR-SIDE-01` makes them a separate aggregate — so these are served for `SideQuestEngine`
    // and default to empty for every Run test.
    func sideQuests() throws -> [SideQuest] { sideQuestList }
    func sideQuest(id: String) throws -> SideQuest? { sideQuestList.first { $0.id == id } }

    func sideQuests(atPlaceID placeID: String) throws -> [SideQuest] {
        sideQuestList.filter { $0.placeId == placeID }
    }

    func collections() throws -> [LetterCollection] { collectionList }
    func collection(id: String) throws -> LetterCollection? { collectionList.first { $0.id == id } }

    func sideQuests(
        suppressingSideQuestIDs: Set<String>, suppressingPlaceIDs: Set<String>
    ) throws -> [SideQuest] {
        sideQuestList.filter {
            !suppressingSideQuestIDs.contains($0.id) && !suppressingPlaceIDs.contains($0.placeId)
        }
    }

    func assetURL(_ relativePath: String) throws -> URL? { nil }
}

/// A clock a test can move. `SideQuestEngine` takes `@Sendable () -> Date`, so the value it reads
/// has to be reference-shared rather than captured — a captured `var` is not `Sendable` under
/// Swift 6.
/// `@unchecked` because the engine is `@MainActor` and every caller of this is a `@MainActor` test:
/// the closure is only ever read on the main actor, and there is no second thread to race with.
final class TestClock: @unchecked Sendable {
    private var value: Date

    init(_ start: Date) { value = start }

    var now: Date { value }

    func advance(by seconds: TimeInterval) { value = value.addingTimeInterval(seconds) }
}

extension SideQuestFixture {
    /// Content that serves the two fixture sidequests and their collection.
    static func repository(
        sideQuests: [SideQuest] = SideQuestFixture.sideQuests,
        collections: [LetterCollection] = [SideQuestFixture.collection()],
        places: [Place] = Fixture.places,
        contentVersion: String = "2026.09.0"
    ) -> StubContentRepository {
        StubContentRepository(
            quest: Fixture.quest(contentVersion: contentVersion),
            places: places,
            sideQuestList: sideQuests,
            collectionList: collections)
    }
}
