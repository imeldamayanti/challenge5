import Foundation
import Testing
@testable import AppFeatures
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

/// `FR-ONB-04` — location permission must not be requested during onboarding; it is requested in
/// context at the first quest-start attempt. `FR-ONB-06` — no App Tracking Transparency prompt,
/// because nothing is collected for tracking. `NFR-BAT-01` — no continuous background location in
/// any release.
///
/// M5 builds no quest-start path at all, so the correct state of this module is that none of these
/// calls appear anywhere in it. A comment saying so would decay; this does not.
struct PermissionCallBoundaryTests {

    static let forbiddenCalls = [
        "requestWhenInUseAuthorization",   // FR-ONB-04
        "requestAlwaysAuthorization",      // FR-ONB-04, FR-PROX-03
        "startUpdatingLocation",           // NFR-BAT-01
        "startMonitoringSignificantLocationChanges",
        "startMonitoring(for:",            // FR-PROX is out of scope for M5
        "ATTrackingManager",               // FR-ONB-06
        "AppTrackingTransparency",
        "requestTrackingAuthorization",
    ]

    /// Reachability checks are forbidden everywhere by `AD-3`, not only in onboarding.
    static let forbiddenReachability = [
        "NWPathMonitor",
        "SCNetworkReachability",
        "isReachable",
    ]

    @Test func appFeaturesRequestsNoPermissionAndStartsNoLocationUpdates() throws {
        let offenders = try Self.occurrences(of: Self.forbiddenCalls, inTargetNamed: "AppFeatures")
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test func noModuleChecksReachability() throws {
        for target in ["AppFeatures", "ContentKit", "DesignSystem"] {
            let offenders = try Self.occurrences(of: Self.forbiddenReachability, inTargetNamed: target)
            #expect(offenders.isEmpty, "\(target): \(offenders)")
        }
    }

    @Test func appFeaturesDoesNotDrawMapsFromLiveTiles() throws {
        // FR-MAP-01: the route display must not depend on live map tiles, and MapKit exposes no
        // public offline tile cache. Preview renders a shipped image instead.
        let offenders = try Self.occurrences(of: ["import MapKit", "MKMapView", "Map("],
                                             inTargetNamed: "AppFeatures")
        #expect(offenders.isEmpty, "\(offenders)")
    }

    static func occurrences(of needles: [String], inTargetNamed target: String) throws -> [String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // AppFeaturesTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("Sources")
            .appendingPathComponent(target)

        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return ["No sources found under \(root.path)"]
        }
        let files = walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty, "No Swift files under \(root.path) — the scan would pass vacuously.")

        var offenders: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                // Skip comments: these strings appear in the requirement notes on purpose.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("*"), !trimmed.hasPrefix("/*") else { continue }
                for needle in needles where contains(line: String(line), needle: needle) {
                    offenders.append("\(file.lastPathComponent):\(number + 1) \(needle)")
                }
            }
        }
        return offenders
    }

    /// Substring matching with a left word boundary, because a bare `contains` cannot tell
    /// SwiftUI's `Map(` from Swift's `flatMap(` — and a guard that fires on `flatMap` is a guard
    /// someone eventually deletes rather than fixes. The boundary is only needed on the left: the
    /// needles all end in a delimiter or are whole tokens.
    private static func contains(line: String, needle: String) -> Bool {
        var search = line[...]
        while let found = search.range(of: needle) {
            let isBoundary = found.lowerBound == line.startIndex
                || !isIdentifierCharacter(line[line.index(before: found.lowerBound)])
            if isBoundary { return true }
            search = line[found.upperBound...]
        }
        return false
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
