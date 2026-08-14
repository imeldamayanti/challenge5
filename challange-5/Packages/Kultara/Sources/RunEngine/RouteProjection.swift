import ContentKit
import Foundation

/// A point in the drawing's own coordinates. Deliberately not `CGPoint`: `RunEngine` is Foundation
/// and `ContentKit`, and the view converts.
public struct ProjectedPoint: Sendable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Maps real coordinates onto a drawn canvas for the run route map (`FR-MAP-02`).
///
/// An equirectangular projection scaled to the bounding box of what is drawn. Over a few hundred
/// metres it is accurate to well under a pixel, and — unlike `Place.mapPoint`, which is authored
/// against a stylised illustration — there is no artwork here for it to disagree with. `mapPoint`
/// is not usable for this: it means nothing at street scale.
///
/// Pure arithmetic with no view type in it, so the thing that can be wrong is testable without a
/// simulator.
public struct RouteProjection: Sendable, Equatable {

    /// Metres per degree of latitude, from the same earth radius `Geo.distanceM` uses — so the
    /// distance the map draws and the distance the status card prints cannot disagree.
    static let metresPerDegreeLatitude = Geo.earthRadiusM * .pi / 180

    private let originLon: Double
    private let originLat: Double
    private let lonScale: Double
    /// Drawn units per degree of latitude.
    private let scale: Double
    private let offsetX: Double
    private let offsetY: Double
    private let height: Double

    /// Fails when every coordinate is the same place — there is no box to fit, and a map of one
    /// point at an arbitrary zoom is a lie about scale. The caller draws nothing instead.
    public init?(coordinates: [Coordinate], width: Double, height: Double, padding: Double = 0) {
        guard !coordinates.isEmpty, width > 0, height > 0 else { return nil }

        let lats = coordinates.map(\.lat)
        let lons = coordinates.map(\.lon)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!

        // Longitude degrees shrink towards the poles. Taken at the middle of the box, which over a
        // walk of a few hundred metres is the whole box.
        let midLat = (minLat + maxLat) / 2
        lonScale = cos(midLat * .pi / 180)

        let spanX = (maxLon - minLon) * lonScale
        let spanY = maxLat - minLat
        guard spanX > 0 || spanY > 0 else { return nil }

        let availableWidth = max(width - 2 * padding, 1)
        let availableHeight = max(height - 2 * padding, 1)

        // A degenerate span in one axis must not decide the scale, or a straight north-south route
        // is drawn at infinite zoom.
        let byWidth = spanX > 0 ? availableWidth / spanX : Double.infinity
        let byHeight = spanY > 0 ? availableHeight / spanY : Double.infinity
        scale = min(byWidth, byHeight)

        originLon = minLon
        originLat = minLat
        // Centred in whatever room the fit left over.
        offsetX = padding + (availableWidth - spanX * scale) / 2
        offsetY = padding + (availableHeight - spanY * scale) / 2
        self.height = height
    }

    /// North is up: latitude increases as `y` decreases, because the canvas's origin is top-left.
    public func project(_ coordinate: Coordinate) -> ProjectedPoint {
        let x = offsetX + (coordinate.lon - originLon) * lonScale * scale
        let y = height - (offsetY + (coordinate.lat - originLat) * scale)
        return ProjectedPoint(x: x, y: y)
    }

    /// How many metres one drawn unit is worth. The arrival radius is a real distance, so the
    /// circle for it is drawn at true scale rather than at a size that looks about right.
    public var metresPerUnit: Double {
        Self.metresPerDegreeLatitude / scale
    }

    /// The inverse, for drawing a distance as a length.
    public func units(forMetres metres: Double) -> Double {
        metres / metresPerUnit
    }
}
