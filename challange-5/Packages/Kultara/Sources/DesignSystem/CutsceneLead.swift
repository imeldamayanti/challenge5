import Foundation

/// How much of a passage a story page shows, when the frame draws a fixed amount of it.
///
/// Two pages on the Hisplora board set a *length* rather than a passage: `187:866` draws two lines
/// of lead under the portrait, and `293:1643` draws one paragraph under the illustration. The
/// authored text is longer than either, and setting all of it turns the page into a different page
/// — on the portrait the picture, the name and the action all move up out of view; on the Story
/// Line the passage runs past the drawing it was written under.
///
/// So both cut the **display** only. Nothing is edited, the content is untouched, and every screen
/// that shows the whole passage still does.
enum StoryTextCut {

    /// `text` cut to `maximumWords`, ending on a sentence where one ends late enough to be an
    /// ending and on a word with an ellipsis where none does.
    ///
    /// Pure, and it slices the original string rather than re-joining split words, so paragraph
    /// breaks and every other piece of the author's whitespace survive the cut.
    ///
    /// - Parameter minimumSentenceWords: how far in a full stop has to fall before ending there is
    ///   better than running to the limit. A sentence three words into a page is not an ending; it
    ///   is a page that lost the rest of itself.
    static func text(_ text: String, maximumWords: Int, minimumSentenceWords: Int) -> String {
        var words = 0
        var inWord = false
        var wordCut = text.startIndex
        var sentenceCut: String.Index?
        var i = text.startIndex

        while i < text.endIndex {
            let character = text[i]
            let next = text.index(after: i)
            if character.isWhitespace {
                inWord = false
            } else {
                if !inWord {
                    inWord = true
                    words += 1
                    if words > maximumWords { break }
                }
                if words == maximumWords { wordCut = next }
                if ".!?…".contains(character), words >= minimumSentenceWords { sentenceCut = next }
            }
            i = next
        }

        guard words > maximumWords else { return text }
        if let sentenceCut { return String(text[..<sentenceCut]) }
        return text[..<wordCut].trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

/// The lead the cutscene's portrait page carries — `187:866`.
///
/// The frame draws two lines under the subject's name: "Walk through the places that once shaped
/// his life. Let him tell you the stories Badung still remembers." — not the whole hook.
public enum CutsceneLeadMetrics {

    /// The frame's two lines come to nineteen words. Twenty-five is that with room for a longer
    /// authored sentence and for Indonesian, which runs longer than the English for the same claim.
    public static let maximumLeadWords = 25

    /// A lead shorter than this is not worth ending a sentence early for — three words under a
    /// portrait read as a caption that lost its second half. Below it the word cut and its ellipsis
    /// are the better ending.
    static let minimumSentenceLeadWords = maximumLeadWords / 2

    /// The hook as the portrait page sets it, cut to `maximumLeadWords`.
    public static func leadText(_ text: String) -> String {
        StoryTextCut.text(
            text,
            maximumWords: maximumLeadWords,
            minimumSentenceWords: minimumSentenceLeadWords)
    }
}

/// The passage the Story Line page carries — `293:1643`.
///
/// The frame draws the lead sentence, the ringed place name, and **one paragraph** beneath them.
/// A checkpoint's lore is every `LoreBlock` joined, which is longer than that and grows with the
/// authoring; left whole it pushes the illustration off the top of a scroll the frame does not
/// draw. Fifty words is the frame's own paragraph with room for a third block and for Indonesian.
///
/// **The labelled treatment is not cut.** `StoryRevealScreen` shows this passage two ways, and only
/// the unlabelled run-flow one is a fixed page: the provenance list carries the accuracy label and
/// the citations for each claim (`FR-CP-05`), and a claim trimmed away is a claim whose source went
/// with it.
public enum StoryPassageMetrics {

    /// One paragraph, as the frame sets it.
    public static let maximumPassageWords = 50

    /// Half the page. A full stop before that is the end of an opening line, not the end of the
    /// paragraph, and stopping there wastes the page the frame drew.
    static let minimumSentencePassageWords = maximumPassageWords / 2

    /// The checkpoint's lore as the Story Line page sets it, cut to `maximumPassageWords`.
    public static func passageText(_ text: String) -> String {
        StoryTextCut.text(
            text,
            maximumWords: maximumPassageWords,
            minimumSentenceWords: minimumSentencePassageWords)
    }
}
