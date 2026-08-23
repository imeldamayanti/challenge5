import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// `921:3851` ("Quest - Card") — the sheet reached straight off a checkpoint's first explanation
/// (the place notice at a sacred Place, the story reveal everywhere else), naming how many quests
/// stand at this place before the sealed scroll opens the walk itself.
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
/// **Two deviations from the frame, both the owner's instruction of 2026-08-23.** The sheet stands
/// at half screen (`.medium` first detent, `921:3870`'s own 540 of 874 is nearer two thirds) and
/// its ground is **white**, not this direction's cream — `921:3870`'s own fill is
/// `backgrounds/primary---elevated = white`. The palette has no white token, so the view takes
/// `Color.white` directly; the inks stay palette tokens, and both read *better* on white than on
/// `paperSheet` (white is strictly brighter than #FDF2DE, so every measured pair only widens).
struct QuestAvailabilityScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let title: String
    let onContinue: () -> Void

    /// The scroll at the size half a screen holds. `921:3869` draws it 194 wide inside a 540-point
    /// sheet; scaled to the `.medium` detent the same fraction of the sheet is 157.
    private static let glyphWidth: CGFloat = 157

    /// `921:3869` hangs its headline 56 points up into the tilted scroll's bounding box — the
    /// box's lower corners are empty paper-shadow space, and the roll end is what the words sit
    /// under. Without this pull-up a centred column reads a full corner of air below the picture.
    /// Scaled with the glyph to the half-screen sheet (56 × 437/540).
    private static let titleOverlap: CGFloat = 45

    /// `921:3869`'s own 28 (Header 16 + Middle 12) scaled to the half-height sheet (× 437/540).
    private static let glyphTopPadding: CGFloat = 23

    /// The frame's button is 362 of a 402 screen — a 20-point side margin, kept absolute because
    /// width does not shrink with the sheet.
    private static let buttonSidePadding: CGFloat = 20

    /// The frame hangs its button 55 above the sheet's bottom edge; the sheet's own home-indicator
    /// inset already supplies 34 of that, so the code adds 21.
    private static let buttonBottomPadding: CGFloat = 21

    var body: some View {
        VStack(spacing: 0) {
            HisploraAvailabilityGlyph(
                width: Self.glyphWidth,
                tiltDegrees: HisploraScrollArt.mapHintTiltDegrees)
                .padding(.top, Self.glyphTopPadding)
                .padding(.bottom, -Self.titleOverlap)

            VStack(spacing: KultaraMetrics.md) {
                Text(title)
                    // New York Semibold — `921:3877`'s headline face, which is the role
                    // `.storyTaskTitle` already decides (display serif, semibold, `.title2`).
                    .kultaraFont(.storyTaskTitle)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.inkDark.color)

                Text(UIStrings.string(.questAvailabilitySubtitle, language))
                    // The frame sets SF Pro Display *Light*; the table carries no light cut, so
                    // this is `body` regular in the same ink — `inkBody` is #444444, the frame's
                    // own value exactly.
                    .kultaraFont(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.inkBody.color)
            }
            .padding(.horizontal, KultaraMetrics.xl)

            Spacer(minLength: KultaraMetrics.lg)

            Button(UIStrings.string(.questAvailabilityContinue, language), action: onContinue)
                .buttonStyle(.hisploraPillOnPaper)
                .padding(.horizontal, Self.buttonSidePadding)
                .padding(.bottom, Self.buttonBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
