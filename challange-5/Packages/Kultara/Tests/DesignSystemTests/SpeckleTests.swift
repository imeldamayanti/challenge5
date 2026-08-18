import CoreGraphics
import Testing
@testable import DesignSystem

@Suite("Speckle")
struct SpeckleTests {

    /// The ground must not shimmer. A generator seeded from the system would reshuffle every
    /// redraw, which is a scrolling screen's background crawling.
    @Test func theFieldIsTheSameEveryTimeItIsAskedFor() {
        let size = CGSize(width: 393, height: 852)
        #expect(KultaraSpeckle.dots(in: size) == KultaraSpeckle.dots(in: size))
    }

    @Test func theFieldIsAsDenseAsItClaims() {
        let size = CGSize(width: 400, height: 800)
        let expected = Int((400.0 * 800.0 / KultaraSpeckle.areaPerDot).rounded())
        #expect(KultaraSpeckle.dots(in: size).count == expected)
    }

    /// Every dot inside the field it was asked for, or the ground picks up a hard edge where the
    /// specks stop.
    @Test func everyDotLandsInsideTheField() {
        let size = CGSize(width: 320, height: 640)
        for dot in KultaraSpeckle.dots(in: size) {
            #expect(dot.x >= 0 && dot.x <= 320)
            #expect(dot.y >= 0 && dot.y <= 640)
        }
    }

    /// The cap is the whole contrast argument: `NFR-A11Y-03` is measured on palette pairs, and a
    /// speck dense enough to be read as a ground would put a colour on screen that no pair
    /// describes.
    @Test func noDotIsStrongerThanTheCap() {
        for dot in KultaraSpeckle.dots(in: CGSize(width: 500, height: 500)) {
            #expect(dot.opacity >= KultaraSpeckle.minimumDotOpacity)
            #expect(dot.opacity <= KultaraSpeckle.maximumDotOpacity)
            #expect(KultaraSpeckle.radiusRange.contains(dot.radius))
        }
    }

    @Test func theCapStaysLowEnoughToBeTexture() {
        #expect(KultaraSpeckle.maximumDotOpacity <= 0.35)
        #expect(KultaraSpeckle.areaPerDot >= 200)
    }

    @Test func anEmptyFieldProducesNothing() {
        #expect(KultaraSpeckle.dots(in: .zero).isEmpty)
        #expect(KultaraSpeckle.dots(in: CGSize(width: 0, height: 800)).isEmpty)
    }

    /// The fleck is chosen from the ground rather than from the colour scheme, so a screen that
    /// paints its own opaque ground gets the readable one without declaring which visual direction
    /// it belongs to.
    @Test func darkGroundsGetALightFleckAndPapersGetADarkOne() {
        let hisplora = HisploraPalette.standard
        for ground in [hisplora.brownDeep, hisplora.brownMid, hisplora.brownStone,
                       KultaraTheme.dark.paper, KultaraTheme.light.photoScrim] {
            #expect(KultaraSpeckle.tint(over: ground) == KultaraSpeckle.lightFleck)
        }
        for ground in [hisplora.paperCream, hisplora.paperWarm, hisplora.paperLight,
                       hisplora.mapGround, KultaraTheme.light.paper] {
            #expect(KultaraSpeckle.tint(over: ground) == KultaraSpeckle.darkFleck)
        }
    }

    /// Both flecks are palette values, not bare white and black — the same rule the rest of the
    /// design system holds, so nothing on screen is a colour nobody measured.
    @Test func bothFlecksAreColoursThePaletteAlreadyCarries() {
        #expect(KultaraSpeckle.lightFleck == HisploraPalette.standard.inkCream)
        #expect(KultaraSpeckle.darkFleck == KultaraTheme.light.ink)
    }
}
