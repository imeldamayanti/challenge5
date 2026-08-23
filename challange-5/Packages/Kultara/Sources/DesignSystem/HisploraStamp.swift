import SwiftUI

/// The perforated postage stamp the Journal envelope and the Explorer's Card are franked with
/// (Figma `511:1431`, `547:2848`).
///
/// **Drawn rather than packaged, and deliberately so.** The design exports the outline as a 25.8 ×
/// 35 SVG — a rectangle whose four edges are a run of half-circle bites. At that size it is a
/// thumbnail; the Stamps tab sets the same object at 160 points, where a rasterised copy of a 26
/// point vector is mush. A perforation is a parameter (how many bites fit along an edge, how deep
/// each one is), not a glyph, so it is reproduced as a `Shape` that stays crisp at both sizes and
/// at every Dynamic Type step. This is the one place in the package that redraws design geometry
/// instead of shipping the export, and the reason is legibility rather than convenience.
public struct HisploraStampShape: Shape {

    /// How many bites the export carries across its width — 25.7875 points of edge, fourteen
    /// perforations.
    ///
    /// A *count*, not a pitch in points. The same stamp is set at 26 points on the envelope and at
    /// 160 on the Explorer's Card, and a fixed pitch would give the second one eighty-seven teeth:
    /// a fine dotted line rather than a perforation. Holding the count constant is what makes the
    /// two read as the same object at two sizes.
    public static let teethAcross: CGFloat = 14
    /// The perforated ring is cut with an even-odd fill so the inner circles subtract from the
    /// rectangle instead of adding bumps in the wrong direction.
    public static let fillStyle = FillStyle(eoFill: true)

    private let teethAcross: CGFloat
    /// An explicit count down the sides, for the one die whose two pitches differ — `921:2262`,
    /// the write-journal stamp, cuts 14 bites across (touching, pitch 25.85 on its 362-point
    /// paper) but only 13 down (pitch 41.8, spaced apart). `nil` keeps the derived count, which
    /// is what every other stamp wants: one pitch, bites touching on all four edges.
    private let teethDown: CGFloat?
    /// How much of the limiting pitch each bite's diameter takes. `nil` (the default) is 1 —
    /// bites touching, which is what the franked dies draw. The Journey Saved photo dies
    /// (`921:2938`/`2943`'s vector, 9 bites across at pitch 15.2 and 13 down at 14.4) cut a
    /// 10.5-point bite at both pitches — spaced apart — which is a span of about 0.71.
    private let biteSpan: CGFloat?

    public init(
        teethAcross: CGFloat = HisploraStampShape.teethAcross,
        teethDown: CGFloat? = nil,
        biteSpan: CGFloat? = nil
    ) {
        self.teethAcross = teethAcross
        self.teethDown = teethDown
        self.biteSpan = biteSpan
    }

    public func path(in rect: CGRect) -> Path {
        // A whole number of bites per edge, or the last one is clipped and the stamp reads as a
        // drawing mistake rather than as perforation.
        let across = max(4, teethAcross.rounded())
        let pitch = rect.width / across
        let down = max(4, (teethDown ?? (rect.height / pitch)).rounded())
        let stepX = rect.width / across
        let stepY = rect.height / down
        let radius = min(stepX, stepY) / 2 * min(biteSpan ?? 1, 1)

        var path = Path()
        path.addRect(rect)

        // Each bite is subtracted from the body, which `.evenOdd` turns into a notch.
        for index in 0..<Int(across) {
            let x = rect.minX + stepX * (CGFloat(index) + 0.5)
            path.addEllipse(in: CGRect(x: x - radius, y: rect.minY - radius,
                                       width: radius * 2, height: radius * 2))
            path.addEllipse(in: CGRect(x: x - radius, y: rect.maxY - radius,
                                       width: radius * 2, height: radius * 2))
        }
        for index in 0..<Int(down) {
            let y = rect.minY + stepY * (CGFloat(index) + 0.5)
            path.addEllipse(in: CGRect(x: rect.minX - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2))
            path.addEllipse(in: CGRect(x: rect.maxX - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2))
        }
        return path
    }
}

/// Where the printing sits on the paper, as fractions of the die (`705:2771`).
///
/// Fractions rather than points, for the reason the perforation is a count rather than a pitch:
/// the same object is set at 26 points on the envelope, 151 on the Explorer's Card and 216 on
/// the stamp award, and a margin fixed in points would be a hairline on one and a border on
/// another.
enum HisploraStampFranking {
    /// 6.37% of the width, left and right — the white margin the window and the caption both
    /// stand inside.
    static let margin: CGFloat = 0.0637
    static let topMargin: CGFloat = 0.0547
    static let bottomMargin: CGFloat = 0.0851
    /// The window runs from 5.47% to 74.93% of the height.
    static let windowHeight: CGFloat = 0.6946
    /// The air between the window and the name under it.
    static let gap: CGFloat = 0.0394
}

/// One franked stamp: a picture over a caption, on perforated paper.
///
/// **The picture is a slot, not an asset.** The design fills these four with illustrations of
/// Badung Market, Pura Maospahit, Puri Pemecutan and Museum Bali. The content tree has no per-place
/// artwork field — `heroImageAsset` exists on `Quest` alone — and an illustration captioned with a
/// real place's name is a claim about that place, which `FR-CP-05` requires to carry a source. So
/// the caller supplies whatever picture it legitimately has, and a stamp with none shows aged paper
/// rather than a borrowed photograph. Same argument as `KultaraPortraitFrame`'s empty frame.
public struct HisploraStampCard<Picture: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let title: String
    private let subtitle: String
    private let showsFranking: Bool
    private let teethAcross: CGFloat
    private let teethDown: CGFloat?
    private let biteSpan: CGFloat?
    private let picture: Picture

    /// 152 × 206 — the perforated frame `547:2851` exports (`Images/badges-frame.svg`), and the
    /// proportion every stamp on the Explorer's Card is now cut to.
    ///
    /// **Fixed, not derived.** The card used to size its window and let the caption add whatever
    /// height it needed, so a two-line place name made one stamp in a grid of them taller than its
    /// neighbour and the perforations came out at a different pitch on each. A stamp is a die-cut
    /// object: it is the same shape whatever is printed on it. The earlier `25.788 / 35` was the
    /// thumbnail's own box on the envelope and is within a thousandth of this one, so the envelope's
    /// franking is unchanged by the switch.
    public static var aspectRatio: CGFloat { 152.0 / 206.0 }

    /// - Parameter showsFranking: whether to print the name and region under the window. The
    ///   design sets them at 2.27 and 1.42 points on the envelope, which is a texture rather than
    ///   words — reproduced at a readable size they would be larger than the stamp. So the
    ///   envelope's stamps are the paper alone, and the Explorer's Card, where the same stamp is
    ///   set six times larger, is where the names are actually printed and read.
    /// - Parameters teethAcross/teethDown/biteSpan: the perforation, for callers holding a die
    ///   whose cut differs from the card family's own. The completion carousel's stamps
    ///   (`921:2793`'s vector) cut 9 bites across and 13 down, spaced — the same die the
    ///   Journey Saved photo stamps hold — while the default stays the touching 14 the
    ///   Explorer's Card was measured against.
    public init(
        title: String,
        subtitle: String,
        showsFranking: Bool = true,
        teethAcross: CGFloat = HisploraStampShape.teethAcross,
        teethDown: CGFloat? = nil,
        biteSpan: CGFloat? = nil,
        @ViewBuilder picture: () -> Picture
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsFranking = showsFranking
        self.teethAcross = teethAcross
        self.teethDown = teethDown
        self.biteSpan = biteSpan
        self.picture = picture()
    }

    public var body: some View {
        paper
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            // White, as the export is filled. The window's own aged cream shows only where a place
            // has no drawing, which is what an unfranked stamp looks like.
            .background(palette.paperStamp.color)
            // Even-odd, not the default non-zero. The path is a rectangle plus a run of circles
            // straddling its edges; under non-zero they union into the body and the card comes out a
            // plain rectangle, which is what shipped before this was caught on device. Under even-odd
            // the half of each circle inside the rectangle is subtracted and the half outside is
            // added — a bump with a notch beside it, which is what a perforation is.
            .clipShape(
                HisploraStampShape(
                    teethAcross: teethAcross, teethDown: teethDown, biteSpan: biteSpan),
                style: FillStyle(eoFill: true))
            // `705:2769`'s own drop shadow — the grid is lifted off the sheet as a stack of stuck-on
            // objects. Only on the franked size: on the envelope these are 26 points across and a
            // shadow at that scale is dirt on the paper.
            .shadow(color: showsFranking ? .black.opacity(0.25) : .clear, radius: 1.5, y: 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(subtitle)")
    }

    @ViewBuilder private var paper: some View {
        if showsFranking {
            GeometryReader { proxy in
                let size = proxy.size
                VStack(alignment: .leading, spacing: 0) {
                    window
                        .frame(height: size.height * HisploraStampFranking.windowHeight)
                    Spacer(minLength: size.height * HisploraStampFranking.gap)
                    franking
                }
                .padding(.horizontal, size.width * HisploraStampFranking.margin)
                .padding(.top, size.height * HisploraStampFranking.topMargin)
                .padding(.bottom, size.height * HisploraStampFranking.bottomMargin)
                .frame(width: size.width, height: size.height, alignment: .top)
            }
        } else {
            window.padding(2)
        }
    }

    private var window: some View {
        ZStack {
            Rectangle().fill(palette.paperWarm.color)
            picture
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var franking: some View {
        // The two roles the table cuts for exactly this: the display serif's bold in caps over the
        // sans at the smallest size it is legible at. Both scale with the reader's text size and
        // shrink before they wrap, because the die does not grow with them.
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .kultaraFont(.stampFranking)
                .foregroundStyle(palette.inkDark.color)
            Text(subtitle)
                .kultaraFont(.stampFrankingDetail)
                .foregroundStyle(palette.inkMuted.color)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public extension HisploraStampCard where Picture == EmptyView {
    /// A stamp with nothing to print in its window — the shipped case, because no place carries
    /// artwork. The aged paper behind the slot is what shows.
    init(title: String, subtitle: String, showsFranking: Bool = true) {
        self.init(title: title, subtitle: subtitle, showsFranking: showsFranking) { EmptyView() }
    }
}
