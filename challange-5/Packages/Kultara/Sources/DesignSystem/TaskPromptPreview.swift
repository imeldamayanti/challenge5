import Foundation

/// How much of a task's prompt the checkpoint's task list shows.
///
/// `452:3132` draws three short invented titles ("The Iron Statue", …). The shipped content has no
/// title field — a task is a `type` and a `prompt` — so the row prints the prompt as its subtitle,
/// and the authored prompts are whole paragraphs: the temple's boundary task runs to fifty-odd
/// words and carries the ritual note with it. Three of those in a column push the footer's pill
/// over the third row and turn a list of *what is waiting* into a wall of text nobody scans.
///
/// So the row shows a preview and the sheet shows the prompt. The cut is by word rather than by
/// character or by `lineLimit`: a character cut lands mid-word, and a line cut varies with Dynamic
/// Type, so at `AccessibilityXXXL` the same row would show three words where it shows fifteen at the
/// default size. A word count reads the same at every size, which is the point of a preview.
///
/// Nothing is lost — every row opens `TaskDetailScreen`, which prints the prompt whole.
public enum TaskPromptPreview {

    /// The most words a row shows before the ellipsis. Fifteen is about two lines of the row's
    /// 15-point light face inside `452:3132`'s 362-point column, which is what the frame draws.
    public static let wordLimit = 15

    /// The character the cut leaves behind, so a truncated row is visibly truncated rather than
    /// looking like a prompt that simply ends oddly.
    public static let ellipsis = "…"

    /// `prompt` cut to at most `limit` words, with `ellipsis` appended when anything was dropped.
    ///
    /// Whitespace is collapsed on the way through: an authored prompt with a line break in it would
    /// otherwise spend one of its fifteen words on nothing. Punctuation the cut leaves stranded at
    /// the end goes with it — "arrived.…" and "here,…" read as typos rather than as a truncation.
    public static func preview(of prompt: String, limit: Int = wordLimit) -> String {
        let words = prompt.split(whereSeparator: \.isWhitespace)
        guard limit > 0, words.count > limit else {
            return words.joined(separator: " ")
        }
        var kept = words.prefix(limit).joined(separator: " ")
        while let last = kept.last, trailingPunctuation.contains(last) {
            kept.removeLast()
        }
        return kept + ellipsis
    }

    /// The characters a cut may strand: a sentence's own stops and separators, plus an ellipsis
    /// already in the authored text, since two in a row is a stutter. Deliberately *not* every
    /// punctuation mark — one shipped question's prompt is a fill-in clue (`c _ n _ _ _`), and an
    /// underscore is punctuation to Unicode.
    private static let trailingPunctuation: Set<Character> = [",", ";", ":", ".", "…", "-", "—"]
}
