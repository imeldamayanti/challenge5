import DesignSystem
import Foundation

/// One of the two papers an envelope holds — `791:5568` ("Trip summary") and `791:5814`
/// ("History"), drawn small inside the envelope and full size in `791:5551`'s modal.
///
/// **Text and picture are both parameters, and that is the point.** The frames export each card as
/// a flat picture with a quest's name baked into it; a screen that shipped those would be naming a
/// walk from a drawing rather than from the walk's own snapshots, which is what `AD-4` and
/// `FR-RUN-06` rule out. Every word here comes from the Run or from `UIStrings`, and the picture is
/// named rather than held — the same rule `StampPresentation.artworkName` follows, for the same
/// reason.
struct JournalPaperPresentation: Sendable, Equatable, Identifiable {

    /// Which of the two papers this is. It is also what the modal's action opens.
    enum Kind: String, Sendable, CaseIterable {
        /// The walk itself: where the reader went and what they wrote down.
        case summary
        /// The lore they unlocked along it.
        case history
    }

    let kind: Kind
    /// Already localized, already interpolated with the quest's region.
    let eyebrow: String
    let title: String
    let actionTitle: String
    /// The packaged drawing this paper prints, or `nil` for aged blank paper.
    ///
    /// **A name in a table, not a field on the content.** `journal-summary-emblem` and
    /// `journal-history-plate` are the two the frames draw; neither is authored, sourced or
    /// consented content, and neither claims anything about a particular place — so they are
    /// defaults that a later content-authored picture replaces, exactly as `StampArtworkResolver`'s
    /// place table is the debt it says it is. Changing what a card shows is changing this line or
    /// the PNG behind it.
    let artworkName: String?
    /// How that drawing is set on the sheet — a disc, or a landscape plate with a gilt edge.
    let artworkStyle: HisploraJournalPaperArtwork.Style

    init(
        kind: Kind,
        eyebrow: String,
        title: String,
        actionTitle: String,
        artworkName: String?,
        artworkStyle: HisploraJournalPaperArtwork.Style
    ) {
        self.kind = kind
        self.eyebrow = eyebrow
        self.title = title
        self.actionTitle = actionTitle
        self.artworkName = artworkName
        self.artworkStyle = artworkStyle
    }

    var id: String { kind.rawValue }

    /// One spoken sentence for the card: what it is, then what its control does.
    var accessibilityLabel: String { "\(eyebrow). \(title)" }
}
