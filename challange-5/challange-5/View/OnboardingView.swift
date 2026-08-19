import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

struct OnboardingView: View {
    @Environment(\.kultaraPalette) private var palette

    private let language: ContentLanguage
    @State private var model: OnboardingViewModel
    private let onFinish: () -> Void

    init(store: any AppPreferencesStore, language: ContentLanguage, onFinish: @escaping () -> Void) {
        self.language = language
        self.onFinish = onFinish
        _model = State(initialValue: OnboardingViewModel(store: store))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
            header
            Spacer(minLength: KultaraMetrics.lg)
            page
            Spacer(minLength: KultaraMetrics.lg)
            footer
        }
        .padding(KultaraMetrics.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .kultaraGround()
        .onChange(of: model.isFinished) { _, finished in
            if finished { onFinish() }
        }
    }

    private var header: some View {
        HStack {
            KultaraEyebrow(UIStrings.string(.appName, language))
            Spacer()
            if model.isSkipAvailable {
                Button { model.skip() } label: {
                    Text(UIStrings.string(.onboardingSkip, language))
                        .kultaraFont(.buttonLabel)
                        .kultaraTapTarget()
                }
                .foregroundStyle(palette.seal.color)
            }
        }
    }

    private var page: some View {
        // `ScrollView` rather than a fixed layout: at the largest accessibility size this body copy
        // is far taller than any iPhone (`NFR-A11Y-01`).
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                // The symbol sits inside a ruled square, the way the reference sets an ornament:
                // framed rather than floating, so it belongs to the page instead of decorating it.
                Image(systemName: model.currentPage.symbolName)
                    .font(.system(.title, design: .default))
                    .foregroundStyle(palette.seal.color)
                    .frame(width: 64, height: 64)
                    .overlay(Rectangle()
                        .stroke(palette.rule.color, lineWidth: KultaraMetrics.hairline))
                    .accessibilityHidden(true)
                Text(UIStrings.string(model.currentPage.titleKey, language))
                    .kultaraFont(.questTitleLarge)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                KultaraRule()
                Text(UIStrings.string(model.currentPage.bodyKey, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        VStack(spacing: KultaraMetrics.md) {
            // Progress as text as well as dots: no essential information carried by shape alone
            // (`NFR-A11Y-04/05`).
            HStack(spacing: KultaraMetrics.sm) {
                ForEach(model.pages) { page in
                    Circle()
                        .fill(page.id == model.pageIndex ? palette.seal.color : palette.rule.color)
                        .frame(width: 7, height: 7)
                }
                Spacer()
                Text("\(model.pageIndex + 1)/\(model.pages.count)")
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.pageIndex + 1) / \(model.pages.count)")

            // The ticket button: the page's one filled control, so it is unmistakably the thing to
            // press. Skip, above, stays a plain word — `FR-ONB-02` wants it available, not loud.
            Button(UIStrings.string(model.primaryActionKey, language)) { model.advance() }
                .buttonStyle(.seal)
        }
    }
}
