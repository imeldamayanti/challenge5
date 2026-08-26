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

        #expect(unmeasured == [palette.highlight, palette.authRule, palette.authProviderRing],
                "unmeasured: \(unmeasured.map(\.hex).sorted())")
    }

    /// The login / register frames' two hairlines (`1429:2829`, `1429:3260`). Both are the visual
    /// boundary of a control drawn white-on-white, and both are far under the 3:1 WCAG 1.4.11 asks
    /// — 1.09:1 for a field's rule, 1.16:1 for the provider row's.
    ///
    /// They ship as drawn at the owner's explicit instruction of 2026-08-26. This test is not a
    /// claim that they pass: it is what keeps the number in the suite rather than in a commit
    /// message, so raising the boundary later is a one-line change here rather than a rediscovery.
    /// If either value is ever moved to pass, this test fails and says the deviation is closed.
    @Test func theEntryHairlinesShipAsDrawnAndDoNotPass() {
        #expect(contrastRatio(palette.authRule, palette.paperStamp) < 3.0)
        #expect(contrastRatio(palette.authProviderRing, palette.paperStamp) < 3.0)
        // ...and the text on either side of them is measured and does pass, so what fails is the
        // outline of the box and never the words in it.
        #expect(contrastRatio(palette.authFieldInk, palette.paperStamp) >= 4.5)
        #expect(contrastRatio(palette.authProviderInk, palette.paperStamp) >= 4.5)
    }

    /// The frames set their quiet labels, their placeholders and the password eye in `#ACB5BB`,
    /// which is 2.19:1 on the card — under body text and under what 1.4.11 asks of a control's own
    /// glyph. `authQuiet` is what ships instead. Restoring the drawn value to match Figma fails the
    /// pair test above; this one says why not.
    @Test func theEntryQuietInkWasDarkenedToPassRatherThanTheThresholdLowered() {
        let asDrawn = SRGBColor(hex: "#ACB5BB")
        #expect(contrastRatio(asDrawn, palette.paperStamp) < 4.5)
        #expect(contrastRatio(palette.authQuiet, palette.paperStamp) >= 4.5)
    }

    /// The masthead's ground is the frames' `#6E2717` and `brownDeep` already *is* that value, so
    /// the design reuses it rather than adding a ninth brown. If `brownDeep` is ever re-sampled for
    /// the story flow, this is what says the entry screens moved with it on purpose.
    @Test func theEntryMastheadStandsOnTheStoryFlowsOwnDeepBrown() {
        #expect(palette.brownDeep == SRGBColor(hex: "#6E2717"))
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

    // MARK: - The three deviations `452:3132`, `447:1880` and `452:3028` forced (2026-08-17)

    /// The task progress bar's own state. `452:3138`–`3141` wash the unfilled segments with 29% cream
    /// over the well, which measures 2.25:1 against a filled one — so the thing that tells a walker
    /// which activities are done would be the thing failing contrast. Unwashed, the pair passes.
    ///
    /// If someone restores the wash to match Figma more closely, this is what says why not.
    @Test func theUnfilledProgressSegmentLostItsWashSoTheBarsStateIsReadable() {
        let asDrawn = blend(palette.paperCream, over: palette.trackWell, alpha: 0.29)
        #expect(contrastRatio(palette.paperCream, asDrawn) < 3.0,
                "the washed segment would be indistinguishable from a filled one")
        #expect(contrastRatio(palette.paperCream, palette.trackWell) >= 3.0)
    }

    /// The bar's outline. `452:3138` draws `#9F8E88`, which is 2.87:1 on the ground it sits on — under
    /// what WCAG 1.4.11 asks of a control's visual boundary. It is drawn in the already measured
    /// `buttonRing` instead, rather than adding a token that cannot pass anything.
    @Test func theProgressBarsOutlineMovedToTheMeasuredRing() {
        let asDrawn = SRGBColor(hex: "#9F8E88")
        #expect(contrastRatio(asDrawn, palette.brownStone) < 3.0)
        #expect(contrastRatio(palette.buttonRing, palette.brownStone) >= 3.0)
    }

    /// `447:1900`'s "Take Photo" pill. Its fill is 45% white over the parchment — all but invisible
    /// against it — and the `#CAB7B0` outline the frame draws measures 1.61:1 on the sheet's lightest
    /// interior. So the one control on that screen would have no discernible boundary at all. It is
    /// outlined in `brownMid`, the same ink the place name above it is set in.
    @Test func theParchmentPillsOutlineMovedToAnInkThatPasses() {
        // The sheet's lightest sampled interior, which is the conservative ground for a light ring.
        let sheet = SRGBColor(hex: "#F3F1E5")
        let asDrawn = SRGBColor(hex: "#CAB7B0")
        #expect(contrastRatio(asDrawn, sheet) < 3.0)
        #expect(contrastRatio(palette.brownMid, sheet) >= 3.0)
        // And the translucent fill on its own gives the control nothing: it is within a shade of the
        // paper it sits on, which is why the ring is load-bearing rather than decoration.
        let fill = blend(palette.inkOnButton, over: sheet, alpha: 0.45)
        #expect(contrastRatio(fill, sheet) < 1.5)
    }

    /// The site-map screen does not use `inkMuted`, and that is measured rather than remembered:
    /// on `mapGround` it is 4.39:1, just under body text. The plan's citation is set in `inkBody`.
    @Test func theSiteMapScreenAvoidsTheMutedInkBecauseItMissesByATenth() {
        #expect(contrastRatio(palette.inkMuted, palette.mapGround) < 4.5)
        #expect(contrastRatio(palette.inkBody, palette.mapGround) >= 4.5)
        // ...and it really is that close, so the exclusion is a threshold call and not a wide miss.
        #expect(contrastRatio(palette.inkMuted, palette.mapGround) > 4.3)
    }

    /// `452:3028` is the one story-flow screen on paper. If `mapGround` ever drifted towards the
    /// browns the screen would stop being a document and the inks measured on it would be measured
    /// against the wrong thing.
    @Test func theSiteMapGroundIsPaperAndNotAnotherBrown() {
        for brown in [palette.brownDeep, palette.brownMid, palette.brownStone] {
            #expect(contrastRatio(palette.mapGround, brown) >= 3.0,
                    "mapGround reads as a brown, not as paper")
        }
    }

    /// Straight alpha compositing, for the two deviations that are about a translucent fill rather
    /// than a flat token. Kept here rather than in `Contrast.swift` because the palette holds no
    /// translucent values — these are two things the *frames* draw, measured to say why they moved.
    private func blend(_ top: SRGBColor, over bottom: SRGBColor, alpha: Double) -> SRGBColor {
        SRGBColor(red: top.red * alpha + bottom.red * (1 - alpha),
                  green: top.green * alpha + bottom.green * (1 - alpha),
                  blue: top.blue * alpha + bottom.blue * (1 - alpha))
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
