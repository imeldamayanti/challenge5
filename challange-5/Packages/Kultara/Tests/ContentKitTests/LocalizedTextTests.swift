import Foundation
import Testing
@testable import ContentKit

/// `NFR-I18N-02` — Indonesian and English at full parity; `NFR-I18N-03` — never mix languages
/// within a passage under any fallback condition. Both are enforced here rather than at the
/// call site: a translation gap must be a decode failure, because a decode failure is the only
/// outcome that cannot be papered over by a view.
struct LocalizedTextTests {

    private let decoder = JSONDecoder()

    private func decode(_ json: String) throws -> LocalizedText {
        try decoder.decode(LocalizedText.self, from: Data(json.utf8))
    }

    // MARK: - The gap cases. These are the tests that matter.

    @Test func missingIndonesianFailsToDecode() {
        #expect(throws: DecodingError.self) {
            try decode(#"{ "en": "The old gate." }"#)
        }
    }

    @Test func missingEnglishFailsToDecode() {
        #expect(throws: DecodingError.self) {
            try decode(#"{ "id": "Gerbang tua." }"#)
        }
    }

    @Test func emptyIndonesianFailsToDecode() {
        #expect(throws: LocalizedTextError.emptyTranslation(language: .id)) {
            try decode(#"{ "id": "", "en": "The old gate." }"#)
        }
    }

    @Test func emptyEnglishFailsToDecode() {
        #expect(throws: LocalizedTextError.emptyTranslation(language: .en)) {
            try decode(#"{ "id": "Gerbang tua.", "en": "" }"#)
        }
    }

    /// Passed as JSON escape sequences, not literal control characters — a raw newline inside
    /// a JSON string is a parse error and would test the parser rather than the parity rule.
    @Test(arguments: ["   ", #"\n"#, #"\t"#, #" \n "#])
    func whitespaceOnlyTranslationFailsToDecode(_ blank: String) {
        #expect(throws: LocalizedTextError.emptyTranslation(language: .en)) {
            try decode(#"{ "id": "Gerbang tua.", "en": "\#(blank)" }"#)
        }
    }

    @Test func nullTranslationFailsToDecode() {
        #expect(throws: (any Error).self) {
            try decode(#"{ "id": "Gerbang tua.", "en": null }"#)
        }
    }

    // MARK: - No fallback under any condition

    @Test func valueReturnsExactlyTheRequestedLanguage() throws {
        let text = try decode(#"{ "id": "Gerbang tua.", "en": "The old gate." }"#)
        #expect(text.value(for: .id) == "Gerbang tua.")
        #expect(text.value(for: .en) == "The old gate.")
    }

    @Test func valueNeverSubstitutesTheOtherLanguage() throws {
        // Both translations are present and distinct; a fallback bug would show up as the
        // wrong one being returned, so assert inequality as well as equality.
        let text = try decode(#"{ "id": "Gerbang tua.", "en": "The old gate." }"#)
        #expect(text.value(for: .en) != text.value(for: .id))
    }

    @Test func decodesWhenBothTranslationsArePresent() throws {
        let text = try decode(#"{ "id": "Gerbang tua.", "en": "The old gate." }"#)
        #expect(text == LocalizedText(id: "Gerbang tua.", en: "The old gate."))
    }

    @Test func roundTripsThroughEncoding() throws {
        let original = LocalizedText(id: "Gerbang tua.", en: "The old gate.")
        let data = try JSONEncoder().encode(original)
        #expect(try decoder.decode(LocalizedText.self, from: data) == original)
    }

    // MARK: - ContentLanguage

    @Test(arguments: [("id", ContentLanguage.id), ("en", ContentLanguage.en)])
    func contentLanguageDecodesFromItsRawValue(_ raw: String, _ expected: ContentLanguage) throws {
        #expect(ContentLanguage(rawValue: raw) == expected)
    }

    @Test func contentLanguageRejectsAnUnknownRawValue() {
        #expect(ContentLanguage(rawValue: "jv") == nil)
    }
}
