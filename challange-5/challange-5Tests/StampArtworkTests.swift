import DesignSystem
import Foundation
import RunEngine
import Testing
@testable import challange_5

/// The rule the reader is told: a place's stamp shows a richer drawing for each of *that place's*
/// quests they resolve, up to the third.
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

    /// stamp id → where it came from, in the shape the resolver gets it from a quest's checkpoints.
    private static var route: [String: [String: StampArtworkResolver.StampSource]] {
        var stamps: [String: StampArtworkResolver.StampSource] = [:]
        for (index, placeID) in places.enumerated() {
            stamps["stamp-\(index)"] = StampArtworkResolver.StampSource(
                placeID: placeID, checkpointID: "cp-\(index)")
        }
        return [questID: stamps]
    }

    private static func slug(_ index: Int) -> String {
        StampArtworkResolver.slugsByPlaceID[places[index]]!
    }

    private static let resolver = StampArtworkResolver(sourcesByStamp: route)

    private static func artwork(_ run: Run, _ stampIndex: Int) -> String? {
        resolver.artworkName(run: run, stampSourceID: "stamp-\(stampIndex)")
    }

    /// A task the walker answered, or skipped.
    private static func task(_ id: String, skipped: Bool) -> TaskResult {
        TaskResult(
            taskID: id, type: .reflection, promptSnapshot: "prompt",
            skipped: skipped, text: skipped ? nil : "an answer",
            completedAt: Date(timeIntervalSince1970: 0))
    }

    /// A walk that reached `answered.count` places, answering that many tasks at each — index 0
    /// first, in route order.
    private static func run(
        answeredPerCheckpoint: [Int], skippedPerCheckpoint: [Int] = [],
        state: RunState = .active
    ) -> Run {
        let started = Date(timeIntervalSince1970: 86_400)
        let results = answeredPerCheckpoint.enumerated().map { index, answered in
            let skipped = skippedPerCheckpoint.indices.contains(index)
                ? skippedPerCheckpoint[index] : 0
            return CheckpointResult(
                checkpointID: "cp-\(index)",
                orderIndex: index,
                arrivedAt: started,
                arrivalMethod: .gps,
                gpsAccuracyM: 8,
                snapshotPlaceName: places[index],
                snapshotLore: [],
                snapshotClueToNext: nil,
                snapshotContentVersion: "test",
                taskResults: (0..<answered).map { task("answered-\(index)-\($0)", skipped: false) }
                    + (0..<skipped).map { task("skipped-\(index)-\($0)", skipped: true) })
        }
        return Run(
            questID: questID,
            contentVersion: "test",
            language: .en,
            snapshotQuestTitle: "A walk",
            checkpointCount: places.count,
            state: state,
            currentCheckpointIndex: max(answeredPerCheckpoint.count - 1, 0),
            startedAt: started,
            updatedAt: started,
            completedAt: state == .completed ? started : nil,
            checkpointResults: results,
            awards: results.map { result in
                Award(type: .stamp, sourceID: "stamp-\(result.orderIndex)",
                      snapshotName: result.snapshotPlaceName, awardedAt: started)
            })
    }

    /// The rule as it was asked for: one quest resolved at a place shows its first drawing, two the
    /// second, three or more the third.
    @Test func eachResolvedQuestMovesThePlaceUpItsOwnSet() {
        let run = Self.run(answeredPerCheckpoint: [1, 2, 3, 4])
        #expect(Self.artwork(run, 0) == "\(Self.slug(0))-stamp1")
        #expect(Self.artwork(run, 1) == "\(Self.slug(1))-stamp2")
        #expect(Self.artwork(run, 2) == "\(Self.slug(2))-stamp3")
        #expect(Self.artwork(run, 3) == "\(Self.slug(3))-stamp3")
    }

    /// The walker's own example: two quests resolved at the first place, then on to the next place
    /// with the first one's tasks left unresolved, where one quest is resolved. The two stamps do
    /// not move together (`AD-2` — walking on is normal, not a forfeit).
    @Test func aPlaceLeftUnfinishedKeepsWhatItEarnedAndTheNextStartsAgain() {
        let run = Self.run(answeredPerCheckpoint: [2, 1])
        #expect(Self.artwork(run, 0) == "\(Self.slug(0))-stamp2")
        #expect(Self.artwork(run, 1) == "\(Self.slug(1))-stamp1")
    }

    /// **A skip does not count**, as of 2026-08-26. The drawing is what doing a quest buys, so two
    /// skipped and one answered at a place is *one* answered, which is the first drawing — and a
    /// place where everything was skipped stays on the first drawing too.
    ///
    /// This inverts what this test asserted earlier the same day. `AD-2` is untouched: no answer
    /// key is needed to tell a skip from an answer, because `TaskResult.skipped` is the walker's
    /// own choice rather than a judgement of their words. The checkpoint's task row was inverted
    /// with it — a skipped task now draws no checkmark and fills no segment, so the picture and the
    /// list still say the same thing about the same place.
    @Test func aSkipDoesNotCountTowardsTheTier() {
        let run = Self.run(answeredPerCheckpoint: [1, 0], skippedPerCheckpoint: [2, 1])
        #expect(Self.artwork(run, 0) == "\(Self.slug(0))-stamp1")
        #expect(Self.artwork(run, 1) == "\(Self.slug(1))-stamp1")
    }

    /// The stamp is franked on arrival (`FR-CP-07`), before any task is resolved — so a place just
    /// reached shows a drawing rather than an empty window.
    @Test func aPlaceJustArrivedAtStillHasAPicture() {
        let run = Self.run(answeredPerCheckpoint: [0])
        #expect(Self.artwork(run, 0) == "\(Self.slug(0))-stamp1")
    }

    /// A finished walk keeps showing what it earned. The tier is the Run's own record, so a later
    /// walk through the same place cannot re-grade a stamp already in the Journal.
    @Test func aFinishedWalksStampsKeepTheirOwnTiers() {
        let first = Self.run(answeredPerCheckpoint: [1], state: .completed)
        let second = Self.run(answeredPerCheckpoint: [3], state: .completed)
        #expect(Self.artwork(first, 0) == "\(Self.slug(0))-stamp1")
        #expect(Self.artwork(second, 0) == "\(Self.slug(0))-stamp3")
    }

    /// Content withdrawn under a finished walk costs the picture and nothing else — the stamp still
    /// carries the name and region the Run recorded (`FR-DONE-05`, `FR-RUN-06`).
    @Test func aStampWithNoResolvablePlaceHasNoDrawing() {
        let run = Self.run(answeredPerCheckpoint: [1])
        #expect(Self.resolver.artworkName(run: run, stampSourceID: "stamp-unknown") == nil)
        #expect(StampArtworkResolver(sourcesByStamp: [:])
            .artworkName(run: run, stampSourceID: "stamp-0") == nil)
    }

    /// `progressStampArtworkName`'s rule, at the resolver: the preview is always one tier ahead of
    /// the record, so it teases what one more *answered* quest gets rather than what has already
    /// happened.
    @Test func thePreviewIsOneTierAheadOfWhatWasActuallyEarned() {
        let run = Self.run(answeredPerCheckpoint: [0, 1, 2])
        #expect(Self.resolver.previewArtworkName(run: run, stampSourceID: "stamp-0")
                == "\(Self.slug(0))-stamp1")
        #expect(Self.resolver.previewArtworkName(run: run, stampSourceID: "stamp-1")
                == "\(Self.slug(1))-stamp2")
        #expect(Self.resolver.previewArtworkName(run: run, stampSourceID: "stamp-2")
                == "\(Self.slug(2))-stamp3")
    }

    /// Past the third drawing there is nothing further to tease, so the preview stops climbing
    /// exactly where the record does.
    @Test func thePreviewStopsAtTheThirdJustAsTheRecordDoes() {
        let run = Self.run(answeredPerCheckpoint: [3])
        #expect(Self.artwork(run, 0) == "\(Self.slug(0))-stamp3")
        #expect(Self.resolver.previewArtworkName(run: run, stampSourceID: "stamp-0")
                == "\(Self.slug(0))-stamp3")
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
