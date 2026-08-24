import Foundation
import Testing
@testable import ContentKit

/// `FR-DISC-01` — browsing and full preview must work at any location on earth, with no network,
/// and with location permission denied. The strongest form of that guarantee is structural: the
/// repository is constructed from a bundle and nothing else, so there is no network client and no
/// location manager for it to be waiting on. `AD-3` — no reachability check anywhere.
struct BundledContentRepositoryTests {

    private func repository() throws -> BundledContentRepository {
        try BundledContentRepository()
    }

    // MARK: - FR-DISC-01 / FR-OFF-01

    @Test func assemblesTheWholeQuestGraphFromTheBundleAlone() throws {
        // No network stack and no location authorisation exist in this process, and none is
        // injected: whatever this returns, it returned offline and location-blind.
        let repository = try repository()
        let quests = try repository.quests()

        #expect(quests.count == 1)
        let quest = try #require(quests.first)
        #expect(quest.orderedCheckpoints.count == 5)
        #expect(quest.orderedCheckpoints.map(\.orderIndex) == [0, 1, 2, 3, 4])
        #expect(quest.orderedCheckpoints.map(\.role) == [.start, .middle, .middle, .middle, .finish])

        // Every checkpoint resolves to a Place, with lore and sources reachable.
        for checkpoint in quest.orderedCheckpoints {
            let place = try #require(try repository.place(id: checkpoint.placeId),
                                     "Checkpoint \(checkpoint.id) has no Place")
            #expect(!place.sources.isEmpty)
            #expect(!checkpoint.loreSegment.isEmpty)
            for block in checkpoint.loreSegment {
                #expect(!block.sourceRefs.isEmpty)
                for ref in block.sourceRefs {
                    #expect(ref < place.sources.count)
                }
            }
        }

        // Both languages resolve for every user-facing string on the preview surface.
        for language in ContentLanguage.allCases {
            #expect(!quest.title.value(for: language).isEmpty)
            #expect(!quest.description.value(for: language).isEmpty)
            #expect(!quest.terrainSummary.value(for: language).isEmpty)
            #expect(!quest.safetyNotes.value(for: language).isEmpty)
        }
    }

    @Test func hasNoNetworkOrLocationCollaboratorToInject() throws {
        // A repository that could be handed a URLSession or a CLLocationManager is a repository
        // that could one day wait on one. `init()` taking nothing is the assertion.
        _ = try BundledContentRepository()
    }

    @Test func exposesTheContentBundleVersionAQuestRunWouldPin() throws {
        // AD-4: a Run pins this at start. Any content change bumps it, per `manifest.json`'s own
        // rule — `s5` shipped the `badung-jejak` collection at `2026.09.1`, `2026.09.2` added
        // Puri Agung Pemecutan's site plan and the third source that cites it (`452:3028`),
        // `2026.09.3` the sixth place and its sidequest, and `2026.09.4` replaced the region map
        // with the wide illustrated island of `275:2309` and re-authored every `mapPoint` onto it.
        // `2026.09.6` added Puri Agung Pemecutan's approach map — the street drawing on `1:4458` —
        // and the fourth source that cites it, and `2026.09.7` read that drawing's own marker for
        // the Place off the illustration, so `187:1103` has a point to beat its dot over.
        // `2026.09.8` re-authored the five `mapPoint`s that were never placed against `275:2309` at
        // all — leftovers from the portrait drawing, 34 to 40 km out, invisible for as long as no
        // quest reached those Places. `IllustratedMapGeoreferenceTests` now guards the whole set.
        // `2026.09.9` added the region map's `gdal2tiles` pyramid — no change to the drawing, but
        // `manifest.regionMap` gained a `tiles` directory and the bundle gained 44 tiles.
        // `2026.09.10` rebuilt that pyramid from a 4× super-resolution pass over the same drawing
        // (543 WebP tiles, six levels, 5 MB), which is more pixels rather than a different picture:
        // `regionMap.asset`, `aspectRatio` and every `mapPoint` are untouched, because a pure scale
        // cannot move anything on the paper.
        // `2026.09.11` replaced the drawing itself — a new 1536 × 1024 chart of Bali and Nusa
        // Penida — so `aspectRatio` went 1.3716 → 1.5, every `mapPoint` was re-authored against the
        // new coastline, and `IllustratedMapGeoreference`'s two rates were re-measured off it.
        // `2026.09.12` shipped the four Story Reveal drawings (`964:3212` and its siblings) as
        // `Place.storyArtwork`, with a citation each, and `2026.09.13` gave Pura Maospahit a
        // `siteMap` — the second Place to carry one, and the reason the foot of its task sheet now
        // draws the map hint at all.
        let repository = try repository()
        #expect(try repository.contentBundleVersion() == "2026.09.13")
    }

    // MARK: - PRD §5.15 — the sidequest seam, five places deep (`s5`, Phase E's 5-place scope)

    @Test func theBundleShipsFiveSidequestsFillingOneCollection() throws {
        // `s5` shipped on the five already-consented places only — `docs/consent-log.md` still
        // names none of them approached, so this stays a D1-b self-grant, not a public claim.
        let repository = try repository()
        #expect(try repository.manifest().schemaVersion == 2)

        let sideQuests = try repository.sideQuests()
        #expect(sideQuests.count == 5)
        #expect(try repository.sideQuest(id: "sq-badung-catur-muka") != nil)
        #expect(try repository.sideQuests(atPlaceID: "badung-catur-muka").map(\.id)
                == ["sq-badung-catur-muka"])

        // Every sidequest resolves to a Place, with lore and sources reachable — the same shape
        // `assemblesTheWholeQuestGraphFromTheBundleAlone` asserts for checkpoints.
        for sideQuest in sideQuests {
            let place = try #require(try repository.place(id: sideQuest.placeId),
                                     "Sidequest \(sideQuest.id) has no Place")
            #expect(!place.sources.isEmpty)
            #expect(!sideQuest.lore.isEmpty)
            for block in sideQuest.lore {
                #expect(!block.sourceRefs.isEmpty)
                for ref in block.sourceRefs {
                    #expect(ref < place.sources.count)
                }
            }
        }

        let collections = try repository.collections()
        #expect(collections.count == 1)
        let collection = try #require(collections.first)
        #expect(collection.phrase == "JEJAK")
        // `V25` — one slot per letter, in order.
        #expect(collection.orderedSlots.map(\.letter) == ["J", "E", "J", "A", "K"])
        // Every slot names a real sidequest, and every sidequest fills exactly one slot (`V24`).
        let slotSideQuestIDs = collection.orderedSlots.map(\.sideQuestId)
        #expect(Set(slotSideQuestIDs) == Set(sideQuests.map(\.id)))
        #expect(Set(slotSideQuestIDs).count == slotSideQuestIDs.count)
    }

    @Test func suppressingAPlaceRemovesOnlyItsOwnSidequest() throws {
        // `AD-5`/`FR-SIDE-14`: the suppressed sets are passed in, never fetched here. Suppressing
        // one place's sidequest must not touch the other four, and an id that resolves to nothing
        // is a harmless no-op rather than a crash.
        let repository = try repository()
        let suppressed = try repository.sideQuests(
            suppressingSideQuestIDs: ["sq-does-not-exist"],
            suppressingPlaceIDs: ["badung-catur-muka"])
        #expect(suppressed.map(\.id).sorted() == [
            "sq-badung-museum-bali", "sq-badung-pasar-badung",
            "sq-badung-pura-maospahit", "sq-badung-puri-agung-pemecutan",
        ])
    }

    @Test func questsAreReturnedInManifestOrder() throws {
        let repository = try repository()
        let manifest = try repository.manifest()
        #expect(try repository.quests().map(\.id) == manifest.quests)
    }

    // MARK: - FR-DISC-08, list side

    @Test func suppressedQuestsAreOmittedFromTheList() throws {
        let repository = try repository()
        let all = try repository.quests()
        let victim = try #require(all.first).id

        let remaining = try repository.quests(suppressingQuestIDs: [victim], suppressingPlaceIDs: [])
        #expect(!remaining.contains { $0.id == victim })
        #expect(remaining.count == all.count - 1)
        // TODO(content): the bundle ships one quest, so suppressing it leaves an empty list and the
        // "some quests remain" branch of FR-DISC-08 is no longer exercised by shipped content. It
        // regains coverage when a second region is authored; until then this only proves the
        // suppressed quest leaves.
        #expect(remaining.isEmpty)
    }

    @Test func aQuestIsSuppressedWhenAnyOfItsPlacesIsSuppressed() throws {
        // A quest whose third checkpoint has been withdrawn is not a shorter quest; it is a
        // quest that cannot be walked. It leaves the list whole.
        let repository = try repository()
        let quest = try #require(try repository.quests().first)
        let middlePlace = quest.orderedCheckpoints[2].placeId

        let remaining = try repository.quests(suppressingQuestIDs: [], suppressingPlaceIDs: [middlePlace])
        #expect(!remaining.contains { $0.id == quest.id })
    }

    @Test func anEmptySuppressionSetChangesNothing() throws {
        let repository = try repository()
        #expect(try repository.quests(suppressingQuestIDs: [], suppressingPlaceIDs: []).map(\.id)
                == (try repository.quests().map(\.id)))
    }

    // MARK: - schema.md A.1 — consent records must not ship

    @Test func consentRecordsAreNotPresentInTheShippedBundle() throws {
        // Named individuals, their roles and signed-document references have no runtime purpose.
        // If this ever passes silently it is because the resource was added back.
        let resourceRoot = try #require(Bundle.module.resourceURL)
        let consentDirectory = resourceRoot.appendingPathComponent("consent")
        #expect(!FileManager.default.fileExists(atPath: consentDirectory.path),
                "consent/ is a build input and must not be shipped (schema.md §A.1)")

        let repository = try repository()
        #expect(try repository.bundle().consentRecords.isEmpty)
    }

    // MARK: - The fixture is valid content

    @Test func theBundledFixturePassesEveryValidatorRule() throws {
        let repository = try repository()
        let findings = ContentValidator.validate(
            try repository.bundle(),
            assets: try repository.assetInventory(),
            today: CalendarDay.today())
        // Consent lives outside the shipped bundle, so V4/V5 cannot be judged from here; they
        // are covered by the CLI run over the authored directory.
        let runtimeFindings = findings.filter { $0.rule != .v4 && $0.rule != .v5 }
        #expect(runtimeFindings.isEmpty, "Bundled fixture is invalid: \(runtimeFindings)")
    }

    @Test func theRoutePreviewImageIsPresentInTheBundle() throws {
        // FR-MAP-01 / FR-OFF-03: preview renders from a shipped image, never from live tiles.
        let repository = try repository()
        let quest = try #require(try repository.quests().first)
        let url = try #require(try repository.assetURL(quest.route.previewImageAsset))
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: url).count > 0)
    }

    @Test func theRouteGeometryIsPresentInTheBundle() throws {
        let repository = try repository()
        let quest = try #require(try repository.quests().first)
        let url = try #require(try repository.assetURL(quest.route.geometryAsset))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Fixture shape the UI depends on

    @Test func theCostBreakdownAgreesWithTheTotalItIsBrokenDownFrom() throws {
        // FR-DISC-05: whatever the total says, the breakdown must add up to it — a card showing
        // Rp 50.000 over a breakdown of Rp 35.000 is worse than no breakdown.
        //
        // TODO(content): no priced quest ships. Museum Bali sells an entry ticket, but its price
        // has not been verified and inventing one would put a fabricated number on the card
        // (`c1-badung-single-quest-content.plan.md` §11). Until that fee is confirmed, the paid
        // card state is unexercised by shipped content and the assertion below is the free case.
        let quest = try #require(try repository().quests().first)
        #expect(quest.estimatedCost.breakdown.reduce(0) { $0 + $1.amount } == quest.estimatedCost.amount)
        if quest.estimatedCost.amount > 0 {
            #expect(!quest.estimatedCost.breakdown.isEmpty)
        }
    }

    @Test func everyQuestHasAHeroImagePresentInTheBundle() throws {
        // The discovery card is built around it; a missing hero means a card that silently falls
        // back to type on paper (validator rule V14 catches the authoring side).
        let repository = try repository()
        for quest in try repository.quests() {
            let asset = try #require(quest.heroImageAsset, "\(quest.id) has no hero image")
            #expect(try repository.assetURL(asset) != nil, "\(asset) is missing from the bundle")
        }
    }

    /// **Two Places ship a plan now, and which two is what the walk can see.**
    /// `TaskDetailScreen` draws the map hint at the foot of the sheet only where the Place carries a
    /// `siteMap` — a hint that opens an empty screen is worse on a walk than no hint — so a Place
    /// losing its plan silently removes a control the walker was offered. Content guard, reading the
    /// shipped bundle deliberately: this is a fact about the content, not a requirement, and it
    /// belongs with the family that catches an authoring mistake rather than with the fixture-backed
    /// requirement guards.
    @Test func thePlacesThatShipAPlanAreThePlacesWhoseSheetOffersOne() throws {
        let repository = try repository()
        // Walked in route order, which is the order the hint appears or does not appear in.
        var withPlans: [String] = []
        for quest in try repository.quests() {
            for checkpoint in quest.checkpoints {
                let place = try #require(try repository.place(id: checkpoint.placeId))
                guard let plan = place.siteMap else { continue }
                withPlans.append(place.id)
                #expect(try repository.assetURL(plan.asset) != nil,
                        "\(plan.asset) is missing from the bundle")
                // V3's runtime half: the plan's citation is what `PlaceSiteMapScreen` prints under
                // it, and an unresolvable `sourceRef` is a drawing making claims with nothing
                // behind them (`FR-CP-05`).
                #expect(plan.sourceRef >= 0 && plan.sourceRef < place.sources.count)
            }
        }
        #expect(withPlans == ["badung-puri-agung-pemecutan", "badung-pura-maospahit"])
    }

    @Test func theRegionMapAndEveryPinAreInTheBundle() throws {
        // FR-MAP-01 / FR-OFF-03: the map screen draws a shipped illustration, so it works with no
        // network and no tile cache.
        let repository = try repository()
        let regionMap = try #require(try repository.manifest().regionMap)
        #expect(try repository.assetURL(regionMap.asset) != nil)

        // The pyramid ships too, and every tile it claims is on disk. A half-written pyramid is
        // the one failure mode that would not show up as a crash or a missing file at launch — the
        // map would simply draw holes where a level ran out, at whichever zoom the reader happened
        // to reach. `scripts/build-map-tiles.sh` writes the whole thing or nothing; this is what
        // notices when a partial one is committed.
        let tilesPath = try #require(regionMap.tiles)
        let root = try #require(try repository.assetURL(tilesPath))
        let manifest = try #require(
            try? Data(contentsOf: root.appendingPathComponent("tiles.json")))
        let pyramid = try JSONDecoder().decode(RasterTilePyramidManifest.self, from: manifest)

        #expect(pyramid.tileSize == 256)
        #expect(pyramid.maxZoom > pyramid.minZoom)

        // The drawing the pyramid was built from must still be the drawing the manifest declares,
        // to the pixel and up to a whole-number scale. A pyramid cut from a *different* picture
        // would draw a coastline every authored `mapPoint` was placed against by eye, and nothing
        // else in the suite would notice.
        #expect(pyramid.sourceWidthPx % 1536 == 0)
        #expect(pyramid.sourceHeightPx % 1024 == 0)
        #expect(pyramid.sourceWidthPx / 1536 == pyramid.sourceHeightPx / 1024)

        for z in pyramid.minZoom...pyramid.maxZoom {
            let scale = pow(2.0, Double(z - pyramid.maxZoom))
            let columns = Int(ceil(Double(pyramid.sourceWidthPx) * scale / 256))
            let rows = Int(ceil(Double(pyramid.sourceHeightPx) * scale / 256))
            for x in 0..<max(columns, 1) {
                for y in 0..<max(rows, 1) {
                    let tile = "\(tilesPath)/\(z)/\(x)/\(y).\(pyramid.tileFormat)"
                    #expect(try repository.assetURL(tile) != nil, "missing tile \(tile)")
                }
            }
        }
    }

    /// A local mirror of `RunEngine.RasterTilePyramid`'s manifest shape. `ContentKitTests` must not
    /// import `RunEngine` — `ContentKit` is the bottom of the stack and a test that reached upward
    /// would make the layering unenforceable — and what is being checked here is the *file*, not
    /// the type that reads it.
    private struct RasterTilePyramidManifest: Decodable {
        let tileSize: Int
        let tileFormat: String
        let sourceWidthPx: Int
        let sourceHeightPx: Int
        let minZoom: Int
        let maxZoom: Int
    }

    @Test func theRegionMapPinsAreInsideTheDrawing() throws {
        let repository = try repository()

        for quest in try repository.quests() {
            for checkpoint in quest.orderedCheckpoints {
                let place = try #require(try repository.place(id: checkpoint.placeId))
                let point = try #require(place.mapPoint, "\(place.id) has no map pin")
                #expect(point.isInsideImage)
            }
        }
    }

    @Test func everyQuestDeclaresACostEvenWhenItIsZero() throws {
        // TODO(content): the bundle ships one free quest, so only the free card state renders.
        // The paid state returns when Museum Bali's verified ticket price lands in
        // `estimatedCost.breakdown`, or when a second, priced quest is authored.
        let quests = try repository().quests()
        #expect(!quests.isEmpty)
        #expect(quests.allSatisfy { $0.estimatedCost.amount >= 0 })
        #expect(quests.contains { $0.estimatedCost.isFree })
    }

    @Test func everyLoreBlockCarriesAnAccuracyLabel() throws {
        // FR-CP-05 / NFR-A11Y-05: every claim ships with its epistemic status attached.
        //
        // TODO(content): the shipped quest carries only `documented` blocks. `oral` requires an
        // interview — a named person, with the consent trail D2 demands — and none has been
        // conducted, so a broken `oral` label would currently ship unnoticed by this suite. The
        // rendering of both labels is covered in DesignSystem, not here.
        let quest = try #require(try repository().quests().first)
        let labels = Set(quest.orderedCheckpoints.flatMap { $0.loreSegment.map(\.accuracy) })
        #expect(!labels.isEmpty)
        #expect(labels.isSubset(of: Set(AccuracyLabel.allCases)))
    }

    @Test func everyVisitedPlaceDisclosesItsPhotoPolicyInBothLanguages() throws {
        // The preview's photo-policy disclosure must have something to disclose at every stop.
        //
        // TODO(content): no `prohibited` Place ships. None of the five sites' photography rules
        // has been confirmed with its management, and all four unconfirmed ones are authored as
        // `restricted` rather than guessed as `prohibited`. FR-TASK-06's prohibited branch is
        // therefore exercised only by ContentValidatorTests, not by shipped content.
        let repository = try repository()
        let quest = try #require(try repository.quests().first)
        for checkpoint in quest.orderedCheckpoints {
            let place = try #require(try repository.place(id: checkpoint.placeId))
            for language in ContentLanguage.allCases {
                #expect(!place.photoPolicy.notes.value(for: language).isEmpty,
                        "\(place.id) states no photo policy in \(language.rawValue)")
            }
        }
    }

    @Test func noPhotoTaskIsOfferedWherePhotographyIsProhibited() throws {
        let repository = try repository()
        let quest = try #require(try repository.quests().first)
        for checkpoint in quest.orderedCheckpoints {
            let place = try #require(try repository.place(id: checkpoint.placeId))
            guard place.photoPolicy.level == .prohibited else { continue }
            #expect(!checkpoint.tasks.contains { $0.type == .photo })
        }
    }

    // MARK: - Failure reporting

    @Test func aMissingQuestIsReportedRatherThanCrashing() throws {
        #expect(try repository().quest(id: "no-such-quest") == nil)
    }

    @Test func aMissingPlaceIsReportedRatherThanCrashing() throws {
        #expect(try repository().place(id: "no-such-place") == nil)
    }
}
