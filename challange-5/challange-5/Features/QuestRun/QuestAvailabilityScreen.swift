import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// `921:3869` ("Activity View - iPhone") — the sheet reached straight off a checkpoint's first
/// explanation (the place notice at a sacred Place, the story reveal everywhere else), naming how
/// many quests stand at this place before the sealed scroll opens the walk itself.
///
/// Presented as a `.sheet()` over whichever screen it was reached from — see
/// `QuestRunViewModel.isPresentingQuestAvailability` for why this is not its own `Stage` case: the
/// frame draws the previous screen dimmed behind a drag-handled sheet, which a native sheet gives
/// for free, the same way `QuestRunView`'s manual-override tool already uses one.
///
/// **The count is real, not the frame's sample "3".** `title` reads the checkpoint's own filtered
/// task count (`FR-TASK-06`), so it says "1 Quest" for every place the shipped content carries
/// today rather than a number nothing backs (`AD-4`).
///
/// **Re-fitted to `921:3869` on 2026-08-24**, which is the same sheet redrawn and moves three
/// things the earlier `921:3462` build got from the older frame:
///
/// - **The two hairlines are gone.** `921:3872` draws its line behind the sheet's own rounded
///   corner and `921:3880` is an empty separator with no line in it at all — the frame renders
///   with neither, so drawing them was reproducing a node rather than the picture.
/// - **The header block has real padding.** `921:3873` is 16 above and 16 either side of the
///   Middle column, which the earlier build had at zero, and holds the gap to the pill.
/// - **The pill is the frame's 58 rather than the shared style's 52** — `.hisploraSheetPill`,
///   `921:3892`'s SF Pro Semibold 17 at −0.34 tracking in 17 points of vertical padding.
///
/// What carried over unchanged: the scroll at the frame's full 194 points with its 268 × 267
/// rotated bounding box, the headline pulled up 56 into it, the Middle block's 12/−56/2 rhythm,
/// the title at New York Semibold 25 with −0.5 tracking in the frame's own #151311, and the
/// subtitle at SF Pro 17 Light with 1.4 leading in #444444.
///
/// Two things stay elastic rather than drawn. The gap between the column and the pill is a
/// `Spacer`, so a sheet shorter than the frame's 540 gives that space up before anything with
/// words in it does; and `@ScaledMetric` backs both type sizes, so Dynamic Type still moves them
/// and a walker at the largest sizes drags to `.large` — which is why that detent stays offered.
struct QuestAvailabilityScreen: View {
    @Environment(\.hisploraPalette) private var palette

    /// The frame's own 194-point scroll; its rotated bounding box is the 268 × 267 container.
    private static let glyphWidth: CGFloat = 194

    /// `921:3875` hangs the headline 56 up into the tilted scroll's bounding box — the box's
    /// lower corners are empty paper-shadow space, and the roll end is what the words sit under.
    private static let titleOverlap: CGFloat = 56

    /// `921:3873` ("Header") — 16 above the Middle column and 16 either side of it, which is what
    /// sets the column's own 370 of the 402 screen.
    private static let headerTopPadding: CGFloat = 16
    private static let headerSidePadding: CGFloat = 16

    /// `921:3874`'s Middle block: 12 above, 2 below, the headline 56 into the glyph.
    private static let middleTopPadding: CGFloat = 12
    private static let middleBottomPadding: CGFloat = 2

    /// `921:3876` ("Frame 104") — 12 between the two texts, 4 of air above and below the pair.
    private static let titleBlockSpacing: CGFloat = 12
    private static let titleBlockVerticalPadding: CGFloat = 4

    /// The frame sets the title column to 308 of the 402 screen and the subtitle's to 352. Ceilings
    /// rather than fixed widths: both are wider than a 375-point screen's own text column, and a
    /// fixed width there would push the words off the paper.
    private static let titleWidth: CGFloat = 308
    private static let subtitleWidth: CGFloat = 352

    /// `921:3892` is 362 of a 402 screen — a 20-point side margin.
    private static let buttonSidePadding: CGFloat = 20

    /// The frame leaves 53 points below the pill before the sheet's bottom edge; the sheet's own
    /// home-indicator inset already supplies 34 of that, so the code adds 19.
    private static let buttonBottomPadding: CGFloat = 19

    /// What the column and the pill are drawn apart by when the sheet is the frame's own height —
    /// `921:3873`'s 427 less the 16 above the column and the 353.26 the column itself measures.
    /// A floor, not a fixed gap: the `Spacer` holding it is what a shorter sheet takes back first.
    private static let minimumActionGap: CGFloat = 24

    /// The frame's headline is New York Extra Large Semibold 25 — the serif design at a display
    /// optical size. `@ScaledMetric` keeps it at 25 by default and lets Dynamic Type move it.
    @ScaledMetric(relativeTo: .title) private var titleSize: CGFloat = 25

    /// The frame's subtitle is SF Pro Display Light 17 with 1.4 leading.
    @ScaledMetric(relativeTo: .body) private var subtitleSize: CGFloat = 17

    let language: ContentLanguage
    let title: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: Self.minimumActionGap)

            Button(UIStrings.string(.questAvailabilityContinue, language), action: onContinue)
                .buttonStyle(.hisploraSheetPill)
                .padding(.horizontal, Self.buttonSidePadding)
                .padding(.bottom, Self.buttonBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    /// `921:3873` around `921:3874` — the glyph and the two texts, and everything the frame pads
    /// them by.
    private var header: some View {
        VStack(spacing: 0) {
            HisploraAvailabilityGlyph(
                width: Self.glyphWidth,
                tiltDegrees: HisploraScrollArt.mapHintTiltDegrees)
                .padding(.bottom, -Self.titleOverlap)

            VStack(spacing: Self.titleBlockSpacing) {
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold, design: .serif))
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 21 / 255, green: 19 / 255, blue: 17 / 255))
                    .frame(maxWidth: Self.titleWidth)

                Text(UIStrings.string(.questAvailabilitySubtitle, language))
                    .font(.system(size: subtitleSize, weight: .light))
                    .lineSpacing(subtitleSize * 0.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.inkBody.color)
                    .frame(maxWidth: Self.subtitleWidth)
            }
            .padding(.vertical, Self.titleBlockVerticalPadding)
        }
        .padding(.top, Self.middleTopPadding)
        .padding(.bottom, Self.middleBottomPadding)
        .frame(maxWidth: .infinity)
        .padding(.top, Self.headerTopPadding)
        .padding(.horizontal, Self.headerSidePadding)
    }
}
