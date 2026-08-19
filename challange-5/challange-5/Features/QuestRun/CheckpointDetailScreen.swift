import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The checkpoint's task list — `452:3132` ("Quest 1/3"), which replaces the earlier `51:201`
/// ("Detail Quest") treatment this screen shipped with.
///
/// A list, not the tasks themselves: every row opens `TaskDetailScreen`, and the answer field, the
/// save and the skip stay where they already are on the checkpoint screen (`TaskCard`, `FR-TASK-02`).
/// This screen's job is narrower — name what is waiting, in the order it is waiting in, and say which
/// of it is done.
///
/// **The frame's three tasks do not exist.** `452:3149`, `452:3159` and `452:3169` name "The Iron
/// Statue", "The Ancient Script" and "The Whip Bearer"; nothing in the content tree carries any of
/// them, and the shipped checkpoints carry exactly one task each. So the rows are whatever `tasks`
/// the run actually has, titled by `TaskType` — and the progress bar draws one segment where the
/// frame draws three, because the bar is the run's state and not the mock-up's (`AD-4`,
/// `FR-RUN-06`).
///
/// **The stamp's picture is the quest's own hero image.** `452:3142` fills it with a generated sketch
/// of a temple gate; a picture presented as a particular place is a claim `FR-CP-05` wants a source
/// for, and the content tree ships one hero image with provenance behind it. Same decision, and same
/// reason, as `PlaceNoticeScreen`'s portrait.
struct CheckpointDetailScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let placeName: String
    let tasks: [ContentTask]
    let taskPrompts: [String: String]
    /// Nil for a task nobody has answered or skipped yet. Drives the trailing glyph and the bar.
    let resolutions: [String: TaskResult]
    /// The quest's hero image, for the stamp. Nil ships a plain cream stamp rather than an empty
    /// perforated hole.
    let stampImageURL: URL?
    let onSelectTask: (ContentTask) -> Void
    let onContinue: () -> Void
    let onBack: () -> Void

    /// `452:3132`'s own margins, in its own 402-point terms. 20 each side is what leaves the drawn
    /// 362-point content column.
    private static let margin: CGFloat = 20

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleBar
                    // The bar is drawn at y = 141 and the title's box ends at 109, so 32 of air —
                    // and the stamp hangs 20 above the bar's own top edge, which is why the two are
                    // one overlaid row rather than two stacked ones.
                    Spacer(minLength: 32)
                    progressRow
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
                .padding(.horizontal, Self.margin)
                .padding(.bottom, KultaraMetrics.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            // Pinned rather than stacked after the frame's 224-point gap: `452:3194` sits at a fixed
            // distance from the home indicator, so anchoring it there keeps it where it is drawn no
            // matter how many rows the list has or how far the words wrap.
            .safeAreaInset(edge: .bottom) {
                Button(UIStrings.string(.checkpointDetailContinueToNext, language),
                       action: onContinue)
                    .buttonStyle(.hisploraPlain(ink: \.inkOnButton))
                    .padding(.horizontal, Self.margin)
                    .padding(.bottom, 30)
            }
        }
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
            completed: resolutions.count,
            total: tasks.count,
            accessibilityLabel: String(
                format: UIStrings.string(.checkpointDetailProgressLabel, language),
                resolutions.count, tasks.count))
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
            if let stampImageURL, let image = BundledImage.load(stampImageURL) {
                image.resizable().scaledToFill()
            } else {
                Color.clear
            }
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

    /// One row: the scroll, the type's name, the prompt, and the state glyph.
    ///
    /// The prompt is the row's subtitle rather than a title of its own, because the content has no
    /// title field — a task is a `type` and a `prompt`, and the frame's short imperative names are
    /// copy invented for the mock-up.
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
                        Text(taskPrompts[task.id] ?? "")
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

    /// `checkmark.seal.fill` for a resolved task, `chevron.forward` for one still open — and both are
    /// named in the row's accessibility value above, because a glyph difference is not a label
    /// (`NFR-A11Y-05`).
    private func stateGlyph(for task: ContentTask) -> some View {
        Image(systemName: isResolved(task) ? "checkmark.seal.fill" : "chevron.forward")
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(palette.brownDeep.color)
            .frame(width: 32, height: 32)
            .accessibilityHidden(true)
    }

    private func isResolved(_ task: ContentTask) -> Bool { resolutions[task.id] != nil }

    private func taskTypeLabel(_ type: TaskType) -> String {
        switch type {
        case .reflection: UIStrings.string(.taskTypeReflection, language)
        case .photo: UIStrings.string(.taskTypePhoto, language)
        case .question: UIStrings.string(.taskTypeQuestion, language)
        }
    }
}
