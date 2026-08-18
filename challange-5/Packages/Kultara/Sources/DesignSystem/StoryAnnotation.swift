import SwiftUI

/// The hand-drawn marker loop the Story Line page rings a place name with — Figma `293:1643`,
/// layer `Element 01` (`293:1650`).
///
/// **A `Shape`, not a packaged PNG.** The design ships it as a 176 × 31 vector with a single filled
/// path, and it is kept as one here for three reasons that a raster would each cost: it takes the
/// palette's `highlight` rather than baking `#F3C029` into pixels, it stays crisp at whatever width
/// the phrase underneath it happens to wrap to, and — the one that decides it — the designer's note
/// asks for the mark to *arrive* after the passage finishes typing, which is a wipe across a vector
/// and a fade across a bitmap.
///
/// The path is the export's own, normalised to the unit square so the mark scales with the phrase
/// it rings instead of being positioned at fixed coordinates.
public struct HisploraHighlightMark: Shape {

    /// The design's own aspect, 176 × 31. Exposed because the mark is drawn behind a line of text
    /// whose height is the reader's to choose, and callers size against it rather than guessing.
    public static let aspectRatio: CGFloat = 176.0 / 31.0

    public init() {}

    public func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.61999 * r.width, y: 0.91399 * r.height))
        p.addCurve(to: CGPoint(x: 0.85830 * r.width, y: 0.87573 * r.height), control1: CGPoint(x: 0.71439 * r.width, y: 0.91921 * r.height), control2: CGPoint(x: 0.78658 * r.width, y: 0.91573 * r.height))
        p.addCurve(to: CGPoint(x: 0.93465 * r.width, y: 0.80963 * r.height), control1: CGPoint(x: 0.88422 * r.width, y: 0.86181 * r.height), control2: CGPoint(x: 0.90966 * r.width, y: 0.83572 * r.height))
        p.addCurve(to: CGPoint(x: 0.96565 * r.width, y: 0.74702 * r.height), control1: CGPoint(x: 0.94576 * r.width, y: 0.79746 * r.height), control2: CGPoint(x: 0.95640 * r.width, y: 0.77311 * r.height))
        p.addCurve(to: CGPoint(x: 0.96843 * r.width, y: 0.60613 * r.height), control1: CGPoint(x: 0.98139 * r.width, y: 0.70354 * r.height), control2: CGPoint(x: 0.98231 * r.width, y: 0.65657 * r.height))
        p.addCurve(to: CGPoint(x: 0.93835 * r.width, y: 0.51743 * r.height), control1: CGPoint(x: 0.95964 * r.width, y: 0.57308 * r.height), control2: CGPoint(x: 0.94899 * r.width, y: 0.54352 * r.height))
        p.addCurve(to: CGPoint(x: 0.84812 * r.width, y: 0.36437 * r.height), control1: CGPoint(x: 0.91012 * r.width, y: 0.45133 * r.height), control2: CGPoint(x: 0.87913 * r.width, y: 0.40611 * r.height))
        p.addCurve(to: CGPoint(x: 0.61120 * r.width, y: 0.14869 * r.height), control1: CGPoint(x: 0.77131 * r.width, y: 0.26175 * r.height), control2: CGPoint(x: 0.69172 * r.width, y: 0.19565 * r.height))
        p.addCurve(to: CGPoint(x: 0.33542 * r.width, y: 0.08434 * r.height), control1: CGPoint(x: 0.51958 * r.width, y: 0.09651 * r.height), control2: CGPoint(x: 0.42796 * r.width, y: 0.07390 * r.height))
        p.addCurve(to: CGPoint(x: 0.13228 * r.width, y: 0.15391 * r.height), control1: CGPoint(x: 0.26739 * r.width, y: 0.09129 * r.height), control2: CGPoint(x: 0.19937 * r.width, y: 0.11390 * r.height))
        p.addCurve(to: CGPoint(x: 0.01845 * r.width, y: 0.22348 * r.height), control1: CGPoint(x: 0.09433 * r.width, y: 0.17652 * r.height), control2: CGPoint(x: 0.05639 * r.width, y: 0.20087 * r.height))
        p.addCurve(to: CGPoint(x: 0.01706 * r.width, y: 0.22522 * r.height), control1: CGPoint(x: 0.01798 * r.width, y: 0.22348 * r.height), control2: CGPoint(x: 0.01752 * r.width, y: 0.22348 * r.height))
        p.addCurve(to: CGPoint(x: 0.00040 * r.width, y: 0.19739 * r.height), control1: CGPoint(x: 0.00734 * r.width, y: 0.23044 * r.height), control2: CGPoint(x: 0.00132 * r.width, y: 0.22000 * r.height))
        p.addCurve(to: CGPoint(x: 0.01336 * r.width, y: 0.15217 * r.height), control1: CGPoint(x: -0.00145 * r.width, y: 0.17478 * r.height), control2: CGPoint(x: 0.00318 * r.width, y: 0.16087 * r.height))
        p.addCurve(to: CGPoint(x: 0.20909 * r.width, y: 0.03390 * r.height), control1: CGPoint(x: 0.07814 * r.width, y: 0.10521 * r.height), control2: CGPoint(x: 0.14338 * r.width, y: 0.05825 * r.height))
        p.addCurve(to: CGPoint(x: 0.42195 * r.width, y: 0.00259 * r.height), control1: CGPoint(x: 0.27989 * r.width, y: 0.00781 * r.height), control2: CGPoint(x: 0.35069 * r.width, y: -0.00611 * r.height))
        p.addCurve(to: CGPoint(x: 0.77871 * r.width, y: 0.19739 * r.height), control1: CGPoint(x: 0.54272 * r.width, y: 0.01650 * r.height), control2: CGPoint(x: 0.66164 * r.width, y: 0.07912 * r.height))
        p.addCurve(to: CGPoint(x: 0.91383 * r.width, y: 0.37828 * r.height), control1: CGPoint(x: 0.82498 * r.width, y: 0.24435 * r.height), control2: CGPoint(x: 0.87033 * r.width, y: 0.30001 * r.height))
        p.addCurve(to: CGPoint(x: 0.97120 * r.width, y: 0.50525 * r.height), control1: CGPoint(x: 0.93373 * r.width, y: 0.41481 * r.height), control2: CGPoint(x: 0.95270 * r.width, y: 0.46003 * r.height))
        p.addCurve(to: CGPoint(x: 0.99157 * r.width, y: 0.58526 * r.height), control1: CGPoint(x: 0.97907 * r.width, y: 0.52438 * r.height), control2: CGPoint(x: 0.98601 * r.width, y: 0.55569 * r.height))
        p.addCurve(to: CGPoint(x: 0.98740 * r.width, y: 0.78354 * r.height), control1: CGPoint(x: 1.00406 * r.width, y: 0.65135 * r.height), control2: CGPoint(x: 1.00267 * r.width, y: 0.72615 * r.height))
        p.addCurve(to: CGPoint(x: 0.95594 * r.width, y: 0.86529 * r.height), control1: CGPoint(x: 0.97861 * r.width, y: 0.81659 * r.height), control2: CGPoint(x: 0.96751 * r.width, y: 0.84442 * r.height))
        p.addCurve(to: CGPoint(x: 0.87080 * r.width, y: 0.95400 * r.height), control1: CGPoint(x: 0.92910 * r.width, y: 0.91573 * r.height), control2: CGPoint(x: 0.89995 * r.width, y: 0.93660 * r.height))
        p.addCurve(to: CGPoint(x: 0.58714 * r.width, y: 0.99052 * r.height), control1: CGPoint(x: 0.77640 * r.width, y: 1.00444 * r.height), control2: CGPoint(x: 0.68200 * r.width, y: 1.00792 * r.height))
        p.addCurve(to: CGPoint(x: 0.47192 * r.width, y: 0.96617 * r.height), control1: CGPoint(x: 0.54873 * r.width, y: 0.98356 * r.height), control2: CGPoint(x: 0.51033 * r.width, y: 0.97661 * r.height))
        p.addCurve(to: CGPoint(x: 0.32292 * r.width, y: 0.91573 * r.height), control1: CGPoint(x: 0.42241 * r.width, y: 0.95226 * r.height), control2: CGPoint(x: 0.37243 * r.width, y: 0.93660 * r.height))
        p.addCurve(to: CGPoint(x: 0.18364 * r.width, y: 0.84094 * r.height), control1: CGPoint(x: 0.27619 * r.width, y: 0.89660 * r.height), control2: CGPoint(x: 0.22991 * r.width, y: 0.87225 * r.height))
        p.addCurve(to: CGPoint(x: 0.10683 * r.width, y: 0.76441 * r.height), control1: CGPoint(x: 0.15773 * r.width, y: 0.82355 * r.height), control2: CGPoint(x: 0.13181 * r.width, y: 0.79398 * r.height))
        p.addCurve(to: CGPoint(x: 0.07305 * r.width, y: 0.69658 * r.height), control1: CGPoint(x: 0.09480 * r.width, y: 0.75050 * r.height), control2: CGPoint(x: 0.08323 * r.width, y: 0.72441 * r.height))
        p.addCurve(to: CGPoint(x: 0.06842 * r.width, y: 0.46525 * r.height), control1: CGPoint(x: 0.05084 * r.width, y: 0.63222 * r.height), control2: CGPoint(x: 0.04945 * r.width, y: 0.54352 * r.height))
        p.addCurve(to: CGPoint(x: 0.10914 * r.width, y: 0.36611 * r.height), control1: CGPoint(x: 0.07953 * r.width, y: 0.41829 * r.height), control2: CGPoint(x: 0.09387 * r.width, y: 0.39046 * r.height))
        p.addCurve(to: CGPoint(x: 0.21464 * r.width, y: 0.25653 * r.height), control1: CGPoint(x: 0.14292 * r.width, y: 0.31219 * r.height), control2: CGPoint(x: 0.17855 * r.width, y: 0.28088 * r.height))
        p.addCurve(to: CGPoint(x: 0.36503 * r.width, y: 0.22000 * r.height), control1: CGPoint(x: 0.26416 * r.width, y: 0.22174 * r.height), control2: CGPoint(x: 0.31413 * r.width, y: 0.20957 * r.height))
        p.addCurve(to: CGPoint(x: 0.38261 * r.width, y: 0.26175 * r.height), control1: CGPoint(x: 0.37752 * r.width, y: 0.22174 * r.height), control2: CGPoint(x: 0.38308 * r.width, y: 0.23566 * r.height))
        p.addCurve(to: CGPoint(x: 0.36503 * r.width, y: 0.29653 * r.height), control1: CGPoint(x: 0.38215 * r.width, y: 0.28436 * r.height), control2: CGPoint(x: 0.37660 * r.width, y: 0.29479 * r.height))
        p.addCurve(to: CGPoint(x: 0.27480 * r.width, y: 0.30871 * r.height), control1: CGPoint(x: 0.33495 * r.width, y: 0.30001 * r.height), control2: CGPoint(x: 0.30488 * r.width, y: 0.30001 * r.height))
        p.addCurve(to: CGPoint(x: 0.12487 * r.width, y: 0.43046 * r.height), control1: CGPoint(x: 0.22344 * r.width, y: 0.32436 * r.height), control2: CGPoint(x: 0.17300 * r.width, y: 0.36089 * r.height))
        p.addCurve(to: CGPoint(x: 0.09341 * r.width, y: 0.49134 * r.height), control1: CGPoint(x: 0.11377 * r.width, y: 0.44612 * r.height), control2: CGPoint(x: 0.10313 * r.width, y: 0.46699 * r.height))
        p.addCurve(to: CGPoint(x: 0.09572 * r.width, y: 0.65483 * r.height), control1: CGPoint(x: 0.07120 * r.width, y: 0.55047 * r.height), control2: CGPoint(x: 0.07212 * r.width, y: 0.60787 * r.height))
        p.addCurve(to: CGPoint(x: 0.13135 * r.width, y: 0.70875 * r.height), control1: CGPoint(x: 0.10683 * r.width, y: 0.67745 * r.height), control2: CGPoint(x: 0.11886 * r.width, y: 0.69484 * r.height))
        p.addCurve(to: CGPoint(x: 0.24889 * r.width, y: 0.79746 * r.height), control1: CGPoint(x: 0.16976 * r.width, y: 0.75397 * r.height), control2: CGPoint(x: 0.20909 * r.width, y: 0.78006 * r.height))
        p.addCurve(to: CGPoint(x: 0.47562 * r.width, y: 0.88268 * r.height), control1: CGPoint(x: 0.32431 * r.width, y: 0.82876 * r.height), control2: CGPoint(x: 0.40020 * r.width, y: 0.86007 * r.height))
        p.addCurve(to: CGPoint(x: 0.61999 * r.width, y: 0.91399 * r.height), control1: CGPoint(x: 0.53069 * r.width, y: 0.90182 * r.height), control2: CGPoint(x: 0.58668 * r.width, y: 0.90704 * r.height))
        p.closeSubpath()
        return p
    }
}

/// A phrase with the marker loop drawn round it, sweeping in left to right once `isMarked` turns
/// true — `293:1643`'s "Puri Agung Pemecutan.", ringed after the passage above it has typed.
///
/// **The mark is never the signal.** `HisploraPalette.highlight` is decoration that fails contrast
/// against paper by a wide margin and says so on the token, so the phrase also carries a weight
/// change; a reader who cannot see the yellow still sees which words are picked out
/// (`NFR-A11Y-05`). Under Reduce Motion the mark is simply there rather than sweeping
/// (`NFR-A11Y-04`), and VoiceOver reads the phrase as ordinary text — the loop is
/// `accessibilityHidden`, because "hand-drawn circle" is not a fact about the place.
public struct HisploraMarkedPhrase: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let phrase: String
    private let font: Font
    private let isMarked: Bool

    /// How far past the phrase's own box the loop is drawn. The design rings a 17-point line with a
    /// 31-point mark, so the loop stands roughly 6 points clear of the type on every side.
    private static let bleed: CGFloat = 6

    public init(_ phrase: String, font: Font = .system(size: 17), isMarked: Bool) {
        self.phrase = phrase
        self.font = font
        self.isMarked = isMarked
    }

    public var body: some View {
        Text(phrase)
            .font(font)
            .fontWeight(.semibold)
            .foregroundStyle(palette.inkBody.color)
            .fixedSize(horizontal: false, vertical: true)
            .background(alignment: .leading) { mark }
    }

    private var mark: some View {
        // `-1` on the x axis: `293:1650` is drawn mirrored, so the loop's open tail falls on the
        // right of the phrase as the frame has it rather than on the left.
        HisploraHighlightMark()
            .fill(palette.highlight.color)
            .scaleEffect(x: -1, y: 1, anchor: .center)
            .padding(-Self.bleed)
            .mask(alignment: .leading) { sweep }
            .accessibilityHidden(true)
    }

    /// The stroke arriving as a stroke does — from the start of the phrase to its end — rather than
    /// the whole loop fading up at once.
    private var sweep: some View {
        GeometryReader { proxy in
            Rectangle()
                .frame(width: isMarked || reduceMotion ? proxy.size.width : 0)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.45),
                    value: isMarked)
        }
    }
}
