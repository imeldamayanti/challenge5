import Foundation

/// One envelope on the Journal's shelf — a walk, rendered as a sealed letter (Figma `332:1607`).
///
/// Built entirely from the Run's own snapshots, never from a content lookup, for the reason
/// `RunJournalSummary` is: a finished walk keeps naming the quest it was, after a correction and
/// after the place is withdrawn (`FR-DONE-05`, `FR-RUN-06`). The only content the presentation
/// reaches for is the hero picture, which is decoration and simply absent when the quest is gone.
struct SealedLetterPresentation: Sendable, Equatable, Identifiable {
    /// The Run's id — what the screen opens when the envelope is unsealed.
    let id: UUID
    let questID: String
    let title: String
    /// "3 of 5 checkpoints", already formatted.
    let progressText: String
    let isComplete: Bool
    /// The stamps franked onto the pocket, in the order they were earned.
    let stamps: [StampPresentation]
    let heroImageURL: URL?
    /// One spoken sentence for the whole card. A reader hears the walk, not "image, image, image".
    let accessibilityLabel: String

    init(
        id: UUID,
        questID: String,
        title: String,
        progressText: String,
        isComplete: Bool,
        stamps: [StampPresentation],
        heroImageURL: URL?,
        accessibilityLabel: String
    ) {
        self.id = id
        self.questID = questID
        self.title = title
        self.progressText = progressText
        self.isComplete = isComplete
        self.stamps = stamps
        self.heroImageURL = heroImageURL
        self.accessibilityLabel = accessibilityLabel
    }
}

/// One franked stamp: a checkpoint that was actually reached.
///
/// **There is no picture on it, and that is a decision.** The frames fill each stamp with an
/// illustration of the place it names. The content tree carries no per-place artwork, and an
/// illustration captioned with a real place's name is a claim about that place — `FR-CP-05` wants
/// every claim to arrive with its source and this one would arrive with none. So the stamp is
/// franked with the name and the region the Run recorded, on aged paper.
struct StampPresentation: Sendable, Equatable, Identifiable {
    /// The award's `sourceID` — the authored `Checkpoint.stampId`.
    let id: String
    /// `Award.snapshotName`, which is the place name as it read on the day.
    let placeName: String
    let region: String

    init(id: String, placeName: String, region: String) {
        self.id = id
        self.placeName = placeName
        self.region = region
    }
}
