import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The cutscene — `98:1588` and `187:866`.
///
/// The plan settles what this is: a *presentation* of data that already exists, not a new content
/// type. It shows the quest's `hookLore` and a place image, once, before the walk. Adding a
/// `cutscene` object to the schema would mean a validator rule, a consent question and a migration,
/// for something `hookLore` already holds.
///
/// **On the portrait.** The frames show a generated likeness of I Gusti Ngurah Made Agung. That
/// image is not shipped here, and the reason is not squeamishness: a portrait of a named historical
/// person is a claim, `FR-CP-05` requires every claim to carry its accuracy label and its source,
/// and the sample content ships no such person, no consent record for one, and no citation. The
/// frame is built to take *whatever image the content supplies* — `KultaraPortraitFrame` was
/// written that way deliberately — so when a licensed or properly-labelled image exists it drops in
/// without this file changing. Until then the frame carries the quest's own hero image, which is
/// content with provenance behind it.

/// `98:1588` — "A Legend Will Guide Your Journey", the covered frame, and the hint that says how
/// to uncover it.
///
/// **The interaction is the screen.** The frame opens obscured, the walker rubs it clear
/// (`223:1987` is that same frame with the picture showing), and when enough of it is gone the
/// flow moves itself on to `187:866`. Nothing is tapped in the drawn design; the picture coming
/// out from under the hand *is* the transition.
///
/// Three things the frame does not draw and this screen has anyway, all of them requirements:
///
/// - Under Reduce Motion or VoiceOver the picture is uncovered from the first frame, because a rub
///   is not an animation anyone can opt out of and it is not a control a screen reader can find
///   (`NFR-A11Y-04`, `NFR-A11Y-05`).
/// - After ten seconds without a finished reveal, the explicit action appears. A gesture with no
///   drawn control is a dead end for whoever does not try it, and this flow has no other way past
///   this screen.
/// - The quest's own title sits in the header, as `447:1870` draws it — from content, never the
///   name the frame bakes in (`AD-4`, `FR-RUN-06`).
struct CutsceneIntroScreen: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let language: ContentLanguage
    /// The quest's title, for the header. Content, not a literal.
    let questTitle: String
    let portraitURL: URL?
    let portraitLabel: String
    let onAdvance: () -> Void
    let onBack: () -> Void

    /// How long the screen waits before drawing the way past the gesture.
    private static let explicitActionAppearsAfter = Duration.seconds(10)

    @State private var hasAdvanced = false
    @State private var showsExplicitAction = false

    /// The rub is skipped outright for the same two settings `HisploraScratchReveal` reads, so the
    /// action has to be there from the start rather than after the wait.
    private var rubIsAvailable: Bool { !(reduceMotion || voiceOverEnabled) }

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: KultaraMetrics.xl) {
                        Text(UIStrings.string(.cutsceneLegendTitle, language))
                            .kultaraFont(.storyDisplay)
                            .foregroundStyle(palette.inkCream.color)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        revealableFrame
                            .padding(.horizontal, KultaraMetrics.xl)
                        Text(UIStrings.string(.cutsceneSwipeHint, language))
                            .font(.system(size: 15))
                            .foregroundStyle(palette.inkDusty.color)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, KultaraMetrics.xl)
                    .padding(.bottom, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                if showsExplicitAction || !rubIsAvailable {
                    Button(UIStrings.string(.cutsceneRevealAction, language), action: advanceOnce)
                        .buttonStyle(.hisploraPill)
                        .transition(.opacity)
                }
            }
            .padding(KultaraMetrics.lg)
            .animation(.easeInOut(duration: 0.25), value: showsExplicitAction)
            .task {
                try? await Task.sleep(for: Self.explicitActionAppearsAfter)
                showsExplicitAction = true
            }
        }
    }

    /// `447:1870` and `187:1093` — the quest's name centred, the back chevron over it on the left.
    /// A `ZStack` rather than a three-column `HStack`, so a long title stays centred on the screen
    /// instead of being pushed off it by the chevron's width.
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
                    action: onBack)
                Spacer()
            }
        }
    }

    /// The gilded frame with the picture under a cover. The reveal wraps only the *picture*, not
    /// the ornament: rubbing the carved gold away would say the frame is what is being uncovered.
    private var revealableFrame: some View {
        KultaraPortraitFrame(accessibilityLabel: portraitLabel) {
            HisploraScratchReveal(onComplete: advanceAfterReveal) {
                HisploraPortraitContent(url: portraitURL)
            }
        }
        // The reveal is a gesture on a picture, and VoiceOver reaches it as the button below.
        .accessibilityHint(UIStrings.string(.cutsceneSwipeHint, language))
    }

    /// A beat after the last stroke, so the picture is seen whole before the screen changes. The
    /// walker rubbed it clear; showing them nothing of what they uncovered wastes the moment.
    private func advanceAfterReveal() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            advanceOnce()
        }
    }

    /// The rub finishing and the button being tapped are the same act, and both can happen — the
    /// button is on screen while the frame is still rubbable. Advancing twice would skip `187:866`
    /// entirely.
    private func advanceOnce() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        onAdvance()
    }
}

/// `187:866` — the subject named, with the quest's hook beneath it and the action to begin.
struct CutscenePortraitScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let portraitURL: URL?
    let portraitLabel: String
    /// The quest's title, from content. Never a baked-in name (`AD-4`).
    let title: String
    let subtitle: String?
    /// `quest.hookLore`, already resolved to the run's language.
    let hook: String
    let onStart: () -> Void
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
                    VStack(spacing: KultaraMetrics.lg) {
                        HisploraFramedImage(url: portraitURL, label: portraitLabel)
                            .padding(.horizontal, KultaraMetrics.xxl)
                        VStack(spacing: KultaraMetrics.sm) {
                            Text(title)
                                .kultaraFont(.storyDisplay)
                                .foregroundStyle(palette.inkCream.color)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityAddTraits(.isHeader)
                            if let subtitle {
                                Text(subtitle)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(palette.inkCream.color)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Text(hook)
                            .font(.system(size: 15))
                            .foregroundStyle(palette.inkDusty.color)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, KultaraMetrics.lg)
                    }
                    .padding(.vertical, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button(UIStrings.string(.cutsceneStartAction, language), action: onStart)
                    .buttonStyle(.hisploraPill)
            }
            .padding(KultaraMetrics.lg)
        }
    }
}

/// The gilded frame with whatever picture the content supplies, or the frame's own fallback when
/// there is none. Kept here rather than inside `KultaraPortraitFrame` because loading a bundled
/// content asset is an app concern — `DesignSystem` knows nothing about `ContentRepository`.
struct HisploraFramedImage: View {
    let url: URL?
    let label: String

    var body: some View {
        KultaraPortraitFrame(accessibilityLabel: label) {
            HisploraPortraitContent(url: url)
        }
    }
}

/// What goes *inside* the frame's opening, on its own so the cutscene can wrap it in the reveal
/// while every other screen sets it straight into the frame.
struct HisploraPortraitContent: View {
    let url: URL?

    var body: some View {
        if let url, let image = BundledImage.load(url) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // No picture is a legitimate state, not an error: the sample content ships no
            // portrait, and the frame is still the design's object. The reveal over an empty
            // opening is a wash lifting off a flat ground — undramatic, but not broken.
            Rectangle().fill(Color.black.opacity(0.18))
        }
    }
}
