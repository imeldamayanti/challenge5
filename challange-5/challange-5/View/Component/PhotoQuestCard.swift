import DesignSystem
import SwiftUI

/// The photo card the Ngalcer Home frame is built from (`28:76`): one photograph, rounded at 12,
/// with the title and a row of facts written over its lower edge.
///
/// The text sits on `photoScrim` at full opacity and the gradient above it is decoration, because a
/// ratio measured against "whatever the photo happens to be" is not a measurement (`NFR-A11Y-03`).
/// The frame draws the caption as a single 80%-black wash; reproducing that literally would leave
/// every measured number in `PhotoScrimTests` describing something other than what is on screen, so
/// the wash is split into a fade and an opaque block and the type only ever lands on the block.
///
/// The caption is laid out first and the photograph is its *background*: a background cannot make
/// its parent smaller, so at the largest accessibility sizes the card grows to fit the words instead
/// of clipping them (`NFR-A11Y-01`). The reverse — a fixed 208-point card with the caption overlaid
/// — loses the title off the top of the scrim.
struct PhotoQuestCard<Facts: View>: View {
    @Environment(\.kultaraPalette) private var palette

    private let title: String
    private let hero: Image?
    private let facts: Facts

    init(title: String, hero: Image?, @ViewBuilder facts: () -> Facts) {
        self.title = title
        self.hero = hero
        self.facts = facts()
    }

    var body: some View {
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
        .background { heroLayer }
        .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.photoCardCornerRadius))
        .accessibilityElement(children: .combine)
    }

    /// The frame's 208 points, scaled. A minimum, not a height — the caption decides. Capped so a
    /// card at the largest accessibility size is still a card rather than a screen.
    @ScaledMetric(relativeTo: .subheadline)
    private var scaledCardHeight: CGFloat = KultaraMetrics.photoCardMinimumHeight
    @ScaledMetric(relativeTo: .subheadline) private var fadeHeight: CGFloat = 56
    private var cardHeight: CGFloat { min(scaledCardHeight, 340) }

    @ViewBuilder private var heroLayer: some View {
        if let hero {
            hero
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        } else {
            // No photograph is not a broken card, just a plainer one — and the caption still lands
            // on the scrim, so its ratio is the measured one either way.
            palette.paperSunken.color
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            Text(title)
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.inkOnPhoto.color)
                .fixedSize(horizontal: false, vertical: true)

            facts
        }
        .padding(.horizontal, KultaraMetrics.lg)
        .padding(.vertical, KultaraMetrics.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
