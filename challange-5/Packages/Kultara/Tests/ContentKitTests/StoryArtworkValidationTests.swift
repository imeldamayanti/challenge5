import Foundation
import Testing
@testable import ContentKit

/// The Story Reveal's per-place background drawing (`964:3212` and its three siblings), and the two
/// ways it can be wrong.
///
/// Same shape as `SiteMapValidationTests` because the field is the same kind of thing: a generated
/// illustration of a real place, carried on `Place`, held to V14 (the asset exists) and V3 (its
/// citation resolves). Every test here proves violating content is **rejected** — confirming that
/// valid content passes proves nothing on its own.
struct StoryArtworkValidationTests {

    private func bundle(_ storyArtwork: PlaceStoryArtwork?, sourceCount: Int = 1) -> ContentBundle {
        let sources = (0..<sourceCount).map {
            Source(kind: .documented, citation: "Sumber \($0)", url: nil)
        }
        return ContentFactory.bundle(places: [
            ContentFactory.place(id: "place-a", sources: sources,
                                 consentRecordId: "place-a", storyArtwork: storyArtwork),
            ContentFactory.place(id: "place-b", consentRecordId: "place-b"),
        ])
    }

    private func findings(_ bundle: ContentBundle) -> [ValidationFinding] {
        ContentValidator.validate(
            bundle,
            assets: ContentFactory.assets(present: [
                "quests/quest-a/route.geojson",
                "quests/quest-a/route-preview.png",
                "places/place-a/story.png",
            ]),
            today: ContentFactory.today)
    }

    private static let valid = PlaceStoryArtwork(
        asset: "places/place-a/story.png", sourceRef: 0)

    @Test func aPlaceWithNoStoryArtworkIsNotAFinding() {
        // Absence is the norm — most Places will never have one drawn, and the screen falls back
        // to its packaged art.
        let found = findings(bundle(nil))
        #expect(!found.contains { $0.rule == .v14 })
        #expect(!found.contains { $0.rule == .v3 })
    }

    @Test func aWellFormedStoryArtworkIsNotAFinding() {
        let found = findings(bundle(Self.valid))
        #expect(!found.contains { $0.rule == .v14 })
        #expect(!found.contains { $0.rule == .v3 })
    }

    // MARK: - V14 · the drawing has to exist

    @Test func v14RejectsStoryArtworkWhoseAssetIsNotInTheBundle() {
        let missing = PlaceStoryArtwork(
            asset: "places/place-a/nowhere.png", sourceRef: 0)
        #expect(findings(bundle(missing)).contains {
            $0.rule == .v14 && $0.message.contains("nowhere.png")
        })
    }

    // MARK: - V3 · the drawing has to cite a source that exists

    @Test(arguments: [1, 2, 7])
    func v3RejectsAStoryArtworkSourceRefPastTheEndOfThePlacesSources(_ ref: Int) {
        let dangling = PlaceStoryArtwork(
            asset: "places/place-a/story.png", sourceRef: ref)
        #expect(findings(bundle(dangling, sourceCount: 1)).contains {
            $0.rule == .v3 && $0.message.contains("storyArtwork")
        })
    }

    @Test func v3RejectsANegativeStoryArtworkSourceRef() {
        let negative = PlaceStoryArtwork(
            asset: "places/place-a/story.png", sourceRef: -1)
        #expect(findings(bundle(negative)).contains {
            $0.rule == .v3 && $0.message.contains("storyArtwork")
        })
    }

    // MARK: - Decoding

    @Test func aPlaceWithNoStoryArtworkKeyDecodes() throws {
        // Every Place shipped before this field existed. A decode failure here would stop all
        // eleven of them loading.
        let json = """
        {"asset":"places/x/story.png","sourceRef":2}
        """
        let decoded = try JSONDecoder().decode(PlaceStoryArtwork.self, from: Data(json.utf8))
        #expect(decoded.asset == "places/x/story.png")
        #expect(decoded.sourceRef == 2)
    }

    @Test func aStoryArtworkRoundTripsThroughEncoding() throws {
        let encoded = try JSONEncoder().encode(Self.valid)
        #expect(try JSONDecoder().decode(PlaceStoryArtwork.self, from: encoded) == Self.valid)
    }
}

/// The four drawings the bundle actually ships for `badung-empat-wajah`'s last four stops.
///
/// Reads live content deliberately, like `ShippedSiteMapTests`: the claim being held is about *these*
/// drawings — each belongs to one place, each carries a citation that admits it is an unverified
/// generated illustration, and the first checkpoint (whose cutscene carries the quest's own hero
/// image) ships none. If a fifth place acquires artwork the count fails and says what to update.
struct ShippedStoryArtworkTests {

    private static let withArtwork = [
        "badung-pura-maospahit",
        "badung-pasar-badung",
        "badung-catur-muka",
        "badung-museum-bali",
    ]

    @Test(arguments: withArtwork)
    func theStopShipsArtworkWhoseCitationResolvesAndAdmitsUnverified(placeID: String) throws {
        let repository = try BundledContentRepository()
        let place = try #require(try repository.place(id: placeID))
        let artwork = try #require(place.storyArtwork, "\(placeID) dropped its story artwork")

        #expect(place.sources.indices.contains(artwork.sourceRef))
        #expect(place.sources[artwork.sourceRef].citation.hasPrefix("BELUM DIVERIFIKASI"))
        _ = try repository.assetURL(artwork.asset)
    }

    @Test func theStartCheckpointShipsNone() throws {
        // Puri Agung Pemecutan's story page keeps the packaged fallback: its opening is told by the
        // quest's own cutscene (`heroImageAsset`), not by a per-place drawing.
        let repository = try BundledContentRepository()
        let place = try repository.place(id: "badung-puri-agung-pemecutan")
        #expect(place?.storyArtwork == nil)
    }
}
