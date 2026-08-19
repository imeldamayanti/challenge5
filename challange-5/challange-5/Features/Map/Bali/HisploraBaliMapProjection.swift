import ContentKit
import CoreGraphics
import Foundation

/// Mathematical coordinate projection engine for the entire island of Bali.
///
/// Maps geographic coordinates across Bali (114.40° E to 115.75° E, -8.90° S to -8.05° S)
/// to screen canvas points with high precision and metric aspect-ratio correction.
struct HisploraBaliMapProjection: Sendable, Equatable {

    let center: Coordinate
    let zoom: CGFloat
    let panOffset: CGSize
    let viewportSize: CGSize

    /// Base scale factor calibrated so the entire Bali archipelago (including Nusa Penida) fits standard screen sizes at zoom 1.0.
    static let baseScaleFactor: CGFloat = 265.0

    /// Latitude cosine factor at central Bali (~8.48° S) for metric distortion correction.
    static let latCosineCorrection: CGFloat = cos(CGFloat(-8.4800 * .pi / 180.0))

    init(
        center: Coordinate = HisploraBaliGeoData.islandCenter,
        zoom: CGFloat = 1.0,
        panOffset: CGSize = .zero,
        viewportSize: CGSize
    ) {
        self.center = center
        self.zoom = max(0.6, zoom)
        self.panOffset = panOffset
        self.viewportSize = viewportSize
    }

    /// Points per degree longitude at current zoom level.
    var pointsPerDegreeLon: CGFloat {
        // Dynamically adapts base scale to screen width so full island is visible on all device sizes
        let responsiveBase = max(viewportSize.width / 1.45, Self.baseScaleFactor)
        return responsiveBase * zoom
    }

    /// Points per degree latitude at current zoom level.
    var pointsPerDegreeLat: CGFloat {
        pointsPerDegreeLon * Self.latCosineCorrection
    }

    /// Projects a geographic `Coordinate` to screen canvas `CGPoint`.
    func project(_ coordinate: Coordinate) -> CGPoint {
        let deltaLon = CGFloat(coordinate.lon - center.lon)
        let deltaLat = CGFloat(coordinate.lat - center.lat)

        let x = (viewportSize.width / 2.0) + (deltaLon * pointsPerDegreeLon) + panOffset.width
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

    /// Converts real-world distance in meters to screen canvas points.
    func metersToPoints(_ meters: Double) -> CGFloat {
        let metersPerDegreeLon = 111320.0 * Double(Self.latCosineCorrection)
        let degrees = meters / metersPerDegreeLon
        return CGFloat(degrees) * pointsPerDegreeLon
    }

    /// Converts screen canvas points to real-world distance in meters.
    func pointsToMeters(_ points: CGFloat) -> Double {
        let degrees = Double(points / pointsPerDegreeLon)
        let metersPerDegreeLon = 111320.0 * Double(Self.latCosineCorrection)
        return degrees * metersPerDegreeLon
    }

    /// Clamps a pan offset so the island does not drift out of view.
    func clampedPan(_ proposedPan: CGSize) -> CGSize {
        let limitX = (pointsPerDegreeLon * 0.85)
        let limitY = (pointsPerDegreeLat * 0.70)

        return CGSize(
            width: min(max(proposedPan.width, -limitX), limitX),
            height: min(max(proposedPan.height, -limitY), limitY)
        )
    }
}
