import ContentKit
import Foundation
import UIStringsKit

enum OnboardingGate {
    @MainActor
    static func shouldPresentOnboarding(store: any AppPreferencesStore) -> Bool {
        store.onboardingCompletedAt == nil
    }
}

/// `FR-ONB-01…06`. Four screens, skippable from the first, teaching the pocket-the-phone model
/// (`AD-1`), and asking for nothing: no account, no email, no location prompt, no tracking prompt.
///
/// **Why four screens when Figma draws three.** `523:1946`, `523:1973` and `523:1999` are Explore /
/// Quest / Collection, and none of the three explains that the phone goes in a pocket between
/// checkpoints. `FR-ONB-03` is a P0 MUST and `AD-1` is the safety model of the whole product, so the
/// screen survives the redesign; `FR-ONB-02` allows four, so nothing has to be traded to keep it. It
/// sits *second* rather than last for the reason it always did — a walker who taps Skip on screen
/// three has still been told, and one who is told on the last screen has not.
///
/// What the redesign did drop is the two screens no requirement asked for: the accuracy-label screen
/// (the labels themselves are on every lore block, where `FR-CP-05` actually puts them) and the
/// still-in-use screen (dress and photo rules are shown before any task by `PlaceNoticeScreen`,
/// which is where `FR-TASK-05` puts them). Both taught something the app teaches again in context;
/// neither is lost.
@MainActor
@Observable
final class OnboardingViewModel {

    let pages: [OnboardingPage] = [
        // `523:1946`.
        OnboardingPage(id: 0, titleKey: .onboardingExploreTitle,
                       bodyKey: .onboardingExploreBody, illustration: .art("explore")),
        // FR-ONB-03 / AD-1. The one screen with no frame behind it, so it carries a symbol rather
        // than an illustration — an invented picture would read as a fourth Figma screen and this
        // one is deliberately not that.
        OnboardingPage(id: 1, titleKey: .onboardingPocketTitle,
                       bodyKey: .onboardingPocketBody, illustration: .symbol("figure.walk.motion")),
        // `523:1973`.
        OnboardingPage(id: 2, titleKey: .onboardingQuestTitle,
                       bodyKey: .onboardingQuestBody, illustration: .art("quest")),
        // `523:1999`, the terminal screen: one wide action instead of the Skip/Next pair.
        OnboardingPage(id: 3, titleKey: .onboardingCollectionTitle,
                       bodyKey: .onboardingCollectionBody, illustration: .art("collection")),
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

    /// Whether the screen draws a Skip control beside the primary action.
    ///
    /// Not the same question as `isSkipAvailable`, which is the requirement. `523:1999` replaces the
    /// pair with a single full-width "Begin Your First Quest", and on that screen the primary action
    /// and Skip would do the same thing — finish onboarding — so drawing both would offer the walker
    /// a choice that is not one.
    var showsSkipControl: Bool { !isLastPage }

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
