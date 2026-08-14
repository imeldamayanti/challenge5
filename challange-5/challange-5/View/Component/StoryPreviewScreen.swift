import ContentKit
import DesignSystem
import SwiftUI

/// `81:588` — the story preview, the typewriter screen.
///
/// The frame: the quest's title in the display serif on a greyed brown ground, a photographed
/// typewriter with a sheet standing out of it, the hook typed onto that sheet in Special Elite, the
/// walking distance and duration ruled off beneath it, and the one filled action at the foot.
///
/// All four of the frame's own materials are here now — the ground `#58453E`, the machine, the
/// typebar face, and the gilded frame the design sets a portrait in. What the frame's portrait
/// *contains* is content, not chrome: `KultaraPortraitFrame` takes whatever picture the quest
/// supplies, and shows the frame empty when it supplies none.
///
/// Distance and duration come from `RouteInfo`, formatted by the same `ContentFormatter` the
/// preview screen uses, so the two cannot print different numbers for the same walk.
struct StoryPreviewScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let title: String
    /// `quest.hookLore`, resolved and joined — the passage that types itself in.
    let hook: String
    let distanceText: String
    let durationText: String
    /// The picture the design sets in the little gilded frame on the sheet. Optional, and empty in
    /// the shipped content: see the note in `CutsceneScreens.swift`.
    var portraitURL: URL? = nil
    let onReady: () -> Void
    let onBack: () -> Void

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                HStack {
                    HisploraBackButton(
                        accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                        action: onBack)
                    Spacer()
                }
                ScrollView {
                    VStack(spacing: KultaraMetrics.xl) {
                        Text(title)
                            .kultaraFont(.storyDisplay)
                            .foregroundStyle(palette.inkCream.color)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        // The machine sits three-quarters of the way across the frame, not edge to
                        // edge — it is an object photographed on a ground, and a full-bleed one
                        // stops reading as one.
                        KultaraTypewriter { sheet }
                            .padding(.horizontal, KultaraMetrics.xl)
                    }
                    .padding(.vertical, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button(UIStrings.string(.storyPreviewReady, language), action: onReady)
                    .buttonStyle(.hisploraPill)
            }
            .padding(KultaraMetrics.lg)
        }
    }

    /// What is typed on the page: the framed picture the design sets at the head of it, the hook,
    /// and the two figures ruled off beneath.
    private var sheet: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
            KultaraPortraitFrame(accessibilityLabel: title) {
                if let portraitURL, let image = BundledImage.load(portraitURL) {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Rectangle().fill(palette.brownStone.color.opacity(0.12))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, KultaraMetrics.xxl)

            // Typed in, because the screen's whole conceit is a page coming out of a machine. The
            // reveal stops itself under Reduce Motion and VoiceOver, and a tap finishes it.
            HisploraTypewriterText(
                hook,
                font: KultaraTypography.font(.typedSheet),
                ink: \.inkDark,
                lineSpacing: KultaraTypography.Role.typedSheet.lineSpacing)

            figures
        }
    }

    /// The rule across the page, then the distance and the duration with a rule standing between
    /// them — as `177:801` draws it.
    private var figures: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            rule.frame(height: KultaraMetrics.hairline)
            // A row at the default size, a column once the figures no longer fit beside each
            // other. `ViewThatFits` rather than a fixed `HStack`, for the reason every other row
            // in this app uses it: at AX5 two figures side by side become two columns of letters.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: KultaraMetrics.lg) {
                    figure(distanceText)
                    rule.frame(width: KultaraMetrics.hairline, height: 24)
                    figure(durationText)
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    figure(distanceText)
                    figure(durationText)
                }
            }
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(palette.inkDark.color.opacity(0.35))
            .accessibilityHidden(true)
    }

    private func figure(_ text: String) -> some View {
        Text(text)
            .kultaraFont(.typedFigure)
            .foregroundStyle(palette.inkDark.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
