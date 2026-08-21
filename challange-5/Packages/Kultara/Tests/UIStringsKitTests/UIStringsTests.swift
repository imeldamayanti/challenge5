import ContentKit
import Testing
@testable import UIStringsKit

/// The three guards `NFR-I18N-01` and `NFR-I18N-02` are actually held by.
///
/// They existed in `AppFeaturesTests` until `b597b5b` deleted that target, and from then until `s4`
/// they were held by nothing: the app target has no unit-test bundle, so a `UIStringKey` case added
/// without a table entry rendered its own raw name on screen and no suite failed. Moving the table
/// into `UIStringsKit` is what put them back (`s4` §8, option 2).
///
/// The third one is the one that catches the real mistake. A missing entry is loud; an entry whose
/// Indonesian and English are the same pasted sentence is silent, and it ships.
@Suite("UI strings")
struct UIStringsTests {

    /// Every declared key has a row in the table. Without this, `UIStrings.string` falls through to
    /// `key.rawValue` and the interface shows `sideQuestNoticeYes` where a button label belongs.
    @Test func everyKeyHasAnEntry() {
        let missing = UIStringKey.allCases.filter { UIStrings.table[$0] == nil }
        #expect(missing.isEmpty, "No table entry for: \(missing.map(\.rawValue).sorted())")
    }

    /// Both languages, on every row. `LocalizedText` has no fallback (`NFR-I18N-03`), so an empty
    /// side is a blank label rather than a graceful degradation into the other language.
    @Test func everyEntryIsTranslatedInBothLanguages() {
        let empty = UIStringKey.allCases.filter { key in
            guard let text = UIStrings.table[key] else { return false }
            return text.value(for: .id).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || text.value(for: .en).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        #expect(empty.isEmpty, "Untranslated: \(empty.map(\.rawValue).sorted())")
    }

    /// Indonesian and English are different text.
    ///
    /// The exemptions are the rows where one string genuinely serves both readers: units and format
    /// skeletons that are digits and separators, and two proper nouns. Everything else that reads
    /// identically in both columns is an untranslated string that was pasted rather than written,
    /// and this is the only thing that would ever notice.
    @Test func indonesianAndEnglishAreActuallyDifferentText() {
        let deliberatelyIdentical: Set<UIStringKey> = [
            .appName,                 // a name, not a word
            .settingsLanguageIndonesian,  // "Bahasa Indonesia" is the endonym in both columns
            .unitMetres, .unitKilometres,
            .unitCheckpointSingular, .unitCheckpointPlural,  // "titik" is both singular and plural
            .collectionProgress,      // "%1$d / %2$d" — digits and a slash
            .collectionBadgeAwarded,  // shares `runBadgeAwarded`'s wording by design
            // "Email" is the everyday Indonesian word. The formal coinage "surel" exists and is
            // not what anyone types it into a form as, so a field labelled with it would be a
            // translation nobody asked for.
            .authEmailPlaceholder,
        ]
        let identical = UIStringKey.allCases.filter { key in
            guard !deliberatelyIdentical.contains(key), let text = UIStrings.table[key] else {
                return false
            }
            return text.value(for: .id) == text.value(for: .en)
        }
        #expect(identical.isEmpty,
                "Identical in both languages: \(identical.map(\.rawValue).sorted())")
    }
}
