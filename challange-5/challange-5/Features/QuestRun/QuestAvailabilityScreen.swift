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
struct QuestAvailabilityScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let title: String
    let onContinue: () -> Void

    /// `921:3869` hangs its headline 56 points up into the tilted scroll's bounding box — the
    /// box's lower corners are empty paper-shadow space, and the roll end is what the words sit
    /// under. Without this pull-up a centred column reads a full corner of air below the picture.
    private static let titleOverlap: CGFloat = 56

    var body: some View {
        VStack(spacing: KultaraMetrics.xl) {
            Spacer(minLength: KultaraMetrics.xxl)

            HisploraAvailabilityGlyph(
                width: 194,
                tiltDegrees: HisploraScrollArt.mapHintTiltDegrees)
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

            Spacer(minLength: KultaraMetrics.xxl)

            Button(UIStrings.string(.questAvailabilityContinue, language), action: onContinue)
                .buttonStyle(.hisploraPillOnPaper)
                .padding(.horizontal, KultaraMetrics.xl)
                .padding(.bottom, KultaraMetrics.xl)
        }
        .frame(maxWidth: .infinity)
        .background(palette.paperSheet.color)
    }
}
