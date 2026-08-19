import SwiftUI

/// The fine speckle every screen's ground now carries.
///
/// It is a *texture over a token*, never a token of its own — the same argument
/// `KultaraPaperTexture` makes for the cream sheet, and it is what keeps `NFR-A11Y-03` measurable.
/// `KultaraThemeTests` and `HisploraThemeTests` measure pairs of palette values; a picture behind
/// text is something neither can see. Two properties keep the measurements honest here:
///
/// 1. the dots are drawn in a tint derived from the ground beneath them, at a per-dot alpha capped
///    by `maximumDotOpacity`, so no dot reaches a colour a measured pair does not describe, and
/// 2. they are sparse — `areaPerDot` square points apart on average — so the ground a glyph
///    actually sits on is the token, with a speck occasionally beside it.
///
/// Drawn rather than shipped as artwork. The one texture in the tree that *is* artwork
/// (`paper-texture.png`, 456 KB of cream) has to be authored once per ground it sits on, and this
/// one sits on nine: three museum surfaces, three Hisplora browns and three Hisplora papers. A
/// generator takes the ground as an argument instead, which is also why the field is deterministic
/// — the same size yields the same dots, so `SpeckleTests` can assert density and opacity rather
/// than a screenshot.
public enum KultaraSpeckle {

    /// One speck, in points, in the space of the field that produced it.
    public struct Dot: Sendable, Equatable {
        public let x: Double
        public let y: Double
        public let radius: Double
        public let opacity: Double

        public init(x: Double, y: Double, radius: Double, opacity: Double) {
            self.x = x
            self.y = y
            self.radius = radius
            self.opacity = opacity
        }
    }

    /// Average square points of ground per speck. Sparse by design: at ~420 pt² a 393×852 screen
    /// carries a little under 800 specks, which reads as grain at arm's length and as nothing at
    /// all under a line of body text.
    public static let areaPerDot: Double = 420

    /// The ceiling on any single dot's alpha. Low enough that a speck landing under a glyph cannot
    /// move that glyph's measured ratio into a different band.
    public static let maximumDotOpacity: Double = 0.30

    /// The floor, so a dot is either visible or not generated at all.
    public static let minimumDotOpacity: Double = 0.08

    /// Radius range, in points. Sub-pixel at the small end on every shipping scale factor, which is
    /// what makes the field read as paper fibre rather than as polka dots.
    public static let radiusRange: ClosedRange<Double> = 0.35...0.95

    /// The specks for a field of this size.
    ///
    /// Deterministic: the seed is fixed and the stream is consumed in a fixed order, so a given
    /// size always yields the same field. That matters twice — a scroll or a state change must not
    /// make the ground shimmer, and the test suite needs something stable to measure.
    public static func dots(in size: CGSize) -> [Dot] {
        let width = Double(size.width)
        let height = Double(size.height)
        guard width > 0, height > 0 else { return [] }

        let count = Int((width * height / areaPerDot).rounded())
        guard count > 0 else { return [] }

        var random = SplitMix64(seed: 0x4B3A_3300_5EED)
        var dots: [Dot] = []
        dots.reserveCapacity(count)
        for _ in 0..<count {
            dots.append(Dot(
                x: random.nextUnit() * width,
                y: random.nextUnit() * height,
                radius: radiusRange.lowerBound
                    + random.nextUnit() * (radiusRange.upperBound - radiusRange.lowerBound),
                opacity: minimumDotOpacity
                    + random.nextUnit() * (maximumDotOpacity - minimumDotOpacity)))
        }
        return dots
    }

    /// The colour the specks are drawn in over a given ground.
    ///
    /// Two values rather than one, because the field has to read on both directions' grounds: the
    /// browns and the scrim want a light fleck, the cream papers want a dark one. The choice is
    /// made from the ground's own relative luminance rather than from the colour scheme, so a
    /// screen that paints an opaque ground of its own — every `HisploraStage`, and the region
    /// map's scrim — gets the right fleck without anyone telling it which direction it belongs to.
    public static func tint(over ground: SRGBColor) -> SRGBColor {
        ground.relativeLuminance < 0.35 ? lightFleck : darkFleck
    }

    /// The fleck on the dark grounds — `inkCream`, so the speckle is a colour the palette already
    /// contains rather than a bare white nobody measured.
    public static let lightFleck = SRGBColor(hex: "#FDF2DE")

    /// The fleck on the papers — the museum ink, for the same reason.
    public static let darkFleck = SRGBColor(hex: "#201C18")
}

/// A 64-bit SplitMix generator, inlined so the field needs no dependency and no `Foundation`
/// randomness. `SystemRandomNumberGenerator` would reshuffle the ground on every redraw.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in `0..<1`.
    mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}

/// The speckle as a view: a `Canvas` of the dots, over whatever the caller has already painted.
///
/// Decoration, and marked as such — it is hidden from assistive technology (`NFR-A11Y-04`) and
/// passes every touch through, so it can be laid over a ground without becoming part of the
/// screen's structure.
public struct KultaraSpeckleField: View {
    private let tint: SRGBColor

    /// The field for a ground, picking the fleck that reads on it.
    public init(over ground: SRGBColor) {
        tint = KultaraSpeckle.tint(over: ground)
    }

    /// The field in a named fleck, for a caller that knows better than the luminance rule.
    public init(fleck: SRGBColor) {
        tint = fleck
    }

    public var body: some View {
        Canvas { context, size in
            let color = tint.color
            for dot in KultaraSpeckle.dots(in: size) {
                let box = CGRect(
                    x: dot.x - dot.radius,
                    y: dot.y - dot.radius,
                    width: dot.radius * 2,
                    height: dot.radius * 2)
                context.fill(Path(ellipseIn: box), with: .color(color.opacity(dot.opacity)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public extension View {
    /// Paints a screen's ground: the token, then the speckle over it.
    ///
    /// One modifier rather than a `ZStack` at each of the twelve call sites, because the ordering
    /// is the load-bearing part — token first, texture second — and twelve hand-written stacks is
    /// twelve chances to put a picture *instead of* the colour a contrast pair was measured
    /// against.
    func kultaraSpeckledGround(_ ground: SRGBColor) -> some View {
        background {
            ZStack {
                ground.color
                KultaraSpeckleField(over: ground)
            }
            .ignoresSafeArea()
        }
    }
}
