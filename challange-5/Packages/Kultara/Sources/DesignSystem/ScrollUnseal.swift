import SwiftUI

/// Where the sealed scroll is in opening itself — the four beats of the reference render, in order.
///
/// A value rather than a pile of booleans, for the reason `HisploraEnvelopeStage` is one: the order
/// matters (nothing reaches `unrolling` without passing `unbinding`), and a test should be able to
/// assert that without building a view.
public enum HisploraScrollUnsealStage: String, Sendable, CaseIterable, Comparable {
    /// Tied, tilted, at rest — `293:1599` as the transition screen has always drawn it.
    case sealed
    /// The roll grows to the width the open sheet will have. The ribbon is still on, and the tilt
    /// does not change — `293:1599` already draws the tied roll level (the asset's own diagonal is
    /// what `sealedTiltDegrees` cancels), so there is nothing to straighten and turning it would
    /// tip a level object over.
    case widening
    /// The ribbon is gone and the roll is the sheet's own two rolls, head against foot.
    case unbinding
    /// The paper comes off them.
    case unrolling
    /// Open, and held for a moment before the screen hands over.
    case open

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }

    public var next: Self? {
        guard let index = Self.allCases.firstIndex(of: self) else { return nil }
        let following = Self.allCases.index(after: index)
        return following < Self.allCases.endIndex ? Self.allCases[following] : nil
    }

    /// Whether the tied roll is what is on screen, or the sheet is.
    ///
    /// The swap happens at `unbinding`, where the tied roll and the shut sheet are the same
    /// silhouette at the same size — which is what lets one picture become the other instead of
    /// dissolving into it.
    public var showsSealedRoll: Bool { self < .unbinding }

    /// How far the sheet is off its rolls at this beat.
    public var openFraction: CGFloat { self >= .unrolling ? 1 : 0 }
}

/// How long each beat lasts, and what it lasts for a walker who has asked for less movement.
///
/// **Reduce Motion and VoiceOver skip it rather than collapsing it.** The Journal's envelope
/// collapses its opening to a cut because the opening *is* that screen's content; this one is a
/// door between two screens the walk has to get through, and a cut through a door is the door
/// opening. Zero-length beats leave the walker on the task sheet, which is where the tap was going.
public struct HisploraScrollUnsealSequence: Sendable, Equatable {

    /// The tilt the tied roll is drawn at — `293:1599`'s own `rotate-[41.6deg]`, which cancels the
    /// diagonal baked into `quest-scroll.png` and stands the roll level. It is a constant through
    /// the whole opening: animating it to zero tips the level roll back onto the asset's diagonal,
    /// which is what the first pass did and what it looked like.
    public static let sealedTiltDegrees: Double = TransitionScrollMetrics.rotationDegrees

    public let rendersImmediately: Bool

    public init(rendersImmediately: Bool) {
        self.rendersImmediately = rendersImmediately
    }

    /// **The reference render's shape at about half its length.** It runs a shade over four seconds,
    /// which is a title sequence; this is the seam between the story and the walk, and the walker
    /// crosses it at every checkpoint of every quest. The beats keep their proportions to each other
    /// — the turn is quick, the unrolling is the long one, the hold is the shortest — so it is the
    /// same movement, not a faster different one. `total` is what a test should assert against.
    public func duration(of stage: HisploraScrollUnsealStage) -> Duration {
        guard !rendersImmediately else { return .zero }
        switch stage {
        case .sealed: return .zero
        case .widening: return .milliseconds(550)
        case .unbinding: return .milliseconds(320)
        case .unrolling: return .milliseconds(900)
        // Long enough to read as the sheet settling, short enough that nobody waits on it.
        case .open: return .milliseconds(260)
        }
    }

    /// The curve each beat moves on. One per beat rather than one for the whole sequence, which is
    /// the correction `HisploraEnvelopeSequence` records: a beat animated for longer than it lasts
    /// finishes early and then sits still.
    public func animation(of stage: HisploraScrollUnsealStage) -> Animation? {
        guard !rendersImmediately else { return nil }
        let seconds = duration(of: stage).seconds
        switch stage {
        case .sealed, .open: return nil
        // A tied roll growing under the reader's thumb carries its weight into the stop.
        case .widening: return .smooth(duration: seconds)
        // The swap between the two pictures is a fade and nothing else; a curve on it would read as
        // the object changing size at the moment it changes identity.
        case .unbinding: return .easeInOut(duration: seconds)
        // Paper coming off a rod does not accelerate. It starts, it runs, it eases into rest.
        case .unrolling: return .easeInOut(duration: seconds)
        }
    }

    /// The whole sequence, from the tap to the hand-over.
    public var total: Duration {
        HisploraScrollUnsealStage.allCases.reduce(Duration.zero) { $0 + duration(of: $1) }
    }
}

/// `447:1886`'s parchment part-unrolled: the two rolls at the size they are drawn, the sheet between
/// them narrowed to what has come off them.
///
/// The vertical twin of `HisploraMapScroll`'s opening, and the same three-slice for the same reason —
/// a roll that thins as the sheet comes off it is what gives a plain squash away. It is a *picture*
/// rather than a container: `HisploraParchmentSheet` still holds the task's words and still grows
/// with them (`NFR-A11Y-01`), and this draws the same paper with nothing on it for the moment the
/// screen is opening it.
public struct HisploraParchmentUnroll: View, Animatable {
    @Environment(\.hisploraPalette) private var palette

    private var openFraction: CGFloat

    public init(openFraction: CGFloat = 1) {
        self.openFraction = openFraction
    }

    /// `nonisolated` for the reason `HisploraMapScroll`'s is: the animation machinery drives this
    /// off the main actor, and it is one `CGFloat`.
    public nonisolated var animatableData: CGFloat {
        get { openFraction }
        set { openFraction = newValue }
    }

    private var open: CGFloat { min(1, max(0, openFraction)) }

    /// **It fills the frame it is given rather than keeping the art's aspect**, which is what
    /// `HisploraParchmentSheet` does with the same picture as a background. The caller is unrolling
    /// *into* a sheet whose height is its own words', so a picture that insisted on 368 × 478 would
    /// land at the wrong height however carefully the caller placed it.
    public var body: some View {
        GeometryReader { proxy in
            sheet(in: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    @ViewBuilder private func sheet(in size: CGSize) -> some View {
        if let image = HisploraScrollArt.sheet.image {
            if open >= 1 {
                image
                    .resizable()
                    .accessibilityHidden(true)
            } else {
                unrolling(image, in: size)
            }
        } else {
            RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                .fill(palette.paperCream.color)
                .accessibilityHidden(true)
        }
    }

    private func unrolling(_ image: Image, in size: CGSize) -> some View {
        let top = size.height * HisploraParchmentUnrollMetrics.topRollHeight
        let bottom = size.height * HisploraParchmentUnrollMetrics.bottomRollHeight
        let paper = size.height * HisploraParchmentUnrollMetrics.sheetHeight
        return VStack(spacing: 0) {
            slice(image, in: size, from: 0, height: top)
            slice(image, in: size, from: top, height: paper)
                // The layout box stays the full sheet's and the paper shrinks inside it, so the
                // band's centre never moves: the rolls travel out from the middle, which is what
                // the reference render does.
                .scaleEffect(y: open, anchor: .center)
                .frame(height: paper * open)
            slice(image, in: size, from: top + paper, height: bottom)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    /// One horizontal band of the asset, drawn at the size the whole asset would be drawn at.
    private func slice(_ image: Image, in size: CGSize, from y: CGFloat, height: CGFloat) -> some View {
        image
            .resizable()
            .frame(width: size.width, height: size.height)
            .offset(y: -y)
            .frame(width: size.width, height: height, alignment: .top)
            .clipped()
    }
}

/// Where the two rolls end in `quest-parchment.png`, in fractions of its own height.
///
/// Measured off the file's alpha rather than read off the frame: a row-by-row scan of the 438 × 570
/// export puts the head roll at y 0…79 and the foot roll at 494…570 — the rows that run the picture's
/// full width, before the sheet's bowed sides start narrowing it. `HisploraParchmentMetrics`'s own
/// numbers are *print* margins in the drawn 368 × 478 space and are a different measurement of a
/// different thing; they are not interchangeable with these.
public enum HisploraParchmentUnrollMetrics {
    public static let topRollHeight: CGFloat = 79.0 / 570.0
    public static let bottomRollHeight: CGFloat = 76.0 / 570.0
    /// What is left between the rolls, and therefore the only part the opening stretches.
    public static let sheetHeight: CGFloat = 1 - topRollHeight - bottomRollHeight

    /// How tall the sheet stands with no paper off the rolls at all — the two rolls, head against
    /// foot, which is the shape the tied roll becomes.
    public static let closedHeight: CGFloat = topRollHeight + bottomRollHeight
}
