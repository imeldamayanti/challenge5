import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// `921:3851`/`921:3462` ("Quest - Card") — the sheet reached straight off a checkpoint's first
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
/// **Frame-exact by the owner's instruction of 2026-08-23** ("need to follow all even the text,
/// weight, all"): the scroll at the frame's full 194 points with its 268 × 267 rotated bounding
/// box, the headline pulled up 56 into it, the Middle block's 12/−56/2 rhythm, the title at New
/// York Semibold 25 with −0.5 tracking in the frame's own #151311, the subtitle at SF Pro 17
/// Light with 1.4 leading in #444444, and both hairlines. Three things stay native or scaled:
/// the sheet stands at `.medium` (437 of the frame's 540 — the same half-screen instruction),
/// the button is the direction's shared pill style (54 tall where the frame draws 58), and
/// `@ScaledMetric` backs both type sizes so Dynamic Type still moves them; a walker at the
/// largest sizes drags to `.large`, which is why that detent stays offered.
struct QuestAvailabilityScreen: View {
    @Environment(\.hisploraPalette) private var palette

    /// The frame's own 194-point scroll; its rotated bounding box is the 268 × 267 container.
    private static let glyphWidth: CGFloat = 194

    /// `921:3468` hangs the headline 56 up into the tilted scroll's bounding box — the box's
    /// lower corners are empty paper-shadow space, and the roll end is what the words sit under.
    private static let titleOverlap: CGFloat = 56

    /// `921:3467`'s Middle block: 12 above, 2 below, the headline 56 into the glyph.
    private static let middleTopPadding: CGFloat = 12
    private static let middleBottomPadding: CGFloat = 2

    /// The frame sets the title column to 308 of the 402 screen.
    private static let titleWidth: CGFloat = 308

    /// The frame's button is 362 of a 402 screen — a 20-point side margin.
    private static let buttonSidePadding: CGFloat = 20

    /// The frame hangs its button 55 above the sheet's bottom edge; the sheet's own home-indicator
    /// inset already supplies 34 of that, so the code adds 21.
    private static let buttonBottomPadding: CGFloat = 21

    /// `921:3462` draws a 1-point hairline above and below the header block
    /// (`separators/vibrant`, #E6E6E6). The palette has no token for it — same standing as the
    /// white ground above.
    private static let separatorInk = Color(red: 0xE6 / 255, green: 0xE6 / 255, blue: 0xE6 / 255)

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
            separator

            HisploraAvailabilityGlyph(
                width: Self.glyphWidth,
                tiltDegrees: HisploraScrollArt.mapHintTiltDegrees)
                .padding(.top, Self.middleTopPadding)
                .padding(.bottom, -Self.titleOverlap)

            VStack(spacing: KultaraMetrics.md) {
                Text(title)
                    .font(.system(size: titleSize, weight: .semibold, design: .serif))
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 21 / 255, green: 19 / 255, blue: 17 / 255))
                    .frame(width: Self.titleWidth)

                Text(UIStrings.string(.questAvailabilitySubtitle, language))
                    .font(.system(size: subtitleSize, weight: .light))
                    .lineSpacing(subtitleSize * 0.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.inkBody.color)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, Self.middleBottomPadding)

            Spacer(minLength: KultaraMetrics.sm)

            separator

            Button(UIStrings.string(.questAvailabilityContinue, language), action: onContinue)
                .buttonStyle(.hisploraPillOnPaper)
                .padding(.horizontal, Self.buttonSidePadding)
                .padding(.bottom, Self.buttonBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    /// `921:3465` / `921:3473` — 24-point side insets, one point tall.
    private var separator: some View {
        Rectangle()
            .fill(Self.separatorInk)
            .frame(height: 1)
            .padding(.horizontal, 24)
    }
}
