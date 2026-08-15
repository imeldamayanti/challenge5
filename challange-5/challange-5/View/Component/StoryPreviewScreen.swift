import ContentKit
import DesignSystem
import SwiftUI

/// The story preview, the typewriter screen — `81:588` on the Hisplora board, restyled to
/// `35:431` ("Cutscene quest - Lore") on the Ngalcer board.
///
/// The frame: the quest's title in the display serif on a greyed brown ground, a photographed
/// typewriter with a sheet standing out of it, the hook typed onto that sheet in Special Elite, the
/// walking distance and duration ruled off beneath it, and the one filled action at the foot.
///
/// **What `35:431` changed.** Two things, both layout. The gilded frame moved *out* of the sheet
/// and now stands over the top of it, its lower half behind the paper — carried by
/// `KultaraTypewriter`'s `crest`. And the two figures gained their names, "Distance" and
/// "Estimated Time", which is `KultaraTypedFigures` taking a label it previously had no room for.
/// Nothing about which data is shown, or where it comes from, moved.
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
                        KultaraTypewriter { crest } sheet: { sheet }
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

    /// The framed picture, standing over the top of the page — `35:431` moved it out of the sheet
    /// and onto the machine, where its lower half falls behind the paper.
    ///
    /// The frame is empty in the shipped content, and that is a decision rather than a gap: see the
    /// note at the head of `CutsceneScreens.swift`. It is still the design's object, so it is still
    /// drawn.
    private var crest: some View {
        KultaraPortraitFrame(accessibilityLabel: title) {
            if let portraitURL, let image = BundledImage.load(portraitURL) {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(palette.brownStone.color.opacity(0.12))
            }
        }
    }

    /// What is typed on the page: the hook, and the two named figures ruled off beneath it.
    private var sheet: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
            // Typed in, because the screen's whole conceit is a page coming out of a machine. The
            // reveal stops itself under Reduce Motion and VoiceOver, and a tap finishes it.
            HisploraTypewriterText(
                hook,
                font: KultaraTypography.font(.typedSheet),
                ink: \.inkDark,
                lineSpacing: KultaraTypography.Role.typedSheet.lineSpacing)

            // `.labelDistance` and `.labelTotalDuration` are the same two strings the preview
            // screen puts over the same two numbers. The board writes "Estimated Time" where the
            // table says "Total time"; one number with two names in two places is how a string
            // table starts drifting, so the existing pair is reused rather than duplicated.
            KultaraTypedFigures([
                KultaraTypedFigure(
                    label: UIStrings.string(.labelDistance, language), value: distanceText),
                KultaraTypedFigure(
                    label: UIStrings.string(.labelTotalDuration, language), value: durationText),
            ])
        }
    }
}
