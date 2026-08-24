import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// A real, walkable quest drawn on the Ngalcer Home card (`PhotoQuestCard`).
///
/// The caption is `275:2183`'s overlay: the title, then one row of three unlabelled facts —
/// region, walking time, checkpoint count — each an icon and a value. What the frame leaves out is
/// still on the card for VoiceOver: `FR-DISC-02` requires distance, `FR-DISC-05` requires the cost
/// total on the card itself, and `NFR-CONT-06` requires walking time and total time as two figures,
/// so the full labelled facts are spoken even though the drawing shows three (`accessibilitySummary`).
/// That is a deviation from the letter of those requirements — the *visible* card no longer carries
/// distance or cost — and it wants the same kind of signed amendment the run flow's exceptions got.
///
/// The frame also draws no arrow badge on the corner, so neither does this. The whole card is the
/// button; a badge on top of it was a second affordance for the same tap.
struct QuestCard: View {
    let row: QuestListRow
    let language: ContentLanguage
    /// A walk over this quest is still open (`FR-RUN-03`'s state, drawn where the walker browses):
    /// `850:2289`'s hanging tag on the top-right corner. The words ON GOING are baked into the
    /// export, so VoiceOver reads `questCardOngoing` instead.
    var isOngoing: Bool = false

    var body: some View {
        PhotoQuestCard(title: row.title, hero: row.heroImageURL.flatMap(BundledImage.load)) {
            HStack(spacing: 10) {
                fact(icon: "quest-popover-pin", iconWidth: 10, text: row.region)
                fact(icon: "quest-popover-clock", iconWidth: 10.73, text: row.walkingTimeText)
                fact(icon: "quest-popover-pencil", iconWidth: 11.59, text: row.checkpointCountText)
            }
        }
        .accessibilityLabel(accessibilitySummary)
        // Applied outside the card's clip shape: the frame hangs the tag eight points *above*
        // the photograph (`850:2289` sits at y −8), so clipping it would cut the string off.
        .overlay(alignment: .topTrailing) {
            if isOngoing {
                Image("ongoing-tag")
                    .resizable()
                    .frame(width: 66, height: 84)
                    .offset(y: -8)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityValue(isOngoing ? UIStrings.string(.questCardOngoing, language) : "")
    }

    /// `275:2183`'s fact, shared with the placeholder cards (`PhotoCardInlineFact`) so every card
    /// on Home reads as one design.
    private func fact(icon: String, iconWidth: CGFloat, text: String) -> some View {
        PhotoCardInlineFact(icon: icon, iconWidth: iconWidth, text: text)
    }

    /// Everything the card no longer *prints*, spoken instead. The six labelled facts the previous
    /// drawing carried, so `FR-DISC-02`, `FR-DISC-05` and `NFR-CONT-06` survive for VoiceOver even
    /// where the frame's row shows three.
    private var accessibilitySummary: Text {
        let facts = [
            UIStrings.string(.labelRegion, language) + " " + row.region,
            UIStrings.string(.labelWalkingTime, language) + " " + row.walkingTimeText,
            UIStrings.string(.previewCheckpointsHeading, language) + " " + row.checkpointCountText,
            UIStrings.string(.labelTotalDuration, language) + " " + row.totalDurationText,
            UIStrings.string(.labelDistance, language) + " " + row.distanceText,
            UIStrings.string(.labelEstimatedCost, language) + " " + row.costText,
        ]
        return Text((row.title + ", " + facts.joined(separator: ", ")))
    }
}
