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

    @Test func oneScreenTeachesThePocketThePhoneWalkingModel() {
        // FR-ONB-03. AD-1 says this must be taught, not left to be discovered.
        let model = OnboardingViewModel(store: InMemoryAppPreferencesStore())
        #expect(model.pages.contains { $0.bodyKey == .onboardingPocketBody })
        #expect(model.pages.contains { $0.titleKey == .onboardingPocketTitle })
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

    @Test func aReturningUserSkipsOnboardingEntirely() {
        // FR-ONB-01: the app is usable on first launch with no account. It must also not re-ask.
        let store = InMemoryAppPreferencesStore(onboardingCompletedAt: Date())
        #expect(!OnboardingGate.shouldPresentOnboarding(store: store))
        #expect(OnboardingGate.shouldPresentOnboarding(store: InMemoryAppPreferencesStore()))
    }
}
