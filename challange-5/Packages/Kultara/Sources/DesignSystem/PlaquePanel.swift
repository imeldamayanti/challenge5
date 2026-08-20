import SwiftUI

/// The cartouche the place notice is printed on — Figma `293:1613`, layer `293:1630`.
///
/// **The frame's own artwork is not shipped, and the reason is not taste.** `293:1630` is a stock
/// wedding-invitation plate: exported, it carries a dozen named individuals and businesses printed
/// across its middle (which is why the designer laid three opaque rectangles over it in Figma to
/// blank them out). Shipping that file — whole or patched — would put third parties' names and
/// somebody else's licensed engraving inside every copy of the app.
///
/// **That changed on 2026-08-18, halfway.** `plaque-plate.png` now ships the plate as a picture with
/// the names erased from its pixels, and `HisploraPlaquePanel` prefers it — see
/// `HisploraPlaqueArtwork.plate`. The names problem is closed; the *licence* on the engraving is not,
/// and the drawing below is what the app falls back to and what it returns to the moment a
/// commissioned ornament replaces the file. Nothing here is dead code.
///
/// So the plate is also **drawn**: its silhouette, its cream, its inset rules, and — since the first
/// pass of this screen read as a blank cream ticket next to the mock-up — its engraving too. The
/// engraving is this project's own vector work rather than a trace of the stock plate: an acanthus
/// spray at the head, four corner curls, a pendant palmette on the lower lobe, and a faint
/// quatrefoil field over the whole sheet. It is the same *kind* of ornament in the same places at
/// the same weights, not the same drawing, which is what keeps the licence question closed while
/// putting the ornateness back.
///
/// **Every number below was measured off the exported plate rather than eyeballed.** The alpha
/// coverage of `293:1630` (402 × 675, sitting at y = 94 on the 874-point frame) gives:
/// straight sides at x = 24…381, the body's top edge at y = 44 and its bottom edge at y = 616, a
/// central lobe rising above the top edge to y ≈ 8 and a pendant lobe falling below the bottom edge
/// to y ≈ 660, and corner arcs that fit a radius-36 circle centred *on* the corner — a scoop, not
/// the usual convex round. `HisploraPlaqueMetrics` holds them and `PlaqueGeometryTests` asserts
/// them, so a later tidy-up cannot quietly flatten the shape back to a rounded rectangle.
public enum HisploraPlaqueMetrics {

    /// How far the head lobe rises above the body's top edge. 44 − 8 on the exported plate.
    public static let crestHeight: CGFloat = 33

    /// How far the pendant lobe falls below the body's bottom edge. 660 − 616.
    public static let pendantDepth: CGFloat = 44

    /// The corner scoop's radius, arced about the corner point itself. Fitted to the measured
    /// left-edge samples (58, 44), (56, 55), (49, 66), (28, 77), (24, 88) — a circle centred at the
    /// corner reproduces all five; a conventional rounded corner misses the first three by 20 points
    /// or more.
    public static let cornerRadius: CGFloat = 36

    /// Half the head lobe's base, where it leaves the body's top edge.
    public static let crestHalfWidth: CGFloat = 100

    /// Half the pendant lobe's base.
    public static let pendantHalfWidth: CGFloat = 90

    /// The two engraved rules, inset from the silhouette. The plate draws a heavier line with a
    /// lighter companion just inside it.
    public static let outerRuleInset: CGFloat = 12
    public static let innerRuleInset: CGFloat = 17

    /// The sheet's own proportions on `293:1630`: straight sides at x = 24…381 and the body's
    /// edges at y = 44 and y = 616, so 357 × 572. The panel's box is that sheet plus both lobes,
    /// and `panelHeight(forWidth:)` is what a caller that wants the plate at its *drawn* size —
    /// rather than at whatever size its contents happen to need — measures against.
    public static let sheetWidth: CGFloat = 357
    public static let sheetHeight: CGFloat = 572

    /// The panel box (crest tip to pendant tip) at the plate's own aspect, for a box `width` wide.
    public static func panelHeight(forWidth width: CGFloat) -> CGFloat {
        width * (sheetHeight / sheetWidth) + crestHeight + pendantDepth
    }

    /// The head spray's box, in the body's own terms: the stock plate's filigree covers x 50…350 of
    /// 402 and y 55…250 of the frame, which against a body starting at y = 44 is this.
    public static let crestSprayWidthFraction: CGFloat = 300.0 / 357.0
    public static let crestSprayHeight: CGFloat = 195
    public static let crestSprayTopOffset: CGFloat = 11
}

/// The plate's outline: a body with scooped corners, a lobe at its head and a pendant at its foot.
///
/// The rect it is handed includes both lobes. `body(in:)` is exposed because the engraving has to
/// know where the straight-sided sheet actually starts — a spray drawn against the full rect sits 33
/// points too high.
public struct HisploraPlaqueShape: Shape {

    /// How deep the corner scoops cut, as a fraction of the panel's shorter side. Kept for callers
    /// that predate `HisploraPlaqueMetrics.cornerRadius`; the shape itself no longer uses it.
    public static let cornerFraction: CGFloat = 1.0 / 12.0

    public init() {}

    /// The straight-sided sheet inside `r`, with the head and foot lobes taken off.
    public static func body(in r: CGRect) -> CGRect {
        CGRect(x: r.minX,
               y: r.minY + HisploraPlaqueMetrics.crestHeight,
               width: r.width,
               height: max(0, r.height - HisploraPlaqueMetrics.crestHeight
                   - HisploraPlaqueMetrics.pendantDepth))
    }

    public func path(in r: CGRect) -> Path {
        let b = Self.body(in: r)
        // On a very short panel the lobes would meet in the middle and the path would fold over
        // itself. Shrink them together rather than letting one win.
        let c = min(HisploraPlaqueMetrics.cornerRadius, min(b.width, b.height) / 3)
        let crestHalf = min(HisploraPlaqueMetrics.crestHalfWidth, b.width / 2 - c)
        let pendantHalf = min(HisploraPlaqueMetrics.pendantHalfWidth, b.width / 2 - c)
        let crest = HisploraPlaqueMetrics.crestHeight
        let pendant = HisploraPlaqueMetrics.pendantDepth
        let cx = b.midX

        var p = Path()
        p.move(to: CGPoint(x: b.minX + c, y: b.minY))
        // The head lobe: an onion arch, so the inflection sits low and the tip is nearly a point.
        p.addLine(to: CGPoint(x: cx - crestHalf, y: b.minY))
        p.addCurve(to: CGPoint(x: cx, y: b.minY - crest),
                   control1: CGPoint(x: cx - crestHalf * 0.70, y: b.minY - crest * 0.55),
                   control2: CGPoint(x: cx - crestHalf * 0.34, y: b.minY - crest))
        p.addCurve(to: CGPoint(x: cx + crestHalf, y: b.minY),
                   control1: CGPoint(x: cx + crestHalf * 0.34, y: b.minY - crest),
                   control2: CGPoint(x: cx + crestHalf * 0.70, y: b.minY - crest * 0.55))
        p.addLine(to: CGPoint(x: b.maxX - c, y: b.minY))
        // Each corner is an arc centred *on* the corner rather than inside it, which is what turns
        // the usual convex round into the scoop the plate is cut with.
        p.addArc(center: CGPoint(x: b.maxX, y: b.minY), radius: c,
                 startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: b.maxX, y: b.maxY - c))
        p.addArc(center: CGPoint(x: b.maxX, y: b.maxY), radius: c,
                 startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
        // The pendant lobe, the head's mirror.
        p.addLine(to: CGPoint(x: cx + pendantHalf, y: b.maxY))
        p.addCurve(to: CGPoint(x: cx, y: b.maxY + pendant),
                   control1: CGPoint(x: cx + pendantHalf * 0.70, y: b.maxY + pendant * 0.55),
                   control2: CGPoint(x: cx + pendantHalf * 0.34, y: b.maxY + pendant))
        p.addCurve(to: CGPoint(x: cx - pendantHalf, y: b.maxY),
                   control1: CGPoint(x: cx - pendantHalf * 0.34, y: b.maxY + pendant),
                   control2: CGPoint(x: cx - pendantHalf * 0.70, y: b.maxY + pendant * 0.55))
        p.addLine(to: CGPoint(x: b.minX + c, y: b.maxY))
        p.addArc(center: CGPoint(x: b.minX, y: b.maxY), radius: c,
                 startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)
        p.addLine(to: CGPoint(x: b.minX, y: b.minY + c))
        p.addArc(center: CGPoint(x: b.minX, y: b.minY), radius: c,
                 startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        p.closeSubpath()
        return p
    }
}

/// The engraved motifs, built in unit space so one drawing serves the head spray, the corner curls
/// and the pendant at three different sizes.
///
/// Unit space runs 0…1 on both axes with the motif's *inner* end at x = 0, so a mirrored copy of the
/// same path completes a symmetrical spray about that edge. Every curve is fixed — no randomness —
/// because an ornament that redraws differently on each layout pass reads as a rendering bug.
public enum HisploraOrnament {

    /// Half an acanthus spray, as a **closed** path meant to be filled as well as stroked.
    ///
    /// Two earlier passes drew this as bare centre lines — stems, hooks and hung arcs — and both read
    /// as wire on device: a pair of antennae beside the portrait, then a scatter of pins. Carving has
    /// a body. So every limb here is a tapered ribbon with two edges and a width that runs out to
    /// nothing, every leaf is a closed teardrop, and only the tendrils stay hairlines. That is the
    /// difference between a diagram of an ornament and an ornament.
    public static func acanthusHalf(in rect: CGRect) -> Path {
        func u(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        let scale = min(rect.width, rect.height)
        var p = Path()

        // The two scrolls that carry the spray, each a ribbon running out to a point.
        p.addPath(ribbon(u(0.00, 0.36), u(0.22, 0.10), u(0.48, 0.08), u(0.74, 0.22),
                         startWidth: scale * 0.085, endWidth: scale * 0.006))
        p.addPath(ribbon(u(0.02, 0.62), u(0.20, 0.52), u(0.42, 0.52), u(0.62, 0.68),
                         startWidth: scale * 0.062, endWidth: scale * 0.005))

        // Each scroll finishes in a volute — the eye is what makes a curve read as carved rather than
        // as a stroke that stopped.
        p.addPath(spiral(center: u(0.80, 0.28), startRadius: scale * 0.070, turns: 1.9))
        p.addPath(spiral(center: u(0.66, 0.74), startRadius: scale * 0.052, turns: 1.7))

        // Leaves, in clusters of two or three the way acanthus grows, hung off the inner curve of
        // each scroll and shrinking outward.
        for (tip, base, width) in [
            (u(0.10, 0.20), u(0.20, 0.46), 0.052),
            (u(0.22, 0.16), u(0.30, 0.40), 0.044),
            (u(0.36, 0.16), u(0.42, 0.38), 0.036),
            (u(0.16, 0.78), u(0.26, 0.58), 0.040),
            (u(0.34, 0.84), u(0.42, 0.62), 0.034),
            (u(0.52, 0.40), u(0.58, 0.56), 0.026),
        ] as [(CGPoint, CGPoint, CGFloat)] {
            p.addPath(teardrop(tip: tip, base: base, width: scale * width))
        }

        // Hairline tendrils into the gaps the ribbons leave, each ending in its own small eye.
        p.move(to: u(0.28, 0.50))
        p.addCurve(to: u(0.52, 0.30), control1: u(0.36, 0.52), control2: u(0.46, 0.42))
        p.addPath(spiral(center: u(0.55, 0.27), startRadius: scale * 0.030, turns: 1.5))
        p.move(to: u(0.40, 0.72))
        p.addCurve(to: u(0.56, 0.88), control1: u(0.48, 0.76), control2: u(0.52, 0.84))
        p.addPath(spiral(center: u(0.58, 0.90), startRadius: scale * 0.024, turns: 1.4))

        // Buds. Filler, and what stops the gaps between limbs reading as bare cream.
        for (x, y, r) in [(0.30, 0.28, 0.017), (0.46, 0.56, 0.014),
                          (0.62, 0.44, 0.012), (0.24, 0.92, 0.011)] as [(CGFloat, CGFloat, CGFloat)] {
            let centre = u(x, y)
            p.addEllipse(in: CGRect(x: centre.x - scale * r, y: centre.y - scale * r,
                                    width: scale * r * 2, height: scale * r * 2))
        }
        return p
    }

    /// A limb: the cubic through the four control points, offset both ways by a width that tapers
    /// from `startWidth` to `endWidth`, closed into one fillable shape.
    private static func ribbon(
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint,
        startWidth: CGFloat, endWidth: CGFloat
    ) -> Path {
        let steps = 28
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point = cubic(p0, p1, p2, p3, t)
            let tangent = cubicTangent(p0, p1, p2, p3, t)
            let length = max(0.0001, (tangent.x * tangent.x + tangent.y * tangent.y).squareRoot())
            let normal = CGPoint(x: -tangent.y / length, y: tangent.x / length)
            // Squared taper: the limb keeps its body through the first half and then runs out, which
            // is how a carved scroll thins rather than a stroked line.
            let width = endWidth + (startWidth - endWidth) * (1 - t) * (1 - t)
            left.append(CGPoint(x: point.x + normal.x * width / 2, y: point.y + normal.y * width / 2))
            right.append(CGPoint(x: point.x - normal.x * width / 2, y: point.y - normal.y * width / 2))
        }
        var p = Path()
        p.move(to: left[0])
        for point in left.dropFirst() { p.addLine(to: point) }
        for point in right.reversed() { p.addLine(to: point) }
        p.closeSubpath()
        return p
    }

    /// A leaf: a point at `tip`, a belly on one side, and a shallower return on the other.
    ///
    /// The belly is held to a minimum share of the leaf's own length. Asked for a narrow width over a
    /// long span the earlier version produced a blade, and a spray of blades reads as wheat rather
    /// than as acanthus — which is exactly how the third pass of this drawing came out.
    private static func teardrop(tip: CGPoint, base: CGPoint, width: CGFloat) -> Path {
        let mid = CGPoint(x: (tip.x + base.x) / 2, y: (tip.y + base.y) / 2)
        let dx = base.x - tip.x
        let dy = base.y - tip.y
        let length = max(0.0001, (dx * dx + dy * dy).squareRoot())
        let normal = CGPoint(x: -dy / length, y: dx / length)
        let belly = max(width, length * 0.34)
        var p = Path()
        p.move(to: tip)
        p.addQuadCurve(to: base, control: CGPoint(x: mid.x + normal.x * belly,
                                                  y: mid.y + normal.y * belly))
        p.addQuadCurve(to: tip, control: CGPoint(x: mid.x - normal.x * belly * 0.78,
                                                 y: mid.y - normal.y * belly * 0.78))
        p.closeSubpath()
        return p
    }

    /// A volute's eye: an Archimedean spiral sampled finely enough to read as a curve. The earlier
    /// version stepped eight times per turn and drew a visible hexagon.
    private static func spiral(center: CGPoint, startRadius: CGFloat, turns: CGFloat) -> Path {
        var p = Path()
        let steps = max(24, Int(turns * 40))
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let angle = Angle.degrees(Double(-90 + 360 * turns * t)).radians
            let r = startRadius * (1 - 0.88 * t)
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if step == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }

    private static func cubic(
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat
    ) -> CGPoint {
        let s = 1 - t
        return CGPoint(
            x: s * s * s * p0.x + 3 * s * s * t * p1.x + 3 * s * t * t * p2.x + t * t * t * p3.x,
            y: s * s * s * p0.y + 3 * s * s * t * p1.y + 3 * s * t * t * p2.y + t * t * t * p3.y)
    }

    private static func cubicTangent(
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat
    ) -> CGPoint {
        let s = 1 - t
        return CGPoint(
            x: 3 * s * s * (p1.x - p0.x) + 6 * s * t * (p2.x - p1.x) + 3 * t * t * (p3.x - p2.x),
            y: 3 * s * s * (p1.y - p0.y) + 6 * s * t * (p2.y - p1.y) + 3 * t * t * (p3.y - p2.y))
    }

    /// The palmette that sits on the centre line: a fan of five ribs over a small collar. Used at
    /// the head of the spray and, at a quarter of the size, on the pendant lobe.
    public static func palmette(in rect: CGRect) -> Path {
        var p = Path()
        let base = CGPoint(x: rect.midX, y: rect.maxY)
        for offset in [-1.0, -0.5, 0.0, 0.5, 1.0] as [CGFloat] {
            let tip = CGPoint(x: rect.midX + rect.width * 0.42 * offset,
                              y: rect.minY + rect.height * (0.12 + 0.30 * abs(offset)))
            p.move(to: base)
            p.addQuadCurve(to: tip,
                           control: CGPoint(x: rect.midX + rect.width * 0.30 * offset,
                                            y: rect.minY + rect.height * 0.55))
        }
        // The collar: a shallow cup closing the ribs off, so the fan reads as one carved unit.
        p.move(to: CGPoint(x: rect.midX - rect.width * 0.22, y: rect.maxY - rect.height * 0.06))
        p.addQuadCurve(to: CGPoint(x: rect.midX + rect.width * 0.22, y: rect.maxY - rect.height * 0.06),
                       control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.12))
        return p
    }

    /// The faint repeating field the sheet is watermarked with: a quatrefoil on a staggered grid.
    /// Kept as one path so the whole field is a single stroke rather than a hundred.
    public static func quatrefoilField(in rect: CGRect, pitch: CGFloat) -> Path {
        var p = Path()
        let lobe = pitch * 0.17
        var row = 0
        var y = rect.minY + pitch / 2
        while y < rect.maxY {
            let stagger = row.isMultiple(of: 2) ? 0 : pitch / 2
            var x = rect.minX + pitch / 2 + stagger
            while x < rect.maxX {
                for angle in stride(from: 0.0, to: 360.0, by: 90.0) {
                    let r = Angle.degrees(angle).radians
                    let cx = x + cos(r) * lobe
                    let cy = y + sin(r) * lobe
                    p.addEllipse(in: CGRect(x: cx - lobe, y: cy - lobe,
                                            width: lobe * 2, height: lobe * 2))
                }
                x += pitch
            }
            y += pitch
            row += 1
        }
        return p
    }

}

/// The engraving laid over the plate's cream: head spray, corner curls, pendant, and the watermark
/// field under all three.
///
/// **Decoration, and only decoration** (`NFR-A11Y-05`). Nothing here carries meaning, nothing here
/// is a control, and every stroke is faint enough that the measured ink-on-`paperCream` ratios still
/// describe what is on screen — the same argument `KultaraPaperTexture` already makes for the
/// museum direction's grain. It is hidden from VoiceOver as one unit.
struct HisploraPlaqueEngraving: View {
    let ink: Color
    let gold: Color

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let body = HisploraPlaqueShape.body(in: rect)
            guard body.width > 0, body.height > 0 else { return }

            // The watermark field, clipped to the sheet so it never bleeds past the scooped corners.
            // Fine pitch and a hairline: at 46 points it read as printed polka dots rather than as a
            // damask worked into the paper.
            context.clip(to: HisploraPlaqueShape().path(in: rect))
            context.stroke(
                HisploraOrnament.quatrefoilField(in: body, pitch: 26),
                with: .color(ink.opacity(0.038)),
                lineWidth: 0.5)

            // The head spray: one half, then its mirror about the centre line. It sits high and wide,
            // filling the cream on either side of the gilded oval that hangs over the plate's head.
            let sprayWidth = body.width * HisploraPlaqueMetrics.crestSprayWidthFraction / 2
            let sprayRect = CGRect(
                x: body.midX,
                y: body.minY + HisploraPlaqueMetrics.crestSprayTopOffset,
                width: sprayWidth,
                height: min(HisploraPlaqueMetrics.crestSprayHeight, body.height * 0.30))
            // Filled first, then outlined: the fill is the limb's body and the outline is the cut
            // around it. Stroking alone is what made the first two passes read as wire.
            drawMirrored(HisploraOrnament.acanthusHalf(in: sprayRect),
                         about: body.midX, in: &context,
                         fill: gold.opacity(0.20), stroke: gold.opacity(0.42), width: 0.7)

            // Corner curls, inside the rules. Each corner gets the same spray at a fifth the size,
            // rotated so its stem runs along the edge it sits on.
            let curlSide = min(body.width * 0.16, 54)
            for corner in Corner.allCases {
                var inner = context
                inner.translateBy(x: corner.anchor(in: body).x, y: corner.anchor(in: body).y)
                inner.scaleBy(x: corner.flipX, y: corner.flipY)
                let motif = HisploraOrnament.acanthusHalf(in: CGRect(
                    x: 0, y: 0, width: curlSide, height: curlSide * 0.82))
                inner.fill(motif, with: .color(gold.opacity(0.16)))
                inner.stroke(motif, with: .color(gold.opacity(0.34)), lineWidth: 0.6)
            }

            // The pendant glyph, sized to the lobe it sits in rather than to the sheet: the lobe
            // tapers, and a fan wide enough to look generous on the flat sheet pokes straight out
            // through the taper's sides.
            let pendantSide = min(body.width * 0.06, 24)
            context.stroke(
                HisploraOrnament.palmette(in: CGRect(
                    x: body.midX - pendantSide / 2,
                    y: body.maxY + 3,
                    width: pendantSide,
                    height: HisploraPlaqueMetrics.pendantDepth * 0.40)),
                with: .color(gold.opacity(0.5)),
                lineWidth: 0.9)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func drawMirrored(
        _ path: Path,
        about x: CGFloat,
        in context: inout GraphicsContext,
        fill: Color,
        stroke: Color,
        width: CGFloat
    ) {
        context.fill(path, with: .color(fill))
        context.stroke(path, with: .color(stroke), lineWidth: width)
        var mirrored = context
        mirrored.translateBy(x: x * 2, y: 0)
        mirrored.scaleBy(x: -1, y: 1)
        mirrored.fill(path, with: .color(fill))
        mirrored.stroke(path, with: .color(stroke), lineWidth: width)
    }

    /// Which corner a curl belongs to, and how the drawing has to be flipped to face inward from it.
    private enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var flipX: CGFloat { self == .topLeading || self == .bottomLeading ? 1 : -1 }
        var flipY: CGFloat { self == .topLeading || self == .topTrailing ? 1 : -1 }

        /// Inset far enough to clear both rules, so a curl never crosses the border it decorates.
        func anchor(in body: CGRect) -> CGPoint {
            let inset = HisploraPlaqueMetrics.innerRuleInset + 10
            switch self {
            case .topLeading: return CGPoint(x: body.minX + inset, y: body.minY + inset)
            case .topTrailing: return CGPoint(x: body.maxX - inset, y: body.minY + inset)
            case .bottomLeading: return CGPoint(x: body.minX + inset, y: body.maxY - inset)
            case .bottomTrailing: return CGPoint(x: body.maxX - inset, y: body.maxY - inset)
            }
        }
    }
}

/// The plate's engraving as a shipped picture, when there is one.
///
/// The drawn ornament above is what the app carries today, and it is a *different* ornament from the
/// mock-up's: sparser, and unmistakably drawn. Closing that gap needs artwork this project owns —
/// commissioned, licensed, or generated for it — and the one thing it may never be is the stock plate
/// in `293:1630`, which carries a dozen real people's names.
///
/// So the seam is here rather than in a future refactor. Drop `plaque-engraving.png` into
/// `Resources/Images` and the panel prefers it, clipped to the same silhouette, with the code-drawn
/// spray falling back the moment the file is absent — the same arrangement `KultaraPortraitFrame` has
/// with its own ornament, and for the same reason: a missing decoration must not take the screen with
/// it. Nothing else has to change, and the sizes stay the panel's.
public enum HisploraPlaqueArtwork {

    /// Loaded once from the package bundle. `Image(_:bundle:)` would resolve lazily and silently draw
    /// nothing if the resource were dropped; this way the miss is a value the panel can branch on.
    public static let engraving: Image? = {
        #if canImport(UIKit)
        guard let url = engravingURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }()

    static var engravingURL: URL? {
        Bundle.module.url(
            forResource: "plaque-engraving", withExtension: "png", subdirectory: "Images")
    }

    /// Whether artwork shipped. False today, and deliberately not asserted either way: a test that
    /// demanded the file would fail until it exists, and one that demanded its absence would fail the
    /// day it arrives.
    public static var isAvailable: Bool { engravingURL != nil }

    /// The **whole plate** as a picture — silhouette, cream, engraving and rules in one — rather than
    /// an engraving to be laid over the drawn shape. When this resolves, the panel draws it *instead
    /// of* the shape, the fill and the two rules; when it does not, everything above still runs.
    ///
    /// `plaque-plate.png` is `625:4377` with the engraved names taken out. The names are the whole
    /// reason the plate was drawn rather than shipped: the stock file carries about two dozen real
    /// people's and businesses' names across its middle, which the Figma frame hides behind three
    /// opaque rectangles (`625:4378`…`625:4380`) rather than removing. The shipped file has them
    /// erased from the pixels — a grayscale closing over the band they occupy, which takes thin dark
    /// strokes off a light ground and leaves the cream and its gradient — so no third party's name is
    /// inside the app. **The engraving's own licence is a separate question and is not settled by
    /// this**: it remains somebody else's plate, and replacing it with commissioned or generated
    /// artwork is a file swap and nothing else.
    public static let plate: Image? = {
        #if canImport(UIKit)
        guard let url = plateURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }()

    static var plateURL: URL? {
        Bundle.module.url(forResource: "plaque-plate", withExtension: "png", subdirectory: "Images")
    }

    /// Whether the plate shipped. Asserted by `PlateArtTests`, unlike `isAvailable` above: this one
    /// is the screen's background, and losing it silently would drop the place notice back to the
    /// drawn plate with nothing saying so.
    public static var plateIsAvailable: Bool { plateURL != nil }
}

/// Where things are inside `plaque-plate.png`, measured off its own pixels rather than read off the
/// frame. Every number below came from an alpha and luminance scan of the shipped file, which is why
/// they are odd numbers: the artwork is not centred in its own canvas and its lobes are not equal.
///
/// The panel needs three things from the picture, and none of them are guessable:
///
/// 1. **Where the straight-sided sheet is.** The panel's own frame *is* the sheet — its callers inset
///    themselves to it and measure their columns from it — so the picture has to be placed by its
///    sheet, not by its edges. `sheet` is the alpha-opaque box at full width.
/// 2. **Which band may be stretched.** Content length varies with Dynamic Type, so the plate has to
///    grow, and stretching the whole picture stretches the crest with it. `capTop`/`capBottom` leave
///    a 60-pixel band at y 430…490 as the only stretchy part — the one horizontal strip of this
///    artwork carrying no ornament at all, just the two edge rules, which are vertical there and so
///    survive being smeared down the page.
/// 3. **What the print area's cream actually is.** `printAreaDarkestCream` is the darkest opaque
///    pixel anywhere text can land. `PlateArtTests` measures `inkBody` against *it* rather than
///    against `paperCream`, because a picture behind text is exactly what `KultaraPaperTexture`'s
///    note warns the contrast suite cannot see.
public enum HisploraPlateArtMetrics {

    /// The artwork's pixel size. Loaded through `UIImage(data:)` it has scale 1, so these are points.
    public static let pixelSize = CGSize(width: 395, height: 631)

    /// The straight-sided sheet: alpha-opaque from x 26 to x 357, and from y 41 (the body's top edge,
    /// above which only the scooped corners and the head lobe reach) to y 576.
    public static let sheet = CGRect(x: 26, y: 41, width: 332, height: 535)

    /// The 3-slice caps. Top and bottom are drawn at their own size and never stretch; everything
    /// between them is the flat band. Left and right are deliberately **zero** — the plate is drawn
    /// at one width per screen and stretching it horizontally as a whole is what the frame does too
    /// (`625:4377` is the 395-pixel file placed 423 wide).
    public static let capTop: CGFloat = 430
    public static let capBottom: CGFloat = 141

    /// The darkest opaque pixel in the area text is printed on, `#D3CAAD` — a faint flourish, not the
    /// cream. The cream itself samples `#EDE6D1`, one step off `paperCream`'s `#EEE7D2`.
    public static let printAreaDarkestCream = SRGBColor(hex: "#D3CAAD")
    public static let printAreaCream = SRGBColor(hex: "#EDE6D1")

    /// How far the picture overhangs the sheet on each side, in its own points. The panel adds these
    /// back to place the file by its sheet.
    public static var leadingOverhang: CGFloat { sheet.minX }
    public static var trailingOverhang: CGFloat { pixelSize.width - sheet.maxX }
    public static var topOverhang: CGFloat { sheet.minY }
    public static var bottomOverhang: CGFloat { pixelSize.height - sheet.maxY }

    /// Where the picture is drawn, given the panel's own box.
    ///
    /// A function rather than four numbers inside the view, because the thing worth guarding is the
    /// *result*: the picture's sheet has to land on `HisploraPlaqueShape.body(in:)` to within a
    /// rounding error, or every column measured against the drawn plate silently shifts. `PlateArtTests`
    /// asserts exactly that, which a `GeometryReader` full of arithmetic could not be made to.
    ///
    /// The vertical overhangs are **not** scaled and the horizontal ones are. That asymmetry is the
    /// three-slice: the caps draw at their own size whatever the width, so the crest is always
    /// `topOverhang` points above the sheet, while the width scales as a whole.
    public static func frame(forPanel panel: CGRect) -> CGRect {
        let sheetRect = HisploraPlaqueShape.body(in: panel)
        guard sheetRect.width > 0 else { return .zero }
        let scale = sheetRect.width / sheet.width
        return CGRect(x: sheetRect.minX - leadingOverhang * scale,
                      y: sheetRect.minY - topOverhang,
                      width: pixelSize.width * scale,
                      height: sheetRect.height + topOverhang + bottomOverhang)
    }

    /// Whether a picture that tall has room for both caps. Below this the slices would overlap and
    /// the plate would tear, so the panel resizes it whole instead.
    public static func canSlice(atHeight height: CGFloat) -> Bool { height >= capTop + capBottom }
}

/// The plaque with something printed on it: the cut shape filled in the flow's cream, the engraving
/// over it, and the two inset rules the plate draws just inside its own edge.
///
/// `interiorTop` is the caller's, because what stands at the plate's head differs by screen: the
/// place notice hangs a gilded oval there and needs the room reserved, and a screen that prints
/// straight onto the plate needs none of it.
public struct HisploraPlaquePanel<Content: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let interiorTop: CGFloat
    private let content: Content

    public init(interiorTop: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.interiorTop = interiorTop
        self.content = content()
    }

    public var body: some View {
        content
            // The lobes are ornament, not layout: nothing may be printed inside them, so the shape
            // is grown past the content rather than the content squeezed into the shape.
            .padding(.top, HisploraPlaqueMetrics.crestHeight + interiorTop)
            .padding(.bottom, HisploraPlaqueMetrics.pendantDepth)
            .background { plate }
    }

    /// The shipped plate when it is there, the drawn one when it is not.
    ///
    /// Both draw into the same box and put the sheet's straight sides in the same place, so nothing
    /// above this line — no padding, no column, no measured indent — knows which one ran.
    @ViewBuilder private var plate: some View {
        if let artwork = HisploraPlaqueArtwork.plate {
            HisploraPlateArt(artwork: artwork)
        } else {
            HisploraPlaqueShape()
                .fill(palette.paperCream.color)
                .overlay { engraving }
                .overlay { rules }
        }
    }

    /// Shipped artwork when it exists, the drawn spray when it does not. The picture is clipped to the
    /// silhouette rather than trusted to match it: artwork arrives at whatever aspect ratio it arrives
    /// at, and the shape is what the layout above is measured against.
    @ViewBuilder private var engraving: some View {
        if let artwork = HisploraPlaqueArtwork.engraving {
            artwork
                .resizable()
                .scaledToFill()
                .clipShape(HisploraPlaqueShape())
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        } else {
            HisploraPlaqueEngraving(
                ink: palette.inkMuted.color,
                gold: palette.highlight.color)
        }
    }

    /// The plate's border: a heavier rule with a lighter companion inside it. Decoration only, and
    /// faint — the rules mark the plate's edge and never carry meaning (`NFR-A11Y-05`), so they are
    /// not a measured pair.
    private var rules: some View {
        ZStack {
            HisploraPlaqueShape()
                .stroke(palette.inkMuted.color.opacity(0.30), lineWidth: KultaraMetrics.hairline)
                .padding(HisploraPlaqueMetrics.outerRuleInset)
            HisploraPlaqueShape()
                .stroke(palette.inkMuted.color.opacity(0.16), lineWidth: KultaraMetrics.hairline)
                .padding(HisploraPlaqueMetrics.innerRuleInset)
        }
        .accessibilityHidden(true)
    }
}

/// The shipped plate, placed by its sheet and stretched only where it has nothing drawn on it.
///
/// It is handed the panel's own box — head lobe, sheet, foot lobe — and has to put the picture's
/// sheet exactly where `HisploraPlaqueShape` would have put its own, because every column and indent
/// on the screens above is measured against that sheet. So the frame it draws into is the panel's box
/// grown by the artwork's measured overhangs, offset back by the same amount, rather than the box
/// itself.
///
/// **Three-slice, not resize.** `interiorTop` and Dynamic Type both make the panel taller than the
/// picture, and a plain `.resizable()` stretches the crest along with the cream — at accessibility
/// text sizes that is a visibly elongated ornament. `capTop`/`capBottom` pin the crest and the foot at
/// their own size and put every extra point into the one flat band. The caps are horizontal-only
/// zero, so the width still scales as a whole, which is what the frame does too.
///
/// `.interpolation(.high)` is the rest of the answer: the file is 395 points wide against a 358-point
/// sheet at 3× on device, so it is always being scaled, and the default interpolation leaves the
/// engraving's hairlines stepped.
struct HisploraPlateArt: View {
    let artwork: Image

    var body: some View {
        GeometryReader { geometry in
            // The panel's box is the sheet plus both lobes; the sheet is what the picture is placed
            // by, and `frame(forPanel:)` is where that arithmetic lives so a test can hold it.
            let box = HisploraPlateArtMetrics.frame(
                forPanel: CGRect(origin: .zero, size: geometry.size))
            image(height: box.height)
                .frame(width: box.width, height: box.height)
                .offset(x: box.minX, y: box.minY)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
        }
    }

    /// Sliced when there is room for the slices, whole when there is not. Below `capTop + capBottom`
    /// the caps would overlap and the picture would tear; a panel that short is not a case the place
    /// notice reaches, but a fallback costs one branch and a torn plate costs a screen.
    @ViewBuilder private func image(height: CGFloat) -> some View {
        let m = HisploraPlateArtMetrics.self
        if m.canSlice(atHeight: height) {
            artwork
                .resizable(
                    capInsets: EdgeInsets(top: m.capTop, leading: 0, bottom: m.capBottom, trailing: 0),
                    resizingMode: .stretch)
                .interpolation(.high)
                .antialiased(true)
        } else {
            artwork
                .resizable()
                .interpolation(.high)
                .antialiased(true)
        }
    }
}
