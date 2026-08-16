import ContentKit
import Foundation

// MARK: - OpenMapTiles Map Document

struct OpenMapTilesMapDocument: Sendable, Equatable {
    let id: String
    let name: String
    let boundingBox: OMTBoundingBox
    let centerCoordinate: Coordinate

    var waterFeatures: [OMTWaterFeature]
    var waterwayFeatures: [OMTWaterwayFeature]
    var waterNameFeatures: [OMTWaterNameFeature]
    var landcoverFeatures: [OMTLandcoverFeature]
    var parkFeatures: [OMTParkFeature]
    var boundaryFeatures: [OMTBoundaryFeature]
    var transportationFeatures: [OMTTransportationFeature]
    var buildingFeatures: [OMTBuildingFeature]
    var placeFeatures: [OMTPlaceFeature]
    var poiFeatures: [OMTPOIFeature]
    var mountainPeakFeatures: [OMTMountainPeakFeature]

    init(
        id: String,
        name: String,
        boundingBox: OMTBoundingBox,
        centerCoordinate: Coordinate,
        waterFeatures: [OMTWaterFeature] = [],
        waterwayFeatures: [OMTWaterwayFeature] = [],
        waterNameFeatures: [OMTWaterNameFeature] = [],
        landcoverFeatures: [OMTLandcoverFeature] = [],
        parkFeatures: [OMTParkFeature] = [],
        boundaryFeatures: [OMTBoundaryFeature] = [],
        transportationFeatures: [OMTTransportationFeature] = [],
        buildingFeatures: [OMTBuildingFeature] = [],
        placeFeatures: [OMTPlaceFeature] = [],
        poiFeatures: [OMTPOIFeature] = [],
        mountainPeakFeatures: [OMTMountainPeakFeature] = []
    ) {
        self.id = id
        self.name = name
        self.boundingBox = boundingBox
        self.centerCoordinate = centerCoordinate
        self.waterFeatures = waterFeatures
        self.waterwayFeatures = waterwayFeatures
        self.waterNameFeatures = waterNameFeatures
        self.landcoverFeatures = landcoverFeatures
        self.parkFeatures = parkFeatures
        self.boundaryFeatures = boundaryFeatures
        self.transportationFeatures = transportationFeatures
        self.buildingFeatures = buildingFeatures
        self.placeFeatures = placeFeatures
        self.poiFeatures = poiFeatures
        self.mountainPeakFeatures = mountainPeakFeatures
    }

    /// Total feature count across all OpenMapTiles layers.
    var totalFeatureCount: Int {
        waterFeatures.count +
        waterwayFeatures.count +
        waterNameFeatures.count +
        landcoverFeatures.count +
        parkFeatures.count +
        boundaryFeatures.count +
        transportationFeatures.count +
        buildingFeatures.count +
        placeFeatures.count +
        poiFeatures.count +
        mountainPeakFeatures.count
    }
}

// MARK: - OpenMapTiles Standard Datasets for Hisplora

enum OpenMapTilesDataset {

    // MARK: - Whole Bali Island OpenMapTiles Document

    static let baliIslandDocument: OpenMapTilesMapDocument = {
        let b = HisploraBaliGeoData.baliBounds
        var doc = OpenMapTilesMapDocument(
            id: "omt-bali-island",
            name: "Pulau Bali (OpenMapTiles Schema)",
            boundingBox: OMTBoundingBox(minLat: b.minLat, maxLat: b.maxLat, minLon: b.minLon, maxLon: b.maxLon),
            centerCoordinate: HisploraBaliGeoData.islandCenter
        )

        // 1. Water Layer (Ocean & Crater Lakes)
        doc.waterFeatures = [
            OMTWaterFeature(
                id: "water-mainland",
                class: .ocean,
                geometry: .polygon(HisploraBaliGeoData.mainlandCoastline),
                name: "Pulau Bali"
            ),
            OMTWaterFeature(
                id: "water-nusa-penida",
                class: .ocean,
                geometry: .polygon(HisploraBaliGeoData.nusaPenidaCoastline),
                name: "Nusa Penida"
            ),
            OMTWaterFeature(
                id: "water-nusa-lembongan",
                class: .ocean,
                geometry: .polygon(HisploraBaliGeoData.nusaLembonganCoastline),
                name: "Nusa Lembongan"
            ),
            OMTWaterFeature(
                id: "water-nusa-ceningan",
                class: .ocean,
                geometry: .polygon(HisploraBaliGeoData.nusaCeninganCoastline),
                name: "Nusa Ceningan"
            ),
            OMTWaterFeature(
                id: "water-menjangan",
                class: .ocean,
                geometry: .polygon(HisploraBaliGeoData.pulauMenjanganCoastline),
                name: "Pulau Menjangan"
            )
        ]

        // Add Crater Lakes to Water layer
        for lake in HisploraBaliGeoData.lakes {
            doc.waterFeatures.append(
                OMTWaterFeature(
                    id: "lake-\(lake.id)",
                    class: .lake,
                    geometry: .polygon(lake.coordinates),
                    name: lake.name
                )
            )
        }

        // 2. Water Name Layer
        doc.waterNameFeatures = [
            OMTWaterNameFeature(id: "wn-laut-bali", name: "L A U T   B A L I", coordinate: Coordinate(lat: -8.08, lon: 115.15), class: .sea, angleDegrees: 0),
            OMTWaterNameFeature(id: "wn-samudera-hindia", name: "S A M U D E R A   H I N D I A", coordinate: Coordinate(lat: -8.88, lon: 115.18), class: .ocean, angleDegrees: 0),
            OMTWaterNameFeature(id: "wn-selat-bali", name: "S E L A T   B A L I", coordinate: Coordinate(lat: -8.28, lon: 114.41), class: .sea, angleDegrees: -75),
            OMTWaterNameFeature(id: "wn-selat-lombok", name: "S E L A T   L O M B O K", coordinate: Coordinate(lat: -8.45, lon: 115.73), class: .sea, angleDegrees: 80),
            OMTWaterNameFeature(id: "wn-selat-badung", name: "SELAT BADUNG", coordinate: Coordinate(lat: -8.67, lon: 115.36), class: .sea, angleDegrees: -35)
        ]

        // 3. Landcover & Parks Layer
        doc.landcoverFeatures = [
            OMTLandcoverFeature(
                id: "lc-central-highlands",
                class: .wood,
                coordinates: [
                    Coordinate(lat: -8.22, lon: 115.12),
                    Coordinate(lat: -8.20, lon: 115.42),
                    Coordinate(lat: -8.36, lon: 115.54),
                    Coordinate(lat: -8.40, lon: 115.35),
                    Coordinate(lat: -8.38, lon: 115.05),
                    Coordinate(lat: -8.28, lon: 115.06)
                ]
            )
        ]

        // 4. Boundary Layer (Admin Level 6: 9 Regencies)
        doc.boundaryFeatures = HisploraBaliGeoData.regencies.map { reg in
            OMTBoundaryFeature(
                id: "boundary-\(reg.id)",
                name: reg.name,
                adminLevel: .regencyOrCounty,
                centerCoordinate: reg.centerCoordinate,
                boundaryCoordinates: reg.boundaryPoints
            )
        }

        // 5. Transportation Layer (Highways & Inter-Regency Roads)
        doc.transportationFeatures = HisploraBaliGeoData.highways.map { hw in
            OMTTransportationFeature(
                id: "trans-\(hw.id)",
                name: hw.name,
                class: .primary,
                coordinates: hw.coordinates
            )
        }

        // 6. Mountain Peaks Layer
        doc.mountainPeakFeatures = HisploraBaliGeoData.mountainPeaks.map { peak in
            OMTMountainPeakFeature(
                id: "peak-\(peak.id)",
                name: peak.name,
                coordinate: peak.coordinate,
                elevationM: peak.elevationM,
                rank: peak.id == "gunung-agung" ? 1 : 2
            )
        }

        // 7. POI Layer (Heritage Quests & Cultural Landmarks)
        doc.poiFeatures = HisploraBaliGeoData.landmarks.map { lm in
            let poiClass: OMTPOIFeature.POIClass
            let poiSubclass: OMTPOIFeature.POISubclass

            switch lm.category {
            case .pura:
                poiClass = .placeOfWorship
                poiSubclass = .pura
            case .puri:
                poiClass = .historic
                poiSubclass = .puri
            case .nature:
                poiClass = .attraction
                poiSubclass = .riceTerrace
            case .village:
                poiClass = .historic
                poiSubclass = .ancientVillage
            case .all:
                poiClass = .attraction
                poiSubclass = .pura
            }

            return OMTPOIFeature(
                id: "poi-\(lm.id)",
                name: lm.name,
                class: poiClass,
                subclass: poiSubclass,
                coordinate: lm.coordinate,
                summary: lm.summary,
                hasWalkingQuest: lm.hasWalkingQuest
            )
        }

        return doc
    }()

    // MARK: - Denpasar Historic District OpenMapTiles Document

    static let denpasarDistrictDocument: OpenMapTilesMapDocument = {
        let b = HisploraDenpasarDistrict.districtBounds
        var doc = OpenMapTilesMapDocument(
            id: "omt-denpasar-district",
            name: "Denpasar Heritage District (OpenMapTiles Schema)",
            boundingBox: OMTBoundingBox(minLat: b.minLat, maxLat: b.maxLat, minLon: b.minLon, maxLon: b.maxLon),
            centerCoordinate: HisploraDenpasarDistrict.centerCoordinate
        )

        // 1. Waterways (Tukad Badung & Tributary)
        doc.waterwayFeatures = HisploraDenpasarDistrict.waterways.map { ww in
            OMTWaterwayFeature(
                id: "ww-\(ww.id)",
                class: .river,
                name: ww.name,
                coordinates: ww.coordinates
            )
        }

        // 2. Parks & Compound Landuse
        doc.parkFeatures = HisploraDenpasarDistrict.areas.filter { $0.kind == .park }.map { area in
            OMTParkFeature(
                id: "park-\(area.id)",
                name: area.name,
                class: .cityPark,
                coordinates: area.coordinates
            )
        }

        // 3. Buildings & Heritage Compounds
        doc.buildingFeatures = HisploraDenpasarDistrict.areas.filter { $0.kind != .park }.map { area in
            let bClass: OMTBuildingFeature.BuildingClass = area.kind == .palaceCompound ? .royalPalace : .religious
            return OMTBuildingFeature(
                id: "bldg-\(area.id)",
                name: area.name,
                class: bClass,
                coordinates: area.coordinates
            )
        }

        // Add Cadastral Parcel Sketches as minor building/parcel outlines
        for parcel in HisploraDenpasarDistrict.parcelSketches {
            doc.buildingFeatures.append(
                OMTBuildingFeature(
                    id: "parcel-\(parcel.id)",
                    class: .parcel,
                    coordinates: parcel.coordinates
                )
            )
        }

        // 4. Transportation (Roads, Alleys, Arterials)
        doc.transportationFeatures = HisploraDenpasarDistrict.roads.map { rd in
            let tClass: OMTTransportationFeature.TransportationClass
            switch rd.type {
            case .major: tClass = .primary
            case .secondary: tClass = .secondary
            case .alley: tClass = .alley
            }

            return OMTTransportationFeature(
                id: "rd-\(rd.id)",
                name: rd.name,
                class: tClass,
                coordinates: rd.coordinates,
                labelOffset: rd.labelOffset
            )
        }

        return doc
    }()
}
