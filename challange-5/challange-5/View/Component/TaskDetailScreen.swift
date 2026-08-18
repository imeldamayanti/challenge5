import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// One task on its own parchment sheet — `447:1880` ("Quest_Filled"), reached from a row on
/// `CheckpointDetailScreen`.
///
/// **The header portrait is not drawn, and that is the standing decision rather than a new one.**
/// `447:1905` puts a 39-point circular likeness beside the title. It is the generated portrait of
/// I Gusti Ngurah Made Agung — a named historical person, which `FR-CP-05` wants a source and a
/// consent record for, and the content tree ships neither. `docs/hisplora-tokens.md` already records
/// that asset as deliberately not shipped, so this screen frames the quest's own hero image in the
/// circle instead, exactly as `PlaceNoticeScreen` and the cutscenes do, and draws nothing at all when
/// the quest ships no hero.
///
/// **"Take Photo" appears only where the task is a photo task.** `447:1900` draws it as the sheet's
/// one action, but the shipped content carries a photo task at exactly one of five checkpoints; four
/// carry a written reflection or a question. Drawing a camera button over a written task would be a
/// control that cannot do what it says. Photo capture is still not built in this build — the note
/// `TaskCard` already carries is what says so — so the camera label is offered and then hands over to
/// the checkpoint screen like every other task, rather than pretending to open a camera.
///
/// **The primary action does not answer the task.** It continues into the checkpoint screen, where
/// `TaskCard` carries the answer field, the save and the skip (`FR-TASK-02`). Duplicating that
/// machinery on a parchment sheet would give the app two places that write a `TaskResult`, and
/// `FR-TASK-07`'s closing reflection is only correct in one of them.
struct TaskDetailScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// `447:1884` — the quest's title, not the place's. The place is printed on the sheet below.
    let questTitle: String
    let placeName: String
    let task: ContentTask
    let prompt: String
    /// Nil until the task has been answered or skipped. Shown as a note on the sheet rather than as a
    /// disabled action: the walker may want to re-read what they wrote (`FR-TASK-07`).
    let resolution: TaskResult?
    /// How far through this checkpoint's tasks the walker is — `447:1903`'s thin determinate bar.
    let completedTasks: Int
    let totalTasks: Int
    let portraitURL: URL?
    /// Nil when the Place ships no plan, which hides the map hint rather than offering one that opens
    /// an empty screen.
    let hasSiteMap: Bool
    let onPrimaryAction: () -> Void
    let onOpenSiteMap: () -> Void
    let onBack: () -> Void

    private static let margin: CGFloat = 20

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            ScrollView {
                VStack(spacing: 0) {
                    titleBar
                    // `447:1903` is a 4-point bar in a box padded 20, sitting at y = 114 under a
                    // title box ending at 108.
                    Spacer(minLength: 6)
                    progressBar
                    // The sheet is drawn at y = 190, 62 under the bar's box.
                    Spacer(minLength: 62)
                    sheet
                }
                .padding(.horizontal, Self.margin)
                .padding(.bottom, KultaraMetrics.xl)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { mapHint }
        }
    }

    /// The back arrow, the quest title centred over it, and the framed hero in the trailing corner.
    ///
    /// The title is an overlay on the row rather than its middle column: with the circle 40 points
    /// wide on one side and the arrow 44 on the other, a three-column row centres the title on the
    /// space between them instead of on the screen, and `447:1884` centres it on the screen.
    private var titleBar: some View {
        HStack {
            HisploraBackButton(
                accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                size: 24,
                action: onBack)
            Spacer(minLength: 0)
            heroCircle
        }
        .overlay {
            Text(questTitle)
                // `447:1884` sets this one in the sans, unlike `452:3136`'s serif. Reproduced as
                // drawn — the two screens really do differ, and 19-point SF Pro is what the frame
                // specifies.
                .font(.system(size: 19))
                .tracking(-0.38)
                .foregroundStyle(palette.inkOnButton.color)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, KultaraMetrics.minimumTapTarget + KultaraMetrics.sm)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, 13)
    }

    @ViewBuilder private var heroCircle: some View {
        if let portraitURL, let image = BundledImage.load(portraitURL) {
            image
                .resizable()
                .scaledToFill()
                // 38.82 as drawn, and 40 is the frame's own box around it.
                .frame(width: 38.82, height: 38.82)
                .clipShape(Circle())
                .overlay(Circle().stroke(palette.buttonRing.color,
                                        lineWidth: KultaraMetrics.hairline))
                // The 1.77° the frame tilts it. Decoration; the circle names nothing, so it stays
                // out of the accessibility tree rather than becoming an unlabelled image.
                .rotationEffect(.degrees(1.77))
                .accessibilityHidden(true)
        } else {
            // The frame's own box, kept so the title stays centred on the screen whether or not the
            // quest ships a hero image.
            Color.clear.frame(width: 40, height: 40)
        }
    }

    /// `447:1903` — the iOS determinate linear bar, filled to how many of this checkpoint's tasks are
    /// resolved. `FR-CP-08` is checkpoints out of total and lives on the checkpoint screen; this is
    /// the finer count, inside one stop.
    private var progressBar: some View {
        ProgressView(
            value: Double(completedTasks),
            total: Double(max(totalTasks, 1)))
            .progressViewStyle(.linear)
            .tint(palette.inkOnButton.color)
            .padding(.vertical, 20)
            .accessibilityLabel(
                String(format: UIStrings.string(.checkpointDetailProgressLabel, language),
                       completedTasks, totalTasks))
    }

    private var sheet: some View {
        HisploraParchmentSheet {
            VStack(spacing: 0) {
                Text(placeName)
                    .kultaraFont(.storyPlaceMark)
                    .foregroundStyle(palette.brownMid.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                // 322 − 311: the ornament sits 11 under the place name's box.
                Spacer(minLength: 11)
                HisploraOrnamentDivider()
                // 355 − 331.
                Spacer(minLength: 24)
                Text(taskTypeLabel)
                    .kultaraFont(.storyTaskTitle)
                    .foregroundStyle(palette.buttonFill.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 4)
                Text(prompt)
                    .font(.system(size: 15, weight: .light))
                    .lineSpacing(15 * 0.4)
                    .foregroundStyle(palette.inkBody.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                // 521 − 449: the action sits 72 under the instruction.
                Spacer(minLength: 72)
                primaryAction
                if let resolution {
                    Spacer(minLength: KultaraMetrics.lg)
                    resolutionNote(resolution)
                }
                if task.type == .photo, resolution == nil {
                    Spacer(minLength: KultaraMetrics.md)
                    Text(UIStrings.string(.taskPhotoNotInThisBuild, language))
                        .font(.system(size: 13))
                        .foregroundStyle(palette.inkMuted.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// `447:1900`'s pill: a 45%-white capsule 220 wide with a near-black label.
    ///
    /// **The outline moved.** The frame draws `#CAB7B0`, which measures 1.61:1 against the sheet's
    /// lightest interior — well under the 3:1 WCAG 1.4.11 asks of a control's visual boundary, and the
    /// translucent fill gives it nothing either. It is drawn in `brownMid` instead, at 7.22:1: the
    /// same brown the place name above is set in, so the control reads as part of the sheet's own ink
    /// rather than as a new colour. Recorded in `docs/hisplora-tokens.md`.
    private var primaryAction: some View {
        Button(action: onPrimaryAction) {
            HStack(spacing: 10) {
                if task.type == .photo {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18.75, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(task.type == .photo
                     ? UIStrings.string(.taskDetailTakePhoto, language)
                     : UIStrings.string(.taskDetailAnswerAction, language))
                    .font(.system(size: 17, weight: .medium))
                    .tracking(-0.51)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(palette.buttonFill.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 17)
            // 220 as drawn, and a maximum rather than a width: at accessibility sizes the label has
            // to be allowed to make the capsule wider than the frame draws it instead of truncating.
            .frame(minWidth: 0, maxWidth: 220)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.inkOnButton.color.opacity(0.45), in: Capsule())
            .overlay(Capsule().stroke(palette.brownMid.color,
                                      lineWidth: KultaraMetrics.hairline))
        }
        .buttonStyle(.plain)
    }

    private func resolutionNote(_ resolution: TaskResult) -> some View {
        VStack(spacing: KultaraMetrics.xs) {
            Text(resolution.skipped
                 ? UIStrings.string(.taskSkippedNote, language)
                 : UIStrings.string(.taskAnsweredNote, language))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.inkMuted.color)
            if let text = resolution.text {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.inkBody.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// `447:1907` — the tilted scroll and the hint under it, as one control.
    ///
    /// One button rather than a glyph beside a caption, because the frame's whole 362-point block is
    /// what the walker taps at. It disappears when the Place ships no plan: a hint that opens an empty
    /// screen is worse on a walk than no hint.
    @ViewBuilder private var mapHint: some View {
        if hasSiteMap {
            Button(action: onOpenSiteMap) {
                VStack(spacing: 12) {
                    HisploraScrollGlyph(
                        size: 32,
                        tiltDegrees: HisploraScrollArt.mapHintTiltDegrees)
                    Text(UIStrings.string(.taskDetailSeeMap, language))
                        .font(.system(size: 17))
                        .tracking(-0.34)
                        .foregroundStyle(palette.inkOnButton.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(UIStrings.string(.taskDetailSeeMapHint, language))
            .padding(.horizontal, Self.margin)
            .padding(.bottom, 30)
        }
    }

    /// The content has no title field for a task — only a `type` and a `prompt` — so the sheet's
    /// masthead is the type's name. `447:1896`'s "Find The Iron Statue" is copy invented for the
    /// mock-up and names a task that exists nowhere in the content tree (`AD-4`).
    private var taskTypeLabel: String {
        switch task.type {
        case .reflection: UIStrings.string(.taskTypeReflection, language)
        case .photo: UIStrings.string(.taskTypePhoto, language)
        case .question: UIStrings.string(.taskTypeQuestion, language)
        }
    }
}
