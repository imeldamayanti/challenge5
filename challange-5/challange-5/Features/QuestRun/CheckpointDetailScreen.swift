import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The checkpoint's task list — `452:3132` ("Quest 1/3"), which replaces the earlier `51:201`
/// ("Detail Quest") treatment this screen shipped with, and `197:148`, the same frame relinked in
/// Ngalcer with a redrawn footer (see `footer` below).
///
/// A list, not the tasks themselves: every row opens `TaskDetailScreen`, and the answer field, the
/// save and the skip stay where they already are on the checkpoint screen (`TaskCard`, `FR-TASK-02`).
/// This screen's job is narrower — name what is waiting, in the order it is waiting in, and say which
/// of it is done.
///
/// **The frame's three tasks do not exist.** `452:3149`, `452:3159` and `452:3169` (`197:161`,
/// `197:171`, `197:181` in the relinked frame) name "The Iron Statue", "The Ancient Script" and "The
/// Whip Bearer"; nothing in the content tree carries any of them, and the shipped checkpoints carry
/// exactly one task each. So the rows are whatever `tasks` the run actually has, titled by
/// `TaskType` — and the progress bar draws one segment where the frame draws three, because the bar
/// is the run's state and not the mock-up's (`AD-4`, `FR-RUN-06`).
///
/// **The stamp in the bar is the place's own tiered drawing, and it previews rather than records.**
/// `452:3142` fills it with a generated sketch of a temple gate. It used to be filled with the
/// quest's hero image, which was honest about provenance and wrong about what the object *is*.
/// What it draws now (`QuestRunViewModel.progressStampArtworkName`) is one tier ahead of what
/// `StampAwardScreen` and the Journal show for this place — none resolved yet draws the first
/// drawing as a reason to do one, one resolved draws the second, and so on — because a walker still
/// reading this list is looking at what one more quest gets them, not at a record of what has
/// already happened. The picture is packaged chrome rather than a sourced claim about a place,
/// which is the same footing every other stamp window in the app stands on.
struct CheckpointDetailScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let placeName: String
    let tasks: [ContentTask]
    let taskPrompts: [String: String]
    /// Nil for a task nobody has answered or skipped yet. Drives the trailing glyph and the bar.
    let resolutions: [String: TaskResult]
    /// The tiered drawing to preview here, by resource name — one tier ahead of what this place has
    /// actually earned (see this file's own doc comment). Nil — a place the design never drew —
    /// ships a plain cream stamp rather than a borrowed picture.
    let stampArtworkName: String?
    /// Whether this is the walk's last checkpoint — `197:148`'s footer reads differently there,
    /// since there is no next place to leave for.
    let isFinal: Bool
    /// The next checkpoint's place name, for the footer's "Next Place" pill. Nil at the final
    /// checkpoint, where `isFinal` decides the footer instead.
    let nextPlaceName: String?
    let onSelectTask: (ContentTask) -> Void
    let onContinue: () -> Void
    let onBack: () -> Void

    /// `452:3132`'s own margins, in its own 402-point terms. 20 each side is what leaves the drawn
    /// 362-point content column.
    private static let margin: CGFloat = 20

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            // The title bar and progress row are a fixed header, not scrolling content — only the
            // task list scrolls. Mirrors `LocationVerifiedScreen`'s header/`ScrollView` split rather
            // than putting the bar inside the scrolled `VStack`, which let it scroll off with the
            // list.
            VStack(alignment: .leading, spacing: 0) {
                titleBar
                // The bar is drawn at y = 141 and the title's box ends at 109, so 32 of air —
                // and the stamp hangs 20 above the bar's own top edge, which is why the two are
                // one overlaid row rather than two stacked ones.
                Spacer(minLength: 32)
                progressRow
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 224 − 181: the heading's box starts 43 under the bar.
                        Spacer(minLength: 43)
                        Text(UIStrings.string(.checkpointDetailAllTasks, language))
                            .kultaraFont(.storySection)
                            .foregroundStyle(palette.inkCream.color)
                            .accessibilityAddTraits(.isHeader)
                        // 269 − 253.
                        Spacer(minLength: 16)
                        rows
                    }
                    .padding(.bottom, KultaraMetrics.xl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .padding(.horizontal, Self.margin)
            // Pinned rather than stacked after the frame's 224-point gap: `197:148` sits at a fixed
            // distance from the home indicator, so anchoring it there keeps it where it is drawn no
            // matter how many rows the list has or how far the words wrap.
            .safeAreaInset(edge: .bottom) { footer }
        }
    }

    /// `197:148`'s own exit — a caption over a full-width white pill — replaces `452:3194`'s single
    /// "Continue to Next Location" button.
    ///
    /// **It leaves directly, not by way of `.atCheckpoint`.** The frame draws one control, named for
    /// where it goes ("Next Place: …"), not a second stop at the dark museum screen this checkpoint
    /// used to hand over to first — which is also where "End this walk" lived. Nothing here was ever
    /// gating progression (`AD-2`), so a walker who has already resolved this checkpoint's tasks
    /// loses no requirement by leaving in one tap instead of two.
    @ViewBuilder private var footer: some View {
        VStack(spacing: 12) {
            // `197:148` sets the caption `#AEAEB2` over `#58453E` — none of the palette's own
            // "quiet" inks are measured against `brownStone`, so this follows `StampAwardScreen`'s
            // own precedent for muted text on the same ground: `inkOnButton` scaled down instead.
            Text(UIStrings.string(isFinal ? .runCompletedHeading : .checkpointDetailOrGoTo,
                                   language))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkOnButton.color.opacity(0.7))
                .multilineTextAlignment(.center)
            if isFinal {
                Button(UIStrings.string(.checkpointDetailFinishAction, language), action: onContinue)
                    .buttonStyle(.hisploraLightPill)
            } else {
                // `197:148`'s own mock names "Pura Pemecutan" — a place absent from the content
                // tree (`AD-4`) — so this reads the next checkpoint's real, resolved name instead.
                Button {
                    onContinue()
                } label: {
                    HStack(spacing: 8) {
                        Text(String(format: UIStrings.string(.checkpointDetailNextPlace, language),
                                    nextPlaceName ?? ""))
                            .lineLimit(1)
                        Image(systemName: "chevron.forward")
                    }
                }
                .buttonStyle(.hisploraLightPill)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Self.margin)
        .padding(.bottom, 30)
    }

    /// The back arrow with the place name centred over it, as every story frame draws it. The glyph
    /// is at `20, 82` and the title's box at `20, 80` — the same row, so the title is an overlay on
    /// the arrow's row rather than a second column that would push it off centre.
    private var titleBar: some View {
        HStack {
            HisploraBackButton(
                accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                size: 24,
                action: onBack)
            Spacer(minLength: 0)
        }
        .overlay {
            Text(placeName)
                .kultaraFont(.storyBarTitle)
                .foregroundStyle(palette.inkOnButton.color)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                // Room for the arrow on both sides, so a long place name truncates rather than
                // running under the control.
                .padding(.horizontal, KultaraMetrics.minimumTapTarget)
        }
        .padding(.top, 13)
    }

    /// The segmented bar with the stamp tilted over its right end.
    ///
    /// The stamp is an overlay, not the row's last element: `452:3142` draws it from y = 121 to 190
    /// while the bar runs 141 to 181, so it hangs past the bar on both edges — and a sibling inside
    /// the row cannot hang past its own row.
    private var progressRow: some View {
        HisploraSegmentedProgress(
            completed: answeredCount,
            total: tasks.count,
            accessibilityLabel: String(
                format: UIStrings.string(.checkpointDetailProgressLabel, language),
                answeredCount, tasks.count))
            // 356 of the 362-point column, as drawn — 3 in on each side.
            .padding(.horizontal, 3)
            .overlay(alignment: .trailing) {
                stamp
                    // `452:3142` stands 318.35…390.1 on a 402-point screen, so its right edge runs
                    // 8 points *past* the 382 the content column ends at.
                    .offset(x: 8, y: -14)
            }
    }

    private var stamp: some View {
        HisploraStamp(
            accessibilityLabel: UIStrings.string(.checkpointDetailStampLabel, language)
        ) {
            HisploraStampArtworkImage(name: stampArtworkName)
        }
        // 64 × 60.91 as drawn; the tilt is inside `HisploraStamp` and grows the drawn box, which is
        // why the frame's own 71.7 × 69.1 is the *rotated* bounds and not the stamp's size.
        .frame(width: 64)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(tasks) { task in
                row(task)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One row: the scroll, the type's name, a preview of the prompt, and the state glyph.
    ///
    /// The prompt is the row's subtitle rather than a title of its own, because the content has no
    /// title field — a task is a `type` and a `prompt`, and the frame's short imperative names are
    /// copy invented for the mock-up. It is cut to `TaskPromptPreview.wordLimit` words here and
    /// printed whole on `TaskDetailScreen`, which is the screen a row opens; the reasoning for the
    /// cut, and for its being counted in words, is on that type.
    private func row(_ task: ContentTask) -> some View {
        Button { onSelectTask(task) } label: {
            HStack(spacing: 4) {
                HStack(spacing: 12) {
                    HisploraScrollGlyph(size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(taskTypeLabel(task.type))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(palette.inkTicket.color)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(TaskPromptPreview.preview(of: taskPrompts[task.id] ?? ""))
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(palette.inkBody.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                stateGlyph(for: task)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.paperTicket.color,
                        in: RoundedRectangle(cornerRadius: KultaraMetrics.photoCardCornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: KultaraMetrics.photoCardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isResolved(task)
                            ? UIStrings.string(.checkpointDetailTaskDone, language)
                            : UIStrings.string(.checkpointDetailTaskOpen, language))
    }

    /// `checkmark.seal.fill` for an answered task, `chevron.forward` for one still open — and both
    /// are named in the row's accessibility value above, because a glyph difference is not a label
    /// (`NFR-A11Y-05`).
    private func stateGlyph(for task: ContentTask) -> some View {
        Image(systemName: isResolved(task) ? "checkmark.seal.fill" : "chevron.forward")
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(palette.brownDeep.color)
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
    }

    /// **A skipped task draws no checkmark and fills no segment**, as of 2026-08-26 — it reads as
    /// still open, because to the walker it is: they can come back and answer it, and the stamp it
    /// would move has not moved. The row is still a `TaskResult` in the walk's record, so nothing is
    /// lost and nothing is re-asked; what the tick claims is that the quest was *done*, and a skip
    /// is the one resolution that says it was not.
    ///
    /// This is the same rule `StampArtworkResolver` counts by, and the two have to keep agreeing:
    /// a row ticked green beside a stamp that did not move is the version of this that reads as a
    /// bug. `AD-2` is untouched — nothing here gates the walk, and `onContinue` leaves the
    /// checkpoint whatever these say.
    private func isResolved(_ task: ContentTask) -> Bool {
        resolutions[task.id].map { !$0.skipped } ?? false
    }

    private var answeredCount: Int { tasks.count { isResolved($0) } }

    private func taskTypeLabel(_ type: TaskType) -> String {
        switch type {
        case .reflection: UIStrings.string(.taskTypeReflection, language)
        case .photo: UIStrings.string(.taskTypePhoto, language)
        case .question: UIStrings.string(.taskTypeQuestion, language)
        }
    }
}
