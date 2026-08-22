import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// A real, walkable quest drawn on the Ngalcer Home card (`PhotoQuestCard`).
///
/// The frame writes three facts under the title — region, duration, checkpoint count. What it
/// leaves out is still here: `FR-DISC-02` requires distance, `FR-DISC-05` requires the cost total
/// on the card itself, and `NFR-CONT-06` requires walking time and total time as two figures. So
/// the frame's row is the first line and the other three run beneath it, stacking at accessibility
/// sizes instead of any of it being dropped.
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
            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    HStack(spacing: KultaraMetrics.md) { region; walking; checkpoints }
                    HStack(spacing: KultaraMetrics.md) { total; distance; cost }
                }
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    region; walking; checkpoints; total; distance; cost
                }
            }
        }
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

    private var region: some View {
        PhotoCardFact(symbolName: "mappin", label: UIStrings.string(.labelRegion, language),
                      value: row.region)
    }
    private var checkpoints: some View {
        PhotoCardFact(symbolName: "flag", label: UIStrings.string(.previewCheckpointsHeading, language),
                      value: row.checkpointCountText)
    }
    private var walking: some View {
        PhotoCardFact(symbolName: "clock", label: UIStrings.string(.labelWalkingTime, language),
                      value: row.walkingTimeText)
    }
    private var total: some View {
        PhotoCardFact(symbolName: "hourglass", label: UIStrings.string(.labelTotalDuration, language),
                      value: row.totalDurationText)
    }
    private var distance: some View {
        PhotoCardFact(symbolName: "figure.walk",
                      label: UIStrings.string(.labelDistance, language), value: row.distanceText)
    }
    /// `FR-DISC-05`. Emphasised when the quest costs money — by weight and symbol, not by hue,
    /// since on a photograph the seal red is not a measurable colour.
    private var cost: some View {
        PhotoCardFact(symbolName: row.showsCostOnCard ? "banknote" : "gift",
                      label: UIStrings.string(.labelEstimatedCost, language),
                      value: row.costText, emphasised: row.showsCostOnCard)
    }
}
