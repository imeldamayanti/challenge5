import ContentKit
import MapKit
import RunEngine
import UIKit

/// `275:2309`'s chart, placed on the world so a live basemap can be drawn under it.
///
/// The rectangle comes from `IllustratedMapGeoreference`, which solves it from the same authored
/// `mapPoint`s the offline surface draws by. So the picture is not *positioned* by this class — it
/// is positioned by the content, and this only turns that into a `MKMapRect`.
///
/// The visible cost, which is deliberate and recorded in `docs/hisplora-tokens.md`: the artwork is
/// stretched about 1.25× vertically against true scale, so placing its features at their real
/// coordinates necessarily draws the picture at a different aspect ratio than the file's. Geography
/// is right and the drawing is squashed. Preserving the drawing's proportions instead puts the
/// coastline up to eleven kilometres out at the island's ends, which is the error a reader sees.
/// `nonisolated` for the same reason the renderer below is, and it is load-bearing rather than
/// tidy: the app target defaults to main-actor isolation, and VectorKit reads `boundingMapRect`
/// from its own tile queue. Left isolated, the first tile that needs the overlay trips
/// `dispatch_assert_queue` and the app dies on the way into the map. Everything here is a `let`
/// decided at init, so there is nothing for the annotation to make unsafe.
nonisolated final class IllustratedMapOverlay: NSObject, MKOverlay {

    /// The whole chart as one bitmap. Nil when a pyramid shipped: the renderer draws tiles then,
    /// and six megabytes of resident bitmap that nothing paints is not a fallback.
    let image: UIImage?
    /// The same drawing as a `gdal2tiles` pyramid, when content ships one. The renderer prefers it
    /// — at street zoom the whole-image draw was stretching a 1469-pixel picture across a rectangle
    /// hundreds of times its width, and a level of the pyramid at least stops that being the *only*
    /// thing available.
    let tiles: RasterTileImageStore?
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D

    init(image: UIImage?, tiles: RasterTileImageStore?, georeference: IllustratedMapGeoreference) {
        self.image = image
        self.tiles = tiles

        let northWest = MKMapPoint(CLLocationCoordinate2D(
            latitude: georeference.northWest.lat, longitude: georeference.northWest.lon))
        let southEast = MKMapPoint(CLLocationCoordinate2D(
            latitude: georeference.southEast.lat, longitude: georeference.southEast.lon))

        boundingMapRect = MKMapRect(
            x: min(northWest.x, southEast.x),
            y: min(northWest.y, southEast.y),
            width: abs(southEast.x - northWest.x),
            height: abs(southEast.y - northWest.y))

        coordinate = MKMapPoint(x: boundingMapRect.midX, y: boundingMapRect.midY).coordinate
    }
}

/// Draws the illustration into its rectangle.
///
/// MapKit hands the renderer a Core Graphics context whose y axis runs the opposite way from the
/// image's, so the flip below is not decoration — without it the island is drawn upside down. It is
/// done in Core Graphics rather than by `UIImage.draw(in:)` because this method is called off the
/// main thread.
/// `nonisolated` because MapKit calls `draw` on a drawing thread, and the app target
/// defaults to main-actor isolation — the override has to match the framework's.
nonisolated final class IllustratedMapOverlayRenderer: MKOverlayRenderer {

    /// Asked once per tile and cached, so `setNeedsDisplay()` is what makes a change of `alpha`
    /// take effect. Answering `false` at zero is the whole reason the overlay can stay added while
    /// the real map is the ground: MapKit stops asking for tiles rather than compositing a
    /// 1469 × 1071 drawing at zero opacity.
    override func canDraw(_ mapRect: MKMapRect, zoomScale: MKZoomScale) -> Bool {
        alpha > 0.01
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard alpha > 0.01, let overlay = overlay as? IllustratedMapOverlay else { return }

        let target = rect(for: overlay.boundingMapRect)
        guard target.width > 0, target.height > 0 else { return }

        context.saveGState()
        context.setAlpha(alpha)
        // The chart's edge is paper, not a hard crop, so interpolation matters at the seams and at
        // the deep zoom levels a walker in Denpasar will actually use.
        context.interpolationQuality = .high

        if let tiles = overlay.tiles {
            drawTiles(tiles, into: target, clippedTo: mapRect, in: context)
        } else if let cgImage = overlay.image?.cgImage {
            draw(cgImage, in: target, on: context)
        }
        context.restoreGState()
    }

    /// Draws one image the right way up.
    ///
    /// MapKit hands the renderer a context whose y axis runs the opposite way from the image's, so
    /// without this the island is upside down. The flip is a reflection about the rectangle's own
    /// centre, which leaves the rectangle where it is and turns only what is printed inside it —
    /// which is what lets every rectangle in this file be computed in the image's own top-left-down
    /// space and then drawn without further correction. It is Core Graphics rather than
    /// `UIImage.draw(in:)` because this runs off the main thread.
    private func draw(_ image: CGImage, in rect: CGRect, on context: CGContext) {
        context.saveGState()
        context.translateBy(x: 0, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -rect.minY)
        context.draw(image, in: rect)
        context.restoreGState()
    }

    /// Draws only the pyramid tiles that meet `mapRect`, at the level whose pixels match what this
    /// pass is about to fill.
    ///
    /// MapKit calls `draw` once per tile of *its* grid, so without the clip every pass would paint
    /// the whole island and throw away all but a 256-point square of it. The level is picked from
    /// the drawn width rather than from `zoomScale` directly, because `zoomScale` is points per map
    /// point and says nothing about how many pixels of artwork are being asked for.
    private func drawTiles(
        _ tiles: RasterTileImageStore,
        into target: CGRect,
        clippedTo mapRect: MKMapRect,
        in context: CGContext
    ) {
        let visible = rect(for: mapRect).intersection(target)
        guard !visible.isNull, !visible.isEmpty else { return }

        let zoom = tiles.pyramid.zoom(forDrawnWidthPx: Double(target.width))
        let region = RasterTilePyramid.NormalizedRect(
            minX: Double((visible.minX - target.minX) / target.width),
            minY: Double((visible.minY - target.minY) / target.height),
            maxX: Double((visible.maxX - target.minX) / target.width),
            maxY: Double((visible.maxY - target.minY) / target.height))

        // Half a device pixel of overlap. There is no pixel grid to round to here — the context is
        // MapKit's and its scale changes with the zoom — so neighbours are grown into each other
        // rather than snapped together. Without it the seams print as hairlines of basemap showing
        // through the chart.
        let bleed = 0.5 / max(contentScaleFactor, 1)

        for tile in tiles.pyramid.tiles(covering: region, atZoom: zoom) {
            guard let image = tiles.image(for: tile)?.cgImage else { continue }
            draw(image, in: tile.rect(in: target).insetBy(dx: -bleed, dy: -bleed), on: context)
        }
    }
}
