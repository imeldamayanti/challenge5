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

    // MARK: - V14 · the marker has to be on the paper

    @Test func anApproachMapWithNoMarkerIsNotAFinding() {
        // The dot is optional and the map shipped before it existed. A Place whose point has not
        // been read off the drawing yet renders the plain map, which is the honest fallback.
        #expect(!findings(bundle(Self.valid)).contains {
            $0.rule == .v14 && $0.message.contains("marker")
        })
    }

    @Test(arguments: [MapPoint(x: -0.01, y: 0.5), MapPoint(x: 1.01, y: 0.5),
                      MapPoint(x: 0.5, y: -0.01), MapPoint(x: 0.5, y: 1.01),
                      MapPoint(x: 12, y: 40)])
    func v14RejectsAMarkerOutsideTheDrawing(_ point: MapPoint) {
        // Range only, the same thing V15 checks of `mapPoint` and for the same reason: whether the
        // dot lands on the right street is a question about the illustration, which no rule can
        // answer. Off the paper entirely a rule can — and `(12, 40)` is what a real coordinate
        // written into this field looks like, which is the mistake most worth catching.
        let offPaper = PlaceApproachMap(
            asset: "places/place-a/approach-map.png", aspectRatio: 1.5869, sourceRef: 0,
            marker: point)
        #expect(findings(bundle(offPaper)).contains {
            $0.rule == .v14 && $0.message.contains("marker")
        })
    }

    @Test func aMarkerOnTheEdgeOfTheDrawingIsAccepted() {
        // The bounds are inclusive: a place drawn hard against the edge of the chart is a drawing
        // decision, not a mistake.
        for point in [MapPoint(x: 0, y: 0), MapPoint(x: 1, y: 1)] {
            let edge = PlaceApproachMap(
                asset: "places/place-a/approach-map.png", aspectRatio: 1.5869, sourceRef: 0,
                marker: point)
            #expect(!findings(bundle(edge)).contains {
                $0.rule == .v14 && $0.message.contains("marker")
            })
        }
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
        #expect(decoded.marker == nil)
    }

    @Test func anApproachMapCarryingAMarkerDecodesIt() throws {
        let json = """
        {"asset":"places/x/approach.png","aspectRatio":1.5,"sourceRef":2,
         "marker":{"x":0.234,"y":0.7919}}
        """
        let decoded = try JSONDecoder().decode(PlaceApproachMap.self, from: Data(json.utf8))
        let marker = try #require(decoded.marker)
        #expect(marker.x == 0.234)
        #expect(marker.y == 0.7919)
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

    @Test func theShippedApproachMapCarriesTheMarkerTheTransitionScreenPulsesOver() throws {
        // `187:1103` puts a beating dot on this drawing, and the point it beats over is authored
        // here rather than projected from `coordinate` — the chart's street grid is stylised, so a
        // real projection would land the dot on the wrong road while looking exact.
        //
        // Read live, like the two tests around it, because the claim is about *this* drawing: the
        // value was read off the illustration's own marker for this Place, and replacing the
        // artwork means reading it off again.
        let repository = try BundledContentRepository()
        let place = try #require(try repository.place(id: "badung-puri-agung-pemecutan"))
        let approachMap = try #require(place.approachMap)
        let marker = try #require(approachMap.marker)

        #expect(marker.isInsideImage)
    }

    @Test func theShippedApproachMapsCitationSaysItIsUnverified() throws {
        // `docs/field-verification-checklist.md`'s convention: a claim nobody has checked carries a
        // citation beginning `BELUM DIVERIFIKASI`.
        //
        // **The screen no longer prints it** — that was a product decision on 2026-08-20, recorded
        // on `ApproachMapView` as an open `FR-CP-05` gap. This still holds the content half: the
        // provenance exists, resolves, and says what it is, so restoring the line is a view change
        // and not a content one.
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
