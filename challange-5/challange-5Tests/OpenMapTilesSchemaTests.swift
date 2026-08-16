import ContentKit
import DesignSystem
import Testing
@testable import challange_5
import Foundation

@Suite("OpenMapTiles Schema & Style Engine Tests")
struct OpenMapTilesSchemaTests {

    @Test("All OpenMapTiles standard layer names are represented")
    func openMapTilesLayerNamesCompleteness() {
        let expectedLayers = [
            "water", "waterway", "water_name", "landcover", "landuse",
            "park", "boundary", "transportation", "transportation_name",
            "building", "place", "poi", "mountain_peak", "aeroway"
        ]

        let allLayers = OpenMapTilesLayerName.allCases.map { $0.rawValue }
        for expected in expectedLayers {
            #expect(allLayers.contains(expected), "Missing OpenMapTiles layer: \(expected)")
        }
    }

    @Test("Whole Bali document conforms to OpenMapTiles vector tile schema")
    func baliIslandDocumentConformsToOMT() {
        let doc = OpenMapTilesDataset.baliIslandDocument

        #expect(doc.id == "omt-bali-island")
        #expect(doc.totalFeatureCount > 30)

        // Water layer
        #expect(doc.waterFeatures.count >= 5)
        #expect(doc.waterFeatures.contains { $0.class == .ocean })
        #expect(doc.waterFeatures.contains { $0.class == .lake })

        // Water Name layer
        #expect(doc.waterNameFeatures.count >= 4)

        // Landcover layer
        #expect(doc.landcoverFeatures.count >= 1)

        // Boundary layer (9 regencies at Admin Level 6)
        #expect(doc.boundaryFeatures.count == 9)
        #expect(doc.boundaryFeatures.allSatisfy { $0.adminLevel == .regencyOrCounty })

        // Transportation layer
        #expect(doc.transportationFeatures.count >= 5)

        // Mountain Peaks layer
        #expect(doc.mountainPeakFeatures.count >= 5)
        #expect(doc.mountainPeakFeatures.contains { $0.id == "peak-gunung-agung" && $0.elevationM == 3142 })

        // POI layer
        #expect(doc.poiFeatures.count >= 15)
        #expect(doc.poiFeatures.contains { $0.class == .placeOfWorship })
        #expect(doc.poiFeatures.contains { $0.class == .historic })
    }

    @Test("Denpasar District document conforms to OpenMapTiles vector tile schema")
    func denpasarDistrictDocumentConformsToOMT() {
        let doc = OpenMapTilesDataset.denpasarDistrictDocument

        #expect(doc.id == "omt-denpasar-district")
        #expect(doc.totalFeatureCount > 20)

        // Waterways (Tukad Badung)
        #expect(doc.waterwayFeatures.count >= 1)
        #expect(doc.waterwayFeatures.contains { $0.name == "Tukad Badung" })

        // Parks (Puputan Square)
        #expect(doc.parkFeatures.count >= 1)

        // Buildings & Compounds (Puri Agung Pemecutan)
        #expect(doc.buildingFeatures.count >= 5)
        #expect(doc.buildingFeatures.contains { $0.class == .royalPalace })
        #expect(doc.buildingFeatures.contains { $0.class == .parcel })

        // Transportation network
        #expect(doc.transportationFeatures.count >= 10)
        #expect(doc.transportationFeatures.contains { $0.class == .primary })
        #expect(doc.transportationFeatures.contains { $0.class == .secondary })
        #expect(doc.transportationFeatures.contains { $0.class == .alley })
    }

    @Test("OpenMapTiles Style Engine correctly maps transportation classes to Hisplora vintage styles")
    func styleEngineTransportationMapping() {
        let primaryStyle = OpenMapTilesStyleEngine.style(for: .primary)
        #expect(primaryStyle.casingWidth == HisploraMapStyle.roadMajorCasingWidth)
        #expect(primaryStyle.fillWidth == HisploraMapStyle.roadMajorFillWidth)

        let secondaryStyle = OpenMapTilesStyleEngine.style(for: .secondary)
        #expect(secondaryStyle.casingWidth == HisploraMapStyle.roadSecondaryCasingWidth)
        #expect(secondaryStyle.fillWidth == HisploraMapStyle.roadSecondaryFillWidth)

        let minorStyle = OpenMapTilesStyleEngine.style(for: .minor)
        #expect(minorStyle.casingWidth == HisploraMapStyle.roadMinorCasingWidth)

        let pathStyle = OpenMapTilesStyleEngine.style(for: .path)
        #expect(pathStyle.strokeStyle != nil)
    }

    @Test("OpenMapTiles Style Engine maps water and park classes to vintage palette")
    func styleEngineWaterAndParkMapping() {
        let oceanStyle = OpenMapTilesStyleEngine.style(for: .ocean)
        #expect(oceanStyle.strokeWidth > 0)

        let lakeStyle = OpenMapTilesStyleEngine.style(for: .lake)
        #expect(lakeStyle.strokeWidth > 0)

        let parkStyle = OpenMapTilesStyleEngine.style(for: .nationalPark)
        #expect(parkStyle.strokeWidth > 0)
    }
}
