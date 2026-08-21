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

    /// `447:1903` sits at y = 114 under a title box ending at 108.
    static let titleToProgress: CGFloat = 6

    /// The determinate bar the frame draws 4 points tall, in a row padded 20 above and below.
    static let progressBarHeight: CGFloat = 4
    static let progressBarPadding: CGFloat = 14

    /// The sheet is drawn at y = 190, 62 under the bar's box. Held at 44 rather than the frame's 62:
    /// the frame draws a photo task, whose sheet is one pill deep, and a written task's field, save
    /// and skip need those points back or the sheet runs past the foot of the screen with the map
    /// hint printed across its lower roll.
    static let sheetTop: CGFloat = 44

    /// How far the sheet's head roll stands below the top of the safe area — the number the
    /// transition screen has to land its unrolled parchment on.
    static var sheetTopInset: CGFloat {
        titleBarTop + titleBarHeight + titleToProgress
            + progressBarHeight + progressBarPadding * 2 + sheetTop
    }

    /// How far the sheet's foot roll hangs *below* the bottom of the safe area.
    ///
    /// **This one is a typical case, not a measurement, and the difference is worth stating.** The
    /// sheet is content-sized — it has to be, so the words can grow (`NFR-A11Y-01`) — and it lives in
    /// a `ScrollView`, so it runs on under the bottom safe-area inset instead of stopping at it. On
    /// the shipped tasks at the default text size its foot lands about this far past that edge, and
    /// that is what the transition's parchment is drawn to. A much shorter task would leave the
    /// crossfade shortening the page a little; a longer one scrolls, and its visible foot is the
    /// screen's edge again. The head roll, which is the edge the eye actually tracks, is exact either
    /// way.
    static let sheetFootOvershoot: CGFloat = 33

    /// The box the sheet occupies inside a stage `height` points tall, measured from the top of the
    /// safe area — which is where a `GeometryReader` inside `HisploraStage` measures from too.
    static func sheetBox(inStageOfHeight height: CGFloat) -> (top: CGFloat, height: CGFloat) {
        let top = sheetTopInset
        return (top, max(0, height - top + sheetFootOvershoot))
    }
}
