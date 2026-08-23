import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The New Discovery card — Figma `1108:2780`, presented over Home the way `1108:2636` draws it:
/// a dimming wash across the whole screen, tab bar included, with the card centred on it.
///
/// It is what a proximity notification resolves to on the phone. The walk into it is
/// `670:1826` (the watch's short look) → a tap → this → "Read Story" → `SideQuestDiscoveryScreen`.
///
/// **A card, not the sidequest flow.** Tapping a row in the nearby list still opens
/// `SideQuestFlowView` — its notice, its story, its challenge — because that is a walker choosing
/// to do a sidequest. This is the other direction: something happened *at* the walker, and the
/// first thing it says is what happened, not what to do about it.
struct NewDiscoveryPopup: View {
    @Environment(\.hisploraPalette) private var palette

    let presentation: SideQuestDiscoveryPresentation
    let onReadStory: () -> Void
    let onDismiss: () -> Void

    private var language: ContentLanguage { presentation.language }

    /// The frame's own figures. `1108:2780` is 300 wide inside a 402-point screen.
    private enum Metrics {
        static let cardWidth: CGFloat = 300
        static let cornerRadius: CGFloat = 19
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 20
        static let stackSpacing: CGFloat = 10
        static let textSpacing: CGFloat = 6
        /// `1108:2790` — the box the key is drawn in, and the box it is drawn in *before* the
        /// turn. Figma rotates a 57.545 × 85.201 child by −89.88°, which sweeps out the 85.323 ×
        /// 57.726 the parent reports.
        static let keyBox = CGSize(width: 85.323, height: 57.726)
        static let keyUnrotated = CGSize(width: 57.545, height: 85.201)
        static let keyRotation = Angle.degrees(-89.88)
    }

    var body: some View {
        ZStack {
            scrim
            card
        }
        // The card arrives over whatever tab is showing, so the whole overlay ignores the safe
        // area: `1108:2778` runs the wash under the status bar and under the tab bar, and a scrim
        // that stops at the tab bar reads as a sheet rather than as the screen going quiet.
        .ignoresSafeArea()
    }

    /// `1108:2778` — a real control, because tapping outside a card is how a card is dismissed and
    /// a gesture recogniser on a rectangle is not something VoiceOver can announce or activate
    /// (`NFR-A11Y-05`).
    private var scrim: some View {
        Button(action: onDismiss) {
            Color.black.opacity(0.4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(UIStrings.string(.discoveryPopupDismiss, language))
    }

    private var card: some View {
        VStack(spacing: Metrics.stackSpacing) {
            key
            text
            readStory
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
        .frame(width: Metrics.cardWidth)
        .background(palette.paperTrip.color,
                    in: RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
        // The card is one announcement: heading, then body, then the control. Grouping it stops
        // VoiceOver reaching the screen underneath before the reader has heard what happened.
        .accessibilityElement(children: .contain)
    }

    /// `1108:2790` — the gold key, laid on its side.
    ///
    /// The turn is a `rotationEffect` on the drawing rather than a pre-rotated export, so the one
    /// asset serves any other placement of the same key and the frame's own angle is legible here
    /// rather than baked into a PNG nobody can measure.
    private var key: some View {
        HisploraStickerImage(name: "sticker-3-07")
            .frame(width: Metrics.keyUnrotated.width, height: Metrics.keyUnrotated.height)
            .rotationEffect(Metrics.keyRotation)
            .frame(width: Metrics.keyBox.width, height: Metrics.keyBox.height)
            .accessibilityHidden(true)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: Metrics.textSpacing) {
            Text(UIStrings.string(.discoveryPopupTitle, language))
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.45)
                .lineSpacing(25 - 20 * 1.19)
                .foregroundStyle(palette.inkDark.color)
                .accessibilityAddTraits(.isHeader)

            Text(UIStrings.string(.discoveryPopupBody, language))
                .font(.system(size: 15))
                .tracking(-0.23)
                .lineSpacing(20 - 15 * 1.19)
                // The frame draws this in `#727272`, which measures **3.92:1** on `paperTrip` —
                // under the 4.5:1 that 15-point body text wants. `inkMuted` is the nearest
                // measured token at 5.43:1 and is what ships. Same handling as `fieldRing` and
                // `trackDim`: where a sampled value fails, the theme yields and the deviation is
                // recorded (`NFR-A11Y-03`, `docs/hisplora-tokens.md`).
                .foregroundStyle(palette.inkMuted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `1108:2785` — a near-black pill that hugs its label rather than filling the card.
    ///
    /// Not `HisploraPillButtonStyle`, which is the story flow's full-width action. This one is
    /// 48 points of padding either side of a 17-point label, and it is centred — the frame's own
    /// shape, and the reason the card reads as an offer rather than a form.
    private var readStory: some View {
        Button(action: onReadStory) {
            Text(UIStrings.string(.discoveryPopupAction, language))
                .font(.system(size: 17, weight: .medium))
                .tracking(-0.34)
                .foregroundStyle(palette.inkOnButton.color)
                .padding(.horizontal, 48)
                .padding(.vertical, 8)
                .frame(minHeight: KultaraMetrics.minimumTapTarget)
                .background(palette.buttonFill.color, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("New Discovery") {
    HisploraStage(ground: \.paperSheet) {
        NewDiscoveryPopup(
            presentation: SideQuestDiscoveryPresentation(
                sideQuestID: "sq-park23",
                title: "Four Directions (test)",
                placeName: "Park 23 XXI",
                synopsis: "You're on a battlefield. The last tale of Badung.",
                claims: [],
                language: .en),
            onReadStory: {},
            onDismiss: {})
    }
}
