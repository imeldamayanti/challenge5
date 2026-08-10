import Foundation
import Testing
@testable import DesignSystem

/// `NFR-A11Y-03`: body text at 4.5:1, large text at 3:1, **measured on the final theme**, and the
/// PRD names the aged-paper "royal letter" direction as being at direct risk — sepia ink on sepia
/// parchment routinely fails. The theme is what gets adapted; the threshold is not negotiable.
///
/// The test enumerates `palette.contrastPairs` rather than a list written here, so a token added
/// later without being measured fails this suite instead of shipping.
struct KultaraThemeTests {

    @Test(arguments: KultaraTheme.allAppearances)
    func everyContrastPairInTheThemeMeetsItsRequirement(_ appearance: KultaraTheme.Appearance) {
        let palette = KultaraTheme.palette(for: appearance)
        for pair in palette.contrastPairs {
            #expect(pair.passes, "\(appearance) · \(pair.measurementLine)")
        }
    }

    @Test(arguments: KultaraTheme.allAppearances)
    func theThemeDeclaresEveryTokenItOwns(_ appearance: KultaraTheme.Appearance) {
        // A palette with tokens that appear in no pair is a palette with unmeasured colours in
        // it. This is the check that keeps `contrastPairs` honest as the theme grows.
        let palette = KultaraTheme.palette(for: appearance)
        let measured = Set(palette.contrastPairs.flatMap { [$0.foreground, $0.background] })
        let declared = Set(palette.allTokens.map(\.value))
        let unmeasured = declared.subtracting(measured)
        #expect(unmeasured.isEmpty,
                "\(appearance): tokens never measured against anything: \(unmeasured.map(\.hex).sorted())")
    }

    @Test(arguments: KultaraTheme.allAppearances)
    func bodyTextIsMeasuredAgainstEverySurfaceItCanLandOn(_ appearance: KultaraTheme.Appearance) {
        // A body ink measured only against the page background passes while being unreadable on
        // a card. Each surface must appear as a background for the body ink.
        let palette = KultaraTheme.palette(for: appearance)
        let surfaces = [palette.paper, palette.paperRaised, palette.paperSunken]
        for surface in surfaces {
            #expect(palette.contrastPairs.contains {
                $0.foreground == palette.ink && $0.background == surface
                    && $0.requirement == .bodyText
            }, "\(appearance): ink is not measured against surface \(surface.hex)")
        }
    }

    @Test func theTwoAccuracyLabelInksAreDistinguishableFromEachOther() {
        // NFR-A11Y-05 forbids colour as the sole carrier of meaning — the chips carry text and a
        // border style too — but if the two inks are also indistinguishable from one another,
        // a reader who *does* rely on colour gets actively misleading information.
        for appearance in KultaraTheme.allAppearances {
            let palette = KultaraTheme.palette(for: appearance)
            #expect(palette.documentedInk != palette.oralInk, "\(appearance)")
        }
    }

    @Test func lightAndDarkAreActuallyDifferentPalettes() {
        // NFR-PLAT-04: dark mode is supported including the aged-paper theme. A dark mode that
        // is the light palette would pass every contrast test and fail the requirement.
        #expect(KultaraTheme.light.paper != KultaraTheme.dark.paper)
        #expect(KultaraTheme.light.ink != KultaraTheme.dark.ink)
        #expect(KultaraTheme.light.paper.relativeLuminance > KultaraTheme.dark.paper.relativeLuminance)
    }

    @Test func everyPairCarriesALabelThatIdentifiesWhereItIsUsed() {
        for appearance in KultaraTheme.allAppearances {
            for pair in KultaraTheme.palette(for: appearance).contrastPairs {
                #expect(!pair.label.isEmpty)
            }
        }
    }

    /// Not an assertion — the measurement report `NFR-A11Y-03` and acceptance criterion 6 ask
    /// for. Printed so the numbers exist in the test log rather than in someone's memory.
    @Test func reportMeasuredContrastRatios() {
        for appearance in KultaraTheme.allAppearances {
            print("── \(appearance) ──")
            for pair in KultaraTheme.palette(for: appearance).contrastPairs {
                print("   " + pair.measurementLine)
            }
        }
    }
}
