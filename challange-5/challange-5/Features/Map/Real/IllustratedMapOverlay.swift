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

    let image: UIImage
    let boundingMapRect: MKMapRect
    let coordinate: CLLocationCoordinate2D

    init(image: UIImage, georeference: IllustratedMapGeoreference) {
        self.image = image

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

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let overlay = overlay as? IllustratedMapOverlay,
              let cgImage = overlay.image.cgImage
        else { return }

        let target = rect(for: overlay.boundingMapRect)

        context.saveGState()
        context.translateBy(x: 0, y: target.maxY)
        context.scaleBy(x: 1, y: -1)
        context.translateBy(x: 0, y: -target.minY)
        context.setAlpha(alpha)
        // The chart's edge is paper, not a hard crop, so interpolation matters at the seams and at
        // the deep zoom levels a walker in Denpasar will actually use.
        context.interpolationQuality = .high
        context.draw(cgImage, in: target)
        context.restoreGState()
    }
}
