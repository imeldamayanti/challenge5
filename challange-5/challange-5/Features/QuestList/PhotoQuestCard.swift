import DesignSystem
import SwiftUI

/// The photo card the Ngalcer Home frame is built from (`28:76`): one photograph, rounded at 12,
/// with the title and a row of facts written over its lower edge.
///
/// The caption is the frame's own wash: one 89-point block running from `photoScrim` at 80% along
/// its bottom edge to nothing at its top (`275:2178`, `275:2183` — the gradient's `startPoint` is
/// `(0.47, 1)`, so it is drawn from the *bottom* up). It replaced a split fade-plus-opaque-block on
/// 2026-08-19 at the author's instruction.
///
/// **That is a deliberate, recorded loss.** A ratio measured against "whatever the photo happens to
/// be" is not a measurement (`NFR-A11Y-03`), and the split version existed so the type only ever
/// landed on opaque scrim and `PhotoScrimTests`' numbers described what was on screen. They no
/// longer do for this card: the title sits high in the block, where the wash is weakest, over an
/// arbitrary photograph. The tokens are unchanged and still measured — what is gone is the
/// guarantee that this card is where they apply. `.black` in the frame is drawn as
/// `palette.photoScrim` so the colour at least stays a token rather than becoming a literal.
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
            caption
                .frame(minHeight: captionHeight, alignment: .leading)
                .background {
                    LinearGradient(
                        stops: [
                            .init(color: palette.photoScrim.color.opacity(0.8), location: 0),
                            .init(color: palette.photoScrim.color.opacity(0), location: 1),
                        ],
                        startPoint: UnitPoint(x: 0.47, y: 1),
                        endPoint: UnitPoint(x: 0.47, y: 0))
                        .accessibilityHidden(true)
                }
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
    /// The frame's 89-point caption block, scaled, and a *minimum* rather than a height for the
    /// same reason the card's is: at the largest content sizes the words are what decide, and a
    /// fixed 89 clips them (`NFR-A11Y-01`).
    @ScaledMetric(relativeTo: .subheadline)
    private var captionHeight: CGFloat = KultaraMetrics.photoCardCaptionHeight
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
        VStack(alignment: .leading, spacing: KultaraMetrics.photoCardCaptionSpacing) {
            Text(title)
                // `275:2183`'s Headline/Regular: SF Pro Semibold at 17, tracked −0.43. Fixed at
                // the frame's size at the owner's explicit instruction, so the caption is the
                // drawing rather than a role that scales away from it (`NFR-A11Y-01` bends here
                // on purpose; the card's own height still grows via `captionHeight`'s minimum).
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.43)
                .foregroundStyle(PhotoCardInk.titleInk.color)
                .fixedSize(horizontal: false, vertical: true)

            facts
        }
        // The frame's 15 and 0. Vertical padding is zero because the 89-point block is what holds
        // the words off the card's bottom edge, and adding both would double the inset.
        .padding(.horizontal, KultaraMetrics.photoCardCaptionInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `275:2183`'s two inks, untokened: `#F6F6F6` for the title and `#AEAEB2` for the facts row.
    /// The palette's `inkOnPhoto`/`inkMutedOnPhoto` are warm creams measured against the old
    /// drawing; the frame's are neutral greys. The scrim guarantee was already recorded as lost on
    /// this card (see the type doc), so these ship as the frame's own values with the numbers
    /// written here — against the 80% scrim floor under a worst-case white photo, `#F6F6F6` is
    /// 12.0:1 and `#AEAEB2` is 5.7:1.
}

/// File-scope because a generic type (`PhotoQuestCard<Facts>`) may not hold stored statics.
enum PhotoCardInk {
    static let titleInk = SRGBColor(hex: "#F6F6F6")
    static let factInk = SRGBColor(hex: "#AEAEB2")
}

/// `275:2183`'s fact: the frame's icon glyph and the value, no label — the one fact shape both
/// the real quest card and the placeholder cards draw, so their captions read as one design.
///
/// The type is SF Pro Semibold 12 (`275:2183`'s Caption1/Emphasized), fixed at the frame's size
/// for the same reason the title is. The icon is one of the popover's exports, tinted the fact
/// grey via template rendering.
struct PhotoCardInlineFact: View {
    let icon: String
    let iconWidth: CGFloat
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            if let image = MapLandmarkImages.image(named: icon) {
                image
                    .resizable()
                    .renderingMode(.template)
                    .frame(width: iconWidth, height: 12)
                    .foregroundStyle(PhotoCardInk.factInk.color)
            } else {
                Color.clear.frame(width: iconWidth, height: 12)
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PhotoCardInk.factInk.color)
        }
    }
}
