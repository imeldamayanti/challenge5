import ContentKit
import DesignSystem
import SwiftUI

/// The paged story reveal — `105:1699`, `187:954`, `187:1053`.
///
/// One page per `LoreBlock`, so the `3/3` pager is `loreSegment.count` and the pages come from
/// content rather than from a fixed set of three.
///
/// **The `FR-CP-05` deviation.** The frames render historical claims as unlabelled prose: no
/// accuracy chip, no citation. That is a knowing departure from `FR-CP-05`, taken by the product
/// owner on 2026-08-13 and recorded in `.claude/plans/m8-qa-fixes.plan.md` (Decisions taken, item
/// 2) — it is *not* an oversight in this file, and it must not be quietly reverted either way.
/// `LoreBlock` still carries `accuracy` and `sourceRefs`; what changes is that this screen does not
/// display them, and the checkpoint screen — which still does — remains where the labels live. The
/// PRD needs the amendment or the signed exception; until it has one, this comment is the record.
struct StoryRevealScreen: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let language: ContentLanguage
    /// One entry per lore block, already resolved to the run's language.
    let pages: [String]
    /// The illustration behind each page, when the content ships one.
    let illustrationURL: URL?
    let onFinish: () -> Void
    let onBack: () -> Void

    @State private var index = 0

    private var isLastPage: Bool { index >= pages.count - 1 }

    var body: some View {
        HisploraStage(ground: \.paperWarm) {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                        illustration
                        // Keyed by index so the reveal restarts per page rather than continuing
                        // from the previous page's character count.
                        HisploraTypewriterText(currentPage, font: .system(size: 17))
                            .id(index)
                    }
                    .padding(.vertical, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                footer
            }
            .padding(KultaraMetrics.lg)
        }
    }

    private var currentPage: String {
        pages.indices.contains(index) ? pages[index] : ""
    }

    private var topBar: some View {
        HStack {
            HisploraBackButton(
                accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                ink: \.inkDark,
                action: back)
            Spacer()
            HisploraPager(
                current: index + 1,
                total: max(pages.count, 1),
                accessibilityLabel: String(
                    format: UIStrings.string(.storyRevealPager, language),
                    index + 1, max(pages.count, 1)))
        }
    }

    @ViewBuilder private var illustration: some View {
        if let illustrationURL, let image = BundledImage.load(illustrationURL) {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }

    private var footer: some View {
        HStack {
            // The auto-advance the transition screen has is deliberately absent here: a reader
            // moves through their own story at their own pace. A skip exists so a repeat walker is
            // not made to page through it again.
            Button(UIStrings.string(.storyRevealSkip, language), action: onFinish)
                .font(.system(size: 15))
                .foregroundStyle(palette.inkMuted.color)
            Spacer()
            HisploraNextButton(
                accessibilityLabel: isLastPage
                    ? UIStrings.string(.transitionContinue, language)
                    : UIStrings.string(.storyRevealNext, language),
                action: advance)
        }
    }

    private func advance() {
        guard !isLastPage else { return onFinish() }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { index += 1 }
    }

    private func back() {
        guard index > 0 else { return onBack() }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { index -= 1 }
    }
}

/// `187:1103` — the transition between the story and the walk.
///
/// The frame auto-advances after five seconds and blinks the place name. Both are honoured and both
/// are bounded: the timer does not run under Reduce Motion or VoiceOver, the blink never reaches
/// zero opacity, and a visible Continue control always exists — a screen that moves on by itself
/// while somebody is still reading it is a timing failure, not a transition (`NFR-A11Y-04/05`).
struct StoryTransitionScreen: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let language: ContentLanguage
    /// The quest's region or title, from content.
    let questName: String
    /// The place being walked to, from content.
    let placeName: String
    let route: RunRoutePresentation?
    let totalCheckpoints: Int
    let onContinue: () -> Void

    static let autoAdvance: Duration = .seconds(5)

    private var advancesOnItsOwn: Bool { !reduceMotion && !voiceOverEnabled }

    var body: some View {
        HisploraStage(ground: \.brownMid) {
            VStack(spacing: KultaraMetrics.xl) {
                Spacer()
                if let route {
                    RunRouteMapView(route: route,
                                    language: language,
                                    totalCheckpoints: totalCheckpoints,
                                    showsChrome: false)
                        .padding(KultaraMetrics.md)
                        .background(palette.paperCream.color,
                                    in: RoundedRectangle(cornerRadius: KultaraMetrics.sm))
                }
                VStack(spacing: KultaraMetrics.xs) {
                    Text(String(format: UIStrings.string(.transitionSteppingInto, language), questName))
                        .font(.system(size: 17))
                        .foregroundStyle(palette.inkCream.color.opacity(0.48))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(placeName)
                        .font(KultaraTypography.font(.questTitle))
                        .foregroundStyle(palette.inkCream.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .hisploraBlink()
                        .accessibilityAddTraits(.isHeader)
                }
                Spacer()
                Button(UIStrings.string(.transitionContinue, language), action: onContinue)
                    .buttonStyle(.hisploraPill)
            }
            .padding(KultaraMetrics.lg)
            .task {
                guard advancesOnItsOwn else { return }
                try? await Task.sleep(for: Self.autoAdvance)
                guard !Task.isCancelled else { return }
                onContinue()
            }
        }
    }
}
