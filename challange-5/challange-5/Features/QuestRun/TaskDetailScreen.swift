import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// One task on its own parchment sheet — `1:4711` ("Quest_Filled", `447:1880` before it).
///
/// **This is where a task is answered.** The checkpoint's first task opens straight from the place
/// notice (`1:4592`), before the menu (`1:4904`) exists to be tapped, so the sheet carries the
/// answer field, the save and the skip rather than handing them to a later screen: a sheet the walk
/// opens on and cannot resolve would be a dead end. Both controls write through the same
/// `QuestRunViewModel.saveTask`/`skipTask` the checkpoint screen's `TaskCard` writes through, so
/// there is still one writer of a `TaskResult` and two ways to reach it.
///
/// **The header portrait is not drawn, and that is the standing decision rather than a new one.**
/// `447:1905` puts a 39-point circular likeness beside the title. It is the generated portrait of
/// I Gusti Ngurah Made Agung — a named historical person, which `FR-CP-05` wants a source and a
/// consent record for, and the content tree ships neither. `docs/hisplora-tokens.md` already records
/// that asset as deliberately not shipped, so this screen frames the quest's own hero image in the
/// circle instead, exactly as `PlaceNoticeScreen` and the cutscenes do, and draws nothing at all when
/// the quest ships no hero.
///
/// **"Take Photo" appears only where the task is a photo task, and it now opens a camera.** `447:1900`
/// draws it as the sheet's one action, and `1:4681` is the screen behind it; the shipped content
/// carries a photo task at exactly one of five checkpoints, and `FR-TASK-06` drops even that one
/// where photography is prohibited. Once a photograph has been taken the sheet becomes `1:4827`
/// ("Quest_Filled" holding an image): the pill gives way to an 88-point thumbnail with a cross on its
/// shoulder, and a white Submit pill replaces the map hint at the foot of the screen. The skip stays
/// available in both states (`FR-TASK-02`, `AD-2`) — the walk is never blocked on hardware.
struct TaskDetailScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// `447:1884` — the quest's title, not the place's. The place is printed on the sheet below.
    let questTitle: String
    let placeName: String
    let task: ContentTask
    let prompt: String
    /// Nil until the task has been answered or skipped. Once set, the field and its two controls give
    /// way to the note and a plain continue: the walker may want to re-read what they wrote
    /// (`FR-TASK-07`), and re-answering is the checkpoint screen's job, not this sheet's.
    let resolution: TaskResult?
    /// The answer being typed. Not persisted until saved — `FR-RUN-01` is about completed actions,
    /// and a half-typed sentence is not one.
    @Binding var draft: String
    /// How far through this checkpoint's tasks the walker is — `447:1903`'s thin determinate bar.
    let completedTasks: Int
    let totalTasks: Int
    let portraitURL: URL?
    /// The photograph just taken for this task, before it is submitted — `1:4850`'s 88-point
    /// thumbnail. Nil on a written task, and on a photo task the walker has not shot yet.
    let photoDraft: Image?
    /// Whether this device can offer the camera at all. False on the Simulator and where access has
    /// been refused, which turns the pill into the note that says so rather than a control that
    /// opens a black screen.
    let isCameraAvailable: Bool
    /// Nil when the Place ships no plan, which hides the map hint rather than offering one that opens
    /// an empty screen.
    let hasSiteMap: Bool
    /// Writes the draft as this task's answer and moves on. An empty draft saves as a skip
    /// (`QuestRunViewModel.saveTask`), so the sheet never traps a walk behind a blank field.
    let onSave: () -> Void
    /// `FR-TASK-02` — the explicit, non-apologetic skip. Same weight as saving, same destination.
    let onSkip: () -> Void
    /// `447:1900` — opens `1:4681`.
    let onTakePhoto: () -> Void
    /// `1:4852` — discards the photograph and re-offers the camera. Nothing is written until Submit,
    /// so this removes a draft rather than editing a record.
    let onRemovePhoto: () -> Void
    /// Leaving an already-resolved sheet forwards.
    let onContinue: () -> Void
    let onOpenSiteMap: () -> Void
    let onBack: () -> Void

    private static let margin: CGFloat = 20

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            // The title bar and progress bar are a fixed header, not scrolling content — only
            // `sheet` scrolls. Mirrors `LocationVerifiedScreen`'s header/`ScrollView` split rather
            // than putting the bar inside the scrolled `VStack`, which let it scroll off with the
            // sheet.
            VStack(spacing: 0) {
                titleBar
                // `447:1903` is a 4-point bar in a box padded 20, sitting at y = 114 under a
                // title box ending at 108.
                Spacer(minLength: 6)
                progressBar
                ScrollView {
                    VStack(spacing: 0) {
                        // The sheet is drawn at y = 190, 62 under the bar's box.
                        Spacer(minLength: 62)
                        sheet
                    }
                    .padding(.bottom, KultaraMetrics.xl)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.horizontal, Self.margin)
            // `1:4827` replaces the map hint with Submit once a photograph is waiting. One inset,
            // not two stacked: the frame draws a single control at that distance from the home
            // indicator, and a hint under a primary action reads as a second action.
            .safeAreaInset(edge: .bottom) {
                if photoDraft != nil { submitBar } else { mapHint }
            }
        }
    }

    /// `1:4854` — the white capsule across the foot of the filled sheet.
    private var submitBar: some View {
        Button(UIStrings.string(.taskPhotoSubmit, language), action: onSave)
            .buttonStyle(.hisploraLightPill)
            .padding(.horizontal, Self.margin)
            .padding(.bottom, 30)
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
                answerSection
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The shapes the foot of the sheet takes: resolved, a photo task in one of its three states, or
    /// a written task waiting for an answer.
    @ViewBuilder private var answerSection: some View {
        if let resolution {
            resolutionNote(resolution)
            Spacer(minLength: KultaraMetrics.lg)
            pill(title: UIStrings.string(.checkpointDetailContinue, language), action: onContinue)
        } else if task.type == .photo {
            photoSection
        } else {
            answerField
            Spacer(minLength: KultaraMetrics.lg)
            pill(title: UIStrings.string(.taskSaveAction, language), action: onSave)
            Spacer(minLength: KultaraMetrics.md)
            // A plain label rather than a second capsule: `FR-TASK-02` asks for a skip that is
            // offered without apology, not one that competes with saving for the eye.
            Button(UIStrings.string(.taskSkipAction, language), action: onSkip)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.brownMid.color)
                .frame(minHeight: KultaraMetrics.minimumTapTarget)
        }
    }

    /// A photo task, in whichever of its three states it is in: a photograph waiting to be
    /// submitted (`1:4827`), the camera on offer (`447:1900`), or a device that cannot open one.
    ///
    /// The skip is present in all three. `AD-2` means a task gates nothing, and a photo task is the
    /// one kind that can fail for a reason the walker has no control over — a locked-down device, a
    /// refused permission, a temple that forbids photography. None of those may end a walk.
    @ViewBuilder private var photoSection: some View {
        if let photoDraft {
            photoThumbnail(photoDraft)
            Spacer(minLength: KultaraMetrics.md)
            Text(UIStrings.string(.taskPhotoSavedNote, language))
                .font(.system(size: 13))
                .foregroundStyle(palette.inkMuted.color)
                .multilineTextAlignment(.center)
            // Submit is pinned at the foot of the screen, as `1:4854` draws it. The skip stays on
            // the sheet so the two are not competing for the same corner of the eye.
            Spacer(minLength: KultaraMetrics.md)
            Button(UIStrings.string(.taskSkipAction, language), action: onSkip)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.brownMid.color)
                .frame(minHeight: KultaraMetrics.minimumTapTarget)
        } else if isCameraAvailable {
            pill(title: UIStrings.string(.taskDetailTakePhoto, language),
                 systemImage: "camera.fill",
                 action: onTakePhoto)
            Spacer(minLength: KultaraMetrics.md)
            Button(UIStrings.string(.taskSkipAction, language), action: onSkip)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.brownMid.color)
                .frame(minHeight: KultaraMetrics.minimumTapTarget)
        } else {
            Text(UIStrings.string(.cameraUnavailable, language))
                .font(.system(size: 13))
                .foregroundStyle(palette.inkMuted.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: KultaraMetrics.lg)
            pill(title: UIStrings.string(.taskSkipAction, language), action: onSkip)
        }
    }

    /// `1:4850` — an 88-point white plate with the photograph in it, and `1:4852`'s cross sitting on
    /// its top-trailing shoulder.
    ///
    /// The cross is a control of its own rather than a corner of the plate, so it carries the
    /// minimum tap target under a 24-point badge (`NFR-A11Y-06`) — which is why it is a `Button` with
    /// a larger `contentShape` than the circle it draws.
    private func photoThumbnail(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 8.213))
            .overlay(RoundedRectangle(cornerRadius: 8.213)
                .stroke(palette.buttonRing.color, lineWidth: KultaraMetrics.hairline))
            .accessibilityLabel(UIStrings.string(.taskPhotoThumbnail, language))
            .overlay(alignment: .topTrailing) {
                Button(action: onRemovePhoto) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.buttonFill.color)
                        .frame(width: 24, height: 24)
                        .background(palette.inkOnButton.color, in: Circle())
                        .overlay(Circle().stroke(palette.buttonRing.color,
                                                 lineWidth: KultaraMetrics.hairline))
                        .frame(width: KultaraMetrics.minimumTapTarget,
                               height: KultaraMetrics.minimumTapTarget)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(UIStrings.string(.taskPhotoRemove, language))
                // The badge straddles the plate's corner as `1:4852` sets it, 7 points proud of the
                // top edge and 10 outside the trailing one.
                .offset(x: KultaraMetrics.minimumTapTarget / 2 - 2,
                        y: -KultaraMetrics.minimumTapTarget / 2 + 5)
            }
    }

    /// The field itself, sunk into the sheet on `paperTicket` — the one paper token measured against
    /// `inkBody` and `inkMuted` (`HisploraThemeTests`), which is what the answer and its placeholder
    /// are set in.
    private var answerField: some View {
        TextField(UIStrings.string(.taskAnswerPlaceholder, language), text: $draft, axis: .vertical)
            .font(.system(size: 15))
            .foregroundStyle(palette.inkBody.color)
            .lineLimit(3...8)
            .textFieldStyle(.plain)
            .padding(KultaraMetrics.md)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.paperTicket.color, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(palette.brownMid.color, lineWidth: KultaraMetrics.hairline))
    }

    /// `447:1900`'s pill: a 45%-white capsule 220 wide with a near-black label.
    ///
    /// **The outline moved.** The frame draws `#CAB7B0`, which measures 1.61:1 against the sheet's
    /// lightest interior — well under the 3:1 WCAG 1.4.11 asks of a control's visual boundary, and the
    /// translucent fill gives it nothing either. It is drawn in `brownMid` instead, at 7.22:1: the
    /// same brown the place name above is set in, so the control reads as part of the sheet's own ink
    /// rather than as a new colour. Recorded in `docs/hisplora-tokens.md`.
    private func pill(
        title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18.75, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
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
