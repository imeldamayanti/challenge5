import ContentKit
import DesignSystem
import SwiftUI

/// `81:588` — the story preview, the typewriter screen.
///
/// The frame draws a photographed typewriter with a sheet of paper rising out of it, the hook typed
/// on the sheet, and the route's distance and duration ruled beneath. The typewriter photograph is
/// not shipped (it is a stock image the design file carries, not content this repo owns), so what
/// is built is the *sheet* — the paper, the typed hook, the ruled figures — on the design's cream
/// ground. That keeps the screen's meaning: a story being typed out for you, with the cost of
/// walking it stated plainly underneath.
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
    let onReady: () -> Void
    let onBack: () -> Void

    var body: some View {
        HisploraStage(ground: \.brownDeep) {
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
                            .font(KultaraTypography.font(.questTitleLarge))
                            .foregroundStyle(palette.inkCream.color)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        sheet
                    }
                    .padding(.vertical, KultaraMetrics.xl)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button(UIStrings.string(.storyPreviewReady, language), action: onReady)
                    .buttonStyle(.hisploraPill)
            }
            .padding(KultaraMetrics.lg)
        }
    }

    /// The sheet in the typewriter: cream paper, the hook typed onto it, and the two figures ruled
    /// off beneath as the frame rules them.
    private var sheet: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
            HisploraTypewriterText(
                hook,
                font: .system(size: 15, design: .monospaced),
                ink: \.inkDark,
                lineSpacing: 5)
            VStack(spacing: KultaraMetrics.sm) {
                Rectangle()
                    .fill(palette.inkDark.color.opacity(0.35))
                    .frame(height: KultaraMetrics.hairline)
                    .accessibilityHidden(true)
                HStack(spacing: KultaraMetrics.lg) {
                    figure(distanceText)
                    Rectangle()
                        .fill(palette.inkDark.color.opacity(0.35))
                        .frame(width: KultaraMetrics.hairline, height: 24)
                        .accessibilityHidden(true)
                    figure(durationText)
                    Spacer()
                }
            }
        }
        .padding(KultaraMetrics.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperCream.color)
        .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.xs))
    }

    private func figure(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, design: .monospaced))
            .foregroundStyle(palette.inkDark.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
