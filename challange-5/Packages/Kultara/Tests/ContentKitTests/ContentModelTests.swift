import Foundation
import Testing
@testable import ContentKit

/// The content model from `schema.md` §A.3–A.7. The tests that carry weight here are the
/// rejections: an enum raw value that no longer exists, a `LoreBlock` with no accuracy label
/// (`NFR-CONT-01`), a malformed date or time. Content is authored by hand, so the decoder is
/// the first line where a typo becomes visible.
struct ContentModelTests {

    private let decoder = JSONDecoder()

    // MARK: - Enums

    @Test func placeTypeDecodesTheHyphenatedRawValue() throws {
        // `ruang-publik` in JSON, `ruangPublik` in Swift — a mismatch here silently drops
        // every public-space Place from the bundle.
        #expect(PlaceType(rawValue: "ruang-publik") == .ruangPublik)
        #expect(PlaceType(rawValue: "puri") == .puri)
    }

    @Test(arguments: ["kelurahan", "temple", "", "Puri"])
    func placeTypeRejectsAnUnknownRawValue(_ raw: String) {
        #expect(PlaceType(rawValue: raw) == nil)
    }

    @Test func distanceSourceDecodesTheHyphenatedRawValue() throws {
        #expect(DistanceSource(rawValue: "walking-directions") == .walkingDirections)
        #expect(DistanceSource(rawValue: "haversine") == .haversine)
    }

    @Test func accuracyLabelHasExactlyTheTwoAuthoredValues() {
        #expect(Set(AccuracyLabel.allCases.map(\.rawValue)) == ["documented", "oral"])
    }

    @Test func taskTypeHasExactlyTheThreeMechanicsPermittedAtSacredPlaces() {
        // FR-TASK-05 limits mechanics to photo, reading, reflection and a single light
        // question. Nothing else may become representable without a deliberate change here.
        #expect(Set(TaskType.allCases.map(\.rawValue)) == ["photo", "reflection", "question"])
    }

    // MARK: - CalendarDay and TimeOfDay

    @Test func calendarDayDecodesAnISODay() throws {
        let day = try decoder.decode(CalendarDay.self, from: Data(#""2026-07-14""#.utf8))
        #expect(day == CalendarDay(year: 2026, month: 7, day: 14))
    }

    @Test(arguments: ["2026-7-14", "14/07/2026", "2026-13-01", "2026-02-30", "", "tomorrow", "2026-07-14T09:00:00Z"])
    func calendarDayRejectsAnythingElse(_ raw: String) {
        #expect(throws: (any Error).self) {
            try decoder.decode(CalendarDay.self, from: Data("\"\(raw)\"".utf8))
        }
    }

    @Test func timeOfDayDecodesAWallClockTime() throws {
        let time = try decoder.decode(TimeOfDay.self, from: Data(#""16:15""#.utf8))
        #expect(time == TimeOfDay(hour: 16, minute: 15))
        #expect(time.minutesFromMidnight == 16 * 60 + 15)
    }

    @Test(arguments: ["16:5", "24:00", "16:60", "4pm", "16", ""])
    func timeOfDayRejectsAnythingElse(_ raw: String) {
        #expect(throws: (any Error).self) {
            try decoder.decode(TimeOfDay.self, from: Data("\"\(raw)\"".utf8))
        }
    }

    @Test func timeOfDaySubtractingMinutesClampsRatherThanWrapping() throws {
        // hardLatestStart is a closing time minus a duration (schema A.5). A quest longer
        // than the time from midnight to closing must not wrap into the previous evening and
        // read as a valid late start.
        #expect(TimeOfDay(hour: 17, minute: 0).subtracting(minutes: 105) == TimeOfDay(hour: 15, minute: 15))
        #expect(TimeOfDay(hour: 1, minute: 0).subtracting(minutes: 120) == TimeOfDay(hour: 0, minute: 0))
    }

    // MARK: - LoreBlock

    @Test func loreBlockDecodesWithItsAccuracyLabelAndSourceRefs() throws {
        let block = try decoder.decode(LoreBlock.self, from: Data(#"""
        {
          "text": { "id": "Sekitar tahun 1660, Kyai Gede Raka mendirikan puri.",
                    "en": "Around 1660, Kyai Gede Raka founded the puri." },
          "accuracy": "documented",
          "sourceRefs": [0]
        }
        """#.utf8))
        #expect(block.accuracy == .documented)
        #expect(block.sourceRefs == [0])
        #expect(block.text.value(for: .id).hasPrefix("Sekitar"))
    }

    @Test func loreBlockWithoutAnAccuracyLabelFailsToDecode() {
        // NFR-CONT-01: there is no field for an unlabelled sentence, and no default either.
        #expect(throws: DecodingError.self) {
            try decoder.decode(LoreBlock.self, from: Data(#"""
            { "text": { "id": "Klaim tanpa label.", "en": "An unlabelled claim." },
              "sourceRefs": [0] }
            """#.utf8))
        }
    }

    @Test func loreBlockWithAnUnknownAccuracyLabelFailsToDecode() {
        #expect(throws: DecodingError.self) {
            try decoder.decode(LoreBlock.self, from: Data(#"""
            { "text": { "id": "Klaim.", "en": "A claim." },
              "accuracy": "probably", "sourceRefs": [0] }
            """#.utf8))
        }
    }

    @Test func loreBlockWithATranslationGapFailsToDecode() {
        #expect(throws: (any Error).self) {
            try decoder.decode(LoreBlock.self, from: Data(#"""
            { "text": { "id": "Hanya Indonesia." },
              "accuracy": "oral", "sourceRefs": [1] }
            """#.utf8))
        }
    }

    // MARK: - Checkpoint

    @Test func checkpointDecodesTheSchemaExample() throws {
        let checkpoint = try decoder.decode(Checkpoint.self, from: Data(Self.checkpointJSON.utf8))
        #expect(checkpoint.id == "jtb-cp1")
        #expect(checkpoint.orderIndex == 0)
        #expect(checkpoint.placeId == "puri-agung-pemecutan")
        #expect(checkpoint.role == .start)
        #expect(checkpoint.loreSegment.count == 2)
        #expect(checkpoint.loreSegment.map(\.accuracy) == [.documented, .oral])
        #expect(checkpoint.clueToNext?.value(for: .en).hasPrefix("Follow Jalan Sutomo") == true)
        #expect(checkpoint.tasks.count == 1)
        #expect(checkpoint.tasks[0].type == .photo)
        #expect(checkpoint.tasks[0].blocksProgression == false)
        #expect(checkpoint.sideQuests.count == 1)
        #expect(checkpoint.stampId == "stamp-jtb-1")
    }

    @Test func finalCheckpointDecodesWithANullClue() throws {
        let json = Self.checkpointJSON.replacingOccurrences(
            of: #""clueToNext": { "id": "Susuri Jalan Sutomo ke utara.", "en": "Follow Jalan Sutomo north." },"#,
            with: #""clueToNext": null,"#)
        let checkpoint = try decoder.decode(Checkpoint.self, from: Data(json.utf8))
        #expect(checkpoint.clueToNext == nil)
    }

    @Test func checkpointOmittingTasksAndSideQuestsDecodesAsEmpty() throws {
        let checkpoint = try decoder.decode(Checkpoint.self, from: Data(#"""
        { "id": "jtb-cp5", "orderIndex": 4, "placeId": "pasar-badung", "role": "finish",
          "loreSegment": [ { "text": { "id": "A.", "en": "A." }, "accuracy": "oral", "sourceRefs": [0] } ],
          "clueToNext": null, "stampId": "stamp-jtb-5" }
        """#.utf8))
        #expect(checkpoint.tasks.isEmpty)
        #expect(checkpoint.sideQuests.isEmpty)
    }

    @Test func checkpointRejectsAnUnknownRole() {
        let json = Self.checkpointJSON.replacingOccurrences(of: #""role": "start""#, with: #""role": "middle-ish""#)
        #expect(throws: DecodingError.self) {
            try decoder.decode(Checkpoint.self, from: Data(json.utf8))
        }
    }

    // MARK: - Place, Quest, Manifest, ConsentRecord round trips

    @Test func placeRoundTripsThroughEncoding() throws {
        let place = try decoder.decode(Place.self, from: Data(Self.placeJSON.utf8))
        #expect(place.id == "puri-agung-pemecutan")
        #expect(place.isSacred)
        #expect(place.type == .puri)
        #expect(place.arrivalRadiusM == 75)
        #expect(place.photoPolicy.level == .restricted)
        #expect(place.sources.count == 2)
        #expect(place.sources.map(\.kind) == [.documented, .oral])
        #expect(place.sources[1].url == nil)
        #expect(place.consentRecordId == "puri-agung-pemecutan")
        #expect(place.accessibility.stepCount == 6)
        #expect(place.visitingHours.weekly.first?.close == TimeOfDay(hour: 17, minute: 0))

        let reDecoded = try decoder.decode(Place.self, from: try JSONEncoder().encode(place))
        #expect(reDecoded == place)
    }

    @Test func questRoundTripsThroughEncoding() throws {
        let quest = try decoder.decode(Quest.self, from: Data(Self.questJSON.utf8))
        #expect(quest.id == "jejak-terakhir-badung")
        #expect(quest.route.distanceSource == .walkingDirections)
        #expect(quest.route.totalDistanceM == 2200)
        #expect(quest.route.walkingTimeMin == 35)
        #expect(quest.route.totalDurationMin == 105)
        #expect(quest.estimatedCost.amount == 0)
        #expect(quest.estimatedCost.breakdown.count == 1)
        #expect(quest.proximityRadiusM == 200)
        #expect(quest.hardLatestStart == TimeOfDay(hour: 15, minute: 15))
        #expect(quest.recommendedStartWindow.from == TimeOfDay(hour: 8, minute: 0))
        #expect(quest.checkpoints.count == 1)

        let reDecoded = try decoder.decode(Quest.self, from: try JSONEncoder().encode(quest))
        #expect(reDecoded == quest)
    }

    @Test func manifestDecodesTheSchemaExample() throws {
        let manifest = try decoder.decode(Manifest.self, from: Data(#"""
        { "schemaVersion": 1, "contentBundleVersion": "2026.08.1",
          "languages": ["id", "en"],
          "places": ["puri-agung-pemecutan"], "quests": ["jejak-terakhir-badung"] }
        """#.utf8))
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.contentBundleVersion == "2026.08.1")
        #expect(manifest.languages == [.id, .en])
        #expect(manifest.quests == ["jejak-terakhir-badung"])
    }

    @Test func consentRecordDecodesTheSchemaExample() throws {
        let record = try decoder.decode(ConsentRecord.self, from: Data(#"""
        { "placeId": "puri-agung-pemecutan", "grantingBody": "Puri Agung Pemecutan",
          "grantedByName": "I Gusti Ngurah Contoh", "grantedByRole": "Penglingsir",
          "grantedAt": "2026-07-14", "expiresAt": "2027-07-14",
          "scope": ["inclusion", "photography", "naming"],
          "documentRef": "consent/2026/puri-agung-pemecutan-signed.pdf",
          "status": "granted", "regionOwner": "Alief Fauzan" }
        """#.utf8))
        #expect(record.status == .granted)
        #expect(record.scope.contains(.photography))
        #expect(record.expiresAt == CalendarDay(year: 2027, month: 7, day: 14))
        #expect(record.regionOwner == "Alief Fauzan")
    }

    @Test func consentRecordRejectsAnUnknownStatus() {
        #expect(throws: DecodingError.self) {
            try decoder.decode(ConsentRecord.self, from: Data(#"""
            { "placeId": "p", "grantingBody": "b", "grantedByName": "n", "grantedByRole": "r",
              "grantedAt": "2026-07-14", "expiresAt": "2027-07-14", "scope": ["inclusion"],
              "documentRef": "d", "status": "pending", "regionOwner": "o" }
            """#.utf8))
        }
    }

    // MARK: - Fixtures

    static let checkpointJSON = #"""
    {
      "id": "jtb-cp1",
      "orderIndex": 0,
      "placeId": "puri-agung-pemecutan",
      "role": "start",
      "loreSegment": [
        { "text": { "id": "Sekitar tahun 1660 puri ini didirikan.", "en": "The puri was founded around 1660." },
          "accuracy": "documented", "sourceRefs": [0] },
        { "text": { "id": "Konon restu kejayaan diberikan di sini.", "en": "Legend holds a blessing was granted here." },
          "accuracy": "oral", "sourceRefs": [1] }
      ],
      "clueToNext": { "id": "Susuri Jalan Sutomo ke utara.", "en": "Follow Jalan Sutomo north." },
      "tasks": [
        { "id": "jtb-cp1-t1", "type": "photo",
          "prompt": { "id": "Foto gerbang utama.", "en": "Photograph the main gate." },
          "blocksProgression": false }
      ],
      "sideQuests": [
        { "id": "jtb-cp1-s1",
          "prompt": { "id": "Cari tahu siapa raja terakhir.", "en": "Find out who the last king was." } }
      ],
      "stampId": "stamp-jtb-1"
    }
    """#

    static let placeJSON = #"""
    {
      "id": "puri-agung-pemecutan",
      "nameOfficial": { "id": "Puri Agung Pemecutan", "en": "Puri Agung Pemecutan" },
      "nameVariants": ["Puri Pemecutan"],
      "type": "puri",
      "isSacred": true,
      "coordinate": { "lat": -8.6584, "lon": 115.2091 },
      "arrivalRadiusM": 75,
      "address": { "id": "Jl. Thamrin No.2, Denpasar Barat", "en": "Jl. Thamrin No.2, West Denpasar" },
      "visitingHours": {
        "notes": { "id": "Cek ulang saat piodalan.", "en": "Re-check during piodalan ceremonies." },
        "weekly": [{ "weekday": 1, "open": "08:00", "close": "17:00" }]
      },
      "dressCode": { "id": "Kamen dan selendang wajib.", "en": "Sarong and sash required." },
      "photoPolicy": { "level": "restricted",
                       "notes": { "id": "Tidak di area suci.", "en": "Not inside sacred areas." } },
      "entryCost": { "amount": 0, "currency": "IDR" },
      "accessibility": { "hasSteps": true, "stepCount": 6, "surface": "paving",
                         "notes": { "id": "Enam undakan rendah.", "en": "Six shallow steps." } },
      "loreStandalone": [
        { "text": { "id": "Puri ini pusat kekuasaan Badung.", "en": "This puri was the seat of Badung." },
          "accuracy": "documented", "sourceRefs": [0] }
      ],
      "sources": [
        { "kind": "documented", "citation": "Pemkot Denpasar, profil sejarah", "url": "https://example.org/a" },
        { "kind": "oral", "citation": "Wawancara pemangku, media lokal 2023", "url": null }
      ],
      "consentRecordId": "puri-agung-pemecutan"
    }
    """#

    static let questJSON = #"""
    {
      "id": "jejak-terakhir-badung",
      "contentVersion": "2026.08.1",
      "title": { "id": "Jejak Terakhir Badung", "en": "Badung's Last Trail" },
      "region": "Denpasar",
      "city": "Denpasar",
      "hookLore": [
        { "text": { "id": "Tahun 1906 kota ini berubah.", "en": "In 1906 this city changed." },
          "accuracy": "documented", "sourceRefs": [0] }
      ],
      "description": { "id": "Jalan kaki menyusuri sisa Badung.", "en": "A walk through what Badung left." },
      "route": {
        "totalDistanceM": 2200,
        "distanceSource": "walking-directions",
        "walkingTimeMin": 35,
        "totalDurationMin": 105,
        "geometryAsset": "quests/jejak-terakhir-badung/route.geojson",
        "previewImageAsset": "quests/jejak-terakhir-badung/route-preview.png"
      },
      "estimatedCost": { "amount": 0, "currency": "IDR",
                         "breakdown": [{ "placeId": "puri-agung-pemecutan", "amount": 0 }] },
      "terrainSummary": { "id": "Trotoar sempit, enam undakan.", "en": "Narrow pavement, six steps." },
      "recommendedStartWindow": { "from": "08:00", "to": "14:00" },
      "hardLatestStart": "15:15",
      "proximityRadiusM": 200,
      "safetyNotes": { "id": "Lalu lintas padat.", "en": "Traffic is heavy." },
      "languages": ["id", "en"],
      "badgeId": "penjaga-ingatan-badung",
      "checkpoints": [ \#(checkpointJSON) ]
    }
    """#
}

/// Additions the Home mockup requires: a hero image per quest, a region map for the map screen,
/// and an authored pin position per Place.
struct RegionMapAndHeroTests {

    private let decoder = JSONDecoder()

    @Test func manifestCarriesAnOptionalRegionMap() throws {
        let manifest = try decoder.decode(Manifest.self, from: Data(#"""
        { "schemaVersion": 1, "contentBundleVersion": "2026.08.2",
          "languages": ["id", "en"], "places": ["p"], "quests": ["q"],
          "regionMap": { "asset": "maps/bali.png", "aspectRatio": 0.4626 } }
        """#.utf8))
        #expect(manifest.regionMap?.asset == "maps/bali.png")
    }

    @Test func manifestWithoutARegionMapStillDecodes() throws {
        // Content that ships no map is valid; the map screen simply has nothing to draw.
        let manifest = try decoder.decode(Manifest.self, from: Data(#"""
        { "schemaVersion": 1, "contentBundleVersion": "2026.08.2",
          "languages": ["id", "en"], "places": ["p"], "quests": ["q"] }
        """#.utf8))
        #expect(manifest.regionMap == nil)
    }

    @Test func mapPointIsNormalisedAndAuthoredRatherThanDerived() throws {
        // The region map is a drawing, not a projection: it is taller than Bali is and the
        // coastline is stylised. Deriving a pin position from lat/lon would put every pin in the
        // wrong place with an air of precision, so the position is authored as a fraction of the
        // image and the validator checks the range rather than the geography.
        let point = try decoder.decode(MapPoint.self, from: Data(#"{ "x": 0.42, "y": 0.63 }"#.utf8))
        #expect(point.x == 0.42)
        #expect(point.y == 0.63)
    }

    @Test func aPlaceMayCarryAMapPoint() throws {
        var json = ContentModelTests.placeJSON
        json = json.replacingOccurrences(
            of: #""arrivalRadiusM": 75,"#,
            with: #""arrivalRadiusM": 75, "mapPoint": { "x": 0.5, "y": 0.5 },"#)
        let place = try decoder.decode(Place.self, from: Data(json.utf8))
        #expect(place.mapPoint == MapPoint(x: 0.5, y: 0.5))
    }

    @Test func aPlaceWithoutAMapPointStillDecodes() throws {
        #expect(try decoder.decode(Place.self, from: Data(ContentModelTests.placeJSON.utf8)).mapPoint == nil)
    }

    @Test func aQuestMayCarryAHeroImage() throws {
        let json = ContentModelTests.questJSON.replacingOccurrences(
            of: #""region": "Denpasar","#,
            with: #""region": "Denpasar", "heroImageAsset": "quests/jejak-terakhir-badung/hero.jpg","#)
        let quest = try decoder.decode(Quest.self, from: Data(json.utf8))
        #expect(quest.heroImageAsset == "quests/jejak-terakhir-badung/hero.jpg")
    }

    @Test func aQuestWithoutAHeroImageStillDecodes() throws {
        #expect(try decoder.decode(Quest.self, from: Data(ContentModelTests.questJSON.utf8)).heroImageAsset == nil)
    }

    @Test func checkpointCountIsExposedForTheCardMetadata() throws {
        // The mockup's card says "5 quests" for what the glossary calls checkpoints. A quest
        // containing quests would collide with the vocabulary FR-CP-08 counts in, so the model
        // names it what it is.
        let quest = try decoder.decode(Quest.self, from: Data(ContentModelTests.questJSON.utf8))
        #expect(quest.checkpointCount == quest.checkpoints.count)
    }
}
