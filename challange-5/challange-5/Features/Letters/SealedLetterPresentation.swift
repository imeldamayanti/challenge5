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
    /// The two sheets this envelope holds (`791:5585`). Two rather than one as of the `791:*`
    /// board, and built here rather than in the view for the reason everything else on this type
    /// is: a card on a shelf is a value, and what is written on it is decided once.
    let papers: [JournalPaperPresentation]
    /// What is written on the back of the envelope (`791:5657`): a salutation, the walk's own
    /// title, where it was walked and when. Four lines of decoration — the same facts are spoken
    /// by `accessibilityLabel` and printed at full size on the papers.
    let addressLines: [String]
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
        papers: [JournalPaperPresentation] = [],
        addressLines: [String] = [],
        accessibilityLabel: String
    ) {
        self.id = id
        self.questID = questID
        self.title = title
        self.progressText = progressText
        self.isComplete = isComplete
        self.stamps = stamps
        self.heroImageURL = heroImageURL
        self.papers = papers
        self.addressLines = addressLines
        self.accessibilityLabel = accessibilityLabel
    }
}

/// One franked stamp: a checkpoint that was actually reached.
///
/// **The picture is a resource name, never an image.** The design draws each place three times and
/// the reader climbs the set by finishing walks through it (`StampArtworkResolver`); which drawing
/// they are on is decided before this type is built, and what lands here is the stem the view hands
/// to `DesignSystem`. A presentation model that carried an `Image` would be holding a piece of the
/// theme, which is the rule `LoreBlockPresentation.Ink` exists to keep.
///
/// `nil` is a real state and stays one: a place the design never drew, or content that has been
/// withdrawn under a finished walk, franks aged paper rather than a borrowed picture.
struct StampPresentation: Sendable, Equatable, Identifiable {
    /// The award's `sourceID` — the authored `Checkpoint.stampId`.
    let id: String
    /// `Award.snapshotName`, which is the place name as it read on the day.
    let placeName: String
    let region: String
    /// `"pemecutan-stamp2"`, or `nil` when this place has no drawing.
    let artworkName: String?

    init(id: String, placeName: String, region: String, artworkName: String? = nil) {
        self.id = id
        self.placeName = placeName
        self.region = region
        self.artworkName = artworkName
    }
}
