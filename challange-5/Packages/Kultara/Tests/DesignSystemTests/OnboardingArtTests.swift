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

    /// The bar's own state, measured the way the task bar's is. `523:2054`–`2056` draw the unfilled
    /// segments as 25% `inkCream` over `brownMid`; `trackDim` is that composite flattened, and the
    /// pair it has to win is against a filled segment rather than against the ground.
    @Test func theDimSegmentIsTheDrawnWashFlattenedAndStillReadsAgainstAFilledOne() {
        let asDrawn = blend(palette.inkCream, over: palette.brownMid, alpha: 0.25)
        // Flattened, not approximated: the two are the same colour, so they have no contrast at all
        // with each other. If someone replaces `trackDim` with a value picked beside the frame, this
        // is what says the token stopped being what the design draws.
        #expect(contrastRatio(palette.trackDim, asDrawn) <= 1.02,
                "trackDim is \(palette.trackDim.hex), the drawn wash flattens to \(asDrawn.hex)")
        #expect(contrastRatio(palette.inkCream, palette.trackDim) >= 3.0)
    }

    /// Straight alpha compositing. `HisploraThemeTests` keeps its own copy for the same reason: the
    /// palette holds no translucent values, and this is a thing the *frame* draws.
    private func blend(_ top: SRGBColor, over bottom: SRGBColor, alpha: Double) -> SRGBColor {
        SRGBColor(red: top.red * alpha + bottom.red * (1 - alpha),
                  green: top.green * alpha + bottom.green * (1 - alpha),
                  blue: top.blue * alpha + bottom.blue * (1 - alpha))
    }
}
