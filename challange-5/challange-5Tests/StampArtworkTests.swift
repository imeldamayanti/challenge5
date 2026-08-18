import DesignSystem
import Foundation
import RunEngine
import Testing
@testable import challange_5

/// The rule the reader is told: a place's stamp shows a richer drawing each time they *finish* a
/// quest through it, up to the third.
///
/// The counting is what these guard. `HisploraStampArtworkTests` in the package guards the clamp
/// and the file names; nothing there knows what a Run is, and nothing here re-tests the clamp.
///
/// Built from a hand-written stamp → place table rather than from the shipped content, for the
/// reason `ContentFixtures.swift` opens with: a guard that reads authored JSON changes meaning
/// every time an author edits it. The *place ids* are taken from the catalog under test, so
/// renaming a row there cannot leave these silently asserting nothing.
struct StampArtworkTests {

    private static let places = Array(StampArtworkResolver.slugsByPlaceID.keys).sorted()
    private static let questID = "test-quest"

    /// stamp id → place id, in the shape the resolver gets it from a quest's checkpoints.
    private static var route: [String: [String: String]] {
        var stamps: [String: String] = [:]
        for (index, placeID) in places.enumerated() { stamps["stamp-\(index)"] = placeID }
        return [questID: stamps]
    }

    private static func slug(_ index: Int) -> String {
        StampArtworkResolver.slugsByPlaceID[places[index]]!
    }

    /// A walk that franked stamps at the first `stampCount` places on the route.
    private static func run(stampCount: Int, state: RunState, day: Int) -> Run {
        let started = Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
        return Run(
            questID: questID,
            contentVersion: "test",
            language: .en,
            snapshotQuestTitle: "A walk",
            checkpointCount: places.count,
            state: state,
            currentCheckpointIndex: max(stampCount - 1, 0),
            startedAt: started,
            updatedAt: started,
            completedAt: state == .completed ? started : nil,
            awards: (0..<stampCount).map { index in
                Award(type: .stamp, sourceID: "stamp-\(index)",
                      snapshotName: places[index], awardedAt: started)
            })
    }

    private static func resolver(_ runs: [Run]) -> StampArtworkResolver {
        StampArtworkResolver(runs: runs, placesByStamp: route)
    }

    @Test func oneFinishedWalkShowsTheFirstDrawingEverywhereItPassed() {
        let resolver = Self.resolver([Self.run(stampCount: 3, state: .completed, day: 1)])
        for index in 0..<3 {
            #expect(resolver.artworkName(questID: Self.questID, stampSourceID: "stamp-\(index)")
                    == "\(Self.slug(index))-stamp1")
        }
    }

    /// The point of the whole feature: a place walked twice moves up, and its neighbours on the
    /// same route do not move with it.
    @Test func eachPlaceClimbsOnItsOwnCount() {
        let resolver = Self.resolver([
            Self.run(stampCount: 3, state: .completed, day: 1),
            Self.run(stampCount: 2, state: .completed, day: 2),
            Self.run(stampCount: 1, state: .completed, day: 3),
        ])
        #expect(resolver.artworkName(questID: Self.questID, stampSourceID: "stamp-0")
                == "\(Self.slug(0))-stamp3")
        #expect(resolver.artworkName(questID: Self.questID, stampSourceID: "stamp-1")
                == "\(Self.slug(1))-stamp2")
        #expect(resolver.artworkName(questID: Self.questID, stampSourceID: "stamp-2")
                == "\(Self.slug(2))-stamp1")
    }

    /// A fourth walk earns nothing new, because there is no fourth drawing.
    @Test func afterThreeItStaysOnTheThird() {
        let resolver = Self.resolver((1...5).map {
            Self.run(stampCount: 1, state: .completed, day: $0)
        })
        #expect(resolver.artworkName(questID: Self.questID, stampSourceID: "stamp-0")
                == "\(Self.slug(0))-stamp3")
    }

    /// Only *finished* walks count. A walk in progress has earned its stamps and shows the first
    /// drawing for them, but it has not moved the reader up the set — the drawing changes when a
    /// quest is finished, which is what they were told.
    @Test func onlyAFinishedWalkCounts() {
        let resolver = Self.resolver([
            Self.run(stampCount: 2, state: .completed, day: 1),
            Self.run(stampCount: 2, state: .active, day: 2),
            Self.run(stampCount: 2, state: .abandoned, day: 3),
        ])
        #expect(resolver.artworkName(questID: Self.questID, stampSourceID: "stamp-0")
                == "\(Self.slug(0))-stamp1")
    }

    /// A place that has never been finished still shows a drawing for the stamp it has already
    /// franked — the floor is the first drawing, not an empty window.
    @Test func aStampEarnedOnAnUnfinishedWalkStillHasAPicture() {
        let resolver = Self.resolver([Self.run(stampCount: 2, state: .active, day: 1)])
        #expect(resolver.artworkName(questID: Self.questID, stampSourceID: "stamp-1")
                == "\(Self.slug(1))-stamp1")
    }

    /// Content withdrawn under a finished walk costs the picture and nothing else — the stamp still
    /// carries the name and region the Run recorded (`FR-DONE-05`, `FR-RUN-06`).
    @Test func aStampWithNoResolvablePlaceHasNoDrawing() {
        let resolver = Self.resolver([Self.run(stampCount: 1, state: .completed, day: 1)])
        #expect(resolver.artworkName(questID: Self.questID, stampSourceID: "stamp-unknown") == nil)
        #expect(resolver.artworkName(questID: "another-quest", stampSourceID: "stamp-0") == nil)
    }

    /// Every place the design drew is reachable by id, and every id maps to a stem the package
    /// actually ships. Without this, renaming a place in content silently empties its window.
    @Test func theCatalogCoversTheDesignsFivePlaces() {
        #expect(StampArtworkResolver.slugsByPlaceID.count == 5)
        #expect(Set(StampArtworkResolver.slugsByPlaceID.values).count == 5)
        // And every stem the app names is one the package actually draws.
        #expect(Set(StampArtworkResolver.slugsByPlaceID.values)
                .isSubset(of: Set(HisploraStampArtwork.slugs)))
    }
}
