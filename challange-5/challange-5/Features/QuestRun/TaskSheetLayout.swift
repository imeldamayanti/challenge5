import CoreGraphics
import DesignSystem

/// Where the task sheet stands on `1:4711`, as numbers two screens share.
///
/// **It exists because of a seam, not because of tidiness.** The transition unrolls a parchment and
/// then hands over to `TaskDetailScreen`, which draws the same parchment — so if the two disagree
/// about where the sheet's head roll sits, the page visibly jumps at the moment the walker crosses
/// between them. Both screens now measure from here, and `TaskDetailScreen` pins the two chrome rows
/// this adds up (`titleBarHeight`, and the bar's own 4 points inside `progressBarPadding`) rather
/// than letting them size themselves, so the arithmetic below is true by construction instead of by
/// coincidence.
enum TaskSheetLayout {

    /// The content column, 20 each side, which leaves the frame's 362 on a 402-point screen.
    static let margin: CGFloat = 20

    /// `447:1884`'s title row: 13 above it, and a row as tall as the back arrow's tap target
    /// (`NFR-A11Y-06`), which is what makes it 44 rather than the 40-point hero circle beside it.
    static let titleBarTop: CGFloat = 13
    static let titleBarHeight: CGFloat = KultaraMetrics.minimumTapTarget

    /// The gap between the title row and the sheet.
    ///
    /// **`447:1903`'s determinate progress bar used to stand here and has been removed by request.**
    /// It was the frame's own object and it counted the run's real tasks rather than the frame's
    /// invented three — but the shipped checkpoints carry one task each, so it drew a bar that was
    /// either empty or full and never anything else. Its old row (6 above, a 4-point bar, 14 each
    /// side of it) is folded into this one number, so the sheet keeps standing where the frame draws
    /// it instead of jumping 32 points up the screen when the bar went.
    ///
    /// **Tightened by request** — with the bar gone the folded row was holding open a gap for an
    /// object that is no longer drawn, and the sheet read as floating away from the title. Its
    /// three terms are kept rather than collapsed into one literal, so what the number is made of
    /// is still legible.
    static let titleToSheet: CGFloat = 6 + 4 + 10

    /// `1:4711` draws the sheet at y = 190, 62 under the bar's box. It was held at 44 rather than
    /// that 62 — the frame draws a photo task, whose sheet is one pill deep, and a written task's
    /// field, save and skip need those points back or the sheet runs past the foot of the screen
    /// with the map hint printed across its lower roll — and is 20 now, by request: the head roll
    /// stood too far under the title bar, which read as the parchment floating free of the screen
    /// it belongs to.
    static let sheetTop: CGFloat = 20

    /// How far the sheet's head roll stands below the top of the safe area — the number the
    /// transition screen has to land its unrolled parchment on.
    static var sheetTopInset: CGFloat {
        titleBarTop + titleBarHeight + titleToSheet + sheetTop
    }

    /// How tall the sheet stands when nothing has measured the real one yet.
    ///
    /// **This replaced an arithmetic that was wrong by two hundred points.** The sheet used to be
    /// drawn as "everything left on the screen, plus 33" on the theory that a content-sized sheet
    /// inside a `ScrollView` runs on past the bottom safe-area inset. It does not: on the shipped
    /// written tasks at the default text size the foot roll settles about 127 points *above* the
    /// bottom of the screen, so the transition unrolled a parchment 219 points longer than the one
    /// it then cross-faded into and the foot roll jumped up the screen at the hand-over. Measured on
    /// iPhone 17 Pro / iOS 26.5: head roll at 199, foot roll ending at 747, on an 874-point stage.
    ///
    /// It is an absolute rather than a fraction of the screen *because* the sheet is content-sized —
    /// the same task on a shorter phone draws the same words at the same size and stands the same
    /// height, and it is the screen underneath that has less room.
    ///
    /// A fallback, not a constant: `TaskDetailScreen` measures the real sheet and reports it, and
    /// from the second checkpoint on the transition unrolls to the height the destination will
    /// actually be. This is what the *first* one uses, and what a photo task — a sheet one pill deep
    /// — is still approximated by.
    static let estimatedSheetHeight: CGFloat = 549

    /// The box the sheet occupies inside a stage `height` points tall, measured from the top of the
    /// safe area — which is where a `GeometryReader` inside `HisploraStage` measures from too.
    ///
    /// - Parameter measuredHeight: the height `TaskDetailScreen` last reported for the sheet this
    ///   transition is opening into, when there is one.
    static func sheetBox(inStageOfHeight height: CGFloat,
                         measuredHeight: CGFloat? = nil) -> (top: CGFloat, height: CGFloat) {
        let top = sheetTopInset
        let sheet = measuredHeight ?? estimatedSheetHeight
        // Never longer than the room below the header — a measurement taken at an accessibility text
        // size can exceed the screen, and the transition has no scroll view to run on into.
        return (top, max(0, min(sheet, height - top)))
    }
}
