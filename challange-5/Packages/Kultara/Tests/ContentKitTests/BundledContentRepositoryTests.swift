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
        // AD-4: a Run pins this at start. Nothing in M5 starts a Run, but the value a Run would
        // pin must already be readable, or the pin has nothing to attach to.
        let repository = try repository()
        #expect(try repository.contentBundleVersion() == "2026.08.1")
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

    @Test func theFixtureCostsMoneySoTheCostPathIsExercised() throws {
        // FR-DISC-05 needs a quest that actually costs something, or the card's cost line is
        // never rendered by any test or any screenshot.
        let quest = try #require(try repository().quests().first)
        #expect(quest.estimatedCost.amount > 0)
        #expect(!quest.estimatedCost.breakdown.isEmpty)
        #expect(quest.estimatedCost.breakdown.reduce(0) { $0 + $1.amount } == quest.estimatedCost.amount)
    }

    @Test func theFixtureCarriesBothAccuracyLabelsSoTheLabelConventionIsExercised() throws {
        // FR-CP-05 / NFR-A11Y-05: both labels must be distinguishable. Content that only ever
        // says "documented" would let a broken oral label ship unnoticed.
        let quest = try #require(try repository().quests().first)
        let labels = Set(quest.orderedCheckpoints.flatMap { $0.loreSegment.map(\.accuracy) })
        #expect(labels == Set(AccuracyLabel.allCases))
    }

    @Test func theFixtureIncludesAPlaceWherePhotographyIsProhibited() throws {
        // So FR-TASK-06 and the preview's photo-policy disclosure have something to disclose.
        let repository = try repository()
        let quest = try #require(try repository.quests().first)
        let policies = try quest.orderedCheckpoints.map { try #require(try repository.place(id: $0.placeId)).photoPolicy.level }
        #expect(policies.contains(.prohibited))
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
