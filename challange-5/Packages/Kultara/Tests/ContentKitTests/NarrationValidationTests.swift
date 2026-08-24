import Foundation
import Testing
@testable import ContentKit

/// `Checkpoint.narration` — the spoken reading of a checkpoint's passage — and the four ways it can
/// be wrong.
///
/// Same shape as `StoryArtworkValidationTests`, because the field is held to the same two rules:
/// V14 (the recording exists) and V3 (its citation resolves against the owning Place). It adds two
/// of its own — a language the quest does not offer, and a language key this build cannot name —
/// because narration is the first content field keyed by language that is not a `LocalizedText`.
///
/// Every test here proves violating content is **rejected**. Confirming valid content passes proves
/// nothing on its own.
struct NarrationValidationTests {

    private func bundle(
        _ narration: [ContentLanguage: CheckpointNarration],
        sourceCount: Int = 1
    ) -> ContentBundle {
        let sources = (0..<sourceCount).map {
            Source(kind: .documented, citation: "Sumber \($0)", url: nil)
        }
        return ContentFactory.bundle(
            places: [
                ContentFactory.place(id: "place-a", sources: sources, consentRecordId: "place-a"),
                ContentFactory.place(id: "place-b", consentRecordId: "place-b"),
            ],
            quests: [
                ContentFactory.quest(checkpoints: [
                    ContentFactory.checkpoint(
                        id: "cp1", orderIndex: 0, placeId: "place-a", role: .start,
                        narration: narration),
                    ContentFactory.checkpoint(
                        id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish,
                        clueToNext: nil),
                ]),
            ])
    }

    private func findings(_ bundle: ContentBundle) -> [ValidationFinding] {
        ContentValidator.validate(
            bundle,
            assets: ContentFactory.assets(present: [
                "quests/quest-a/route.geojson",
                "quests/quest-a/route-preview.png",
                "quests/quest-a/narration/cp1-en.mp3",
            ]),
            today: ContentFactory.today)
    }

    private static let valid = CheckpointNarration(
        asset: "quests/quest-a/narration/cp1-en.mp3", sourceRef: 0)

    @Test func aCheckpointWithNoNarrationIsNotAFinding() {
        // Absence is the norm: most checkpoints will never be recorded, and one that is not simply
        // draws no control.
        let found = findings(bundle([:]))
        #expect(!found.contains { $0.rule == .v14 })
        #expect(!found.contains { $0.rule == .v3 })
    }

    @Test func aWellFormedNarrationIsNotAFinding() {
        let found = findings(bundle([.en: Self.valid]))
        #expect(!found.contains { $0.rule == .v14 })
        #expect(!found.contains { $0.rule == .v3 })
    }

    // MARK: - V14 · the recording has to exist

    @Test func v14RejectsNarrationWhoseAssetIsNotInTheBundle() {
        // A path that resolves to nothing draws a play button over silence — worse than no control,
        // because the walker waits for it.
        let missing = CheckpointNarration(
            asset: "quests/quest-a/narration/nowhere.mp3", sourceRef: 0)
        #expect(findings(bundle([.en: missing])).contains {
            $0.rule == .v14 && $0.message.contains("nowhere.mp3")
        })
    }

    // MARK: - V3 · the citation has to resolve

    @Test func v3RejectsNarrationCitingASourceThePlaceDoesNotHave() {
        // The recording is a synthesised voice, and where that is recorded is the Place's own
        // `sources`. An index past the end leaves it recorded nowhere.
        let overrun = CheckpointNarration(
            asset: "quests/quest-a/narration/cp1-en.mp3", sourceRef: 3)
        #expect(findings(bundle([.en: overrun], sourceCount: 1)).contains {
            $0.rule == .v3 && $0.message.contains("narration")
        })
    }

    @Test func v3RejectsNarrationCitingANegativeSourceIndex() {
        let negative = CheckpointNarration(
            asset: "quests/quest-a/narration/cp1-en.mp3", sourceRef: -1)
        #expect(findings(bundle([.en: negative])).contains {
            $0.rule == .v3 && $0.message.contains("narration")
        })
    }

    // MARK: - V3 · a recording nobody can reach

    @Test func v3RejectsARecordingInALanguageTheQuestDoesNotOffer() {
        // The run's language comes from `Quest.languages`, so a recording outside that set is a
        // file no state of the app can play. It ships weight and reaches nobody.
        let englishOnly = ContentFactory.bundle(
            places: [
                ContentFactory.place(id: "place-a", consentRecordId: "place-a"),
                ContentFactory.place(id: "place-b", consentRecordId: "place-b"),
            ],
            quests: [
                ContentFactory.quest(languages: [.en], checkpoints: [
                    ContentFactory.checkpoint(
                        id: "cp1", orderIndex: 0, placeId: "place-a", role: .start,
                        narration: [.id: Self.valid]),
                    ContentFactory.checkpoint(
                        id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish,
                        clueToNext: nil),
                ]),
            ])
        #expect(findings(englishOnly).contains {
            $0.rule == .v3 && $0.message.contains("not among the quest's languages")
        })
    }

    // MARK: - The decoder, which is where the language key is checked

    @Test func aNarrationKeyedByALanguageThisBuildCannotNameFailsToDecode() throws {
        // Not a validator finding, deliberately: content shipping `"jv"` has made a claim about a
        // language nothing here can render, and swallowing the key would hide the mistake behind a
        // screen that quietly draws no control.
        let json = Data("""
        {
          "id": "cp1", "orderIndex": 0, "placeId": "place-a", "role": "start",
          "loreSegment": [
            { "text": { "id": "Klaim", "en": "Claim" },
              "accuracy": "documented", "sourceRefs": [0] }
          ],
          "clueToNext": { "id": "Petunjuk", "en": "Clue" },
          "tasks": [], "bonusPrompts": [], "stampId": "stamp-cp1",
          "narration": { "jv": { "asset": "a.mp3", "sourceRef": 0 } }
        }
        """.utf8)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Checkpoint.self, from: json)
        }
    }

    @Test func narrationDecodesFromTheLanguageKeyedObjectContentActuallyWrites() throws {
        // `[ContentLanguage: …]` would encode as a flat `["en", …]` array without
        // `CodingKeyRepresentable`, so this pins the on-disk shape rather than only the round trip.
        let json = Data("""
        {
          "id": "cp1", "orderIndex": 0, "placeId": "place-a", "role": "start",
          "loreSegment": [
            { "text": { "id": "Klaim", "en": "Claim" },
              "accuracy": "documented", "sourceRefs": [0] }
          ],
          "clueToNext": { "id": "Petunjuk", "en": "Clue" },
          "tasks": [], "bonusPrompts": [], "stampId": "stamp-cp1",
          "narration": {
            "en": { "asset": "quests/q/narration/cp1-en.mp3", "sourceRef": 4 }
          }
        }
        """.utf8)
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: json)
        #expect(checkpoint.narration[.en]?.asset == "quests/q/narration/cp1-en.mp3")
        #expect(checkpoint.narration[.en]?.sourceRef == 4)
        #expect(checkpoint.narration[.id] == nil)
    }

    @Test func aCheckpointWithNoNarrationKeyDecodesToNoNarrationRatherThanFailing() throws {
        // Every checkpoint authored before this field existed still has to load.
        let json = Data("""
        {
          "id": "cp1", "orderIndex": 0, "placeId": "place-a", "role": "start",
          "loreSegment": [
            { "text": { "id": "Klaim", "en": "Claim" },
              "accuracy": "documented", "sourceRefs": [0] }
          ],
          "clueToNext": null,
          "tasks": [], "bonusPrompts": [], "stampId": "stamp-cp1"
        }
        """.utf8)
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: json)
        #expect(checkpoint.narration.isEmpty)
    }

    // MARK: - V1 · the field wears a LocalizedText's shape without being one

    @Test func v1DoesNotReadANarrationMapAsALocalizedTextWithANonStringTranslation() throws {
        // `{"en": {"asset": …}}` is keys drawn from `id`/`en` carrying non-strings, which is
        // exactly the defect V1 exists to catch. The exception is named, not a loosening of the
        // rule — the test below proves the rule still bites everywhere else.
        let document = Data("""
        { "checkpoints": [
            { "narration": { "en": { "asset": "a.mp3", "sourceRef": 0 } } }
        ] }
        """.utf8)
        let found = ContentValidator.validateRawDocument(
            path: "quests/quest-a.json", json: document)
        #expect(!found.contains { $0.rule == .v1 })
    }

    @Test func v1StillRejectsANonStringTranslationInAFieldThatIsNotNarration() throws {
        let document = Data("""
        { "checkpoints": [
            { "clueToNext": { "en": { "asset": "a.mp3" } } }
        ] }
        """.utf8)
        let found = ContentValidator.validateRawDocument(
            path: "quests/quest-a.json", json: document)
        #expect(found.contains { $0.rule == .v1 })
    }
}

/// The shipped bundle's own narration, which is a *content* guard rather than a requirement guard —
/// the family `BundledContentRepositoryTests` belongs to. It reads live content deliberately: the
/// thing worth catching is a recording that stops shipping, and a fixture cannot see that.
struct BundledNarrationTests {

    private func repository() throws -> BundledContentRepository {
        try BundledContentRepository()
    }

    @Test func everyCheckpointOfTheShippedQuestCarriesAnEnglishReadingThatResolves() throws {
        let repository = try repository()
        let quest = try #require(try repository.quest(id: "badung-empat-wajah"))
        #expect(quest.checkpoints.count == 5)
        for checkpoint in quest.orderedCheckpoints {
            let narration = try #require(
                checkpoint.narration[.en],
                "\(checkpoint.id) ships no English narration")
            let url = try repository.assetURL(narration.asset)
            #expect(url != nil, "\(checkpoint.id) narration asset \(narration.asset) is missing")
        }
    }

    @Test func theShippedNarrationCitesTheSyntheticVoiceOnEachPlace() throws {
        // The recordings are text-to-speech, not a narrator in a booth, and `FR-CP-05`'s habit in
        // this codebase is that a generated artefact carries a citation saying so. Losing that
        // citation while keeping the audio is the silent failure worth a guard.
        let repository = try repository()
        let quest = try #require(try repository.quest(id: "badung-empat-wajah"))
        for checkpoint in quest.orderedCheckpoints {
            let narration = try #require(checkpoint.narration[.en])
            let place = try #require(try repository.place(id: checkpoint.placeId))
            let source = try #require(place.sources.indices.contains(narration.sourceRef)
                ? place.sources[narration.sourceRef] : nil)
            #expect(
                source.citation.contains("sintetis"),
                "\(place.id) narration cites a source that does not name the synthetic voice")
        }
    }

    @Test func noCheckpointShipsAnIndonesianReading() throws {
        // An inverted guard, so the gap is visible rather than assumed. Only the English readings
        // exist; the Indonesian walker gets the passage on the page and no control, which is the
        // no-fallback rule working, not a bug. Recording the Indonesian set is what turns this red.
        let repository = try repository()
        let quest = try #require(try repository.quest(id: "badung-empat-wajah"))
        #expect(quest.orderedCheckpoints.allSatisfy { $0.narration[.id] == nil })
    }
}
