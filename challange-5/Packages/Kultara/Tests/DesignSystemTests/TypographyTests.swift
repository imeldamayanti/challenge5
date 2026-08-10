import Foundation
import SwiftUI
import Testing
@testable import DesignSystem

/// `NFR-A11Y-01` — all text supports Dynamic Type through the largest accessibility size without
/// truncation or overlap. Lore is long-form reading, so this is the whole product, not a detail.
/// The structural half of that is here: no role may be defined by an absolute point size, because
/// a fixed size does not scale no matter how the layout is written.
struct TypographyTests {

    @Test func everyTextRoleIsDefinedByATextStyleAndNotAFixedSize() {
        for role in KultaraTypography.Role.allCases {
            // `textStyle` is non-optional, so the assertion that matters is that the type offers
            // no way to express a fixed size — checked by the absence of such an API and by this
            // enumeration staying exhaustive.
            _ = role.textStyle
            #expect(!role.rawValue.isEmpty)
        }
        #expect(KultaraTypography.Role.allCases.count >= 6)
    }

    @Test func loreUsesABodyStyleRatherThanACaptionStyle() {
        // A caption-sized lore passage is unreadable at default size and disastrous at
        // accessibility sizes. Naming it here keeps someone from "tightening" it later.
        #expect(KultaraTypography.Role.lore.textStyle == .body)
        #expect(KultaraTypography.Role.body.textStyle == .body)
    }

    @Test func metadataIsNotSmallerThanFootnote() {
        // Quest cards carry distance, duration and cost as metadata. Below footnote it stops
        // being information a walker can read in the street.
        let permitted: Set<Font.TextStyle> = [.footnote, .subheadline, .callout, .body]
        #expect(permitted.contains(KultaraTypography.Role.metadata.textStyle))
    }

    @Test func onlyGenuinelyLargeRolesClaimTheThreeToOneContrastAllowance() {
        // WCAG's 3:1 allowance applies to large text only. A body role claiming it would be a
        // quiet way of lowering the bar the theme was measured against.
        for role in KultaraTypography.Role.allCases {
            if role.isLargeText {
                #expect(role.contrastRequirement == .largeText, "\(role)")
                #expect([.largeTitle, .title, .title2].contains(role.textStyle), "\(role)")
            } else {
                #expect(role.contrastRequirement == .bodyText, "\(role)")
            }
        }
    }

    @Test func tapTargetsAreAtLeastFortyFourPoints() {
        #expect(KultaraMetrics.minimumTapTarget == 44)   // NFR-A11Y-06
    }

    @Test func theSpacingScaleIsMonotonic() {
        let scale = KultaraMetrics.spacingScale
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }
}

/// `FR-CP-05` — the accuracy label is rendered with a consistent, legible visual convention and is
/// never hidden behind a tap. `NFR-A11Y-05` — colour must not be the sole carrier of meaning,
/// explicitly including these labels.
struct AccuracyChipTests {

    @Test func theTwoChipsDifferInSomethingOtherThanColour() {
        let documented = ChipAppearance.documented
        let oral = ChipAppearance.oral
        // If the only difference were the ink, a reader with a colour-vision difference would see
        // one undifferentiated label on every claim in the app.
        #expect(documented.border != oral.border)
        #expect(documented.symbolName != oral.symbolName)
    }

    @Test func bothChipsCarryABorderThickEnoughToSee() {
        for chip in [ChipAppearance.documented, ChipAppearance.oral] {
            #expect(chip.borderWidth >= 1)
        }
    }

    @Test func chipsAreNotRenderedAsAnInteractiveControl() {
        // The label is information, not a disclosure affordance — FR-CP-05 forbids hiding it
        // behind a tap, and a chip that looks tappable invites exactly that reading.
        for chip in [ChipAppearance.documented, ChipAppearance.oral] {
            #expect(chip.isInteractive == false)
        }
    }
}
