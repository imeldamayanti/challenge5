import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The stamp, presented once a task has been resolved and its story told — Figma `1:4641` ("Quest").
///
/// **The stamp is presented here, not granted here.** `FR-CP-07` awards it on *arrival*, before any
/// task exists to complete — `RunEngine.applyArrival` writes both the `Award` and
/// `CheckpointResult.stampAwardedAt` in the same breath as the snapshot. This screen is where the
/// walker is finally *shown* it, which is what the frame is for; it writes nothing. Moving the award
/// to this screen would mean a walker who reaches a checkpoint and closes the app has no stamp for a
/// place they stood in, which is precisely what `FR-CP-07` is written to prevent.
///
/// **The drawing is tiered by walking, not by this checkpoint.** `HisploraStampArtwork` shows a place
/// the first of its three illustrations on a first finished quest through it, the second on a second,
/// the third from then on — counted from the reader's own finished Runs by `StampArtworkResolver`.
/// A walk in progress is not finished, so a first-time walker sees the first drawing here and the
/// Journal shows them the same one afterwards.
///
/// **Two actions, and one of them disappears.** `1:4650` draws "Next Location" beside "More Quests
/// (2)". The count is this checkpoint's *unresolved* tasks, from the Run's own results — and when it
/// reaches zero the second pill goes, because a control offering nothing is worse than one control.
/// Neither gates anything: "Next Location" is the same exit `checkpointDetailContinueToNext` is, and
/// the walk has never been blocked on a task (`AD-2`).
struct StampAwardScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// `Award.snapshotName` — the place as it read on the day, not as content reads today
    /// (`FR-RUN-06`).
    let placeName: String
    /// The quest's region, which is what every other stamp in the app is franked with.
    let region: String
    /// `"pemecutan-stamp1"`, or nil for a place the design never drew — which franks aged paper
    /// rather than a borrowed picture.
    let artworkName: String?
    /// Which of the walk's stamps this is, and how many there are: `1:4648`'s caption, made a count
    /// rather than the frame's invented "First Trace Stamp" ordinal.
    let stampNumber: Int
    let totalStamps: Int
    /// How many tasks at this checkpoint are still unresolved.
    let remainingTasks: Int
    /// Back to this checkpoint's task menu.
    let onMoreQuests: () -> Void
    /// On towards the next checkpoint — or, at the final one, to the summary.
    let onNextLocation: () -> Void

    private static let margin: CGFloat = 20

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            ScrollView {
                VStack(spacing: 0) {
                    // `1:4644` sets the headline at y 110, under a bar this screen does not draw.
                    Spacer(minLength: 24)
                    headline
                    // 228 − 168.
                    Spacer(minLength: 60)
                    stamp
                    Spacer(minLength: 24)
                    caption
                    Spacer(minLength: 40)
                    body(text: remainingTasks > 0
                         ? UIStrings.string(.stampAwardBody, language)
                         : UIStrings.string(.stampAwardBodyAllDone, language))
                }
                .padding(.horizontal, Self.margin)
                .padding(.bottom, KultaraMetrics.xl)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Pinned at a fixed distance from the home indicator, as `1:4650` draws them, so a
            // longer headline above cannot push them off the screen.
            .safeAreaInset(edge: .bottom) { actions }
        }
    }

    /// `1:4645` — 31-point New York, centred, in cream.
    private var headline: some View {
        Text(UIStrings.string(.stampAwardHeading, language))
            .kultaraFont(.onboardingDisplay)
            .foregroundStyle(palette.inkOnButton.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }

    /// `1:4647` — the franked stamp at 216 × 293, which is `HisploraStampCard`'s own 152 × 206 die
    /// set larger. The same object the Journal and the Explorer's Card frank, at the size this frame
    /// draws it.
    private var stamp: some View {
        HisploraStampCard(title: placeName, subtitle: region, artworkName: artworkName)
            // 216 × 293 as `1:4647` draws it, which is the die's own 152 : 206 at a larger size.
            .frame(width: 216,
                   height: 216 / HisploraStampCard<HisploraStampArtworkImage>.aspectRatio)
            .accessibilityElement(children: .combine)
    }

    /// `1:4648` — what the stamp is, under it.
    ///
    /// The frame says "First Trace Stamp". An ordinal spelled out in words is a translation problem
    /// in two languages and a content problem in a quest of any other length, so it is a count: this
    /// stamp's place in the walk, which is a fact the Run already holds.
    private var caption: some View {
        Text(String(format: UIStrings.string(.stampAwardCaption, language),
                    stampNumber, totalStamps))
            .font(.system(size: 19, weight: .bold))
            .tracking(-0.38)
            .foregroundStyle(palette.inkOnButton.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private func body(text: String) -> some View {
        Text(text)
            .font(.system(size: 17))
            .tracking(-0.34)
            .lineSpacing(17 * 0.4)
            .foregroundStyle(palette.inkOnButton.color.opacity(0.84))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    /// `15:2798` is the dark pill and `1:4653` the white one, side by side and equally wide.
    ///
    /// A `ViewThatFits` rather than a plain `HStack`: two 17-point labels fit across 362 points at
    /// the default size and do not at the accessibility sizes, where the frame's row would either
    /// truncate or squeeze each pill to a column of single letters (`NFR-A11Y-01`).
    @ViewBuilder private var actions: some View {
        let next = Button(UIStrings.string(.stampAwardNextLocation, language),
                          action: onNextLocation)
            .buttonStyle(.hisploraPill)
        let more = Button(String(format: UIStrings.string(.stampAwardMoreQuests, language),
                                 remainingTasks),
                          action: onMoreQuests)
            .buttonStyle(.hisploraLightPill)

        Group {
            if remainingTasks > 0 {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { next; more }
                    VStack(spacing: 12) { more; next }
                }
            } else {
                next
            }
        }
        .padding(.horizontal, Self.margin)
        .padding(.bottom, 30)
    }
}
