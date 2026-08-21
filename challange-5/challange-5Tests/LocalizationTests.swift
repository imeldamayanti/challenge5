// Restored by m7 step 6 from b597b5b^ (Tests/AppFeaturesTests/LocalizationTests.swift).
// NFR-I18N-01/02/03/05. m7 calls this the step that matters most in raw terms: roughly fifty
// string keys were added during M6 and nothing has checked either language since.
import Foundation
import Testing
@testable import challange_5
import UIStringsKit
@testable import ContentKit

/// `NFR-I18N-01` — all user-facing strings externalised, none hardcoded. `NFR-I18N-02` — Indonesian
/// and English at full parity. UI strings go through the same `LocalizedText` pair as content, and
/// the same no-fallback rule, so an untranslated button cannot appear inside an Indonesian screen.
struct UIStringsTests {

    @Test func everyKeyHasAnEntry() {
        let missing = UIStringKey.allCases.filter { UIStrings.table[$0] == nil }
        #expect(missing.isEmpty, "Keys with no entry: \(missing.map(\.rawValue))")
    }

    @Test func everyEntryIsTranslatedInBothLanguages() {
        for key in UIStringKey.allCases {
            guard let text = UIStrings.table[key] else { continue }
            for language in ContentLanguage.allCases {
                let value = text.value(for: language)
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        "\(key.rawValue) has no \(language.rawValue) translation")
            }
        }
    }

    @Test func indonesianAndEnglishAreActuallyDifferentText() {
        // A copy-paste of the English string into the Indonesian slot passes a non-empty check
        // and ships a half-translated app. Two kinds of string are legitimately identical: the
        // app's own name, and SI unit symbols — `NFR-I18N-05` mandates metric units, and "m" is
        // "m" in both languages. Translating a unit symbol would be the actual bug.
        //
        // A third kind joined them after M6, found by restoring this very test: a string made
        // entirely of format specifiers and punctuation, such as a progress counter's
        // `"%1$d / %2$d"`. It contains no words, so it cannot be the half-translation this guard
        // exists to catch — and it is exempted by that PROPERTY rather than by name, so the guard
        // does not get shorter every time another one is added. Anything containing a letter must
        // still differ.
        // And a fourth: a loanword that *is* the Indonesian word. "Email" is what an Indonesian
        // form is labelled with; "surel" is the formal coinage and nobody types their address into
        // it. Exempted by name, because unlike the specifiers there is no property to test for.
        let identicalByDesign: Set<UIStringKey> = [
            .appName, .unitMetres, .unitKilometres, .authEmailPlaceholder]
        for key in UIStringKey.allCases where !identicalByDesign.contains(key) {
            guard let text = UIStrings.table[key] else { continue }
            // The specifiers themselves carry letters (`%1$d`), so they come out before the
            // question "does this string contain any words at all" can be asked honestly.
            let words = text.en.replacing(/%[0-9]*\$?[@a-zA-Z]/, with: "")
            guard words.contains(where: \.isLetter) else { continue }
            #expect(text.id != text.en, "\(key.rawValue) is identical in both languages")
        }
    }

    @Test func stringLookupReturnsExactlyTheRequestedLanguage() {
        let indonesian = UIStrings.string(.questListTitle, .id)
        let english = UIStrings.string(.questListTitle, .en)
        #expect(indonesian == UIStrings.table[.questListTitle]?.id)
        #expect(english == UIStrings.table[.questListTitle]?.en)
        #expect(indonesian != english)
    }

    @Test func theTableHasNoOrphanedEntries() {
        // An entry with no key means a string nobody can ask for — dead copy that still gets
        // translated and reviewed.
        #expect(UIStrings.table.count == UIStringKey.allCases.count)
    }
}

/// `FR-ONB-05` — language defaults to the device language when it is Indonesian or English, and to
/// English otherwise, and is changeable in Settings.
struct LanguageResolverTests {

    @Test(arguments: [
        (["id-ID"], ContentLanguage.id),
        (["id"], .id),
        (["in-ID"], .id),          // the legacy subtag some devices still report
        (["en-GB"], .en),
        (["en"], .en),
        (["ja-JP"], .en),          // anything else → English
        (["de-DE", "id-ID"], .en), // the *first* preference decides, not any match
        ([], .en),
    ])
    func deviceLanguageDecidesTheDefault(_ codes: [String], _ expected: ContentLanguage) {
        #expect(LanguageResolver.resolve(override: nil, deviceLanguageCodes: codes) == expected)
    }

    @Test func aSettingsOverrideBeatsTheDeviceLanguage() {
        #expect(LanguageResolver.resolve(override: .en, deviceLanguageCodes: ["id-ID"]) == .en)
        #expect(LanguageResolver.resolve(override: .id, deviceLanguageCodes: ["ja-JP"]) == .id)
    }

    @Test func caseAndRegionAreIgnored() {
        #expect(LanguageResolver.resolve(override: nil, deviceLanguageCodes: ["ID-id"]) == .id)
        #expect(LanguageResolver.resolve(override: nil, deviceLanguageCodes: ["EN-US"]) == .en)
    }
}

@MainActor
struct AppPreferencesStoreTests {

    @Test func aFreshInstallHasNoLanguageOverrideAndNoCompletedOnboarding() {
        let store = InMemoryAppPreferencesStore()
        #expect(store.preferredLanguage == nil)
        #expect(store.onboardingCompletedAt == nil)
    }

    @Test func aLanguageOverrideSurvivesBeingReadBack() {
        let store = InMemoryAppPreferencesStore()
        store.preferredLanguage = .id
        #expect(store.preferredLanguage == .id)
    }

    @Test func userDefaultsBackedStoreRoundTripsThroughASuite() throws {
        let suiteName = "kultara-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsAppPreferencesStore(defaults: defaults)
        store.preferredLanguage = .en
        store.onboardingCompletedAt = Date(timeIntervalSince1970: 1_000_000)

        let reopened = UserDefaultsAppPreferencesStore(defaults: defaults)
        #expect(reopened.preferredLanguage == .en)
        #expect(reopened.onboardingCompletedAt == Date(timeIntervalSince1970: 1_000_000))
    }

    @Test func anUnrecognisedStoredLanguageIsTreatedAsNoOverrideRatherThanCrashing() throws {
        // A build that once shipped a third language, or a corrupted domain, must not take the
        // app down on launch.
        let suiteName = "kultara-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("jv", forKey: UserDefaultsAppPreferencesStore.preferredLanguageKey)
        #expect(UserDefaultsAppPreferencesStore(defaults: defaults).preferredLanguage == nil)
    }

    @Test func removingAllClearsEverythingItOwns() throws {
        let suiteName = "kultara-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsAppPreferencesStore(defaults: defaults)
        store.preferredLanguage = .id
        store.onboardingCompletedAt = Date()
        store.removeAll()

        #expect(store.preferredLanguage == nil)
        #expect(store.onboardingCompletedAt == nil)
    }
}

struct ContentFormatterTests {

    @Test func zeroBytesReadsAsANumberNotAsTheWordZero() {
        // ByteCountFormatter's default renders 0 as "Zero KB", which reads as a bug in a Settings
        // row rather than as a measurement.
        let text = ContentFormatter(language: .en).bytes(0)
        #expect(!text.lowercased().contains("zero"), "\(text)")
        #expect(text.contains("0"), "\(text)")
    }

    @Test func distanceSwitchesToKilometresAtOneThousandMetres() {
        let formatter = ContentFormatter(language: .en)
        #expect(formatter.distance(metres: 999).contains("999"))
        #expect(formatter.distance(metres: 999).hasSuffix("m"))
        #expect(formatter.distance(metres: 1000).contains("1.0"))
        #expect(formatter.distance(metres: 2600).contains("2.6"))
    }

    @Test func indonesianUsesACommaAsTheDecimalSeparator() {
        // NFR-I18N-05 is about units; this is about the language the user is reading. "2.6 km" in
        // an Indonesian interface is wrong even on a US-locale phone.
        #expect(ContentFormatter(language: .id).distance(metres: 2600).contains("2,6"))
    }

    @Test func aFreeQuestFormatsAsFreeRatherThanAsZeroCurrency() {
        #expect(ContentFormatter(language: .en).cost(amount: 0, currency: "IDR") == "Free")
        #expect(ContentFormatter(language: .id).cost(amount: 0, currency: "IDR") == "Gratis")
    }

    @Test func indonesianRupiahIsShownWithoutMinorUnits() {
        let text = ContentFormatter(language: .id).cost(amount: 50_000, currency: "IDR")
        #expect(!text.contains(",00"), "\(text)")
        #expect(text.contains("50"), "\(text)")
    }
}
