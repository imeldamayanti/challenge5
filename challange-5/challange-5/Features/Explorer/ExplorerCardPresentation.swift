import Foundation

/// The Explorer's Card, resolved (Figma `547:2724`, `547:2848`, `547:2952`).
///
/// Every number and every row here is the reader's own record. Nothing on this screen is content:
/// the counts come from Runs and sidequest records, and the names come from the snapshots those
/// carry, so the card renders offline and keeps reading correctly after content changes underneath
/// it (`FR-DONE-05`).
struct ExplorerCardPresentation: Sendable, Equatable {

    /// The three surfaces the strip switches between.
    enum Tab: String, Sendable, CaseIterable, Identifiable {
        case quests, stamps, badges
        var id: String { rawValue }
    }

    /// What the Quests tab is showing. The frame draws one list of finished walks; the reader also
    /// needs the unfinished ones, because Profile is the only route back into a walk in progress —
    /// so the list gains a filter rather than the tab gaining a second heading.
    ///
    /// `all` puts the unfinished ones first: a walk still open is the thing a reader opens their own
    /// card to act on, and a finished one is a record.
    enum QuestFilter: String, Sendable, CaseIterable, Identifiable {
        case all, unfinished, done
        var id: String { rawValue }

        func includes(_ quest: QuestRowPresentation) -> Bool {
            switch self {
            case .all: true
            case .unfinished: !quest.isComplete
            case .done: quest.isComplete
            }
        }
    }

    /// What the card is headed with. There is no account in this build, so this is a role and not
    /// a name — see `.profileExplorerName`.
    let name: String
    let questCount: Int
    let stampCount: Int
    let badgeCount: Int
    let quests: [QuestRowPresentation]
    let stamps: [StampPresentation]
    let badges: [BadgePresentation]

    static let empty = ExplorerCardPresentation(
        name: "", questCount: 0, stampCount: 0, badgeCount: 0,
        quests: [], stamps: [], badges: [])

    init(
        name: String,
        questCount: Int,
        stampCount: Int,
        badgeCount: Int,
        quests: [QuestRowPresentation],
        stamps: [StampPresentation],
        badges: [BadgePresentation]
    ) {
        self.name = name
        self.questCount = questCount
        self.stampCount = stampCount
        self.badgeCount = badgeCount
        self.quests = quests
        self.stamps = stamps
        self.badges = badges
    }
}

/// One row on the Quests tab: a walk the reader has under way, or one they have finished
/// (`705:2827`).
///
/// **Both, since 2026-08-20, and filtered rather than split.** The tab used to list unfinished
/// walks only, on the argument that a finished one is already a badge and a sealed letter. The
/// frame lists finished ones, and both readings are right about a different reader — so the list
/// carries both and a three-way filter says which. What the tab must not lose is the resume: it is
/// the only route back into a walk in progress, which is why an unfinished row still carries the
/// Run's id and a finished one does not.
///
/// Every word comes from the Run's own snapshots (`FR-DONE-05`, `FR-RUN-06`), so a walk keeps
/// naming itself after a content correction and after the quest is withdrawn underneath it. The
/// one exception is `detailEmphasis`, the region, which no Run snapshots — it is read from content
/// and comes back empty for a withdrawn quest, which the row prints as a plain "Completed" rather
/// than as a sentence with nothing after "at".
///
/// Sidequests used to be listed here and no longer are. They are not quests — `FR-SIDE-04`
/// encounters have their own surfaces in the Journal's collection and the nearby list — and a row
/// of them under a tab called "Quests" said they were part of the walk.
struct QuestRowPresentation: Sendable, Equatable, Identifiable {
    /// The Run's id. Identity only — what the row *opens* is `resumeRunID`, which a finished walk
    /// does not have.
    let id: UUID
    let title: String
    /// "3 of 5 checkpoints" for an unfinished walk; "You completed this quest at" for a finished
    /// one, with the place in `detailEmphasis`.
    let detail: String
    let detailEmphasis: String?
    let isComplete: Bool
    /// Non-nil only while the walk is still open.
    let resumeRunID: UUID?

    init(
        id: UUID,
        title: String,
        detail: String,
        detailEmphasis: String? = nil,
        isComplete: Bool,
        resumeRunID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.detailEmphasis = detailEmphasis
        self.isComplete = isComplete
        self.resumeRunID = resumeRunID
    }
}

/// One badge: a walk finished, or a collection completed (`FR-SIDE-09`).
///
/// `waxIndex` is a position, not a colour. The view turns it into one of the four seals the frames
/// cast; keeping the colour out of the model is the same rule `LoreBlockPresentation.Ink` follows —
/// a presentation type that knows a palette can hold one.
struct BadgePresentation: Sendable, Equatable, Identifiable {
    let id: String
    let name: String
    let waxIndex: Int

    init(id: String, name: String, waxIndex: Int) {
        self.id = id
        self.name = name
        self.waxIndex = waxIndex
    }
}
