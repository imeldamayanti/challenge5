import ContentKit
import Foundation
import RunEngine
import Testing
@testable import challange_5

/// The Quests tab on the Explorer's Card (`705:2824`).
///
/// **What these hold is the split, not the styling.** The frame lists finished walks; the tab
/// shipped listing unfinished ones, because Profile is the only route back into a walk in progress.
/// Both are now in one list behind a three-way filter, and the two facts that must not rot are that
/// `all` puts the unfinished ones first and that only an unfinished row carries something to
/// resume — a finished walk has nowhere to go from here, and a row that looks tappable and is not
/// is worse than a row that does not.
struct ExplorerCardQuestFilterTests {

    private static func unfinished(_ title: String) -> QuestRowPresentation {
        let id = UUID()
        return QuestRowPresentation(
            id: id, title: title, detail: "2 of 5 checkpoints", isComplete: false, resumeRunID: id)
    }

    private static func done(_ title: String, region: String? = "Badung") -> QuestRowPresentation {
        QuestRowPresentation(
            id: UUID(),
            title: title,
            detail: region == nil ? "Completed" : "You completed this quest at",
            detailEmphasis: region,
            isComplete: true)
    }

    @Test func allKeepsBothKindsAndUnfinishedIsFirst() {
        let rows = [Self.unfinished("Open"), Self.done("Closed")]
        let visible = rows.filter(ExplorerCardPresentation.QuestFilter.all.includes)
        #expect(visible.map(\.title) == ["Open", "Closed"])
    }

    @Test func eachFilterShowsOnlyItsOwnKind() {
        let rows = [Self.unfinished("Open"), Self.done("Closed")]
        #expect(rows.filter(ExplorerCardPresentation.QuestFilter.unfinished.includes)
                    .map(\.title) == ["Open"])
        #expect(rows.filter(ExplorerCardPresentation.QuestFilter.done.includes)
                    .map(\.title) == ["Closed"])
    }

    /// The resume is the tab's reason for existing, and it belongs to exactly one kind of row.
    @Test func onlyAnUnfinishedWalkCarriesSomethingToResume() {
        #expect(Self.unfinished("Open").resumeRunID != nil)
        #expect(Self.done("Closed").resumeRunID == nil)
    }

    /// A withdrawn quest has no region to name, and the row must not print "completed at" with
    /// nothing after it — the Run snapshots its title but never its region.
    @Test func aFinishedWalkWithNoRegionSaysCompletedRatherThanCompletedAtNothing() {
        let row = Self.done("Closed", region: nil)
        #expect(row.detailEmphasis == nil)
        #expect(!row.detail.hasSuffix("at"))
    }

    /// Three chips, in the order the reader reads them.
    @Test func theFilterOffersEverythingUnfinishedAndDone() {
        #expect(ExplorerCardPresentation.QuestFilter.allCases.map(\.rawValue)
                == ["all", "unfinished", "done"])
    }
}

/// What the Explorer's Card counts as the reader's record: the Stamps and Badges tabs.
///
/// These read a hand-built store rather than the shipped bundle, the way `StampArtworkTests` does —
/// what is asserted is which walks contribute, not what any quest happens to contain.
@MainActor
struct ExplorerCardRecordTests {

    private static let questID = "test-quest"

    /// A walk that reached `checkpoints` places, in the given state, carrying a stamp per arrival
    /// and — when it finished — the badge `FR-DONE-01` awards with the last one.
    private static func run(
        state: RunState, checkpoints: Int = 2, badgeID: String = "badge-test-quest"
    ) -> Run {
        let at = Date(timeIntervalSince1970: 86_400)
        let results = (0..<checkpoints).map { index in
            CheckpointResult(
                checkpointID: "cp-\(index)",
                orderIndex: index,
                arrivedAt: at,
                arrivalMethod: .gps,
                gpsAccuracyM: 8,
                snapshotPlaceName: "Place \(index)",
                snapshotLore: [],
                snapshotClueToNext: nil,
                snapshotContentVersion: "test",
                taskResults: [])
        }
        var awards = results.map { result in
            Award(type: .stamp, sourceID: "stamp-\(result.orderIndex)",
                  snapshotName: result.snapshotPlaceName, awardedAt: at)
        }
        if state == .completed {
            awards.append(Award(type: .badge, sourceID: badgeID,
                                snapshotName: "A walk", awardedAt: at))
        }
        return Run(
            questID: questID,
            contentVersion: "test",
            language: .en,
            snapshotQuestTitle: "A walk",
            checkpointCount: checkpoints,
            state: state,
            currentCheckpointIndex: checkpoints - 1,
            startedAt: at,
            updatedAt: at,
            completedAt: state == .completed ? at : nil,
            checkpointResults: results,
            awards: awards)
    }

    private static func card(_ runs: [Run]) -> ExplorerCardViewModel {
        ExplorerCardViewModel(
            runStore: InMemoryRunStore(runs),
            sideQuestStore: InMemorySideQuestStore(),
            repository: FixtureContentRepository(),
            preferences: InMemoryAppPreferencesStore(),
            language: .en)
    }

    /// The reported defect: stamps for quests nobody had finished stood on the card. `FR-CP-07`
    /// awards a stamp on arrival, so a walk still under way genuinely holds some — they belong to
    /// the Quests tab, where the walk can be resumed, and land here when it closes.
    @Test func anUnfinishedWalkPutsNoStampsOnTheCard() {
        let model = Self.card([Self.run(state: .active)])
        #expect(model.presentation.stamps.isEmpty)
        #expect(model.presentation.stampCount == 0)
    }

    /// A walk explicitly put down (`FR-RUN-05`) is not a record of anything either.
    @Test func anAbandonedWalkPutsNoStampsOnTheCard() {
        let model = Self.card([Self.run(state: .abandoned)])
        #expect(model.presentation.stamps.isEmpty)
    }

    @Test func aFinishedWalkPutsOneStampPerCheckpointItReached() {
        let model = Self.card([Self.run(state: .completed, checkpoints: 3)])
        #expect(model.presentation.stamps.count == 3)
        #expect(model.presentation.stampCount == 3)
    }

    /// The unfinished walk is still listed — it is only its stamps that wait.
    @Test func anUnfinishedWalkIsStillOnTheQuestsTab() {
        let model = Self.card([Self.run(state: .active)])
        #expect(model.presentation.quests.count == 1)
        #expect(model.presentation.quests.first?.resumeRunID != nil)
    }

    /// Both Badung walks are marked with the seal their letter is closed with (`511:1430`), and the
    /// view model is what carries the name — a badge with no entry keeps the wax for its position.
    @Test func theBadungWalksAreSealedWithTheEnvelopesOwnSeal() {
        let model = Self.card([
            Self.run(state: .completed, badgeID: "badge-badung-empat-wajah"),
        ])
        #expect(model.presentation.badges.first?.sealArtworkName == "wax-seal")
    }

    @Test func aBadgeTheDesignCastsNoSealForKeepsTheWaxForItsPosition() {
        let model = Self.card([Self.run(state: .completed, badgeID: "badge-something-else")])
        #expect(model.presentation.badges.first?.sealArtworkName == nil)
    }

    /// The catalogue names both shipped quests' badges and nothing that does not ship.
    @Test func bothBadungQuestsAreInTheSealCatalogue() {
        #expect(BadgeSealCatalog.artworkName(forBadgeID: "badge-badung-empat-wajah") == "wax-seal")
        #expect(BadgeSealCatalog.artworkName(forBadgeID: "badge-mini-badung") == "wax-seal")
    }
}
