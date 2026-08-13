import ContentKit
import DesignSystem
import SwiftUI

struct QuestCard: View {
    @Environment(\.kultaraPalette) private var palette
    let row: QuestListRow
    let language: ContentLanguage

    var body: some View {
        // The Home design's card: one photograph, rounded, with the title and the facts written
        // over its lower edge and a filled arrow in the corner. The text sits on `photoScrim` at
        // full opacity and the gradient above it is decoration, because a ratio measured against
        // "whatever the photo happens to be" is not a measurement (`NFR-A11Y-03`).
        //
        // What the design leaves out is still here — FR-DISC-02 requires distance, FR-DISC-05
        // requires the cost total on the card itself, and NFR-CONT-06 requires walking time and
        // total time as two figures. So the facts run to two lines rather than the design's one,
        // and stack at accessibility sizes instead of dropping any of it.
        //
        // The caption is laid out first and the photograph is its *background*: a background
        // cannot make its parent smaller, so at the largest accessibility sizes the card grows to
        // fit the words instead of clipping them (`NFR-A11Y-01`). The reverse — a fixed-height
        // card with the caption overlaid — loses the title off the top of the scrim, which is
        // exactly what it did before this was written down.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [palette.photoScrim.color.opacity(0), palette.photoScrim.color],
                startPoint: .top, endPoint: .bottom)
                .frame(height: fadeHeight)
                .accessibilityHidden(true)
            caption
                .background(palette.photoScrim.color)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: cardHeight)
        .background { hero }
        .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.photoCardCornerRadius))
        .overlay(alignment: .topTrailing) {
            SealArrowBadge()
                .padding(KultaraMetrics.md)
        }
        .accessibilityElement(children: .combine)
    }

    /// The photograph's own height at default size. It is a minimum, not a height: the caption
    /// decides how tall the card actually is.
    @ScaledMetric(relativeTo: .subheadline) private var scaledCardHeight: CGFloat = 224
    @ScaledMetric(relativeTo: .subheadline) private var fadeHeight: CGFloat = 72
    private var cardHeight: CGFloat { min(scaledCardHeight, 340) }

    @ViewBuilder private var hero: some View {
        if let url = row.heroImageURL, let image = BundledImage.load(url) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        } else {
            // No hero is not a broken card, just a plainer one — and the caption still lands on
            // the scrim, so its ratio is the measured one either way.
            palette.paperSunken.color
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            Text(row.title)
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.inkOnPhoto.color)
                .fixedSize(horizontal: false, vertical: true)

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
        .padding(KultaraMetrics.md)
        .frame(maxWidth: .infinity, alignment: .leading)
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
