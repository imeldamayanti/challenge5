import Foundation

/// One card in the discovery list, carrying every field `FR-DISC-02` requires plus the quest id, so
/// reaching preview is one tap and not a fetch (`FR-DISC-07`).
struct QuestListRow: Sendable, Identifiable, Equatable {
    let questID: String
    let title: String
    let region: String
    let distanceText: String
    let walkingTimeText: String
    let totalDurationText: String
    let costText: String
    /// `FR-DISC-05` — a quest that costs money shows its total on the card, not only in preview.
    let showsCostOnCard: Bool
    /// `FR-CP-08` counts progress in checkpoints, so the card counts them by that name. The Home
    /// mockup labels this "5 quests"; a quest containing quests collides with the glossary.
    let checkpointCount: Int
    let checkpointCountText: String
    /// The photograph the card is built around. Nil renders as type on paper rather than as a gap.
    let heroImageURL: URL?

    var id: String { questID }

    init(
        questID: String,
        title: String,
        region: String,
        distanceText: String,
        walkingTimeText: String,
        totalDurationText: String,
        costText: String,
        showsCostOnCard: Bool,
        checkpointCount: Int = 0,
        checkpointCountText: String = "",
        heroImageURL: URL? = nil
    ) {
        self.questID = questID
        self.title = title
        self.region = region
        self.distanceText = distanceText
        self.walkingTimeText = walkingTimeText
        self.totalDurationText = totalDurationText
        self.costText = costText
        self.showsCostOnCard = showsCostOnCard
        self.checkpointCount = checkpointCount
        self.checkpointCountText = checkpointCountText
        self.heroImageURL = heroImageURL
    }
}
