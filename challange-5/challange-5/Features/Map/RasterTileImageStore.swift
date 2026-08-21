import RunEngine
import UIKit

/// Reads the region illustration's `gdal2tiles` pyramid off disk and keeps the decoded tiles
/// around.
///
/// Shared by both map surfaces on purpose: `RegionMapView` draws the pyramid into a `Canvas` and
/// `IllustratedMapOverlayRenderer` draws it into MapKit's context, and the two must agree about
/// which file covers which patch of the drawing or the wand would swap between two subtly
/// different maps.
///
/// `nonisolated` and thread-safe rather than `@MainActor`, because MapKit calls its renderer on a
/// drawing thread — the same reason `IllustratedMapOverlayRenderer` is nonisolated. `@unchecked`
/// because `NSCache` is not `Sendable` on paper while being thread-safe in fact; every stored
/// property here is a `let` and nothing else is shared.
nonisolated final class RasterTileImageStore: @unchecked Sendable {

    let pyramid: RasterTilePyramid

    private let root: URL
    private let cache = NSCache<NSString, UIImage>()

    /// Nil when the directory carries no `tiles.json`. The callers then draw the single PNG they
    /// drew before, which is a real fallback rather than an empty screen — content that has not
    /// been through `scripts/build-map-tiles.sh` is still content.
    init?(directory: URL) {
        let manifest = directory.appendingPathComponent("tiles.json")
        guard let data = try? Data(contentsOf: manifest),
              let pyramid = try? JSONDecoder().decode(RasterTilePyramid.self, from: data),
              pyramid.tileSize > 0, pyramid.maxZoom >= pyramid.minZoom
        else { return nil }

        self.root = directory
        self.pyramid = pyramid
        // A level of the shipped pyramid is thirty 256-pixel tiles, so the whole thing fits in a
        // few tens of megabytes decoded and the cap is really there for a re-tiled, larger
        // artwork. Counted in tiles rather than bytes because every tile costs the same.
        cache.countLimit = 128
    }

    /// The decoded tile, or nil when the file is missing — which happens legitimately at the
    /// grid's padded edge, where gdal2tiles writes nothing for a tile that would hold no picture.
    /// A caller that treats nil as an error would report a broken map every time the reader panned
    /// to a corner.
    func image(for tile: RasterTilePyramid.Tile) -> UIImage? {
        let key = tile.relativePath as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let url = root.appendingPathComponent(tile.relativePath)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        // Decoded here rather than at first draw. `UIImage(contentsOfFile:)` is lazy, so without
        // this the JPEG-sized work lands inside the render loop — on the main thread for the
        // `Canvas` and inside MapKit's tile pass for the overlay, which is precisely the stutter a
        // reader reads as the map fighting the pinch.
        let ready = image.preparingForDisplay() ?? image
        cache.setObject(ready, forKey: key)
        return ready
    }

    /// The level to draw when `drawnWidth` points of screen are about to be filled with the whole
    /// artwork, at `displayScale` pixels to the point.
    func zoom(forDrawnWidth drawnWidth: CGFloat, displayScale: CGFloat) -> Int {
        pyramid.zoom(forDrawnWidthPx: Double(drawnWidth * max(displayScale, 1)))
    }
}

extension RasterTilePyramid.Tile {

    /// The tile's place inside a rectangle the whole artwork has been drawn into.
    ///
    /// An extension in the app target rather than a method on the type: `RunEngine` is
    /// Foundation-only by the layering rule, and a `CGRect` on a value that also has to be
    /// testable under `swift test` is the sort of convenience that quietly makes the boundary
    /// unenforceable.
    /// `nonisolated` because the app target defaults to main-actor isolation and the overlay
    /// renderer calls this from MapKit's drawing thread.
    nonisolated func rect(in artwork: CGRect) -> CGRect {
        CGRect(
            x: artwork.minX + CGFloat(originX) * artwork.width,
            y: artwork.minY + CGFloat(originY) * artwork.height,
            width: CGFloat(width) * artwork.width,
            height: CGFloat(height) * artwork.height)
    }
}
