import Foundation
import Testing
@testable import DesignSystem

/// `NFR-A11Y-03` applies to the new visual direction exactly as it applied to the old one. The
/// Figma frames were sampled, measured, and two values had to move — this suite is what makes that
/// a fact rather than a claim in a commit message.
struct HisploraThemeTests {

    private let palette = HisploraPalette.standard

    @Test func everyContrastPairMeetsItsRequirement() {
        for pair in palette.contrastPairs {
            #expect(pair.passes, "\(pair.measurementLine)")
        }
    }

    /// The same check the museum palette gets: a token measured against nothing is a colour nobody
    /// checked. `highlight` is the one deliberate exclusion, so it is named here rather than
    /// silently skipped — if it ever starts carrying text, this test is where that shows up.
    @Test func everyTokenIsMeasuredExceptTheDrawnAnnotation() {
        let measured = Set(palette.contrastPairs.flatMap { [$0.foreground, $0.background] })
        let declared = Set(palette.allTokens.map(\.value))
        let unmeasured = declared.subtracting(measured)

        #expect(unmeasured == [palette.highlight],
                "unmeasured: \(unmeasured.map(\.hex).sorted())")
    }

    /// The pill is near-black on mid-brown, which is 2.04:1 — below what WCAG 1.4.11 asks of a
    /// control's visual boundary. The design draws no border, so one was added. If someone removes
    /// it to match the frame more closely, this fails and says why.
    @Test func theFilledControlHasADiscernibleBoundary() {
        #expect(contrastRatio(palette.buttonFill, palette.brownMid) < 3.0,
                "the fill alone would not need a ring")
        #expect(contrastRatio(palette.buttonRing, palette.brownMid) >= 3.0)
    }

    /// The deviation is recorded as a value, not as prose: if someone restores the design's
    /// `#CBAFA8` because it matches Figma, the pair test above fails — and this one explains it.
    @Test func theMutedInkWasLightenedToPassRatherThanTheThresholdLowered() {
        let asDrawn = SRGBColor(hex: "#CBAFA8")
        #expect(contrastRatio(asDrawn, palette.brownMid) < 4.5)
        #expect(contrastRatio(palette.inkDusty, palette.brownMid) >= 4.5)
        // ...and it did not move further than it had to.
        #expect(contrastRatio(palette.inkDusty, palette.brownMid) < 4.8)
    }

    /// The two grounds have to be tellable apart, or the cutscene's card is invisible on its page.
    @Test func theTwoBrownGroundsAreDistinct() {
        #expect(palette.brownDeep != palette.brownMid)
    }

    /// Printed for the same reason the museum theme's numbers are: so they exist in the log rather
    /// than in someone's memory.
    @Test func reportMeasuredContrastRatios() {
        print("── Hisplora ──")
        for pair in palette.contrastPairs {
            print("   " + pair.measurementLine)
        }
    }
}
