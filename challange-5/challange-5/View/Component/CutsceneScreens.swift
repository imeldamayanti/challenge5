import ContentKit
import DesignSystem
import SwiftUI

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

/// `98:1588` — "A Legend Will Guide Your Journey", the framed image, and the hint to continue.
struct CutsceneIntroScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let portraitURL: URL?
    let portraitLabel: String
    let onAdvance: () -> Void
    let onBack: () -> Void

    var body: some View {
        HisploraStage(ground: \.brownMid) {
            VStack(spacing: 0) {
                HStack {
                    HisploraBackButton(
                        accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                        action: onBack)
                    Spacer()
                }
                ScrollView {
                    VStack(spacing: KultaraMetrics.xl) {
                        Text(UIStrings.string(.cutsceneLegendTitle, language))
                            .font(KultaraTypography.font(.questTitleLarge))
                            .foregroundStyle(palette.inkCream.color)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        HisploraFramedImage(url: portraitURL, label: portraitLabel)
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
                // The frame says "swipe photo frame to reveal". A swipe is offered, but it is never
                // the only way forward — a gesture with no visible control is a dead end for anyone
                // who does not discover it, and for VoiceOver it is not a control at all.
                Button(UIStrings.string(.storyRevealNext, language), action: onAdvance)
                    .buttonStyle(.hisploraPill)
            }
            .padding(KultaraMetrics.lg)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        if value.translation.width < -24 { onAdvance() }
                    })
        }
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
        HisploraStage(ground: \.brownMid) {
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
                                .font(KultaraTypography.font(.questTitleLarge))
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
            if let url, let image = BundledImage.load(url) {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // No picture is a legitimate state, not an error: the sample content ships no
                // portrait, and the frame is still the design's object.
                Rectangle().fill(Color.black.opacity(0.18))
            }
        }
    }
}
