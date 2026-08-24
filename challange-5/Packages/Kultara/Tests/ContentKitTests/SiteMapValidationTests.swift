import Foundation
import Testing
@testable import ContentKit

/// The drawn plan of a Place's grounds (`452:3028`), and the two ways it can be wrong.
///
/// The load-bearing one is the citation. A site plan asserts where the gates are and how far apart
/// the walls stand; `FR-CP-05` holds that to the same standard as a sentence of lore, and a
/// `sourceRef` that resolves to nothing renders as no citation at all — an unsourced claim about a
/// real place, which is exactly what the rule forbids. Every test here proves violating content is
/// **rejected**: confirming that valid content passes proves nothing on its own.
struct SiteMapValidationTests {

    private func bundle(_ siteMap: PlaceSiteMap?, sourceCount: Int = 1) -> ContentBundle {
        let sources = (0..<sourceCount).map {
            Source(kind: .documented, citation: "Sumber \($0)", url: nil)
        }
        return ContentFactory.bundle(places: [
            ContentFactory.place(id: "place-a", sources: sources,
                                 consentRecordId: "place-a", siteMap: siteMap),
            ContentFactory.place(id: "place-b", consentRecordId: "place-b"),
        ])
    }

    private func findings(_ bundle: ContentBundle) -> [ValidationFinding] {
        ContentValidator.validate(
            bundle,
            assets: ContentFactory.assets(present: [
                "quests/quest-a/route.geojson",
                "quests/quest-a/route-preview.png",
                "places/place-a/site-map.png",
            ]),
            today: ContentFactory.today)
    }

    private static let valid = PlaceSiteMap(
        asset: "places/place-a/site-map.png", aspectRatio: 1.12, sourceRef: 0)

    @Test func aPlaceWithNoPlanIsNotAFinding() {
        // Most Places never will have one — a market floor and a road junction are not buildings
        // with a plan. Absence is the norm, not an omission.
        let found = findings(bundle(nil))
        #expect(!found.contains { $0.rule == .v14 })
        #expect(!found.contains { $0.rule == .v3 })
    }

    @Test func aWellFormedPlanIsNotAFinding() {
        let found = findings(bundle(Self.valid))
        #expect(!found.contains { $0.rule == .v14 })
        #expect(!found.contains { $0.rule == .v3 })
    }

    // MARK: - V14 · the drawing has to exist

    @Test func v14RejectsAPlanWhoseAssetIsNotInTheBundle() {
        let missing = PlaceSiteMap(
            asset: "places/place-a/nowhere.png", aspectRatio: 1.12, sourceRef: 0)
        #expect(findings(bundle(missing)).contains {
            $0.rule == .v14 && $0.message.contains("nowhere.png")
        })
    }

    @Test(arguments: [0.0, -1.0])
    func v14RejectsAPlanWithANonPositiveAspectRatio(_ ratio: Double) {
        // The screen reserves space from this before it decodes the bytes. Zero collapses the plan
        // to a hairline and negative flips it.
        let bad = PlaceSiteMap(
            asset: "places/place-a/site-map.png", aspectRatio: ratio, sourceRef: 0)
        #expect(findings(bundle(bad)).contains {
            $0.rule == .v14 && $0.message.contains("aspectRatio")
        })
    }

    // MARK: - V3 · the drawing has to cite a source that exists

    @Test(arguments: [1, 2, 7])
    func v3RejectsASiteMapSourceRefPastTheEndOfThePlacesSources(_ ref: Int) {
        let dangling = PlaceSiteMap(
            asset: "places/place-a/site-map.png", aspectRatio: 1.12, sourceRef: ref)
        #expect(findings(bundle(dangling, sourceCount: 1)).contains {
            $0.rule == .v3 && $0.message.contains("siteMap")
        })
    }

    @Test func v3RejectsANegativeSiteMapSourceRef() {
        let negative = PlaceSiteMap(
            asset: "places/place-a/site-map.png", aspectRatio: 1.12, sourceRef: -1)
        #expect(findings(bundle(negative)).contains {
            $0.rule == .v3 && $0.message.contains("siteMap")
        })
    }

    // MARK: - Decoding

    @Test func aPlaceWithNoSiteMapKeyDecodes() throws {
        // `siteMap` is optional and every Place shipped before it existed. A decode failure here
        // would mean four of the five shipped Places stop loading.
        let json = """
        {"asset":"places/x/plan.png","aspectRatio":1.5,"sourceRef":2}
        """
        let decoded = try JSONDecoder().decode(PlaceSiteMap.self, from: Data(json.utf8))
        #expect(decoded.asset == "places/x/plan.png")
        #expect(decoded.aspectRatio == 1.5)
        #expect(decoded.sourceRef == 2)
    }

    @Test func aSiteMapRoundTripsThroughEncoding() throws {
        let encoded = try JSONEncoder().encode(Self.valid)
        #expect(try JSONDecoder().decode(PlaceSiteMap.self, from: encoded) == Self.valid)
    }
}

/// The plan the bundle actually ships, and the sentence printed under it.
///
/// Unlike the requirement guards above this reads live content deliberately, because the claim being
/// held is about *this* drawing: it is a generated illustration of a real puri annotated with real
/// distances, and the only thing standing between that and an unsourced factual claim on screen is a
/// citation that says so. If someone swaps in a verified survey the first expectation fails and says
/// what to update; if someone drops the marker the second one fails.
struct ShippedSiteMapTests {

    @Test func puriAgungPemecutanShipsAPlanWhoseCitationResolves() throws {
        let repository = try BundledContentRepository()
        let place = try #require(try repository.place(id: "badung-puri-agung-pemecutan"))
        let siteMap = try #require(place.siteMap)

        #expect(place.sources.indices.contains(siteMap.sourceRef))
        #expect(siteMap.aspectRatio > 0)
        _ = try repository.assetURL(siteMap.asset)
    }

    @Test func theShippedPlansCitationSaysItIsUnverified() throws {
        // `docs/field-verification-checklist.md`'s convention: a claim nobody has checked carries a
        // citation beginning `BELUM DIVERIFIKASI`. This drawing is generated and unsurveyed, and the
        // site-map screen prints this exact string — so the screen tells the truth for as long as
        // this holds and no longer.
        let repository = try BundledContentRepository()
        let place = try #require(try repository.place(id: "badung-puri-agung-pemecutan"))
        let siteMap = try #require(place.siteMap)
        let citation = place.sources[siteMap.sourceRef].citation

        #expect(citation.hasPrefix("BELUM DIVERIFIKASI"))
    }

    @Test func noOtherShippedPlaceClaimsAPlanItDoesNotHave() throws {
        // Four of the five stops are a temple wall, a market floor, a road junction and a museum.
        // None ships a plan, and none should acquire one without a citation — which V14 and V3 hold,
        // but only for a plan that is actually authored.
        let repository = try BundledContentRepository()
        for id in ["badung-pura-maospahit", "badung-pasar-badung",
                   "badung-catur-muka", "badung-museum-bali"] {
            let place = try #require(try repository.place(id: id))
            #expect(place.siteMap == nil, "\(id) now ships a plan; check its citation")
        }
    }
}
