import Foundation
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
