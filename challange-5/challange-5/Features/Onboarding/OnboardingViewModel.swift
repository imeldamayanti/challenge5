import ContentKit
import Foundation
import UIStringsKit

enum OnboardingGate {
    @MainActor
    static func shouldPresentOnboarding(store: any AppPreferencesStore) -> Bool {
        store.onboardingCompletedAt == nil
    }
}

/// `FR-ONB-01`, `02`, `04`, `05`, `06`. Three screens, skippable from the first, and asking for
/// nothing: no account, no email, no location prompt, no tracking prompt.
///
/// **`FR-ONB-03` is not met by this screen any more, and that is a decision rather than an
/// oversight.** The requirement says onboarding *must* explain the pocket-the-phone walking model
/// (`AD-1`). A fourth screen carrying it stood second here from the first board until 2026-08-20,
/// when the owner asked for exact parity with `702:2068` / `702:1999` / `702:1980` — three screens,
/// Explore / Quest / Collection — and it was removed on that instruction.
///
/// **The walker is still told, and by the same words.** `QuestRunView.safetyNotice` — the
/// `FR-START-04` screen shown before the first Run of every quest, with an "I understand" the
/// walker has to tap — already printed this screen's paragraph under the quest's authored
/// `safetyNotes`, and still does. The string outlived the screen and was renamed
/// `onboardingPocketBody` → `safetyPocketBody` to say where it is now read; the *title* had no
/// second caller and went. So `AD-1` is taught as a UI string on a screen nobody can walk past,
/// which is a stronger guarantee than the authored `safetyNotes` beside it (no validator rule
/// requires a quest's notes to mention the phone at all).
///
/// What is genuinely lost is the *timing*: it is taught before the first walk rather than before
/// the app is first used, and a walker who never starts a quest is never told. That is the gap, and
/// it is what `FR-ONB-03` literally asks for — the PRD still carries it as a P0 MUST, so it wants
/// an amendment or a signed exception with an owner, the way `FR-START-04`'s was signed on
/// 2026-08-16. Until it has one this class is knowingly out of step with the spec.
///
/// What the 2026-08-18 redesign had already dropped is the two screens no requirement asked for:
/// the accuracy-label screen (the labels themselves are on every lore block, where `FR-CP-05`
/// actually puts them) and the still-in-use screen (dress and photo rules are shown before any task
/// by `PlaceNoticeScreen`, which is where `FR-TASK-05` puts them). Both taught something the app
/// teaches again in context; neither is lost.
@MainActor
@Observable
final class OnboardingViewModel {

    let pages: [OnboardingPage] = [
        // `702:2068`.
        OnboardingPage(id: 0, titleKey: .onboardingExploreTitle,
                       bodyKey: .onboardingExploreBody, illustration: .art("explore")),
        // `702:1999`.
        OnboardingPage(id: 1, titleKey: .onboardingQuestTitle,
                       bodyKey: .onboardingQuestBody, illustration: .art("quest")),
        // `702:1980`, the terminal screen: one full-width action instead of the half-width Next.
        OnboardingPage(id: 2, titleKey: .onboardingCollectionTitle,
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

    /// Whether the screen draws a Skip control.
    ///
    /// Always true now, and that is the redesign's own change rather than a relaxation. The earlier
    /// board put Skip in the footer as a pill beside Next, so the last screen — where Skip and
    /// "Begin Your First Quest" do the same thing — had to drop it or offer a choice that is not
    /// one. `702:2068`, `702:1999` and `702:1980` move it to the top right as an underlined link on
    /// all three, where it reads as leaving rather than as the second of two ways forward, and the
    /// footer carries the one action.
    ///
    /// Kept as a property rather than folded into the view, because `isSkipAvailable` is the
    /// requirement and this is what the screen draws; collapsing the two would make a layout change
    /// look like a requirements change the next time they diverge.
    var showsSkipControl: Bool { true }

    /// Whether the primary action fills the row or takes the right half of it.
    ///
    /// `702:2075` and `702:2010` draw a Skip pill at zero opacity beside Next, which is a designer
    /// leaving the old two-pill row in place with one half switched off — so Next is drawn at half
    /// width on the first two screens and `702:1990` fills the row on the last. Reproduced as the
    /// result rather than as the mechanism: there is no invisible control here, just a narrower one.
    var primaryActionFillsTheRow: Bool { isLastPage }

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
