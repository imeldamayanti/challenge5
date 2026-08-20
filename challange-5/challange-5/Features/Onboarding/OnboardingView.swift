import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// Onboarding, on the Hisplora direction — Figma `702:2068`, `702:1999` and `702:1980`.
///
/// The frames: a cream ground (`paperSheet`), a three-segment position bar under the status bar, an
/// underlined Skip at the top right, one illustration filling the upper third, a 30-point New York
/// title, a 17-point sans paragraph, and at the foot a near-black pill — half-width "Next" on the
/// first two screens, full-width "Begin Your First Quest" on the last.
///
/// **What the 2026-08-20 redesign changed.** The board moved onboarding off `brownMid` and onto
/// cream, which flips every ink on the screen: `inkCream` type becomes `buttonFill`, the progress
/// bar's dim segment is re-composited over the new ground (`trackDim`, re-sampled), and the pill
/// drops the hairline it needed on brown — see `HisploraPillButtonStyle` on why that ring is wrong
/// here rather than merely unnecessary. Skip moved from a footer pill to a top-right text link, so
/// it now reads as leaving rather than as the second of two ways forward, and it is drawn on every
/// screen including the last.
///
/// **Why the whole screen moves to Hisplora rather than half of it.** The seam between the two
/// visual directions falls between screens and never inside one; that is the rule the run flow was
/// built on and this is the same move applied to the app's first screen. Onboarding is the one
/// Hisplora surface reached before the museum theme is ever seen, which is fine — it is a screen
/// boundary, and `KultaraRootView` shows exactly one of the two.
///
/// **Three screens, and all three are the board's.** A fourth carrying `FR-ONB-03` used to stand
/// second; it was removed on 2026-08-20 for exact frame parity, which is a live gap against the PRD
/// — `OnboardingViewModel` has the whole account and where the walker is told instead.
struct OnboardingView: View {
    @Environment(\.hisploraPalette) private var palette

    /// `702:2068`'s own margins, in its own 402-point terms — the same 20 `CheckpointDetailScreen`
    /// takes from `452:3132`, and not on `KultaraMetrics`' spacing scale for the same reason: it is
    /// this board's page margin, not a step of the museum theme's rhythm.
    private static let margin: CGFloat = 20

    /// 514 − 182 on the frame: the band between the Skip link and the title, which the illustration
    /// stands in. Given as a box rather than as the picture's own height so the title lands in the
    /// same place on all three screens — the exports are 277, 257 and 274 points tall and the frame
    /// positions the title absolutely, which amounts to the same thing.
    private static let illustrationBand: CGFloat = 332

    /// 182 − 122: the air between the Skip link's box and the top of the picture. Measured from the
    /// link rather than from the bar, because the link is what the header actually ends with —
    /// 17-point type padded out to its 44-point target lands its box at 122 on the frame's own
    /// numbers.
    private static let illustrationTop: CGFloat = 60

    /// 599 − 514: the room the frame leaves the title before the paragraph starts.
    ///
    /// A floor, not a height. The board sets both tops absolutely, so a one-line title ("History
    /// Becomes A Quest") is followed by 55 points of air and a two-line one by 25 — reproduced as
    /// "the paragraph starts at 599 unless the title has grown past it", which is what a fixed body
    /// top actually means once the type can scale (`NFR-A11Y-01`).
    private static let titleBand: CGFloat = 85

    private let language: ContentLanguage
    @State private var model: OnboardingViewModel
    private let onFinish: () -> Void

    init(store: any AppPreferencesStore, language: ContentLanguage, onFinish: @escaping () -> Void) {
        self.language = language
        self.onFinish = onFinish
        _model = State(initialValue: OnboardingViewModel(store: store))
    }

    var body: some View {
        HisploraStage(ground: \.paperSheet) {
            VStack(spacing: 0) {
                header
                page
                footer
            }
        }
        .onChange(of: model.isFinished) { _, finished in
            if finished { onFinish() }
        }
    }

    /// `737:4732`: the bar at 74, the Skip link at 98.
    private var header: some View {
        VStack(alignment: .trailing, spacing: 0) {
            HisploraProgressBar(
                current: model.pageIndex,
                total: model.pages.count,
                accessibilityLabel: String(
                    format: UIStrings.string(.onboardingProgress, language),
                    model.pageIndex + 1, model.pages.count))
            if model.showsSkipControl {
                Button(UIStrings.string(.onboardingSkip, language)) { model.skip() }
                    .buttonStyle(.hisploraTextLink)
            }
        }
        .padding(.horizontal, Self.margin)
        // 74 on the frame, under a 62-point status bar.
        .padding(.top, KultaraMetrics.md)
    }

    /// The illustration and the words, in one scroll.
    ///
    /// A `ScrollView` rather than the frame's fixed positions: at the largest accessibility size the
    /// title and paragraph together are taller than any iPhone, and the picture is the thing that
    /// has to give way rather than the copy (`NFR-A11Y-01`). The foot stays outside it, so the
    /// action never scrolls out of reach.
    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                illustration
                    .frame(maxWidth: .infinity)
                    // Top-aligned, not centred: the frames put every picture's top edge at 182 and
                    // let them end at different heights, so centring in the band would shift each
                    // one by half its own difference from the tallest.
                    .frame(height: Self.illustrationBand, alignment: .top)
                    .padding(.top, Self.illustrationTop)
                Text(UIStrings.string(model.currentPage.titleKey, language))
                    .kultaraFont(.onboardingDisplay)
                    .foregroundStyle(palette.buttonFill.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, minHeight: Self.titleBand, alignment: .topLeading)
                    .padding(.horizontal, Self.margin)
                Text(UIStrings.string(model.currentPage.bodyKey, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.buttonFill.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Self.margin)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The picture changes with the page and the words change under it; without this the two
        // cross-fade out of step and the screen reads as one element being swapped inside another.
        .id(model.pageIndex)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: model.pageIndex)
    }

    @ViewBuilder
    private var illustration: some View {
        switch model.currentPage.illustration {
        case .art(let name):
            if let art = HisploraOnboardingArt(rawValue: name), let image = art.image {
                image
                    .resizable()
                    .scaledToFit()
                    // The exports are wider than the 362-point text column — `explore` is the whole
                    // frame less 12 points — so the picture is sized against the screen rather than
                    // against the column, and laid out outside the page's horizontal padding.
                    .containerRelativeFrame(.horizontal) { width, _ in width * art.widthFraction }
                    // Decoration. Everything the picture says, the title and the paragraph beside it
                    // say in words (`NFR-A11Y-04`).
                    .accessibilityHidden(true)
            }
        }
    }

    /// `702:2074` and `702:1990`: the near-black pill, at half the row's width or all of it.
    private var footer: some View {
        HStack(spacing: KultaraMetrics.md) {
            if !model.primaryActionFillsTheRow {
                // The other half of the row. `702:2075` draws a Skip pill here at zero opacity;
                // this is that space with no control in it, because a control nobody can see is a
                // thing VoiceOver still finds.
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
            Button(UIStrings.string(model.primaryActionKey, language)) { model.advance() }
                .buttonStyle(.hisploraPillOnPaper)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, KultaraMetrics.xl)
        // 874 − 789 on the frame, less the 34 the home indicator's safe-area inset already gives.
        .padding(.bottom, KultaraMetrics.xxl + KultaraMetrics.lg)
    }
}
