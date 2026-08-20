import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// `187:1103` — the map on the open scroll, a dot beating over where the walk begins, and the place
/// named under it. It comes straight off `187:866`'s "Start the Journey" and moves itself on.
///
/// **It is the one screen in the run flow with no control on it.** The frame draws none, and the
/// reason it can get away with that is that it asserts nothing and asks nothing: it is the beat
/// between being told a story and being sent somewhere. Three consequences follow, and all three
/// are here rather than in the frame:
///
/// - **The back chevron stays.** A screen that leaves on its own must still be leavable on purpose,
///   or the five seconds are five seconds a walker cannot get out of.
/// - **Under VoiceOver the clock does not run, and a control appears instead.** A screen that reads
///   itself out and then vanishes mid-sentence is not a screen a reader can use, and there is no
///   duration that fixes that — the reader's own pace is the only right one (`NFR-A11Y-05`).
///   `CutsceneIntroScreen` draws its button under the same rule and for the same reason.
/// - **The wait is `.task`, not a timer the model owns.** `.task` is cancelled when this view goes
///   away, so backing out takes the countdown with it. A model-side timer would keep counting and
///   push the walker onto the reveal from a screen they had already left.
///
/// Everything drawn here is content (`AD-4`, `FR-RUN-06`): the quest's title in the bar, the
/// quest's region in the eyebrow, the checkpoint's place under the scroll, and the map and its dot
/// out of the Place's own `approachMap`. Nothing about Badung is baked in.
struct ApproachTransitionScreen: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let language: ContentLanguage
    /// The quest's title, for the header. Content, never a literal.
    let questTitle: String
    /// The quest's region — what the eyebrow's sentence ends on.
    let region: String
    /// The place the dot is over, named under the scroll.
    let placeName: String
    /// The checkpoint's authored approach map, or nil where the Place ships none. The screen still
    /// draws and still moves on: the words under the scroll are the sentence, and the map
    /// illustrates it.
    let approachMap: ApproachMapPresentation?
    let onAdvance: () -> Void
    let onBack: () -> Void

    /// Guards the two ways off this screen against each other. Under VoiceOver only the button
    /// exists and under every other setting only the clock does, but a double tap landing as the
    /// last tick fires would advance twice and skip the reveal.
    @State private var hasAdvanced = false

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        // The frame opens the scroll at y = 380 of 874 — well down the page, so the
                        // map lands in the middle third rather than under the bar.
                        Spacer(minLength: 48)
                        scroll
                        Spacer(minLength: 32)
                        caption
                        Spacer(minLength: 24)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
                // The scroll is drawn wider than this column, so the scroll view must not crop it.
                .scrollClipDisabled()
                if voiceOverEnabled {
                    Button(UIStrings.string(.transitionContinue, language), action: advanceOnce)
                        .buttonStyle(.hisploraLightPill)
                        .padding(.bottom, 30)
                }
            }
            // 20 each side, which leaves the frame's 362-point content column on a 402-point screen
            // — the same column `1:4458` uses, and this screen carries the same scroll.
            .padding(.horizontal, 20)
        }
        .task {
            guard !voiceOverEnabled else { return }
            try? await Task.sleep(for: QuestRunViewModel.approachTransitionDuration)
            advanceOnce()
        }
    }

    /// The quest's name centred with the chevron over it on the left — the same bar the cutscene
    /// and `1:4458` carry, and a `ZStack` for the same reason: a long title stays centred instead
    /// of being pushed off by the chevron's width.
    private var header: some View {
        ZStack {
            Text(questTitle)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.inkCream.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, KultaraMetrics.minimumTapTarget)
                .accessibilityAddTraits(.isHeader)
            HStack {
                HisploraBackButton(
                    accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                    size: 24,
                    action: onBack)
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 13)
    }

    /// The open scroll with the drawing in its paper field — `1:4467`, the same object `1:4458`
    /// draws, here holding the dot as well.
    @ViewBuilder private var scroll: some View {
        if let approachMap {
            HisploraMapScroll {
                ApproachMapView(language: language,
                                placeName: placeName,
                                approachMap: approachMap,
                                pulsesAtMarker: true)
            }
            // The scroll runs x −19…420 on a 402-point screen while this column is the frame's 362.
            // Escaping by the column's margin plus the bleed is what gets it to its drawn width;
            // clipping it to the column would put both rods inside the screen and make it a
            // different object.
            .padding(.horizontal, -(20 + HisploraMapScrollMetrics.screenBleed))
        }
    }

    /// `187:1114` and `187:1116` — the app's sentence about the walk, closed by the quest's region,
    /// and the place's own name under it.
    private var caption: some View {
        VStack(spacing: KultaraMetrics.sm) {
            Text(String(format: UIStrings.string(.transitionSteppingInto, language), region))
                .font(.system(size: 17))
                .tracking(-0.34)
                .foregroundStyle(palette.inkDusty.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(placeName)
                .kultaraFont(.storyDisplay)
                .foregroundStyle(palette.inkCream.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func advanceOnce() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        onAdvance()
    }
}
