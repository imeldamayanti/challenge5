import ContentKit
import Foundation

/// Where the region illustration sits on the real world, so a real basemap can be drawn under it.
///
/// `MapPoint` is authored against the drawing and stays that way (`ContentKit.MapPoint`). This type
/// does not replace that rule — it reads the same authored points the other way round, to answer a
/// question the drawing alone cannot: *which patch of Bali is this picture of?* The discovery map
/// needs the answer because it now stands the illustration over a live basemap, and a live basemap
/// has an opinion about where things are.
///
/// The fit is deliberately **not** a regression over the anchors. The two rates are read off
/// `docs/hisplora-tokens.md` — 960 px per degree of longitude, 1206 per degree of latitude, measured
/// from three features on the artwork at known real coordinates — and only the *origin* is solved
/// here. Every shipped Place but one sits inside Denpasar, so a two-variable fit over that cluster
/// would be numerically unstable and would move every time an author nudged a pin. Fixed rates plus
/// a mean offset is stable with a single anchor and stays true to the measurement that was actually
/// made.
///
/// The consequence, stated plainly: the drawing is stretched about 1.25× vertically against true
/// scale, so a placement that puts drawn features at their real coordinates necessarily draws the
/// picture at a different aspect ratio than the file's. Geography is correct and the art is
/// squashed. The alternative — preserving the artwork's proportions — puts the coastline up to
/// eleven kilometres out at the island's ends, which is the error that shows.
public struct IllustratedMapGeoreference: Sendable, Equatable {

    /// One authored point and the real place it stands for.
    public struct Anchor: Sendable, Equatable {
        public let point: MapPoint
        public let coordinate: Coordinate

        public init(point: MapPoint, coordinate: Coordinate) {
            self.point = point
            self.coordinate = coordinate
        }
    }

    /// `275:2309`'s chart, at the pixel size the shipped asset is.
    public static let baliIllustratedWidthPx: Double = 1469
    public static let baliIllustratedHeightPx: Double = 1071
    /// `docs/hisplora-tokens.md` — measured off the artwork, not derived from a projection.
    public static let baliIllustratedPixelsPerDegreeLon: Double = 960
    public static let baliIllustratedPixelsPerDegreeLat: Double = 1206

    public let imageWidthPx: Double
    public let imageHeightPx: Double
    public let pixelsPerDegreeLon: Double
    public let pixelsPerDegreeLat: Double
    /// Longitude at the image's left edge, latitude at its top edge.
    public let originLon: Double
    public let originLat: Double

    public init(
        imageWidthPx: Double,
        imageHeightPx: Double,
        pixelsPerDegreeLon: Double,
        pixelsPerDegreeLat: Double,
        originLon: Double,
        originLat: Double
    ) {
        self.imageWidthPx = imageWidthPx
        self.imageHeightPx = imageHeightPx
        self.pixelsPerDegreeLon = pixelsPerDegreeLon
        self.pixelsPerDegreeLat = pixelsPerDegreeLat
        self.originLon = originLon
        self.originLat = originLat
    }

    /// Solves the origin from one or more anchors, at the artwork's own measured rates.
    ///
    /// Nil for an empty anchor set rather than a guessed origin: an illustration placed at an
    /// invented latitude is a map that lies, and the caller can honestly draw no overlay at all.
    public static func fittedToBaliIllustration(anchors: [Anchor]) -> IllustratedMapGeoreference? {
        fitted(
            imageWidthPx: baliIllustratedWidthPx,
            imageHeightPx: baliIllustratedHeightPx,
            pixelsPerDegreeLon: baliIllustratedPixelsPerDegreeLon,
            pixelsPerDegreeLat: baliIllustratedPixelsPerDegreeLat,
            anchors: anchors)
    }

    public static func fitted(
        imageWidthPx: Double,
        imageHeightPx: Double,
        pixelsPerDegreeLon: Double,
        pixelsPerDegreeLat: Double,
        anchors: [Anchor]
    ) -> IllustratedMapGeoreference? {
        guard !anchors.isEmpty,
              imageWidthPx > 0, imageHeightPx > 0,
              pixelsPerDegreeLon > 0, pixelsPerDegreeLat > 0
        else { return nil }

        var lonSum = 0.0
        var latSum = 0.0
        for anchor in anchors {
            // lon = originLon + x_px / pxPerDegLon  →  originLon = lon − x_px / pxPerDegLon
            lonSum += anchor.coordinate.lon - (anchor.point.x * imageWidthPx) / pixelsPerDegreeLon
            // Latitude decreases down the image.
            latSum += anchor.coordinate.lat + (anchor.point.y * imageHeightPx) / pixelsPerDegreeLat
        }

        let count = Double(anchors.count)
        return IllustratedMapGeoreference(
            imageWidthPx: imageWidthPx,
            imageHeightPx: imageHeightPx,
            pixelsPerDegreeLon: pixelsPerDegreeLon,
            pixelsPerDegreeLat: pixelsPerDegreeLat,
            originLon: lonSum / count,
            originLat: latSum / count)
    }

    public var lonSpanDegrees: Double { imageWidthPx / pixelsPerDegreeLon }
    public var latSpanDegrees: Double { imageHeightPx / pixelsPerDegreeLat }

    /// The image's top-left corner in the world.
    public var northWest: Coordinate { Coordinate(lat: originLat, lon: originLon) }
    /// The image's bottom-right corner in the world.
    public var southEast: Coordinate {
        Coordinate(lat: originLat - latSpanDegrees, lon: originLon + lonSpanDegrees)
    }

    public func coordinate(at point: MapPoint) -> Coordinate {
        Coordinate(
            lat: originLat - (point.y * imageHeightPx) / pixelsPerDegreeLat,
            lon: originLon + (point.x * imageWidthPx) / pixelsPerDegreeLon)
    }

    /// The inverse. Outside 0…1 when the coordinate falls off the drawing, which the caller is
    /// expected to check rather than have clamped for it — clamping would pin an off-map place to
    /// the edge of the paper and look deliberate.
    public func point(for coordinate: Coordinate) -> MapPoint {
        MapPoint(
            x: ((coordinate.lon - originLon) * pixelsPerDegreeLon) / imageWidthPx,
            y: ((originLat - coordinate.lat) * pixelsPerDegreeLat) / imageHeightPx)
    }

    /// How far the fit puts an anchor from where it actually is, in metres. The residual is the
    /// honest measure of this placement and is what its test asserts on.
    public func residualMetres(for anchor: Anchor) -> Double {
        Geo.distanceM(coordinate(at: anchor.point), anchor.coordinate)
    }
}
