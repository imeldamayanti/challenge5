import Foundation
import Testing
@testable import DesignSystem

/// The tokenizer behind `HisploraMarkedPassage` — the piece that turns a joined passage plus a
/// table of phrases into the words and marked groups the wrap layout places.
///
/// The load-bearing property is that marking never changes *what* reads out: the concatenation of
/// every non-break token, in order, is the passage itself, and the character counts sum to what
/// the reveal budget walks. A phrase the text does not contain is ignored rather than an error,
/// so a marks table can survive a wording change without taking the screen down.
struct HisploraMarkedPassageTests {

    private func plainText(of tokens: [HisploraMarkedPassage.Token]) -> String {
        tokens.filter { !$0.isBreak }.map(\.text).joined(separator: " ")
    }

    /// The whitespace the tokenizer drops (the wrap layout owns those gaps) — what the reveal
    /// budget actually walks.
    private func revealableCount(_ text: String) -> Int {
        text.filter { !$0.isWhitespace }.count
    }

    @Test func tokensReadBackAsThePassage() {
        let text = "The split gateway stands as a trace of Bali's ancient connection with Java."
        let tokens = HisploraMarkedPassage.tokenize(text: text, markedPhrases: [])
        #expect(plainText(of: tokens) == text)
        #expect(tokens.reduce(0) { $0 + $1.characterCount } == revealableCount(text))
        #expect(tokens.allSatisfy { !$0.isMarked })
    }

    @Test func aMarkedPhraseBecomesOneUnbrokenToken() {
        let text = "associated with Kebo Iwa, a legendary patih"
        let tokens = HisploraMarkedPassage.tokenize(text: text, markedPhrases: ["Kebo Iwa"])
        let marked = tokens.filter(\.isMarked)
        #expect(marked.count == 1)
        #expect(marked.first?.text == "Kebo Iwa")
        // The words either side stay plain, in order.
        #expect(tokens.first?.text == "associated")
        #expect(tokens.last?.text == "patih")
    }

    @Test func severalPhrasesMarkInTheSamePassage() {
        let text = "stands Museum Bali, opened in 1932, and keeps going"
        let phrases = ["Museum Bali,", "opened in 1932,"]
        let tokens = HisploraMarkedPassage.tokenize(text: text, markedPhrases: phrases)
        #expect(tokens.filter(\.isMarked).map(\.text) == phrases)
        // A marked group keeps the spaces *inside* itself ("Kebo Iwa" reads as one phrase), so
        // the budget walks those too.
        let intraPhraseSpaces = phrases.joined().filter(\.isWhitespace).count
        #expect(tokens.reduce(0) { $0 + $1.characterCount }
            == revealableCount(text) + intraPhraseSpaces)
    }

    @Test func aMissingPhraseIsIgnoredRatherThanFatal() {
        let text = "four faces look toward the four directions"
        let tokens = HisploraMarkedPassage.tokenize(text: text, markedPhrases: ["Tukad Badung"])
        #expect(tokens.allSatisfy { !$0.isMarked })
        #expect(plainText(of: tokens) == text)
    }

    @Test func paragraphBreaksBecomeBreakTokens() {
        let text = "first paragraph\n\nsecond paragraph"
        let tokens = HisploraMarkedPassage.tokenize(text: text, markedPhrases: [])
        let breaks = tokens.filter(\.isBreak)
        #expect(breaks.count == 2)
        #expect(breaks.allSatisfy { $0.characterCount == 0 })
    }

    @Test func overlappingMatchesResolveToTheLongestPhrase() {
        let text = "opened in 1932, the museum kept its gate"
        let tokens = HisploraMarkedPassage.tokenize(
            text: text, markedPhrases: ["1932", "opened in 1932,"])
        #expect(tokens.filter(\.isMarked).map(\.text) == ["opened in 1932,"])
    }
}
