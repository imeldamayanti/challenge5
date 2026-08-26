import SwiftUI

/// How much of a passage a progressive reveal has shown.
///
/// Split out as a value so the rule — how many characters at time *t*, and when it is finished —
/// is testable without a running view. The three requirements motion has to satisfy here
/// (`NFR-A11Y-04`, `NFR-A11Y-05`) are all decided by this type plus the two flags passed into it.
public struct TypewriterProgress: Sendable, Equatable {

    /// Characters per second. Slow enough to read along with, fast enough that a three-line
    /// passage does not become a wait.
    ///
    /// This is the *reveal* rate — a passage appearing, which is what the story reveal and the
    /// place notice do. A page being typed on a machine is a different thing and runs at
    /// `TypewriterMetrics.sheetCharactersPerSecond`, which is slower on purpose.
    public static let charactersPerSecond: Double = 42

    public let characterCount: Int
    public let elapsed: Duration
    /// `accessibilityReduceMotion`, or VoiceOver running. Either one renders the passage complete
    /// at once: a screen reader must receive the whole string, not a character at a time.
    public let rendersImmediately: Bool
    /// The rate this particular passage runs at. Defaulted, so every existing caller keeps the
    /// reveal rate and only a caller that means "typed, not revealed" pays for the difference.
    public let charactersPerSecond: Double

    public init(
        characterCount: Int,
        elapsed: Duration,
        rendersImmediately: Bool,
        charactersPerSecond: Double = TypewriterProgress.charactersPerSecond
    ) {
        self.characterCount = characterCount
        self.elapsed = elapsed
        self.rendersImmediately = rendersImmediately
        self.charactersPerSecond = charactersPerSecond
    }

    /// How long a typist rests *after* a character, as a multiple of one character's own interval.
    ///
    /// A constant interval is what makes a reveal read as a wipe rather than as typing: real typing
    /// is a run of keys and then a hand stopping at the end of a clause. The multiples are small —
    /// nothing here is a pause a reader waits *through*, and a tap ends the whole passage anyway.
    ///
    /// Pure, and separate from `visibleCharacters`, because the two answer different questions:
    /// this one is the rhythm the view types at, that one is the rule a test can hold. A time-based
    /// reveal cannot carry rhythm without becoming a scan of the whole string per frame.
    public static func dwell(after character: Character) -> Double {
        if character.isNewline { return 8 }
        if ".!?…".contains(character) { return 6 }
        if ",;:".contains(character) { return 3 }
        return 0
    }

    private var elapsedSeconds: Double {
        Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
    }

    /// How many characters are on screen now.
    public var visibleCharacters: Int {
        guard !rendersImmediately else { return characterCount }
        let shown = Int((max(0, elapsedSeconds) * charactersPerSecond).rounded(.down))
        return min(characterCount, max(0, shown))
    }

    public var isComplete: Bool { visibleCharacters >= characterCount }

    /// How long the whole passage takes. A tap skips to the end, so this is the ceiling on
    /// patience, never a gate.
    public var totalDuration: Duration {
        guard !rendersImmediately, charactersPerSecond > 0 else { return .zero }
        return .seconds(Double(characterCount) / charactersPerSecond)
    }
}

/// A passage that types itself in, unless it shouldn't.
///
/// Three rules, all of them requirements rather than preferences:
///
/// - Under Reduce Motion or VoiceOver it renders complete immediately, and the accessibility value
///   is always the whole passage — a screen reader never receives a half-typed sentence.
/// - A tap completes it at once. `FR-CP-03` wants lore re-readable at rest, and nobody should have
///   to sit out a typewriter to re-read a line.
/// - It is one `Text` revealed progressively, not a stack of appearing lines, so the layout does
///   not reflow as it runs.
public struct HisploraTypewriterText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private let text: String
    private let font: Font
    private let ink: KeyPath<HisploraPalette, SRGBColor>
    private let lineSpacing: CGFloat
    /// Set when the passage has to be flush on both edges. The role rather than a flag, because a
    /// justified paragraph is laid out by UIKit and UIKit needs the role's `UIFont` — see
    /// `JustifiedRevealText`.
    private let justifiedRole: KultaraTypography.Role?
    /// How fast this passage types. The story preview's sheet is the one caller that slows it: a
    /// page coming out of a machine is typed, and typing that runs at reveal speed reads as a wipe.
    private let charactersPerSecond: Double
    private let onComplete: () -> Void

    @Environment(\.hisploraPalette) private var palette
    @State private var visibleCharacters = 0
    @State private var isFinished = false

    public init(
        _ text: String,
        font: Font = .system(size: 17),
        ink: KeyPath<HisploraPalette, SRGBColor> = \.inkBody,
        lineSpacing: CGFloat = 4,
        charactersPerSecond: Double = TypewriterProgress.charactersPerSecond,
        onComplete: @escaping () -> Void = {}
    ) {
        self.text = text
        self.font = font
        self.ink = ink
        self.lineSpacing = lineSpacing
        self.justifiedRole = nil
        self.charactersPerSecond = charactersPerSecond
        self.onComplete = onComplete
    }

    /// The same passage set justified — flush left *and* right, as `81:588` sets the typed sheet.
    ///
    /// It takes the role rather than a `Font` because that is the only form UIKit can be given: the
    /// face, the size and the Dynamic Type style all have to be resolved again as a `UIFont`, and
    /// `KultaraFonts.uiFont(_:)` is what does it from the same table `font(_:)` reads.
    public init(
        _ text: String,
        justifiedIn role: KultaraTypography.Role,
        ink: KeyPath<HisploraPalette, SRGBColor> = \.inkBody,
        charactersPerSecond: Double = TypewriterProgress.charactersPerSecond,
        onComplete: @escaping () -> Void = {}
    ) {
        self.text = text
        self.font = KultaraTypography.font(role)
        self.ink = ink
        self.lineSpacing = role.lineSpacing
        self.justifiedRole = role
        self.charactersPerSecond = charactersPerSecond
        self.onComplete = onComplete
    }

    private var rendersImmediately: Bool { reduceMotion || voiceOverEnabled }

    private var shown: String {
        guard !rendersImmediately, !isFinished else { return text }
        return String(text.prefix(visibleCharacters))
    }

    public var body: some View {
        passage
            .contentShape(Rectangle())
            .onTapGesture { complete() }
            // VoiceOver reads the passage, whole, whatever is drawn.
            .accessibilityLabel(text)
            .task(id: text) { await run() }
    }

    /// Justified or ragged, the two draw the same passage and differ only in who lays it out.
    @ViewBuilder private var passage: some View {
        if let justifiedRole {
            // No hidden twin underneath: this one always lays the *whole* passage out and paints
            // the untyped tail clear, so its height is the finished height from the first frame.
            JustifiedRevealText(
                text: text,
                visibleCharacters: rendersImmediately || isFinished ? text.count : visibleCharacters,
                role: justifiedRole,
                ink: palette[keyPath: ink].color,
                lineSpacing: lineSpacing)
        } else {
            // The full passage is laid out invisibly underneath, so the block does not grow line by
            // line and shove everything below it down the screen as it types.
            Text(shown)
                .font(font)
                .foregroundStyle(palette[keyPath: ink].color)
                .lineSpacing(lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Text(text)
                        .font(font)
                        .lineSpacing(lineSpacing)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hidden()
                        .accessibilityHidden(true))
        }
    }

    private func complete() {
        guard !isFinished else { return }
        isFinished = true
        visibleCharacters = text.count
        onComplete()
    }

    /// Types the passage in, one character at a time, resting where a typist rests.
    ///
    /// The rest is what makes it typing rather than a wipe — a run of keys, then a hand stopping at
    /// the end of a clause (`TypewriterProgress.dwell(after:)`). It is drawn from the character just
    /// typed, so it costs one comparison per character and nothing per frame.
    ///
    /// Nothing here gates anything: a tap completes the passage at any point, and the whole string
    /// is already the accessibility label.
    private func run() async {
        guard !rendersImmediately else {
            complete()
            return
        }
        isFinished = false
        visibleCharacters = 0
        let keystroke = 1 / charactersPerSecond
        for character in text {
            try? await Task.sleep(for: .seconds(keystroke))
            guard !Task.isCancelled else { return }
            guard !isFinished else { return }
            visibleCharacters += 1
            let rest = TypewriterProgress.dwell(after: character)
            guard rest > 0 else { continue }
            try? await Task.sleep(for: .seconds(keystroke * rest))
            guard !Task.isCancelled else { return }
            guard !isFinished else { return }
        }
        complete()
    }
}

/// The place name on the transition screen (`187:1103`) pulses; it never blinks out.
///
/// Opacity floors at `minimumOpacity` rather than zero — a name that disappears is a name somebody
/// misses — and the pulse stops entirely under Reduce Motion. It is decoration in both cases: the
/// name is the signal, the pulse never is (`NFR-A11Y-05`).
public struct HisploraBlink: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDim = false

    public static let minimumOpacity: Double = 0.55
    public static let period: Duration = .milliseconds(1100)

    public init() {}

    public func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || !isDim ? 1 : Self.minimumOpacity)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                value: isDim)
            .onAppear { if !reduceMotion { isDim = true } }
    }
}

public extension View {
    func hisploraBlink() -> some View {
        modifier(HisploraBlink())
    }
}
