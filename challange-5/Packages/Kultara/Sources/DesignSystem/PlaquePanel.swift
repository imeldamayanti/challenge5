import SwiftUI

/// The cartouche the place notice is printed on — Figma `293:1613`, layer `293:1630`.
///
/// **The frame's own artwork is not shipped, and the reason is not taste.** `293:1630` is a stock
/// wedding-invitation plate: exported, it carries a dozen named individuals and businesses printed
/// across its middle (which is why the designer laid three opaque rectangles over it in Figma to
/// blank them out). Shipping that file — whole or patched — would put third parties' names and
/// somebody else's licensed engraving inside every copy of the app. So the panel is drawn: the
/// design's silhouette, its cream, and its inset rule, in code.
///
/// What that costs, stated rather than glossed: the frame's engraved crown and its corner
/// flourishes are not reproduced, and the small glyph centred on its lower edge is not either. If a
/// licensed or commissioned ornament arrives, it drops in behind `content` without this shape
/// changing — the same arrangement `KultaraPortraitFrame` already has with its own ornament.
public struct HisploraPlaqueShape: Shape {

    /// How deep the corner scoops cut, as a fraction of the panel's shorter side. Measured off
    /// `293:1630`: the notch spans roughly a twelfth of the 402-point width.
    public static let cornerFraction: CGFloat = 1.0 / 12.0

    public init() {}

    public func path(in r: CGRect) -> Path {
        let c = min(r.width, r.height) * Self.cornerFraction
        var p = Path()
        p.move(to: CGPoint(x: r.minX + c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        // Each corner is an arc centred *on* the corner rather than inside it, which is what turns
        // the usual convex round into the scoop the plate is cut with.
        p.addArc(center: CGPoint(x: r.maxX, y: r.minY), radius: c,
                 startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        p.addArc(center: CGPoint(x: r.maxX, y: r.maxY), radius: c,
                 startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX, y: r.maxY), radius: c,
                 startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        p.addArc(center: CGPoint(x: r.minX, y: r.minY), radius: c,
                 startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// The plaque with something printed on it: the cut shape filled in the flow's cream, the paper
/// texture the rest of the direction already uses, and the inset rule the plate draws just inside
/// its own edge.
public struct HisploraPlaquePanel<Content: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .background {
                HisploraPlaqueShape()
                    .fill(palette.paperCream.color)
                    .overlay {
                        // Decoration only, and faint: the rule marks the plate's border, it never
                        // carries meaning (`NFR-A11Y-05`), so it is not a measured pair.
                        HisploraPlaqueShape()
                            .stroke(palette.inkMuted.color.opacity(0.28),
                                    lineWidth: KultaraMetrics.hairline)
                            .padding(KultaraMetrics.md)
                    }
            }
    }
}
