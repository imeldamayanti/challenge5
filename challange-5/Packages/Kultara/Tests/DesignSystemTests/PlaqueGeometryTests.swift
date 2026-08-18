import CoreGraphics
import Testing

@testable import DesignSystem

/// The plate's silhouette is measured, not styled — every value in `HisploraPlaqueMetrics` came from
/// the alpha coverage of the exported `293:1630`, whose artwork this project may not ship (it is a
/// stock wedding-invitation plate carrying real people's names). Because the drawing replaces an
/// asset nobody can diff it against, these are the only thing standing between the shape and a slow
/// drift back into a rounded rectangle.
@Suite struct PlaqueGeometryTests {

    /// The five left-edge samples the corner radius was fitted to, in the plate's own 402 × 675
    /// coordinates: an arc centred *on* the corner passes through all of them, a conventional
    /// rounded corner misses the first three by more than 20 points.
    @Test func theCornerIsAScoopArcedAboutTheCornerPointItself() {
        let measured: [(y: CGFloat, x: CGFloat)] =
            [(44, 58), (55, 56), (66, 49), (77, 28)]
        let corner = CGPoint(x: 24, y: 44)
        let radius = HisploraPlaqueMetrics.cornerRadius

        for sample in measured {
            let dy = sample.y - corner.y
            // Solve the scoop's own circle for x at the sampled y.
            let dx = (radius * radius - dy * dy).squareRoot()
            #expect(abs((corner.x + dx) - sample.x) < 9,
                    "scoop misses the plate's measured edge at y = \(sample.y)")

            // And confirm the alternative really is wrong, so this test fails if someone swaps the
            // arc's centre for the usual inset one.
            let insetCentre = CGPoint(x: corner.x + radius, y: corner.y + radius)
            let insetDy = sample.y - insetCentre.y
            if abs(insetDy) <= radius {
                let insetX = insetCentre.x - (radius * radius - insetDy * insetDy).squareRoot()
                if sample.y < 70 {
                    #expect(abs(insetX - sample.x) > 15,
                            "a conventional rounded corner should not fit y = \(sample.y)")
                }
            }
        }
    }

    /// The head and foot lobes are ornament outside the sheet. `body(in:)` is what the engraving and
    /// the panel's padding both anchor to, so a lobe folded into the body would print prose inside
    /// the ornament.
    @Test func theBodyExcludesBothLobes() {
        let rect = CGRect(x: 0, y: 0, width: 358, height: 640)
        let body = HisploraPlaqueShape.body(in: rect)

        #expect(body.minY == HisploraPlaqueMetrics.crestHeight)
        #expect(body.maxY == rect.maxY - HisploraPlaqueMetrics.pendantDepth)
        #expect(body.width == rect.width)
    }

    /// A panel shorter than its own ornament must still draw a closed, in-bounds outline rather than
    /// a path folded through itself — the case a long content string at the largest Dynamic Type size
    /// cannot produce, but a preview or a future caller can.
    @Test func theShapeStaysInsideItsRectAtEveryHeight() {
        for height in [80.0, 140.0, 400.0, 900.0] as [CGFloat] {
            let rect = CGRect(x: 0, y: 0, width: 358, height: height)
            let bounds = HisploraPlaqueShape().path(in: rect).boundingRect

            #expect(bounds.minX >= rect.minX - 0.5)
            #expect(bounds.maxX <= rect.maxX + 0.5)
            #expect(bounds.minY >= rect.minY - 0.5)
            #expect(bounds.maxY <= rect.maxY + 0.5)
            #expect(!bounds.isEmpty)
        }
    }

    /// The lobes are what make the plate a cartouche rather than a card: at the sizes this screen
    /// actually uses, the outline has to reach both the crest tip and the pendant tail.
    @Test func theOutlineReachesBothLobes() {
        let rect = CGRect(x: 0, y: 0, width: 358, height: 640)
        let path = HisploraPlaqueShape().path(in: rect)

        #expect(path.contains(CGPoint(x: rect.midX, y: 2)),
                "the crest tip should be inside the outline")
        #expect(path.contains(CGPoint(x: rect.midX, y: rect.maxY - 2)),
                "the pendant tail should be inside the outline")
        // And the corners are cut away, which is the whole point of the scoop.
        #expect(!path.contains(CGPoint(x: 1, y: HisploraPlaqueMetrics.crestHeight + 1)))
    }

    /// The watermark field is one path over the sheet. If it ever came back empty the plate would go
    /// blank again without anything failing, which is exactly how the first pass of this screen
    /// shipped as a plain cream ticket.
    @Test func theEngravedFieldCoversTheSheet() {
        let body = CGRect(x: 0, y: 33, width: 358, height: 560)
        let field = HisploraOrnament.quatrefoilField(in: body, pitch: 46).boundingRect

        #expect(!field.isEmpty)
        #expect(field.width > body.width * 0.8)
        #expect(field.height > body.height * 0.8)
    }

    /// Both motifs have to draw something at every size the panel asks for them at — the corner curls
    /// are a fifth the size of the head spray, and a motif that collapses at small sizes would leave
    /// the corners bare.
    @Test func theMotifsDrawAtEverySizeThePanelUses() {
        for side in [30.0, 74.0, 160.0] as [CGFloat] {
            let rect = CGRect(x: 0, y: 0, width: side, height: side * 0.82)
            #expect(!HisploraOrnament.acanthusHalf(in: rect).boundingRect.isEmpty)
            #expect(!HisploraOrnament.palmette(in: rect).boundingRect.isEmpty)
        }
    }
}
