import Foundation
import Testing
@testable import DesignSystem

/// The measuring instrument, tested against published reference values before it is pointed at
/// the theme. `NFR-A11Y-03` requires a *measured* 4.5:1, and a measurement is only worth having
/// if the ruler is right.
struct ContrastTests {

    private let tolerance = 0.01

    @Test func relativeLuminanceMatchesTheWCAGDefinitionAtTheExtremes() {
        #expect(abs(SRGBColor(hex: "#FFFFFF").relativeLuminance - 1.0) < 1e-9)
        #expect(abs(SRGBColor(hex: "#000000").relativeLuminance - 0.0) < 1e-9)
    }

    @Test func relativeLuminanceAppliesTheGammaCurveNotALinearRamp() {
        // Mid-grey is 21.6% luminance, not 50%. A linear ramp here is the classic bug that
        // makes a palette look compliant and read as mud.
        #expect(abs(SRGBColor(hex: "#808080").relativeLuminance - 0.215861) < 1e-5)
    }

    @Test(arguments: [
        ("#000000", "#FFFFFF", 21.0),
        ("#FFFFFF", "#FFFFFF", 1.0),
        ("#767676", "#FFFFFF", 4.5422),   // the canonical "just passes 4.5:1" grey
        ("#808080", "#FFFFFF", 3.9494),   // and the one just below it
        ("#0000FF", "#FFFFFF", 8.5925),
        ("#FF0000", "#FFFFFF", 3.9985),
        ("#00FF00", "#000000", 15.3040),
    ])
    func contrastRatioMatchesPublishedReferenceValues(_ a: String, _ b: String, _ expected: Double) {
        let measured = contrastRatio(SRGBColor(hex: a), SRGBColor(hex: b))
        #expect(abs(measured - expected) < tolerance,
                "\(a) on \(b): measured \(measured), expected \(expected)")
    }

    @Test func contrastRatioIsSymmetric() {
        let a = SRGBColor(hex: "#2A2118")
        let b = SRGBColor(hex: "#F4EAD5")
        #expect(abs(contrastRatio(a, b) - contrastRatio(b, a)) < 1e-12)
    }

    @Test func contrastRatioIsNeverBelowOne() {
        for hex in ["#000000", "#FFFFFF", "#7A2617", "#8FBF9A"] {
            let colour = SRGBColor(hex: hex)
            #expect(contrastRatio(colour, colour) >= 1.0 - 1e-12)
        }
    }

    @Test(arguments: ["#F4EAD5", "F4EAD5", "#f4ead5"])
    func hexParsingAcceptsTheFormsWeActuallyWrite(_ hex: String) {
        #expect(SRGBColor(hex: hex) == SRGBColor(red: 244 / 255, green: 234 / 255, blue: 213 / 255))
    }

    @Test func contrastRequirementThresholdsAreTheWCAGAAValues() {
        #expect(ContrastRequirement.bodyText.minimumRatio == 4.5)
        #expect(ContrastRequirement.largeText.minimumRatio == 3.0)
        #expect(ContrastRequirement.nonTextEssential.minimumRatio == 3.0)
    }
}
