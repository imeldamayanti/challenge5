import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

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
                // Not a scroll view. The machine is the one thing on this screen that must not
                // move, and a scroll around the whole stack is what was moving it: the page and the
                // photograph travelled together. The title and the machine are fixed here, and the
                // scrolling — when a long page or a large text size needs any — happens inside
                // `KultaraTypewriter`, on the paper alone.
                VStack(spacing: KultaraMetrics.sm) {
                    Text(title)
                        .kultaraFont(.storyDisplay)
                        .foregroundStyle(palette.inkCream.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    // Given the width of the screen, less the stage's own margin. The sheet is cut
                    // to the width of the paper in the machine's roller, so every point taken off
                    // the machine is taken off the page twice over — and a column narrow enough to
                    // break "Distance | Total time" into two stacked rows costs more height than
                    // the wider machine ever did.
                    KultaraTypewriter { crest } sheet: { sheet }
                }
                .padding(.vertical, KultaraMetrics.xs)
                .frame(maxHeight: .infinity, alignment: .top)
                // White, as `81:594` draws it — a filled pill in `inkOnButton` with the label in
                // `buttonFill`, which is `HisploraLightPillButtonStyle` and its 58-point metrics.
                // It was the flow's near-black `hisploraPill`, which is the *other* frame's action.
                Button(UIStrings.string(.storyPreviewReady, language), action: onReady)
                    .buttonStyle(.hisploraLightPill)
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
        KultaraPortraitFrame(
            accessibilityLabel: title,
            portraitBlur: PortraitFrameMetrics.softFocusBlur
        ) {
            if let portraitURL, let image = BundledImage.load(portraitURL) {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(palette.brownStone.color.opacity(0.12))
            }
        }
    }

    /// What is typed on the page: the hook, and the two named figures ruled off beneath it.
    private var sheet: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            // Typed in, because the screen's whole conceit is a page coming out of a machine. The
            // reveal stops itself under Reduce Motion and VoiceOver, and a tap finishes it.
            //
            // Cut to one sheet. The page is now a fixed window over a machine that does not move,
            // so a hook longer than it fits would turn the photograph into a scroll view. This
            // trims the *display* only — `hookLore` is untouched, and the passage is not shown
            // anywhere else on this screen for the cut to disagree with.
            //
            // Set justified — flush on both edges, the way a page comes out of a machine that
            // cannot rag a margin. Ragged-right is what shipped, and it is the one thing on this
            // sheet that read as a text view rather than as typing.
            // Typed at the machine's own pace — `TypewriterMetrics.sheetCharactersPerSecond`,
            // less than half the rate a passage is *revealed* at elsewhere, with a rest at the end
            // of each clause. This page is a sheet in a roller, not a paragraph fading up.
            HisploraTypewriterText(
                TypewriterMetrics.sheetText(hook),
                justifiedIn: .typedSheet,
                ink: \.inkDark,
                charactersPerSecond: TypewriterMetrics.sheetCharactersPerSecond)

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
