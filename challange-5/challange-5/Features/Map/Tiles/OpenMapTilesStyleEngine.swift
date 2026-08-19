import ContentKit
import DesignSystem
import SwiftUI

// MARK: - OpenMapTiles Style Directives

struct OMTRoadStyleDirective: Sendable, Equatable {
    let casingColor: Color
    let casingWidth: CGFloat
    let fillColor: Color
    let fillWidth: CGFloat
    let strokeStyle: StrokeStyle?
}

struct OMTPolygonStyleDirective: Sendable, Equatable {
    let fillColor: Color
    let strokeColor: Color
    let strokeWidth: CGFloat
    let strokeStyle: StrokeStyle?
}

// MARK: - OpenMapTiles Style Engine

enum OpenMapTilesStyleEngine {

    // MARK: - Transportation Road Styling

    static func style(for roadClass: OMTTransportationFeature.TransportationClass) -> OMTRoadStyleDirective {
        switch roadClass {
        case .motorway, .trunk, .primary:
            return OMTRoadStyleDirective(
                casingColor: HisploraMapStyle.roadCasing.color,
                casingWidth: HisploraMapStyle.roadMajorCasingWidth,
                fillColor: HisploraMapStyle.roadFill.color,
                fillWidth: HisploraMapStyle.roadMajorFillWidth,
                strokeStyle: nil
            )
        case .secondary:
            return OMTRoadStyleDirective(
                casingColor: HisploraMapStyle.roadCasing.color,
                casingWidth: HisploraMapStyle.roadSecondaryCasingWidth,
                fillColor: HisploraMapStyle.roadFill.color,
                fillWidth: HisploraMapStyle.roadSecondaryFillWidth,
                strokeStyle: nil
            )
        case .tertiary, .minor, .service:
            return OMTRoadStyleDirective(
                casingColor: HisploraMapStyle.roadCasingMinor.color,
                casingWidth: HisploraMapStyle.roadMinorCasingWidth,
                fillColor: HisploraMapStyle.roadFillMinor.color,
                fillWidth: HisploraMapStyle.roadMinorFillWidth,
                strokeStyle: nil
            )
        case .alley:
            return OMTRoadStyleDirective(
                casingColor: HisploraMapStyle.roadCasingMinor.color.opacity(0.8),
                casingWidth: 1.2,
                fillColor: HisploraMapStyle.roadFillMinor.color,
                fillWidth: 0.8,
                strokeStyle: nil
            )
        case .path, .pedestrian, .track:
            return OMTRoadStyleDirective(
                casingColor: HisploraMapStyle.routeInk.color,
                casingWidth: 2.4,
                fillColor: .clear,
                fillWidth: 0,
                strokeStyle: HisploraMapStyle.routeStrokeStyle
            )
        }
    }

    // MARK: - Water Feature Styling

    static func style(for waterClass: OMTWaterFeature.WaterClass) -> OMTPolygonStyleDirective {
        switch waterClass {
        case .ocean, .sea:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.parchmentGround.color,
                strokeColor: HisploraMapStyle.roadCasing.color,
                strokeWidth: 1.6,
                strokeStyle: nil
            )
        case .lake, .reservoir, .river, .swimmingPool:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.riverFill.color,
                strokeColor: HisploraMapStyle.riverCasing.color,
                strokeWidth: 1.1,
                strokeStyle: nil
            )
        }
    }

    // MARK: - Landcover Styling

    static func style(for landcoverClass: OMTLandcoverFeature.LandcoverClass) -> OMTPolygonStyleDirective {
        switch landcoverClass {
        case .wood:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.parkWash.color.opacity(0.35),
                strokeColor: .clear,
                strokeWidth: 0,
                strokeStyle: nil
            )
        case .scrub, .grass, .farmland, .crop:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.parkWash.color.opacity(0.20),
                strokeColor: .clear,
                strokeWidth: 0,
                strokeStyle: nil
            )
        case .sand:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.parchmentSunken.color.opacity(0.6),
                strokeColor: .clear,
                strokeWidth: 0,
                strokeStyle: nil
            )
        case .wetland, .rock:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.parchmentBorder.color.opacity(0.4),
                strokeColor: .clear,
                strokeWidth: 0,
                strokeStyle: nil
            )
        }
    }

    // MARK: - Park Styling

    static func style(for parkClass: OMTParkFeature.ParkClass) -> OMTPolygonStyleDirective {
        switch parkClass {
        case .nationalPark, .natureReserve, .protectedArea:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.parkWash.color.opacity(0.38),
                strokeColor: HisploraMapStyle.parkBorder.color,
                strokeWidth: 1.2,
                strokeStyle: nil
            )
        case .cityPark:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.parkWash.color.opacity(0.50),
                strokeColor: HisploraMapStyle.parkBorder.color,
                strokeWidth: 1.0,
                strokeStyle: nil
            )
        }
    }

    // MARK: - Building / Compound Styling

    static func style(for buildingClass: OMTBuildingFeature.BuildingClass) -> OMTPolygonStyleDirective {
        switch buildingClass {
        case .royalPalace, .templeCompound:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.compoundWash.color,
                strokeColor: HisploraMapStyle.compoundBorder.color,
                strokeWidth: 1.2,
                strokeStyle: nil
            )
        case .residential, .commercial, .market, .religious:
            return OMTPolygonStyleDirective(
                fillColor: HisploraMapStyle.parchmentWarm.color,
                strokeColor: HisploraMapStyle.parcelLine.color,
                strokeWidth: 0.8,
                strokeStyle: nil
            )
        case .parcel:
            return OMTPolygonStyleDirective(
                fillColor: .clear,
                strokeColor: HisploraMapStyle.parcelLine.color,
                strokeWidth: 0.6,
                strokeStyle: HisploraMapStyle.parcelStrokeStyle
            )
        }
    }
}
