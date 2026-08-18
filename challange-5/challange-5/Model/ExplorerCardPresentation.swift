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
    let activities: [ActivityPresentation]
    let stamps: [StampPresentation]
    let badges: [BadgePresentation]

    static let empty = ExplorerCardPresentation(
        name: "", questCount: 0, stampCount: 0, badgeCount: 0,
        activities: [], stamps: [], badges: [])

    init(
        name: String,
        questCount: Int,
        stampCount: Int,
        badgeCount: Int,
        activities: [ActivityPresentation],
        stamps: [StampPresentation],
        badges: [BadgePresentation]
    ) {
        self.name = name
        self.questCount = questCount
        self.stampCount = stampCount
        self.badgeCount = badgeCount
        self.activities = activities
        self.stamps = stamps
        self.badges = badges
    }
}

/// One row on the Quests tab: something the reader was asked to find, and whether they did.
///
/// These are sidequests — the encounters that ask for a thing at a place and record an answer
/// (`FR-SIDE-04`). Checkpoint tasks are deliberately not listed here: `AD-2` makes them keepsakes
/// that never gate anything, and a list of them under a "completed" seal would say they were a
/// requirement.
struct ActivityPresentation: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let isComplete: Bool

    init(id: String, title: String, detail: String, isComplete: Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isComplete = isComplete
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
