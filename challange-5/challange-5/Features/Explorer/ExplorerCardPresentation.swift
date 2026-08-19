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

    /// What the card is headed with. There is no account in this build, so this is a role and not
    /// a name — see `.profileExplorerName`.
    let name: String
    let questCount: Int
    let stampCount: Int
    let badgeCount: Int
    let inProgressQuests: [InProgressQuestPresentation]
    let stamps: [StampPresentation]
    let badges: [BadgePresentation]

    static let empty = ExplorerCardPresentation(
        name: "", questCount: 0, stampCount: 0, badgeCount: 0,
        inProgressQuests: [], stamps: [], badges: [])

    init(
        name: String,
        questCount: Int,
        stampCount: Int,
        badgeCount: Int,
        inProgressQuests: [InProgressQuestPresentation],
        stamps: [StampPresentation],
        badges: [BadgePresentation]
    ) {
        self.name = name
        self.questCount = questCount
        self.stampCount = stampCount
        self.badgeCount = badgeCount
        self.inProgressQuests = inProgressQuests
        self.stamps = stamps
        self.badges = badges
    }
}

/// One row on the Quests tab: a walk the reader started and has not finished.
///
/// **Unfinished only, and that is the whole list.** A finished walk is already told twice — as a
/// badge on the third tab and as a sealed letter in the Journal — so repeating it here would make
/// the tab a second Journal. What no other surface answers is "what am I part-way through", which
/// is what a reader opens their own card to find out.
///
/// Every word comes from the Run's own snapshots (`FR-DONE-05`, `FR-RUN-06`), so a walk keeps
/// naming itself after a content correction and after the quest is withdrawn underneath it.
///
/// Sidequests used to be listed here and no longer are. They are not quests — `FR-SIDE-04`
/// encounters have their own surfaces in the Journal's collection and the nearby list — and a row
/// of them under a tab called "Quests" said they were part of the walk.
struct InProgressQuestPresentation: Sendable, Equatable, Identifiable {
    /// The Run's id, which is also what the row opens.
    let id: UUID
    let title: String
    /// "3 of 5 checkpoints", already formatted.
    let detail: String

    init(id: UUID, title: String, detail: String) {
        self.id = id
        self.title = title
        self.detail = detail
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
