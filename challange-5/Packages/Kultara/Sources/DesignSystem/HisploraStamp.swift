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

    private let teethAcross: CGFloat

    public init(teethAcross: CGFloat = HisploraStampShape.teethAcross) {
        self.teethAcross = teethAcross
    }

    public func path(in rect: CGRect) -> Path {
        // A whole number of bites per edge, or the last one is clipped and the stamp reads as a
        // drawing mistake rather than as perforation.
        let across = max(4, teethAcross.rounded())
        let pitch = rect.width / across
        let down = max(4, (rect.height / pitch).rounded())
        let stepX = rect.width / across
        let stepY = rect.height / down
        let radius = min(stepX, stepY) / 2

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
    private let picture: Picture

    /// 25.788 × 35 in the design.
    public static var aspectRatio: CGFloat { 25.788 / 35 }

    /// - Parameter showsFranking: whether to print the name and region under the window. The
    ///   design sets them at 2.27 and 1.42 points on the envelope, which is a texture rather than
    ///   words — reproduced at a readable size they would be larger than the stamp. So the
    ///   envelope's stamps are the paper alone, and the Explorer's Card, where the same stamp is
    ///   set six times larger, is where the names are actually printed and read.
    public init(
        title: String,
        subtitle: String,
        showsFranking: Bool = true,
        @ViewBuilder picture: () -> Picture
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsFranking = showsFranking
        self.picture = picture()
    }

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle().fill(palette.paperWarm.color)
                picture
            }
            .clipped()
            .frame(maxWidth: .infinity)
            .aspectRatio(showsFranking ? 1.05 : nil, contentMode: .fit)

            if showsFranking {
            VStack(alignment: .leading, spacing: 1) {
                // The franking, in the two roles the table already has for exactly this: the
                // museum label over its apparatus. The design sets the name in the display serif's
                // bold cut; `eyebrow` is the sans equivalent, and the reason to prefer it is that
                // the serif ships in one weight (see `Role.weight`).
                Text(title)
                    .kultaraFont(.eyebrow)
                    .foregroundStyle(palette.inkDark.color)
                Text(subtitle)
                    .kultaraFont(.caption)
                    .foregroundStyle(palette.inkMuted.color)
            }
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, KultaraMetrics.sm)
            .padding(.vertical, KultaraMetrics.xs)
            }
        }
        .padding(showsFranking ? KultaraMetrics.xs : 2)
        .background(palette.paperLight.color)
        // Even-odd, not the default non-zero. The path is a rectangle plus a run of circles
        // straddling its edges; under non-zero they union into the body and the card comes out a
        // plain rectangle, which is what shipped before this was caught on device. Under even-odd
        // the half of each circle inside the rectangle is subtracted and the half outside is
        // added — a bump with a notch beside it, which is what a perforation is.
        .clipShape(HisploraStampShape(), style: FillStyle(eoFill: true))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}

public extension HisploraStampCard where Picture == EmptyView {
    /// A stamp with nothing to print in its window — the shipped case, because no place carries
    /// artwork. The aged paper behind the slot is what shows.
    init(title: String, subtitle: String, showsFranking: Bool = true) {
        self.init(title: title, subtitle: subtitle, showsFranking: showsFranking) { EmptyView() }
    }
}
