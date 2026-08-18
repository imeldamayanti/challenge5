import CoreGraphics
import Foundation

/// Where a drawn illustration sits inside the window it is being explored through.
///
/// Two screens now show a bundled drawing larger than the space it is given and let the reader drag
/// it — the region map (`RegionMapView`) and a Place's site plan (`PlaceSiteMapScreen`, Figma
/// `452:2651`). Both need the same three answers, none of which is a judgement call:
///
/// - what size the artwork is drawn at before zoom, so it covers the window rather than
///   letterboxing into it,
/// - how far a pan may travel before an edge of the artwork would come inside the window, and
/// - where a normalised point on the artwork lands on screen once it has been scaled and offset.
///
/// They live here as pure geometry rather than inside a `View` because getting the third one wrong
/// puts a marker somewhere plausible and wrong, and a `GeometryProxy` is not something a test can
/// hold. `ArtworkViewportTests` holds all three.
public enum ArtworkViewport {

    /// The size the artwork is drawn at before zoom: scaled to *cover* `viewport`, never to fit
    /// inside it. Filling is what makes the drawing reach the window's edges on every device
    /// instead of floating in a band of ground colour whose height depends on the screen.
    ///
    /// `aspectRatio` is width ÷ height. A non-positive one would divide by zero or invert the
    /// drawing, so it is floored rather than trusted — content supplies it.
    public static func filledSize(aspectRatio: Double, in viewport: CGSize) -> CGSize {
        let ratio = max(aspectRatio, 0.05)
        let byWidth = CGSize(width: viewport.width, height: viewport.width / ratio)
        let byHeight = CGSize(width: viewport.height * ratio, height: viewport.height)
        return byWidth.height >= viewport.height ? byWidth : byHeight
    }

    /// How far the artwork may be offset from centre before one of its edges comes inside the
    /// window. Zero on an axis the artwork does not overflow — a drawing that exactly covers the
    /// window in one direction does not pan in that direction.
    public static func panLimit(content: CGSize, scale: CGFloat, in viewport: CGSize) -> CGSize {
        CGSize(width: max((content.width * scale - viewport.width) / 2, 0),
               height: max((content.height * scale - viewport.height) / 2, 0))
    }

    /// `proposed` brought back inside `panLimit`. Both the drawn offset and the stored one have to
    /// go through this: clamping only what is drawn lets repeated drags accumulate an offset far
    /// outside the artwork, and the next drag back spends its whole distance unwinding a number
    /// nothing on screen ever reflected.
    public static func clampedPan(
        _ proposed: CGSize,
        content: CGSize,
        scale: CGFloat,
        in viewport: CGSize
    ) -> CGSize {
        let limit = panLimit(content: content, scale: scale, in: viewport)
        return CGSize(width: min(max(proposed.width, -limit.width), limit.width),
                      height: min(max(proposed.height, -limit.height), limit.height))
    }

    /// The pan that shows the artwork's leading edge — its top-left corner against the window's.
    ///
    /// `452:2651` crops the plan on the right, not evenly on both sides: the drawing's left edge is
    /// flush with the window and the reader drags to reach the rest. Positive offset moves content
    /// right and down, so that is the limit itself rather than its negation.
    public static func leadingPan(content: CGSize, scale: CGFloat, in viewport: CGSize) -> CGSize {
        panLimit(content: content, scale: scale, in: viewport)
    }

    /// Where a normalised point on the artwork lands in the window, having gone through the same
    /// centre-anchored scale and offset the artwork does.
    ///
    /// This exists so a marker can be drawn *outside* the `scaleEffect` and still sit exactly on
    /// the thing it marks. Inside it, a 4× zoom would draw an 8-point dot at 32 points — the marker
    /// would grow with the drawing it is pointing at, which is the one thing it must not do.
    public static func position(
        of point: CGPoint,
        drawnAt content: CGSize,
        in viewport: CGSize,
        scale: CGFloat,
        offset: CGSize
    ) -> CGPoint {
        CGPoint(
            x: viewport.width / 2 + (content.width * point.x - content.width / 2) * scale + offset.width,
            y: viewport.height / 2 + (content.height * point.y - content.height / 2) * scale + offset.height)
    }
}
