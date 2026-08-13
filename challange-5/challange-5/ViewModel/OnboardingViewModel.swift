import ContentKit
import Foundation

enum OnboardingGate {
    @MainActor
    static func shouldPresentOnboarding(store: any AppPreferencesStore) -> Bool {
        store.onboardingCompletedAt == nil
    }
}

/// `FR-ONB-01…06`. Four screens, skippable from the first, teaching the pocket-the-phone model
/// (`AD-1`), and asking for nothing: no account, no email, no location prompt, no tracking prompt.
@MainActor
@Observable
final class OnboardingViewModel {

    let pages: [OnboardingPage] = [
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

    private(set) var pageIndex = 0
    private(set) var isFinished = false

    private let store: any AppPreferencesStore

    init(store: any AppPreferencesStore) {
        self.store = store
    }

    /// Always true. `FR-ONB-02` requires skippability *from the first screen*, and an escape hatch
    /// that appears only at the end is not one.
    var isSkipAvailable: Bool { true }

    var isLastPage: Bool { pageIndex >= pages.count - 1 }

    var currentPage: OnboardingPage { pages[min(pageIndex, pages.count - 1)] }

    var primaryActionKey: UIStringKey { isLastPage ? .onboardingStart : .onboardingNext }

    func advance() {
        if isLastPage {
            finish()
        } else {
            pageIndex += 1
        }
    }

    func skip() {
        finish()
    }

    private func finish() {
        if store.onboardingCompletedAt == nil {
            store.onboardingCompletedAt = Date()
        }
        isFinished = true
    }
}
