import DesignSystem
import SwiftUI

/// One paper card, built from its presentation — the app-target side of
/// `HisploraJournalPaperCard`, which knows about type and paper and nothing about a walk.
///
/// It exists so the modal and the envelope's own thumbnails are the same card rather than two
/// compositions that agree today: `card` is what the thumbnail scales, and `body` is what the modal
/// draws.
struct JournalPaperCard: View {
    let paper: JournalPaperPresentation
    /// `nil` draws the pill as a label rather than a control, which is what a 50%-scale thumbnail
    /// needs — see `HisploraJournalPaperCard`.
    var action: (() -> Void)?

    var body: some View {
        card
            .accessibilityElement(children: .contain)
            .accessibilityLabel(paper.accessibilityLabel)
    }

    var card: HisploraJournalPaperCard<HisploraJournalPaperArtwork> {
        HisploraJournalPaperCard(
            eyebrow: paper.eyebrow,
            title: paper.title,
            actionTitle: paper.actionTitle,
            action: action
        ) {
            HisploraJournalPaperArtwork(
                artworkName: paper.artworkName,
                style: paper.artworkStyle)
        }
    }
}
