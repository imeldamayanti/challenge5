import Testing
@testable import DesignSystem

/// The checkpoint's task list showed each authored prompt whole, and at Pura Maospahit the third
/// row ran past the footer's pill. The rule that cuts it is a pure value so it can be held here
/// rather than looked at on a screen.
@Suite("Task prompt preview")
struct TaskPromptPreviewTests {

    /// The shipped prompt that overran the row.
    private let boundaryTask = """
        The Line You Do Not Cross. Find the area visitors may not enter. Stop at the boundary you \
        are allowed to reach, then take or choose a picture that shows it. The temple grounds are a \
        place of worship: anyone who is ritually unable to enter, including those menstruating, does \
        not cross them.
        """

    @Test func aLongPromptIsCutToTheWordLimit() {
        let preview = TaskPromptPreview.preview(of: boundaryTask)
        let words = preview.split(whereSeparator: \.isWhitespace)
        #expect(words.count == TaskPromptPreview.wordLimit)
        #expect(preview.hasSuffix(TaskPromptPreview.ellipsis))
    }

    /// A prompt already inside the limit is printed as it was authored — no ellipsis promising more.
    @Test func aShortPromptIsLeftAlone() {
        let short = "Photograph the temple gateway."
        #expect(TaskPromptPreview.preview(of: short) == short)
        #expect(!TaskPromptPreview.preview(of: short).hasSuffix(TaskPromptPreview.ellipsis))
    }

    /// Exactly at the limit is not truncation. Off by one here would mark every fifteen-word prompt
    /// as having more behind it.
    @Test func exactlyTheLimitIsNotTruncated() {
        let fifteen = (1...15).map(String.init).joined(separator: " ")
        #expect(TaskPromptPreview.preview(of: fifteen) == fifteen)

        let sixteen = (1...16).map(String.init).joined(separator: " ")
        #expect(TaskPromptPreview.preview(of: sixteen) == fifteen + TaskPromptPreview.ellipsis)
    }

    /// The preview is the prompt's own opening, not a summary of it.
    @Test func thePreviewKeepsTheOpeningWordsInOrder() {
        #expect(TaskPromptPreview.preview(of: boundaryTask)
            .hasPrefix("The Line You Do Not Cross."))
    }

    /// A cut landing on a stop would read "arrived.…", which is a typo rather than a truncation.
    @Test func punctuationTheCutStrandsGoesWithIt() {
        #expect(TaskPromptPreview.preview(of: "one two three. four", limit: 3)
            == "one two three" + TaskPromptPreview.ellipsis)
        #expect(TaskPromptPreview.preview(of: "one two three, four", limit: 3)
            == "one two three" + TaskPromptPreview.ellipsis)
    }

    /// One shipped question is a fill-in clue (`c _ n _ _ _`), and an underscore is punctuation to
    /// Unicode — stripping every mark would eat the clue.
    @Test func aFillInCluesUnderscoresSurviveTheCut() {
        #expect(TaskPromptPreview.preview(of: "the clue: c _ n _ _ _ and more", limit: 6)
            == "the clue: c _ n _" + TaskPromptPreview.ellipsis)
    }

    /// An authored line break must not spend one of the fifteen words on nothing.
    @Test func whitespaceIsCollapsed() {
        #expect(TaskPromptPreview.preview(of: "  one\n\ntwo   three  ") == "one two three")
    }

    @Test func anEmptyPromptStaysEmpty() {
        #expect(TaskPromptPreview.preview(of: "").isEmpty)
        #expect(TaskPromptPreview.preview(of: "   ").isEmpty)
    }
}
