// Restored by m7 step 5 from b597b5b^ (Tests/AppFeaturesTests/OnboardingTests.swift).
// Import only: @testable import AppFeatures became @testable import challange_5, and UIStrings
// moved into its own UIStringsKit target after the plan was written.
import Foundation
import Testing
@testable import challange_5
import UIStringsKit
@testable import ContentKit

@MainActor
struct OnboardingTests {

    @Test func onboardingIsAtMostFourScreens() {
        // FR-ONB-02
        #expect(OnboardingViewModel(store: InMemoryAppPreferencesStore()).pages.count <= 4)
    }

    @Test func skipIsAvailableFromTheFirstScreen() {
        // FR-ONB-02 says skippable *from the first screen* — not from the last one, which is
        // where a "skip" that only appears at the end would put it.
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        #expect(model.pageIndex == 0)
        #expect(model.isSkipAvailable)
    }

    @Test func skipRemainsAvailableOnEveryScreen() {
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        for _ in 0..<model.pages.count {
            #expect(model.isSkipAvailable)
            model.advance()
        }
    }

    /// **`FR-ONB-03` is no longer met here, and this test says so rather than disappearing.**
    ///
    /// It used to assert the opposite — that one screen taught the pocket-the-phone model
    /// (`AD-1`). The owner asked on 2026-08-20 for exact parity with the three Figma frames, so
    /// that screen was removed. Deleting the guard silently would have left nothing in the suite
    /// pointing at a P0 MUST the app stopped satisfying, so it is inverted instead: onboarding is
    /// the board's three screens, and the walker meets `AD-1` on the `FR-START-04` safety notice
    /// instead, which prints the very same paragraph (`safetyPocketBody`) and cannot be walked
    /// past. What is lost is the timing, not the words.
    ///
    /// If the screen comes back, this test fails and `OnboardingViewModel`'s note is what to read.
    /// If the PRD is amended or an exception is signed with an owner, this is where to record it.
    @Test func onboardingIsTheBoardsThreeScreensAndNoLongerTeachesThePocketModel() {
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        #expect(model.pages.count == 3)
        #expect(model.pages.map(\.titleKey) == [
            .onboardingExploreTitle, .onboardingQuestTitle, .onboardingCollectionTitle,
        ])
    }

    @Test func everyScreenHasTranslatedTitleAndBody() {
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        for page in model.pages {
            for language in ContentLanguage.allCases {
                #expect(!UIStrings.string(page.titleKey, language).isEmpty)
                #expect(!UIStrings.string(page.bodyKey, language).isEmpty)
            }
        }
    }

    @Test func skippingMarksOnboardingCompleteSoItDoesNotReappear() {
        let store = InMemoryAppPreferencesStore()
        let model = OnboardingViewModel(store: store)
        model.skip()
        #expect(store.onboardingCompletedAt != nil)
        #expect(model.isFinished)
    }

    @Test func advancingPastTheLastScreenFinishes() {
        let store = InMemoryAppPreferencesStore()
        let model = OnboardingViewModel(store: store)
        for _ in 0..<model.pages.count { model.advance() }
        #expect(model.isFinished)
        #expect(store.onboardingCompletedAt != nil)
    }

    @Test func advancingDoesNotRunOffTheEndOfThePageList() {
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        for _ in 0..<(model.pages.count + 5) { model.advance() }
        #expect(model.pageIndex <= model.pages.count - 1)
    }

    @Test func theLastScreenOffersStartRatherThanNext() {
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        #expect(model.primaryActionKey == .onboardingNext)
        for _ in 0..<(model.pages.count - 1) { model.advance() }
        #expect(model.isLastPage)
        #expect(model.primaryActionKey == .onboardingStart)
    }

    /// `702:2068`, `702:1999` and `702:1980` all draw the underlined Skip at the top right,
    /// including the last screen — which the earlier board could not do, because there Skip was a
    /// footer pill beside the primary action and on the last screen the two did the same thing.
    /// Moving it into the header is what makes it drawable everywhere, so it is asserted everywhere.
    @Test func theSkipLinkIsDrawnOnEveryScreenIncludingTheLast() {
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        for _ in 0..<model.pages.count {
            #expect(model.showsSkipControl)
            model.advance()
        }
    }

    /// `702:2074` draws Next at half the row's width and `702:1990` fills the row with "Begin Your
    /// First Quest". The half-width state is the first screens', not the last one's.
    @Test func onlyTheLastScreensActionFillsTheFooterRow() {
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        for _ in 0..<(model.pages.count - 1) {
            #expect(!model.primaryActionFillsTheRow)
            model.advance()
        }
        #expect(model.isLastPage)
        #expect(model.primaryActionFillsTheRow)
    }

    @Test func aReturningUserSkipsOnboardingEntirely() {
        // FR-ONB-01: the app is usable on first launch with no account. It must also not re-ask.
        let store = InMemoryAppPreferencesStore(onboardingCompletedAt: Date())
        #expect(!OnboardingGate.shouldPresentOnboarding(store: store))
        #expect(OnboardingGate.shouldPresentOnboarding(store: InMemoryAppPreferencesStore()))
    }
}
