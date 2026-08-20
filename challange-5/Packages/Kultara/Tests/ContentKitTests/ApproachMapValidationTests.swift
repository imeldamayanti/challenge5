import Foundation
import Testing
@testable import ContentKit

/// The drawn map of the streets around a Place (`1:4458`), and the two ways it can be wrong.
///
/// The load-bearing one is the citation, for the same reason it is on the site plan: a street map
/// names real roads and asserts how they meet, `FR-CP-05` holds that to the standard of a sentence
/// of lore, and a `sourceRef` that resolves to nothing renders as no citation at all. Every test
/// here proves violating content is **rejected**; confirming that valid content passes proves
/// nothing on its own.
struct ApproachMapValidationTests {

    private func bundle(_ approachMap: PlaceApproachMap?, sourceCount: Int = 1) -> ContentBundle {
        let sources = (0..<sourceCount).map {
            Source(kind: .documented, citation: "Sumber \($0)", url: nil)
        }
        return ContentFactory.bundle(places: [
            ContentFactory.place(id: "place-a", sources: sources,
                                 consentRecordId: "place-a", approachMap: approachMap),
            ContentFactory.place(id: "place-b", consentRecordId: "place-b"),
        ])
    }

    private func findings(_ bundle: ContentBundle) -> [ValidationFinding] {
        ContentValidator.validate(
            bundle,
            assets: ContentFactory.assets(present: [
                "quests/quest-a/route.geojson",
                "quests/quest-a/route-preview.png",
                "places/place-a/approach-map.png",
            ]),
            today: ContentFactory.today)
    }

    private static let valid = PlaceApproachMap(
        asset: "places/place-a/approach-map.png", aspectRatio: 1.5869, sourceRef: 0)

    @Test func aPlaceWithNoApproachMapIsNotAFinding() {
        // Absence is the norm: only one shipped Place has a drawing of its surroundings, and the
        // Location Verified screen falls back to the run's projected route for the rest.
        let found = findings(bundle(nil))
        #expect(!found.contains { $0.rule == .v14 })
        #expect(!found.contains { $0.rule == .v3 })
    }

    @Test func aWellFormedApproachMapIsNotAFinding() {
        let found = findings(bundle(Self.valid))
        #expect(!found.contains { $0.rule == .v14 })
        #expect(!found.contains { $0.rule == .v3 })
    }

    // MARK: - V14 · the drawing has to exist

    @Test func v14RejectsAnApproachMapWhoseAssetIsNotInTheBundle() {
        let missing = PlaceApproachMap(
            asset: "places/place-a/nowhere.png", aspectRatio: 1.5869, sourceRef: 0)
        #expect(findings(bundle(missing)).contains {
            $0.rule == .v14 && $0.message.contains("nowhere.png")
        })
    }

    @Test(arguments: [0.0, -1.0])
    func v14RejectsAnApproachMapWithANonPositiveAspectRatio(_ ratio: Double) {
        // The screen reserves space from this before it decodes the bytes. Zero collapses the
        // drawing to a hairline and negative flips it.
        let bad = PlaceApproachMap(
            asset: "places/place-a/approach-map.png", aspectRatio: ratio, sourceRef: 0)
        #expect(findings(bundle(bad)).contains {
            $0.rule == .v14 && $0.message.contains("aspectRatio")
        })
    }

    // MARK: - V3 · the drawing has to cite a source that exists

    @Test(arguments: [1, 2, 7])
    func v3RejectsAnApproachMapSourceRefPastTheEndOfThePlacesSources(_ ref: Int) {
        let dangling = PlaceApproachMap(
            asset: "places/place-a/approach-map.png", aspectRatio: 1.5869, sourceRef: ref)
        #expect(findings(bundle(dangling, sourceCount: 1)).contains {
            $0.rule == .v3 && $0.message.contains("approachMap")
        })
    }

    @Test func v3RejectsANegativeApproachMapSourceRef() {
        let negative = PlaceApproachMap(
            asset: "places/place-a/approach-map.png", aspectRatio: 1.5869, sourceRef: -1)
        #expect(findings(bundle(negative)).contains {
            $0.rule == .v3 && $0.message.contains("approachMap")
        })
    }

    // MARK: - Decoding

    @Test func aPlaceWithNoApproachMapKeyDecodes() throws {
        // `approachMap` is optional and every Place shipped before it existed. A decode failure
        // here would mean ten of the eleven shipped Places stop loading.
        let json = """
        {"asset":"places/x/approach.png","aspectRatio":1.5,"sourceRef":2}
        """
        let decoded = try JSONDecoder().decode(PlaceApproachMap.self, from: Data(json.utf8))
        #expect(decoded.asset == "places/x/approach.png")
        #expect(decoded.aspectRatio == 1.5)
        #expect(decoded.sourceRef == 2)
    }

    @Test func anApproachMapRoundTripsThroughEncoding() throws {
        let encoded = try JSONEncoder().encode(Self.valid)
        #expect(try JSONDecoder().decode(PlaceApproachMap.self, from: encoded) == Self.valid)
    }
}

/// The approach map the bundle actually ships, and the sentence printed under it.
///
/// Reads live content deliberately, for the reason `ShippedSiteMapTests` does: the claim being held
/// is about *this* drawing. It names real Denpasar streets and has not been checked against any map
/// source, and the only thing between that and an unsourced factual claim on screen is a citation
/// saying so.
struct ShippedApproachMapTests {

    @Test func puriAgungPemecutanShipsAnApproachMapWhoseCitationResolves() throws {
        let repository = try BundledContentRepository()
        let place = try #require(try repository.place(id: "badung-puri-agung-pemecutan"))
        let approachMap = try #require(place.approachMap)

        #expect(place.sources.indices.contains(approachMap.sourceRef))
        #expect(approachMap.aspectRatio > 0)
        _ = try repository.assetURL(approachMap.asset)
    }

    @Test func theShippedApproachMapsCitationSaysItIsUnverified() throws {
        // `docs/field-verification-checklist.md`'s convention: a claim nobody has checked carries a
        // citation beginning `BELUM DIVERIFIKASI`. `ApproachMapView` prints this exact string, so
        // the screen tells the truth for as long as this holds and no longer.
        let repository = try BundledContentRepository()
        let place = try #require(try repository.place(id: "badung-puri-agung-pemecutan"))
        let approachMap = try #require(place.approachMap)
        let citation = place.sources[approachMap.sourceRef].citation

        #expect(citation.hasPrefix("BELUM DIVERIFIKASI"))
    }

    @Test func noOtherShippedPlaceClaimsAnApproachMapItDoesNotHave() throws {
        // The Location Verified screen falls back to the run's projected route at these four. A
        // drawing acquired without a citation would put an unsourced street map on that screen.
        let repository = try BundledContentRepository()
        for id in ["badung-pura-maospahit", "badung-pasar-kumbasari",
                   "badung-catur-muka", "badung-museum-bali"] {
            let place = try #require(try repository.place(id: id))
            #expect(place.approachMap == nil, "\(id) now ships an approach map; check its citation")
        }
    }
}
