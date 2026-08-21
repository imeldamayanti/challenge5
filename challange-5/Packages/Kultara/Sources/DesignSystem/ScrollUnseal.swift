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
        case .widening: return .milliseconds(520)
        case .unbinding: return .milliseconds(300)
        case .unrolling: return .milliseconds(950)
        // Long enough to read as the sheet settling, short enough that nobody waits on it.
        case .open: return .milliseconds(240)
        }
    }

    /// How long the runner waits before starting the *next* beat — shorter than the beat itself, so
    /// the following one begins while this one is still easing out.
    ///
    /// **This is the fix for an opening that read as four separate movements.** Sleeping for exactly
    /// `duration(of:)` meant every beat ran to a full stop before the next one started, so the roll
    /// grew, stopped, faded, stopped, unrolled, stopped. Overlapping the tails hands the motion from
    /// one beat to the next without the object ever coming to rest mid-sequence. The overlap is
    /// small on purpose: the two beats that *change identity* (`unbinding`'s cross-fade) must still
    /// land on a silhouette that has finished growing, so `widening` keeps most of its tail.
    public func hold(of stage: HisploraScrollUnsealStage) -> Duration {
        guard !rendersImmediately else { return .zero }
        switch stage {
        case .sealed: return .zero
        case .widening: return .milliseconds(430)
        case .unbinding: return .milliseconds(215)
        case .unrolling: return .milliseconds(780)
        case .open: return duration(of: .open)
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
        // A tied roll growing under the reader's thumb carries its weight into the stop — quick off
        // the mark, long tail. `.smooth(duration:)` was a spring, and a spring does not finish at
        // its `duration`: the next beat started on values still in motion and the two animations
        // fought, which is most of what read as a stutter here. A timing curve ends when it says it
        // does, which is what makes `hold(of:)`'s overlap a chosen overlap rather than an accident.
        case .widening: return .timingCurve(0.22, 0.68, 0.24, 1, duration: seconds)
        // The swap between the two pictures is a fade and nothing else; a curve on it would read as
        // the object changing size at the moment it changes identity.
        case .unbinding: return .easeInOut(duration: seconds)
        // Paper coming off a rod does not accelerate. It starts, it runs, it eases into rest.
        case .unrolling: return .timingCurve(0.32, 0, 0.12, 1, duration: seconds)
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
    /// *into* a sheet whose height is its own words', so a picture that insisted on 368 × 482 would
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
                    // The same nine-slice `HisploraParchmentSheet` settles into, and it has to be:
                    // this unrolls into a box the height of the task's own words, which is well past
                    // the art's 482, so a plain stretch here would hand over to a screen whose rolls
                    // are a third the size and the page would visibly snap at the seam.
                    .resizable(capInsets: HisploraParchmentMetrics.rollCaps,
                               resizingMode: .stretch)
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

    /// **The rolls are absolute, not fractions of the box.** They were fractions while the sheet was
    /// a plain stretch and both ends grew together; now that the settled sheet pins them
    /// (`HisploraParchmentMetrics.rollCaps`), a roll that is a fraction of a 700-point box opens at
    /// nearly a hundred points and hands over to one drawn at sixty-four.
    /// `HisploraParchmentUnrollMetrics` still records where they sit in the *file*, which is what the
    /// guard scans; this is where they sit on the *screen*.
    private func unrolling(_ image: Image, in size: CGSize) -> some View {
        let top = HisploraParchmentMetrics.rollHeadHeight
        let bottom = HisploraParchmentMetrics.rollFootHeight
        let paper = max(0, size.height - top - bottom)
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

    /// One horizontal band of the asset, drawn at the size the whole asset would be drawn at — and
    /// nine-sliced there, so the band a roll is cut from is the roll at the height it settles to.
    private func slice(_ image: Image, in size: CGSize, from y: CGFloat, height: CGFloat) -> some View {
        image
            .resizable(capInsets: HisploraParchmentMetrics.rollCaps, resizingMode: .stretch)
            .frame(width: size.width, height: size.height)
            .offset(y: -y)
            .frame(width: size.width, height: height, alignment: .top)
            .clipped()
    }
}

/// Where the two rolls end in `quest-parchment.png`, in fractions of its own height.
///
/// Measured off the file's alpha rather than read off the frame: a row-by-row scan of the 368 × 482
/// file puts the head roll at y 0…63 and the foot roll at 418…482 — the rows that run the picture's
/// full width, before the sheet's bowed sides start narrowing it. `HisploraParchmentMetrics`'s own
/// numbers are *print* margins in the same 368 × 482 space and are a different measurement of a
/// different thing; they are not interchangeable with these.
///
/// **These describe the file, not the screen.** The drawing takes its roll heights from
/// `HisploraParchmentMetrics.rollHeadHeight`/`rollFootHeight` — the same points the nine-slice pins
/// them to — and these fractions are what the guard scans the shipped bytes against, so a re-export
/// cropped differently fails there rather than cutting a roll in half on device.
public enum HisploraParchmentUnrollMetrics {
    public static let topRollHeight: CGFloat = 64.0 / 482.0
    public static let bottomRollHeight: CGFloat = 64.0 / 482.0
    /// What is left between the rolls, and therefore the only part the opening stretches.
    public static let sheetHeight: CGFloat = 1 - topRollHeight - bottomRollHeight

    /// How tall the sheet stands with no paper off the rolls at all — the two rolls, head against
    /// foot, which is the shape the tied roll becomes.
    public static let closedHeight: CGFloat = topRollHeight + bottomRollHeight
}

/// How the tied roll moves while nobody has touched it yet — the idle beat before `sealed` becomes
/// `widening`.
///
/// **A screen whose only control is a picture has to say that it is one.** `293:1595` draws the
/// scroll at rest and prints "Tap to reveal" under it, and on device the picture read as decoration:
/// the words were doing all the work, and a reader who did not look at the foot of the screen had
/// nothing telling them the object was live. A slow drift makes the roll the thing that invites the
/// tap, which is what the frame's composition assumes.
///
/// It is deliberately below the threshold where it reads as an animation playing — one breath every
/// three and a half seconds, seven points of travel, under two degrees of sway. Anything larger
/// competes with the opening the tap starts.
///
/// **Reduce Motion stops it entirely rather than shrinking it.** There is nowhere for an idle loop
/// to arrive, so a collapsed version of it is a still picture — which is what a reader who asked for
/// less movement should get (`NFR-A11Y-05`).
public enum HisploraScrollIdleMotion {
    /// How far the roll rises off its resting line at the top of the breath, in points.
    public static let floatOffset: CGFloat = 7
    /// The sway, in degrees, applied *around* the roll's own drawn tilt rather than replacing it.
    public static let tiltDegrees: Double = 1.6
    /// How much the roll grows at the top of the breath, as a fraction of its own size.
    public static let scaleRange: CGFloat = 0.014
    /// One half-breath. The loop autoreverses, so a full rise-and-fall is twice this.
    public static let period: Double = 3.4
    /// How long the drift takes to come to rest once the roll has been tapped. Short, so it is out
    /// of the way before `widening` is doing anything the eye can follow.
    public static let settle: Double = 0.18
    /// How faint the caption goes at the bottom of its own breath. It shares the roll's clock so the
    /// two read as one object breathing, not as two things animating near each other.
    public static let captionFloor: Double = 0.62
}

/// Applies `HisploraScrollIdleMotion` to whatever it wraps for as long as `isActive`.
///
/// The repeating animation is attached to the phase value rather than to the view, so switching
/// `isActive` off swaps the repeat for a single short easing back to rest instead of leaving a
/// forever-animation running underneath the sequence that follows it.
private struct HisploraIdleDrift: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool
    let sways: Bool
    @State private var lifted = false

    private var running: Bool { isActive && !reduceMotion }
    private var phase: CGFloat { (running && lifted) ? 1 : 0 }

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 + HisploraScrollIdleMotion.scaleRange * phase)
            .rotationEffect(
                .degrees(sways ? HisploraScrollIdleMotion.tiltDegrees * Double(phase) : 0))
            .offset(y: -HisploraScrollIdleMotion.floatOffset * phase)
            .animation(
                running
                    ? .easeInOut(duration: HisploraScrollIdleMotion.period)
                        .repeatForever(autoreverses: true)
                    : .easeOut(duration: HisploraScrollIdleMotion.settle),
                value: phase)
            // Started here rather than at `init`, so the first breath begins on the frame the screen
            // actually appears on instead of part-way through.
            .onAppear { lifted = true }
    }
}

/// The caption's half of the same breath — opacity only, since the words sit at a measured distance
/// from the home indicator and must not move off it.
private struct HisploraIdlePulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool
    @State private var lifted = false

    private var running: Bool { isActive && !reduceMotion }

    func body(content: Content) -> some View {
        let dim = (running && lifted) ? HisploraScrollIdleMotion.captionFloor : 1
        content
            .opacity(dim)
            .animation(
                running
                    ? .easeInOut(duration: HisploraScrollIdleMotion.period)
                        .repeatForever(autoreverses: true)
                    : .easeOut(duration: HisploraScrollIdleMotion.settle),
                value: dim)
            .onAppear { lifted = true }
    }
}

public extension View {
    /// The sealed scroll's idle breath — see `HisploraScrollIdleMotion`.
    ///
    /// - Parameter sways: whether the drift adds its own rotation. False for anything already drawn
    ///   at a fixed angle it must not be nudged off.
    func hisploraIdleDrift(isActive: Bool, sways: Bool = true) -> some View {
        modifier(HisploraIdleDrift(isActive: isActive, sways: sways))
    }

    /// The caption's opacity half of the same breath.
    func hisploraIdlePulse(isActive: Bool) -> some View {
        modifier(HisploraIdlePulse(isActive: isActive))
    }
}
