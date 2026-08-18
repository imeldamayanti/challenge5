import Testing
@testable import DesignSystem

/// The lead on `187:866`. The frame draws two lines under the portrait; `hookLore` is longer than
/// that in the shipped quest and will be longer still in authored ones, so the cut is a rule rather
/// than a hope about how writers write.
@Suite("Cutscene lead")
struct CutsceneLeadTests {

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    /// The frame's own lead — nineteen words — passes through untouched, punctuation and all.
    @Test func aLeadTheLengthOfTheFramesIsLeftAlone() {
        let lead = """
            Walk through the places that once shaped his life. Let him tell you the stories Badung \
            still remembers.
            """
        #expect(CutsceneLeadMetrics.leadText(lead) == lead)
    }

    /// Short text keeps its own whitespace, paragraph breaks included: the cut is the only thing
    /// this function is allowed to do to a passage.
    @Test func shortTextIsReturnedVerbatim() {
        let hook = "One line.\n\nAnd a second."
        #expect(CutsceneLeadMetrics.leadText(hook) == hook)
    }

    @Test func aLongHookIsCutToTheWordLimit() {
        let hook = Array(repeating: "walk", count: 200).joined(separator: " ")
        #expect(wordCount(CutsceneLeadMetrics.leadText(hook)) <= CutsceneLeadMetrics.maximumLeadWords)
    }

    /// A cut that lands mid-sentence takes an ellipsis — a lead that stops on a bare word reads as
    /// a bug rather than as an ending.
    @Test func aCutMidSentenceIsMarked() {
        let hook = Array(repeating: "walk", count: 200).joined(separator: " ")
        #expect(CutsceneLeadMetrics.leadText(hook).hasSuffix("…"))
    }

    /// When a sentence ends inside the limit the lead ends there instead, with no ellipsis: the
    /// page reads as written rather than as truncated.
    @Test func theCutPrefersTheLastWholeSentence() {
        let sentence = Array(repeating: "walk", count: 19).joined(separator: " ") + " home."
        let hook = sentence + " " + Array(repeating: "onward", count: 40).joined(separator: " ")
        #expect(CutsceneLeadMetrics.leadText(hook) == sentence)
    }

    /// But not at any price. A full stop three words in is not an ending worth taking — the word
    /// cut is the better lead there, and this is the boundary that says so.
    @Test func aSentenceEndingTooEarlyIsNotTakenAsTheEnding() {
        let hook = "Badung fell. " + Array(repeating: "walk", count: 60).joined(separator: " ")
        let lead = CutsceneLeadMetrics.leadText(hook)
        #expect(lead.hasSuffix("…"))
        #expect(wordCount(lead) == CutsceneLeadMetrics.maximumLeadWords)
    }

    /// The limit is the frame's two lines plus room, not an arbitrary number: a lead long enough to
    /// push the portrait and the action off the page is the thing this rule exists to prevent.
    @Test func theLimitStaysTwoLinesWorth() {
        #expect(CutsceneLeadMetrics.maximumLeadWords == 25)
        #expect(CutsceneLeadMetrics.minimumSentenceLeadWords < CutsceneLeadMetrics.maximumLeadWords)
    }
}

/// The paragraph on `293:1643`. A checkpoint's lore is every `LoreBlock` joined, so the page's
/// length is a rule rather than a hope about how many blocks an author writes.
@Suite("Story passage")
struct StoryPassageTests {

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    @Test func aPassageWithinTheLimitIsLeftAlone() {
        let passage = Array(repeating: "walk", count: 50).joined(separator: " ")
        #expect(StoryPassageMetrics.passageText(passage) == passage)
    }

    @Test func aLongPassageIsCutToFiftyWords() {
        let passage = Array(repeating: "walk", count: 400).joined(separator: " ")
        let page = StoryPassageMetrics.passageText(passage)
        #expect(wordCount(page) <= StoryPassageMetrics.maximumPassageWords)
        #expect(page.hasSuffix("…"))
    }

    /// The cut slices the authored string rather than re-joining split words, so the `\n\n` between
    /// two lore blocks is still a paragraph break on the page.
    @Test func paragraphBreaksSurviveTheCut() {
        let first = Array(repeating: "walk", count: 20).joined(separator: " ") + "."
        let second = Array(repeating: "onward", count: 24).joined(separator: " ") + " home. "
            + Array(repeating: "further", count: 60).joined(separator: " ")
        let page = StoryPassageMetrics.passageText(first + "\n\n" + second)
        #expect(page.contains("\n\n"))
        #expect(wordCount(page) <= StoryPassageMetrics.maximumPassageWords)
    }

    @Test func theCutPrefersTheLastWholeSentence() {
        let sentence = Array(repeating: "walk", count: 39).joined(separator: " ") + " home."
        let passage = sentence + " " + Array(repeating: "onward", count: 60).joined(separator: " ")
        #expect(StoryPassageMetrics.passageText(passage) == sentence)
    }

    /// A full stop in the opening line is not the end of the paragraph — the page runs to the limit
    /// instead of stopping a fifth of the way in.
    @Test func aSentenceEndingTooEarlyIsNotTakenAsTheEnding() {
        let passage = "Badung fell. " + Array(repeating: "walk", count: 120).joined(separator: " ")
        let page = StoryPassageMetrics.passageText(passage)
        #expect(page.hasSuffix("…"))
        #expect(wordCount(page) == StoryPassageMetrics.maximumPassageWords)
    }

    /// The two pages set two different lengths, and the passage is the longer one: a lead that ran
    /// to a paragraph would push the portrait off `187:866`.
    @Test func theLimitIsOneParagraphAndLongerThanTheCutsceneLead() {
        #expect(StoryPassageMetrics.maximumPassageWords == 50)
        #expect(StoryPassageMetrics.maximumPassageWords > CutsceneLeadMetrics.maximumLeadWords)
    }
}
