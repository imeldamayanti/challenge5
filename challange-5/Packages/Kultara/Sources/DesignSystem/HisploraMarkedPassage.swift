import SwiftUI

/// A passage that types itself in **and** carries the hand-drawn marker loops round chosen phrases,
/// the way the four Story frames (`964:3212` and its siblings) draw them: "Kebo Iwa", "Pasar
/// Badung", "Catur Muka statue", "Museum Bali," and "opened in 1932," all sit mid-sentence, under a
/// yellow stroke, inside text that still wraps like ordinary prose.
///
/// A single `Text` cannot host an overlay on one of its own substrings, and `HisploraMarkedPhrase`
/// is its own view — so this component lays the passage out as words in `WordWrapLayout`, groups
/// the words each marked phrase covers into one unbreakable token, and draws the loop behind that
/// token. The reveal is one shared character budget walked across the tokens in reading order, so
/// what types in reads exactly as the joined passage does.
///
/// Three rules carried over from `HisploraTypewriterText`, all requirements rather than
/// preferences:
///
/// - Under Reduce Motion or VoiceOver everything renders complete at once — passage typed, marks
///   swept — and the accessibility value is always the whole passage.
/// - A tap completes it. Nobody sits out a typewriter to re-read a line (`FR-CP-03`).
/// - The full layout stands invisibly underneath while it types, so nothing below reflows as the
///   passage grows.
public struct HisploraMarkedPassage: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private let text: String
    private let markedPhrases: [String]
    private let font: Font
    private let ink: KeyPath<HisploraPalette, SRGBColor>
    private let lineSpacing: CGFloat
    private let onComplete: () -> Void

    @State private var visibleCharacters = 0
    @State private var isFinished = false

    public init(
        _ text: String,
        markedPhrases: [String] = [],
        font: Font = .system(size: 17),
        ink: KeyPath<HisploraPalette, SRGBColor> = \.inkBody,
        lineSpacing: CGFloat = 4,
        onComplete: @escaping () -> Void = {}
    ) {
        self.text = text
        self.markedPhrases = markedPhrases
        self.font = font
        self.ink = ink
        self.lineSpacing = lineSpacing
        self.onComplete = onComplete
    }

    // MARK: - Tokens

    /// One laid-out unit: a word, a marked phrase (which may span several words), or a paragraph
    /// break. Words carry no spaces — `WordWrapLayout` puts a word-space between neighbours — and
    /// a break is a zero-size subview that forces the next row.
    struct Token: Equatable {
        let text: String
        let isMarked: Bool
        let isBreak: Bool
        /// How many characters of the passage this token reveals. A break reveals none; the sum
        /// over all tokens is `text.count`.
        let characterCount: Int

        static func breakToken() -> Token {
            Token(text: "", isMarked: false, isBreak: true, characterCount: 0)
        }
    }

    /// Splits the passage into words and marked groups, in reading order.
    ///
    /// Each phrase is matched at its **first** occurrence, case-sensitively; a phrase the text does
    /// not contain is ignored rather than an error, so a table entry can survive a wording change
    /// without taking the screen with it. Phrases are applied longest first so overlapping matches
    /// resolve to the longer one, and already-consumed spans never match again.
    ///
    /// Character-array work throughout: `String.Index` arithmetic around `range(of:in:)` proved
    /// fragile here (a silent trap under one specific overlap), and indices into an array are the
    /// thing that cannot be wrong.
    ///
    /// `nonisolated`, deliberately: this module builds under MainActor default isolation, and an
    /// isolated comparator handed to `sorted(by:)` asserts its queue the moment a second element
    /// makes sort actually call it — which is how a tokenizer took down the test process.
    nonisolated static func tokenize(text: String, markedPhrases: [String]) -> [Token] {
        let characters = Array(text)
        let count = characters.count

        // Marked character spans, non-overlapping, in reading order.
        var markedSpans: [Range<Int>] = []
        for phrase in markedPhrases.sorted(by: { $0.count > $1.count }) where !phrase.isEmpty {
            let needle = Array(phrase)
            var start = 0
            outer: while start + needle.count <= count {
                guard characters[start] == needle[0] else {
                    start += 1
                    continue
                }
                for offset in 1..<needle.count where characters[start + offset] != needle[offset] {
                    start += 1
                    continue outer
                }
                let span = start..<(start + needle.count)
                if !markedSpans.contains(where: { $0.overlaps(span) }) {
                    markedSpans.append(span)
                }
                start = span.upperBound
            }
        }
        markedSpans.sort { $0.lowerBound < $1.lowerBound }

        var tokens: [Token] = []
        // Emits one plain segment: words split on whitespace, each newline run becoming break
        // tokens. The whitespace itself goes nowhere — the wrap layout owns those gaps.
        func emitPlain(_ slice: ArraySlice<Character>) {
            var word: [Character] = []
            func flush() {
                guard !word.isEmpty else { return }
                tokens.append(Token(
                    text: String(word), isMarked: false, isBreak: false,
                    characterCount: word.count))
                word = []
            }
            for character in slice {
                if character.isWhitespace {
                    flush()
                    if character.isNewline {
                        tokens.append(.breakToken())
                    }
                } else {
                    word.append(character)
                }
            }
            flush()
        }

        var cursor = 0
        for span in markedSpans {
            if cursor < span.lowerBound {
                emitPlain(characters[cursor..<span.lowerBound])
            }
            let group = String(characters[span])
            tokens.append(Token(
                text: group, isMarked: true, isBreak: false, characterCount: group.count))
            cursor = span.upperBound
        }
        if cursor < count {
            emitPlain(characters[cursor...])
        }
        return tokens
    }

    private var tokens: [Token] { Self.tokenize(text: text, markedPhrases: markedPhrases) }

    private var rendersImmediately: Bool { reduceMotion || voiceOverEnabled }

    // MARK: - Body

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // The finished page, invisible, holding the height while the passage types.
            flow(tokens: tokens, budget: .max, marksShown: true)
                .hidden()
                .accessibilityHidden(true)
            flow(tokens: tokens, budget: visibleBudget, marksShown: marksShown)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { complete() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .task(id: text) { await run() }
    }

    private var visibleBudget: Int {
        (isFinished || rendersImmediately) ? .max : visibleCharacters
    }

    private var marksShown: Bool { isFinished || rendersImmediately }

    /// What the reveal walks to. Not `text.count`: the tokenizer drops the whitespace between
    /// words (the layout owns those gaps), so counting the whole string would spend the last few
    /// ticks revealing nothing.
    private var totalRevealableCharacters: Int {
        tokens.reduce(0) { $0 + $1.characterCount }
    }

    @ViewBuilder private func flow(tokens: [Token], budget: Int, marksShown: Bool) -> some View {
        WordWrapLayout(lineSpacing: lineSpacing, breaks: IndexSet(tokens.indices.filter {
            tokens[$0].isBreak
        })) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                if token.isBreak {
                    Color.clear.frame(width: 0, height: 0)
                } else if token.isMarked {
                    HisploraMarkedPhrase(token.text, font: font, isMarked: marksShown)
                        .opacity(revealedCharacterCount(upTo: index, in: tokens, budget: budget) > 0 ? 1 : 0)
                } else {
                    Text(revealedPrefix(of: token, upTo: index, in: tokens, budget: budget))
                        .font(font)
                        .foregroundStyle(palette[keyPath: ink].color)
                }
            }
        }
    }

    /// Characters revealed by the tokens *before* `index`, against the budget.
    private func revealedBefore(_ index: Int, in tokens: [Token], budget: Int) -> Int {
        var count = 0
        for i in 0..<index {
            count += min(max(budget - count, 0), tokens[i].characterCount)
            if count >= budget { break }
        }
        return count
    }

    private func revealedCharacterCount(upTo index: Int, in tokens: [Token], budget: Int) -> Int {
        guard budget != .max else { return tokenCharacterCount(at: index, in: tokens) }
        let before = revealedBefore(index, in: tokens, budget: budget)
        return max(min(budget - before, tokenCharacterCount(at: index, in: tokens)), 0)
    }

    private func tokenCharacterCount(at index: Int, in tokens: [Token]) -> Int {
        tokens[index].characterCount
    }

    private func revealedPrefix(of token: Token, upTo index: Int, in tokens: [Token], budget: Int)
        -> String {
        guard budget != .max else { return token.text }
        let revealed = revealedCharacterCount(upTo: index, in: tokens, budget: budget)
        guard revealed < token.text.count else { return token.text }
        return String(token.text.prefix(revealed))
    }

    // MARK: - Reveal

    private func complete() {
        guard !isFinished else { return }
        isFinished = true
        visibleCharacters = totalRevealableCharacters
        onComplete()
    }

    private func run() async {
        guard !rendersImmediately else {
            complete()
            return
        }
        isFinished = false
        visibleCharacters = 0
        let interval = Duration.seconds(1 / TypewriterProgress.charactersPerSecond)
        while visibleCharacters < totalRevealableCharacters && !isFinished {
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            guard !isFinished else { return }
            visibleCharacters += 1
        }
        complete()
    }
}

/// Word-wrap for the passage's tokens — the piece `Layout` exists for.
///
/// Rows fill left to right within the width the container offers; the next word that no longer
/// fits starts a new row, and a break subview always does. Row height is the tallest subview in
/// it, and the row gap is the caller's line spacing, so the wrapped block reads with the same
/// leading a single `Text` would give.
struct WordWrapLayout: Layout {
    let lineSpacing: CGFloat
    /// Indices of the subviews that force the next row.
    let breaks: IndexSet

    /// The width of one space at the passage's font. Not measurable here without resolving fonts,
    /// so it is a constant close to SF Pro's at 17 points.
    static let wordSpace: CGFloat = 4.5

    struct Cache {
        var rows: [[Int]] = []
        var rowSizes: [CGSize] = []
        var size: CGSize = .zero
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    /// Rows are recomputed against the width actually on offer — caching them across proposals
    /// would hold onto a wrap decided for a different container.
    private func compute(subviews: Subviews, maxWidth: CGFloat) -> Cache {
        var cache = Cache()
        var current: [Int] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        func closeRow() {
            cache.rows.append(current)
            cache.rowSizes.append(CGSize(width: currentWidth, height: currentHeight))
            current = []
            currentWidth = 0
            currentHeight = 0
        }

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if breaks.contains(index) {
                if !current.isEmpty { closeRow() } else {
                    // A break on an empty row still spends the row — two blank lines in a row
                    // must stay two blank lines.
                    cache.rows.append([])
                    cache.rowSizes.append(CGSize(width: 0, height: size.height))
                }
                continue
            }
            let gap = current.isEmpty ? 0 : Self.wordSpace
            if !current.isEmpty, currentWidth + gap + size.width > maxWidth {
                closeRow()
            }
            if current.isEmpty {
                current = [index]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                current.append(index)
                currentWidth += gap + size.width
                currentHeight = max(currentHeight, size.height)
            }
        }
        if !current.isEmpty || cache.rows.isEmpty {
            closeRow()
        }
        cache.size = CGSize(
            width: cache.rowSizes.map(\.width).max() ?? 0,
            height: cache.rowSizes.map(\.height).reduce(0) { $0 + $1 }
                + CGFloat(max(cache.rowSizes.count - 1, 0)) * lineSpacing)
        return cache
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        cache = compute(subviews: subviews, maxWidth: maxWidth.isFinite ? maxWidth : .infinity)
        return cache.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        cache = compute(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for (row, indices) in cache.rows.enumerated() {
            var x = bounds.minX
            let rowHeight = cache.rowSizes[row].height
            for index in indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - size.height) / 2),
                    anchor: .topLeading,
                    proposal: .unspecified)
                x += size.width + Self.wordSpace
            }
            y += rowHeight + lineSpacing
        }
    }
}
