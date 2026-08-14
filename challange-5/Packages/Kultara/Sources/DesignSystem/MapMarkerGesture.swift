import CoreGraphics
import Foundation

/// When a touch on a map marker counts as a selection.
///
/// The region map is a full-bleed illustration the reader pinches and drags, with markers drawn on
/// top of it. A marker rendered as a plain `Button` claims any touch that starts inside it and fires
/// on release — so the lift at the end of a pinch, or a drag that began over a pin, navigates away
/// from the map instead of moving it. Both rules below exist to stop that, and both are numbers
/// rather than judgement calls so a test can hold them.
public enum MapMarkerGesture {

    /// How far a touch may travel and still be read as a tap. Ten points is under the system's own
    /// drag slop, so a finger that meant to pan has already exceeded it by the time it lifts.
    public static let tapTravelLimit: CGFloat = 10

    /// How long after a pan or a pinch ends before markers accept touches again. The second finger
    /// of a pinch lifts a few milliseconds after the first, and without this window that lift lands
    /// on whatever marker it happens to be over.
    public static let settleDelay: Duration = .milliseconds(150)

    /// Whether a touch that moved by `translation` should select the marker it ended on.
    public static func isTap(translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) < tapTravelLimit
    }
}
