import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// Onboarding, on the Hisplora direction — Figma `523:1946`, `523:1973` and `523:1999`.
///
/// The frames: a mid-brown ground, a segmented position bar under the status bar, one illustration
/// filling the upper half, a 30-point New York title, a 17-point sans paragraph, and at the foot
/// either a Skip/Next pair or — on the last screen — one wide "Begin Your First Quest".
///
/// **Why the whole screen moves to Hisplora rather than half of it.** The seam between the two
/// visual directions falls between screens and never inside one; that is the rule the run flow was
/// built on and this is the same move applied to the app's first screen. Onboarding is now the one
/// Hisplora surface reached before the museum theme is ever seen, which is fine — it is a screen
/// boundary, and `KultaraRootView` shows exactly one of the two.
///
/// **The fourth screen is not in Figma.** `OnboardingViewModel` explains why it exists; here it is
/// simply the one page whose illustration is a symbol rather than an export.
struct OnboardingView: View {
    @Environment(\.hisploraPalette) private var palette

    /// `523:1946`'s own margins, in its own 402-point terms — the same 20 `CheckpointDetailScreen`
    /// takes from `452:3132`, and not on `KultaraMetrics`' spacing scale for the same reason: it is
    /// this board's page margin, not a step of the museum theme's rhythm.
    private static let margin: CGFloat = 20

    private let language: ContentLanguage
    @State private var model: OnboardingViewModel
    private let onFinish: () -> Void

    init(store: any AppPreferencesStore, language: ContentLanguage, onFinish: @escaping () -> Void) {
        self.language = language
        self.onFinish = onFinish
        _model = State(initialValue: OnboardingViewModel(store: store))
    }

    var body: some View {
        HisploraStage(ground: \.brownMid) {
            VStack(spacing: 0) {
                HisploraProgressBar(
                    current: model.pageIndex,
                    total: model.pages.count,
                    accessibilityLabel: String(
                        format: UIStrings.string(.onboardingProgress, language),
                        model.pageIndex + 1, model.pages.count))
                    .padding(.horizontal, Self.margin)
                    // 74 on the frame, under a 62-point status bar.
                    .padding(.top, KultaraMetrics.md)
                page
                footer
            }
        }
        .onChange(of: model.isFinished) { _, finished in
            if finished { onFinish() }
        }
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
                    // 188 on the frame, measured from the bar at 78.
                    .padding(.top, 110)
                Text(UIStrings.string(model.currentPage.titleKey, language))
                    .kultaraFont(.onboardingDisplay)
                    .foregroundStyle(palette.inkCream.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, Self.margin)
                    .padding(.top, KultaraMetrics.xxl + KultaraMetrics.lg)
                Text(UIStrings.string(model.currentPage.bodyKey, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.inkCream.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Self.margin)
                    .padding(.top, KultaraMetrics.xl)
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
        case .symbol(let symbolName):
            Image(systemName: symbolName)
                .font(.system(size: 96, weight: .light))
                .foregroundStyle(palette.inkCream.color)
                .frame(width: 200, height: 200)
                .background(
                    Circle().stroke(palette.buttonRing.color, lineWidth: KultaraMetrics.hairline))
                .accessibilityHidden(true)
        }
    }

    /// `523:2029` and `523:2050`: two equal pills, or one wide one on the last screen.
    private var footer: some View {
        HStack(spacing: KultaraMetrics.md) {
            if model.showsSkipControl {
                Button(UIStrings.string(.onboardingSkip, language)) { model.skip() }
                    .buttonStyle(.hisploraLightPill)
            }
            Button(UIStrings.string(model.primaryActionKey, language)) { model.advance() }
                .buttonStyle(.hisploraPill)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, KultaraMetrics.xl)
        // 874 − 825 on the frame, above the home indicator's own inset.
        .padding(.bottom, KultaraMetrics.md)
    }
}
