import ContentKit
import CoreGraphics
import Foundation

/// Mathematical coordinate projection engine converting real-world geographic coordinates
/// (Latitude / Longitude) into 2D canvas pixel coordinates and vice versa.
///
/// Implements spherical Mercator projection tuned for local walking scale in Bali (~8.6° S),
/// accounting for latitude aspect ratio distortion (cos(lat)) so distances remain uniform in X and Y.
struct HisploraMapProjection: Sendable, Equatable {

    let center: Coordinate
    let zoom: CGFloat
    let panOffset: CGSize
    let viewportSize: CGSize

    /// Reference base scale: points per degree longitude at zoom level 1.0.
    /// Derived so that the Denpasar historic district (~0.0185° lon, ~0.0150° lat) nicely fills an iPhone screen.
    static let basePointsPerDegreeLon: CGFloat = 20000.0

    /// Latitude of Denpasar (~ -8.65° S) cosine factor for metric distortion correction.
    static let latCosineCorrection: CGFloat = cos(CGFloat(-8.6565 * .pi / 180.0))

    init(
        center: Coordinate = HisploraDenpasarDistrict.centerCoordinate,
        zoom: CGFloat = 1.0,
        panOffset: CGSize = .zero,
        viewportSize: CGSize
    ) {
        self.center = center
        self.zoom = max(0.5, zoom)
        self.panOffset = panOffset
        self.viewportSize = viewportSize
    }

    /// Current points per degree of longitude at active zoom.
    var pointsPerDegreeLon: CGFloat {
        Self.basePointsPerDegreeLon * zoom
    }

    /// Current points per degree of latitude at active zoom.
    var pointsPerDegreeLat: CGFloat {
        Self.basePointsPerDegreeLon * zoom * Self.latCosineCorrection
    }

    /// Converts a geographic `Coordinate` to screen canvas `CGPoint`.
    func project(_ coordinate: Coordinate) -> CGPoint {
        let deltaLon = CGFloat(coordinate.lon - center.lon)
        let deltaLat = CGFloat(coordinate.lat - center.lat)

        let x = (viewportSize.width / 2.0) + (deltaLon * pointsPerDegreeLon) + panOffset.width
        // In screen space, positive Y goes downward, while in geography higher latitude is north (upward).
        let y = (viewportSize.height / 2.0) - (deltaLat * pointsPerDegreeLat) + panOffset.height

        return CGPoint(x: x, y: y)
    }

    /// Converts a screen canvas `CGPoint` back to a geographic `Coordinate`.
    func unproject(_ point: CGPoint) -> Coordinate {
        let deltaX = point.x - (viewportSize.width / 2.0) - panOffset.width
        let deltaY = (viewportSize.height / 2.0) - (point.y - panOffset.height)

        let lon = Double(deltaX / pointsPerDegreeLon) + center.lon
        let lat = Double(deltaY / pointsPerDegreeLat) + center.lat

        return Coordinate(lat: lat, lon: lon)
    }

    /// Converts real-world distance in meters to screen canvas points at active zoom.
    func metersToPoints(_ meters: Double) -> CGFloat {
        // At equator, 1 degree lon ≈ 111,320 meters. At 8.65° S, 1 deg lon ≈ 111,320 * cos(8.65°) ≈ 110,050 m.
        let metersPerDegreeLon = 111320.0 * Double(Self.latCosineCorrection)
        let degrees = meters / metersPerDegreeLon
        return CGFloat(degrees) * pointsPerDegreeLon
    }

    /// Converts screen canvas points to distance in meters at active zoom.
    func pointsToMeters(_ points: CGFloat) -> Double {
        let degrees = Double(points / pointsPerDegreeLon)
        let metersPerDegreeLon = 111320.0 * Double(Self.latCosineCorrection)
        return degrees * metersPerDegreeLon
    }

    /// Returns the visible geographic bounding box currently displayed in the viewport.
    var visibleBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let topLeft = unproject(CGPoint(x: 0, y: 0))
        let bottomRight = unproject(CGPoint(x: viewportSize.width, y: viewportSize.height))

        return (
            minLat: min(topLeft.lat, bottomRight.lat),
            maxLat: max(topLeft.lat, bottomRight.lat),
            minLon: min(topLeft.lon, bottomRight.lon),
            maxLon: max(topLeft.lon, bottomRight.lon)
        )
    }

    /// Clamps a pan offset so the user cannot pan completely away from the heritage district.
    func clampedPan(_ proposedPan: CGSize) -> CGSize {
        let limitX = (pointsPerDegreeLon * 0.025) // ~2.5km boundary
        let limitY = (pointsPerDegreeLat * 0.025)

        return CGSize(
            width: min(max(proposedPan.width, -limitX), limitX),
            height: min(max(proposedPan.height, -limitY), limitY)
        )
    }
}
