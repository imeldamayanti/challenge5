import Foundation
import Testing
@testable import DesignSystem

/// The onboarding screens are three pictures and four words. If a picture silently fails to load,
/// the screen still lays out, still passes contrast, and still reads correctly to VoiceOver — it is
/// just blank for half its height, which is exactly the kind of failure nothing else here would
/// catch.
struct OnboardingArtTests {

    @Test func everyOnboardingIllustrationShipped() {
        for art in HisploraOnboardingArt.allCases {
            #expect(art.isAvailable, "missing \(art.resourceName).png")
        }
    }

    /// The file name is derived, so a case added without an asset fails the test above rather than
    /// resolving to some other picture. This pins the derivation itself.
    @Test func theResourceNameIsTheCaseNameUnderTheOnboardingPrefix() {
        #expect(HisploraOnboardingArt.explore.resourceName == "onboarding-explore")
        #expect(HisploraOnboardingArt.quest.resourceName == "onboarding-quest")
        #expect(HisploraOnboardingArt.collection.resourceName == "onboarding-collection")
    }

    /// Both numbers are hand-copied from Figma, and a transposed pair would draw a picture stretched
    /// rather than crash. Every export is landscape and none is wider than the frame.
    @Test func everyIllustrationIsLandscapeAndFitsTheFrame() {
        for art in HisploraOnboardingArt.allCases {
            #expect(art.aspectRatio > 1, "\(art.rawValue) is not landscape")
            #expect(art.widthFraction > 0 && art.widthFraction <= 1,
                    "\(art.rawValue) would be drawn wider than the screen")
        }
    }

    /// `explore` is the one export wider than the 362-point text column, which is the whole reason
    /// the picture is laid out outside the page's horizontal padding. If it ever stops being true,
    /// the layout comment in `OnboardingView` stops being true with it.
    @Test func theExploreIllustrationIsWiderThanTheTextColumn() {
        let column: CGFloat = 362.0 / 402.0
        #expect(HisploraOnboardingArt.explore.widthFraction > column)
    }
}

/// The one palette value the onboarding frames added.
struct OnboardingProgressBarTests {

    private let palette = HisploraPalette.standard

    /// The bar's own state, measured the way the task bar's is. `702:2081`–`2082` draw the unfilled
    /// segments as 25% `buttonFill` over `paperSheet`; `trackDim` is that composite flattened, and
    /// the pair it has to win is against a filled segment rather than against the ground.
    @Test func theDimSegmentIsTheDrawnWashFlattenedAndStillReadsAgainstAFilledOne() {
        let asDrawn = blend(palette.buttonFill, over: palette.paperSheet, alpha: 0.25)
        // Flattened, not approximated: the two are the same colour, so they have no contrast at all
        // with each other. If someone replaces `trackDim` with a value picked beside the frame, this
        // is what says the token stopped being what the design draws.
        #expect(contrastRatio(palette.trackDim, asDrawn) <= 1.02,
                "trackDim is \(palette.trackDim.hex), the drawn wash flattens to \(asDrawn.hex)")
        #expect(contrastRatio(palette.buttonFill, palette.trackDim) >= 3.0)
    }

    /// The redesign's ground swap, held as a value rather than as a memory.
    ///
    /// The wash is 25% of the ink over whatever the screen stands on, so moving onboarding from
    /// `brownMid` to `paperSheet` moves the flattened value with it — `#926954` became `#C3BAAB`,
    /// and the two are nowhere near each other. What this pins is the direction of the dependency:
    /// if someone restores the brown composite because an older frame is open beside them, the bar
    /// stops being what `702:2081` draws even though it would still pass its own contrast pair.
    @Test func theDimSegmentMovedWithTheGroundRatherThanStayingOnTheBrownComposite() {
        let onBrown = blend(palette.inkCream, over: palette.brownMid, alpha: 0.25)
        let onCream = blend(palette.buttonFill, over: palette.paperSheet, alpha: 0.25)
        #expect(contrastRatio(onBrown, onCream) > 2.0,
                "the two grounds' composites are \(onBrown.hex) and \(onCream.hex)")
        #expect(contrastRatio(palette.trackDim, onCream) <= 1.02)
    }

    /// The underlined Skip the redesign moved to the top right. It is the one piece of type on these
    /// screens set below full strength, so it is the one that can fail — and it is body-sized.
    @Test func theQuietSkipLinkIsTheDrawnWashFlattenedAndStillReadsAsBodyText() {
        let asDrawn = blend(palette.buttonFill, over: palette.paperSheet, alpha: 0.75)
        #expect(contrastRatio(palette.inkQuiet, asDrawn) <= 1.02,
                "inkQuiet is \(palette.inkQuiet.hex), the drawn wash flattens to \(asDrawn.hex)")
        #expect(contrastRatio(palette.inkQuiet, palette.paperSheet) >= 4.5)
    }

    /// The pill drops its hairline on cream, and that is a measurement rather than a preference:
    /// the fill is its own boundary here, while `buttonRing` — measured on the browns — would be a
    /// fainter outline than the edge it outlines.
    @Test func theActionNeedsNoRingOnTheCreamGround() {
        #expect(contrastRatio(palette.buttonFill, palette.paperSheet) >= 3.0)
        #expect(contrastRatio(palette.buttonRing, palette.paperSheet) < 3.0)
    }

    /// Straight alpha compositing. `HisploraThemeTests` keeps its own copy for the same reason: the
    /// palette holds no translucent values, and this is a thing the *frame* draws.
    private func blend(_ top: SRGBColor, over bottom: SRGBColor, alpha: Double) -> SRGBColor {
        SRGBColor(red: top.red * alpha + bottom.red * (1 - alpha),
                  green: top.green * alpha + bottom.green * (1 - alpha),
                  blue: top.blue * alpha + bottom.blue * (1 - alpha))
    }
}
