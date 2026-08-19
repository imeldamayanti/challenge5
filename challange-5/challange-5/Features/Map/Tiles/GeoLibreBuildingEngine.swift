import ContentKit
import CoreGraphics
import DesignSystem
import Foundation
import SwiftUI

// MARK: - GeoLibre Building Model (OpenMapTiles / Overture Schema Compatible)

public struct GeoLibreBuilding: Identifiable, Sendable, Equatable {
    public enum BuildingClass: String, Sendable, CaseIterable, Identifiable {
        case royalPalace = "palace"
        case templeShrine = "temple"
        case civic = "civic"
        case commercialShophouse = "commercial"
        case marketHall = "market"
        case residentialCompound = "residential"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .royalPalace: "Royal Palace (Puri)"
            case .templeShrine: "Temple / Shrine (Pura)"
            case .civic: "Heritage Civic Building"
            case .commercialShophouse: "Colonial Shophouse"
            case .marketHall: "Traditional Market Hall"
            case .residentialCompound: "Balinese Compound (Pekarangan)"
            }
        }

        public var iconName: String {
            switch self {
            case .royalPalace: "crown.fill"
            case .templeShrine: "sparkles"
            case .civic: "building.columns.fill"
            case .commercialShophouse: "storefront.fill"
            case .marketHall: "basket.fill"
            case .residentialCompound: "house.fill"
            }
        }
    }

    public enum RoofType: String, Sendable, Equatable {
        case balineseMeru = "meru"
        case limasan = "limasan"
        case pitched = "pitched"
        case shophouse = "shophouse"
        case flat = "flat"
    }

    public let id: String
    public let name: String
    public let `class`: BuildingClass
    public let coordinates: [Coordinate]
    public let heightM: Double
    public let levels: Int
    public let roofType: RoofType
    public let architecturalStyle: String
    public let historyNote: String?

    public init(
        id: String,
        name: String,
        class: BuildingClass,
        coordinates: [Coordinate],
        heightM: Double = 6.0,
        levels: Int = 1,
        roofType: RoofType = .limasan,
        architecturalStyle: String = "Traditional Balinese",
        historyNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.class = `class`
        self.coordinates = coordinates
        self.heightM = heightM
        self.levels = levels
        self.roofType = roofType
        self.architecturalStyle = architecturalStyle
        self.historyNote = historyNote
    }

    /// Center coordinate calculated from bounding vertices
    public var centerCoordinate: Coordinate {
        guard !coordinates.isEmpty else { return Coordinate(lat: 0, lon: 0) }
        let avgLat = coordinates.map(\.lat).reduce(0, +) / Double(coordinates.count)
        let avgLon = coordinates.map(\.lon).reduce(0, +) / Double(coordinates.count)
        return Coordinate(lat: avgLat, lon: avgLon)
    }
}

// MARK: - GeoLibre Map Customization Options

public struct GeoLibreBuildingOptions: Sendable, Equatable {
    public enum RenderMode: String, Sendable, CaseIterable, Identifiable {
        case isometric25D = "2.5D Extruded"
        case flat2D = "2D Footprints"

        public var id: String { rawValue }
    }

    public var isEnabled: Bool
    public var renderMode: RenderMode
    public var showBuildingLabels: Bool
    public var showParcels: Bool
    public var visibleClasses: Set<GeoLibreBuilding.BuildingClass>

    public init(
        isEnabled: Bool = true,
        renderMode: RenderMode = .isometric25D,
        showBuildingLabels: Bool = true,
        showParcels: Bool = true,
        visibleClasses: Set<GeoLibreBuilding.BuildingClass> = Set(GeoLibreBuilding.BuildingClass.allCases)
    ) {
        self.isEnabled = isEnabled
        self.renderMode = renderMode
        self.showBuildingLabels = showBuildingLabels
        self.showParcels = showParcels
        self.visibleClasses = visibleClasses
    }
}

// MARK: - GeoLibre 2.5D Extrusion Math & Geometry Engine

public enum GeoLibreBuildingMath {

    /// Extrusion angle vector (315° northwest light direction -> 2.5D isometric offset toward top-right)
    public static let isometricAngleRadians: Double = -0.785398 // -45 degrees
    public static let lightDirection = CGPoint(x: cos(isometricAngleRadians), y: sin(isometricAngleRadians))

    /// Calculates 2.5D extruded roof points from ground footprint points
    public static func computeRoofPoints(
        groundPoints: [CGPoint],
        heightPixels: CGFloat,
        scale: CGFloat = 1.0
    ) -> [CGPoint] {
        let offsetX = heightPixels * 0.55
        let offsetY = -heightPixels * 0.70

        // If scale is < 1.0 (for tiered roofs), shrink points towards the center
        let center = groundPoints.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let c = CGPoint(x: center.x / CGFloat(groundPoints.count), y: center.y / CGFloat(groundPoints.count))

        return groundPoints.map { pt in
            let scaledX = c.x + (pt.x - c.x) * scale
            let scaledY = c.y + (pt.y - c.y) * scale
            return CGPoint(x: scaledX + offsetX, y: scaledY + offsetY)
        }
    }

    /// Determines shade for a wall based on its normal relative to light direction
    public static func wallShadeFactor(p1: CGPoint, p2: CGPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let len = sqrt(dx*dx + dy*dy)
        guard len > 0 else { return 0.5 }
        
        let normal = CGPoint(x: -dy / len, y: dx / len)
        let dot = normal.x * lightDirection.x + normal.y * lightDirection.y
        
        // Map dot product [-1, 1] to a shade factor [0.2, 0.8]
        return 0.5 + (Double(dot) * 0.3)
    }

    /// Checks if a screen point is inside a polygon using ray casting algorithm
    public static func contains(point: CGPoint, in polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]

            if ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside.toggle()
            }
            j = i
        }

        return inside
    }
}
