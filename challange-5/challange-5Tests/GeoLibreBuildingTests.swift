import ContentKit
import CoreGraphics
import Foundation
import Testing
@testable import challange_5

@Suite("GeoLibre Building & Extrusion Engine Tests")
struct GeoLibreBuildingTests {

    @Test("All Denpasar heritage buildings are defined with valid coordinates and heights")
    func testDenpasarBuildingsValid() {
        let buildings = HisploraDenpasarDistrict.buildings
        #expect(buildings.count >= 8, "Expected at least 8 heritage buildings in Denpasar district")

        for bldg in buildings {
            #expect(!bldg.id.isEmpty)
            #expect(!bldg.name.isEmpty)
            #expect(bldg.coordinates.count >= 3, "Building \(bldg.name) must have at least 3 vertices")
            #expect(bldg.heightM > 0, "Building \(bldg.name) must have a positive height")
            #expect(bldg.levels >= 1, "Building \(bldg.name) must have at least 1 level")
            #expect(!bldg.architecturalStyle.isEmpty)

            for coord in bldg.coordinates {
                #expect(coord.lat >= -8.70 && coord.lat <= -8.60, "Building \(bldg.name) latitude out of range")
                #expect(coord.lon >= 115.18 && coord.lon <= 115.25, "Building \(bldg.name) longitude out of range")
            }
        }
    }

    @Test("Point-in-polygon ray casting accurately detects taps inside building footprint")
    func testPointInPolygonDetection() {
        let polygon: [CGPoint] = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100),
            CGPoint(x: 200, y: 200),
            CGPoint(x: 100, y: 200)
        ]

        let insidePoint = CGPoint(x: 150, y: 150)
        let outsidePoint = CGPoint(x: 250, y: 250)
        let farOutsidePoint = CGPoint(x: 50, y: 50)

        #expect(GeoLibreBuildingMath.contains(point: insidePoint, in: polygon) == true)
        #expect(GeoLibreBuildingMath.contains(point: outsidePoint, in: polygon) == false)
        #expect(GeoLibreBuildingMath.contains(point: farOutsidePoint, in: polygon) == false)
    }

    @Test("Isometric 2.5D extrusion computes roof offsets proportionally to pixel height")
    func testIsometricRoofComputation() {
        let groundPoints: [CGPoint] = [
            CGPoint(x: 50, y: 50),
            CGPoint(x: 80, y: 50),
            CGPoint(x: 80, y: 80),
            CGPoint(x: 50, y: 80)
        ]

        let heightPixels: CGFloat = 20.0
        let roofPoints = GeoLibreBuildingMath.computeRoofPoints(groundPoints: groundPoints, heightPixels: heightPixels)

        #expect(roofPoints.count == groundPoints.count)

        // Roof should be offset upwards (negative Y) and slightly to the right (positive X)
        let expectedOffsetX = heightPixels * 0.55
        let expectedOffsetY = -heightPixels * 0.70

        for (ground, roof) in zip(groundPoints, roofPoints) {
            #expect(abs(roof.x - (ground.x + expectedOffsetX)) < 0.001)
            #expect(abs(roof.y - (ground.y + expectedOffsetY)) < 0.001)
        }
    }

    @Test("GeoLibreBuildingOptions allows customizing render modes and class visibility")
    func testBuildingOptionsCustomization() {
        var options = GeoLibreBuildingOptions()
        #expect(options.isEnabled == true)
        #expect(options.renderMode == .isometric25D)
        #expect(options.showBuildingLabels == true)
        #expect(options.showParcels == true)
        #expect(options.visibleClasses.count == GeoLibreBuilding.BuildingClass.allCases.count)

        // Toggle to 2D
        options.renderMode = .flat2D
        #expect(options.renderMode == .flat2D)

        // Filter out commercial shophouses
        options.visibleClasses.remove(.commercialShophouse)
        #expect(!options.visibleClasses.contains(.commercialShophouse))
        #expect(options.visibleClasses.contains(.royalPalace))
    }

    @Test("Building center coordinates calculate correctly")
    func testBuildingCenterCoordinate() {
        let building = GeoLibreBuilding(
            id: "test-bldg",
            name: "Test Pavilion",
            class: .royalPalace,
            coordinates: [
                Coordinate(lat: -8.650, lon: 115.200),
                Coordinate(lat: -8.650, lon: 115.210),
                Coordinate(lat: -8.660, lon: 115.210),
                Coordinate(lat: -8.660, lon: 115.200)
            ],
            heightM: 10.0
        )

        let center = building.centerCoordinate
        #expect(abs(center.lat - (-8.655)) < 0.0001)
        #expect(abs(center.lon - 115.205) < 0.0001)
    }
}
