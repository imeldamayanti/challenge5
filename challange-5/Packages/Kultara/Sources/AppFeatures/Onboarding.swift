import ContentKit
import DesignSystem
import SwiftUI

public struct OnboardingPage: Sendable, Identifiable {
    public let id: Int
    public let titleKey: UIStringKey
    public let bodyKey: UIStringKey
    public let symbolName: String
}

public enum OnboardingGate {
    @MainActor
    public static func shouldPresentOnboarding(store: any AppPreferencesStore) -> Bool {
        store.onboardingCompletedAt == nil
    }
}

/// `FR-ONB-01…06`. Four screens, skippable from the first, teaching the pocket-the-phone model
/// (`AD-1`), and asking for nothing: no account, no email, no location prompt, no tracking prompt.
@MainActor
@Observable
public final class OnboardingViewModel {

    public let pages: [OnboardingPage] = [
        OnboardingPage(id: 0, titleKey: .onboardingWelcomeTitle,
                       bodyKey: .onboardingWelcomeBody, symbolName: "figure.walk"),
        // FR-ONB-03 / AD-1. This screen is the whole safety model of the product, so it comes
        // second rather than last, where it would be skipped past.
        OnboardingPage(id: 1, titleKey: .onboardingPocketTitle,
                       bodyKey: .onboardingPocketBody, symbolName: "iphone.slash"),
        OnboardingPage(id: 2, titleKey: .onboardingAccuracyTitle,
                       bodyKey: .onboardingAccuracyBody, symbolName: "doc.text.magnifyingglass"),
        OnboardingPage(id: 3, titleKey: .onboardingRespectTitle,
                       bodyKey: .onboardingRespectBody, symbolName: "hands.and.sparkles"),
    ]

    public private(set) var pageIndex = 0
    public private(set) var isFinished = false

    private let store: any AppPreferencesStore

    public init(store: any AppPreferencesStore) {
        self.store = store
    }

    /// Always true. `FR-ONB-02` requires skippability *from the first screen*, and an escape hatch
    /// that appears only at the end is not one.
    public var isSkipAvailable: Bool { true }

    public var isLastPage: Bool { pageIndex >= pages.count - 1 }

    public var currentPage: OnboardingPage { pages[min(pageIndex, pages.count - 1)] }

    public var primaryActionKey: UIStringKey { isLastPage ? .onboardingStart : .onboardingNext }

    public func advance() {
        if isLastPage {
            finish()
        } else {
            pageIndex += 1
        }
    }

    public func skip() {
        finish()
    }

    private func finish() {
        if store.onboardingCompletedAt == nil {
            store.onboardingCompletedAt = Date()
        }
        isFinished = true
    }
}

// MARK: - View

public struct OnboardingView: View {
    @Environment(\.kultaraPalette) private var palette

    private let language: ContentLanguage
    @State private var model: OnboardingViewModel
    private let onFinish: () -> Void

    public init(store: any AppPreferencesStore, language: ContentLanguage, onFinish: @escaping () -> Void) {
        self.language = language
        self.onFinish = onFinish
        _model = State(initialValue: OnboardingViewModel(store: store))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
            header
            Spacer(minLength: KultaraMetrics.lg)
            page
            Spacer(minLength: KultaraMetrics.lg)
            footer
        }
        .padding(KultaraMetrics.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.paper.color)
        .onChange(of: model.isFinished) { _, finished in
            if finished { onFinish() }
        }
    }

    private var header: some View {
        HStack {
            Text(UIStrings.string(.appName, language))
                .kultaraFont(.sectionHeading)
                .foregroundStyle(palette.inkMuted.color)
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
                Image(systemName: model.currentPage.symbolName)
                    .font(.system(.largeTitle, design: .monospaced))
                    .foregroundStyle(palette.seal.color)
                    .accessibilityHidden(true)
                Text(UIStrings.string(model.currentPage.titleKey, language))
                    .kultaraFont(.questTitleLarge)
                    .foregroundStyle(palette.ink.color)
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

            Button { model.advance() } label: {
                Text(UIStrings.string(model.primaryActionKey, language))
                    .kultaraFont(.buttonLabel)
                    .foregroundStyle(palette.inkOnSeal.color)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    .background(palette.sealFill.color)
                    .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius))
            }
        }
    }
}
