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

    /// **The reference render's shape at well under half its length.** It runs a shade over four
    /// seconds, which is a title sequence; this is the seam between the story and the walk, and the
    /// walker crosses it at every checkpoint of every quest. The beats keep their proportions to each
    /// other — the turn is quick, the unrolling is the long one, the hold is the shortest — so it is
    /// the same movement, not a faster different one. `total` is what a test should assert against.
    ///
    /// **These are shorter than they were, because the screen was measurably slower than these
    /// numbers said.** The runner slept `hold(of:)` twice per beat — a merge left two identical
    /// `Task.sleep` calls in `StoryTransitionScreen.unseal` — so the walker waited about 3.3 s at a
    /// checkpoint, most of it looking at a blank open parchment. That doubling is gone, and the beats
    /// are trimmed with it: the wait the walker actually feels is the sum of the holds, and the open
    /// sheet has nothing on it, so the last two beats are where the trimming falls hardest.
    public func duration(of stage: HisploraScrollUnsealStage) -> Duration {
        guard !rendersImmediately else { return .zero }
        switch stage {
        case .sealed: return .zero
        case .widening: return .milliseconds(420)
        case .unbinding: return .milliseconds(260)
        case .unrolling: return .milliseconds(780)
        // Long enough to read as the sheet settling, short enough that nobody waits on it. The page
        // it hands over to draws the same parchment, so this beat holds a blank sheet — every
        // millisecond of it is a millisecond of nothing.
        case .open: return .milliseconds(140)
        }
    }

    /// How long the runner waits before starting the *next* beat — shorter than the beat itself, so
    /// the following one begins while this one is still easing out.
    ///
    /// **This is the fix for an opening that read as four separate movements.** Sleeping for exactly
    /// `duration(of:)` meant every beat ran to a full stop before the next one started, so the roll
    /// grew, stopped, faded, stopped, unrolled, stopped. Overlapping the tails hands the motion from
    /// one beat to the next without the object ever coming to rest mid-sequence. The overlap is
    /// small on purpose: the beat that *changes identity* (`unbinding`'s cross-fade) must still land
    /// on a silhouette that has finished growing, so `widening` keeps most of its tail.
    public func hold(of stage: HisploraScrollUnsealStage) -> Duration {
        guard !rendersImmediately else { return .zero }
        switch stage {
        case .sealed: return .zero
        case .widening: return .milliseconds(320)
        case .unbinding: return .milliseconds(190)
        case .unrolling: return .milliseconds(600)
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

    /// **The paper is uncovered, never stretched, and that is the whole difference.**
    ///
    /// The first pass drew the whole paper band and put a `scaleEffect(y: open)` on it, so at a
    /// third open the sheet was the finished picture squashed to a third of its height — the grain,
    /// the vignette and the bowed sides all compressed with it. On screen that reads as a rubber
    /// band being pulled, which is exactly what `verticalscroll2.mp4` does *not* do: in the
    /// reference render the paper is at its final scale from the first frame it is visible, and what
    /// changes is how much of it has come off the rolls.
    ///
    /// So the band is cut in two and each half is drawn at full size, clipped to what has unrolled:
    /// the head roll's half peels down from the top of the band, the foot roll's half peels up from
    /// the bottom, and the two meet in the middle at `open == 1`. At that moment the four slices are
    /// contiguous rows of one picture, so the last frame of the opening and the settled sheet are
    /// the same pixels rather than two things that nearly agree.
    ///
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
        let shown = paper * open
        // Split odd pixels toward the foot rather than rounding both halves, so the two never sum
        // to less than `shown` and leave a hairline of ground between them.
        let offHead = (shown / 2).rounded(.down)
        let offFoot = shown - offHead
        return VStack(spacing: 0) {
            slice(image, in: size, from: 0, height: top)
            slice(image, in: size, from: top, height: offHead)
            slice(image, in: size, from: top + paper - offFoot, height: offFoot)
            slice(image, in: size, from: top + paper, height: bottom)
        }
        // The layout box stays the full sheet's and the stack shrinks inside it, so the band's
        // centre never moves: the rolls travel out from the middle, which is what the reference
        // render does.
        .frame(width: size.width, height: size.height, alignment: .center)
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

/// The tied roll's idle shake — what it does while nobody has tapped it yet.
///
/// **A screen whose only control is a picture has to say that it is one.** `293:1595` draws the
/// scroll at rest and prints "Tap to reveal" under it, and on device the picture read as decoration:
/// the words were doing all the work, and a reader who did not look at the foot of the screen had
/// nothing telling them the object was live.
///
/// **It is a shake rather than a drift, and that was the correction.** A slow rise-and-fall reads as
/// an object floating — atmosphere, not an invitation. Four quick tips damping out, then a long
/// still hold, reads as the roll asking to be picked up. The proportions are what carry that: the
/// whole shake is under half a second and the rest between shakes is more than four times as long,
/// so the screen is at rest most of the time and the movement is an event rather than a state.
///
/// **Reduce Motion stops it entirely rather than shrinking it.** There is nowhere for an idle loop
/// to arrive, so a collapsed version of it is a still picture — which is what a reader who asked for
/// less movement should get (`NFR-A11Y-05`).
public enum HisploraScrollIdleShake {

    /// One tip of the shake. The loop runs these in order, forever, starting and ending at rest.
    public enum Beat: String, Sendable, CaseIterable {
        /// Still, and by far the longest of them — the shake is punctuation between rests.
        case rest
        case tipBack
        case tipForward
        case tipBackAgain
        case tipForwardAgain

        /// The sway, in degrees, applied *around* the roll's own drawn tilt rather than replacing
        /// it. Each tip is smaller than the one before: a shake that does not damp reads as a
        /// glitch rather than as an object being nudged.
        public var tiltDegrees: Double {
            switch self {
            case .rest: return 0
            case .tipBack: return -3.4
            case .tipForward: return 2.6
            case .tipBackAgain: return -1.6
            case .tipForwardAgain: return 0.7
            }
        }

        /// How far the roll lifts on this beat, in points. Small, and only on the first two: a
        /// shake that also travels reads as the object being thrown rather than knocked.
        public var lift: CGFloat {
            switch self {
            case .rest: return 0
            case .tipBack: return -5
            case .tipForward: return -3
            case .tipBackAgain: return -1.5
            case .tipForwardAgain: return 0
            }
        }

        /// How long this beat lasts, in seconds.
        public var seconds: Double {
            switch self {
            case .rest: return 2.2
            case .tipBack: return 0.13
            case .tipForward: return 0.11
            case .tipBackAgain: return 0.1
            case .tipForwardAgain: return 0.09
            }
        }
    }

    /// The whole loop, rest included.
    public static var cycleSeconds: Double {
        Beat.allCases.reduce(0) { $0 + $1.seconds }
    }

    /// How long the shake itself runs, without the rest it punctuates.
    public static var shakeSeconds: Double {
        Beat.allCases.filter { $0 != .rest }.reduce(0) { $0 + $1.seconds }
    }

    /// The curve one tip travels on. The tips are quick and even; coming back to rest is where the
    /// weight is, so that beat alone gets a spring.
    public static func animation(of beat: Beat) -> Animation {
        beat == .rest
            ? .spring(duration: beat.seconds * 0.35, bounce: 0.2)
            : .easeInOut(duration: beat.seconds)
    }

    /// How the roll comes back to rest when the walker taps it mid-tip.
    ///
    /// **The shake used to stop rather than settle**, which is most of what read as the tap being
    /// stiff: `PhaseAnimator` was unmounted the instant `isActive` went false, so whatever tilt and
    /// lift the current beat had reached snapped to zero on the same frame the opening started. A
    /// picture that jumps and *then* begins moving smoothly reads as a jolt, however good the
    /// movement after it is. The shake now runs on plain state, so switching it off is an animation
    /// like any other — short enough to be under the opening's first beat, soft enough to hand the
    /// roll's own weight into it.
    public static let settle: Animation = .spring(duration: 0.26, bounce: 0.12)

    /// How faint the caption goes at the bottom of its own breath. It shares the roll's clock so the
    /// two read as one object asking rather than as two things animating near each other.
    public static let captionFloor: Double = 0.62
}

/// Runs `HisploraScrollIdleShake` on whatever it wraps for as long as `isActive`.
private struct HisploraIdleShakeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool

    private var running: Bool { isActive && !reduceMotion }

    /// The tilt and lift the roll is at right now — one pair of values whether the shake is running,
    /// settling or off, which is the whole point of driving it by hand.
    ///
    /// **`PhaseAnimator` was what this used to be, and it could not settle.** It applied its phase
    /// inside its own builder, so the view it produced simply stopped existing when `isActive` went
    /// false and the roll snapped back to level on that frame — under the walker's thumb, on the
    /// frame the opening began. A chain of `repeatForever` animations is the other obvious shape and
    /// is the one `PhaseAnimator` was chosen over: the beats have different lengths, so a repeating
    /// animation per property loops each on its own clock and the tilt and the lift drift apart
    /// within a few cycles. One task walking the beats in order keeps them on one clock *and* leaves
    /// the values somewhere an ordinary animation can take over from.
    @State private var tiltDegrees: Double = 0
    @State private var lift: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(tiltDegrees))
            .offset(y: lift)
            .task(id: running) { @MainActor in
                guard running else {
                    // Not a reset — the roll travels back to level from wherever the tap caught it
                    // (`HisploraScrollIdleShake.settle`).
                    withAnimation(HisploraScrollIdleShake.settle) {
                        tiltDegrees = 0
                        lift = 0
                    }
                    return
                }
                while !Task.isCancelled {
                    for beat in HisploraScrollIdleShake.Beat.allCases {
                        withAnimation(HisploraScrollIdleShake.animation(of: beat)) {
                            tiltDegrees = beat.tiltDegrees
                            lift = beat.lift
                        }
                        // A cancelled sleep throws, which leaves the loop with the values mid-tip —
                        // exactly what the `guard` above then animates out of.
                        do { try await Task.sleep(for: .seconds(beat.seconds)) } catch { return }
                    }
                }
            }
    }
}

/// The caption's half of the same invitation — opacity only, since the words sit at a measured
/// distance from the home indicator and must not move off it.
private struct HisploraIdlePulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool
    @State private var lifted = false

    private var running: Bool { isActive && !reduceMotion }

    func body(content: Content) -> some View {
        let dim = (running && lifted) ? HisploraScrollIdleShake.captionFloor : 1
        content
            .opacity(dim)
            .animation(
                running
                    ? .easeInOut(duration: HisploraScrollIdleShake.cycleSeconds / 2)
                        .repeatForever(autoreverses: true)
                    : .easeOut(duration: 0.18),
                value: dim)
            // Started here rather than at `init`, so the first breath begins on the frame the
            // screen actually appears on instead of part-way through.
            .onAppear { lifted = true }
    }
}

public extension View {
    /// The sealed scroll's idle shake — see `HisploraScrollIdleShake`.
    func hisploraIdleShake(isActive: Bool) -> some View {
        modifier(HisploraIdleShakeModifier(isActive: isActive))
    }

    /// The caption's opacity half of the same invitation.
    func hisploraIdlePulse(isActive: Bool) -> some View {
        modifier(HisploraIdlePulse(isActive: isActive))
    }
}
