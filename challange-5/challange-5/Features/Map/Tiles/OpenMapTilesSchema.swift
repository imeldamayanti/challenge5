import ContentKit
import CoreGraphics
import Foundation

// MARK: - OpenMapTiles Standard Layer Types (https://openmaptiles.org/schema/)

enum OpenMapTilesLayerName: String, Sendable, CaseIterable, Identifiable {
    case water = "water"
    case waterway = "waterway"
    case waterName = "water_name"
    case landcover = "landcover"
    case landuse = "landuse"
    case park = "park"
    case boundary = "boundary"
    case transportation = "transportation"
    case transportationName = "transportation_name"
    case building = "building"
    case place = "place"
    case poi = "poi"
    case mountainPeak = "mountain_peak"
    case aeroway = "aeroway"

    var id: String { rawValue }
}

struct OMTBoundingBox: Sendable, Equatable {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
}

// MARK: - Geometry Primitives

enum OpenMapTilesGeometry: Sendable, Equatable {
    case point(Coordinate)
    case lineString([Coordinate])
    case polygon([Coordinate])
    case multiPolygon([[Coordinate]])
}

// MARK: - 1. Water Layer (https://openmaptiles.org/schema/#water)

struct OMTWaterFeature: Identifiable, Sendable, Equatable {
    enum WaterClass: String, Sendable, Equatable {
        case ocean = "ocean"
        case sea = "sea"
        case lake = "lake"
        case reservoir = "reservoir"
        case river = "river"
        case swimmingPool = "swimming_pool"
    }

    let id: String
    let `class`: WaterClass
    let geometry: OpenMapTilesGeometry
    let name: String?
    let isIntermittent: Bool

    init(
        id: String,
        class: WaterClass,
        geometry: OpenMapTilesGeometry,
        name: String? = nil,
        isIntermittent: Bool = false
    ) {
        self.id = id
        self.class = `class`
        self.geometry = geometry
        self.name = name
        self.isIntermittent = isIntermittent
    }
}

// MARK: - 2. Waterway Layer (https://openmaptiles.org/schema/#waterway)

struct OMTWaterwayFeature: Identifiable, Sendable, Equatable {
    enum WaterwayClass: String, Sendable, Equatable {
        case river = "river"
        case stream = "stream"
        case canal = "canal"
        case ditch = "ditch"
        case drain = "drain"
    }

    let id: String
    let `class`: WaterwayClass
    let name: String?
    let nameEn: String?
    let coordinates: [Coordinate]
    let isTunnel: Bool
    let isBridge: Bool

    init(
        id: String,
        class: WaterwayClass = .river,
        name: String? = nil,
        nameEn: String? = nil,
        coordinates: [Coordinate],
        isTunnel: Bool = false,
        isBridge: Bool = false
    ) {
        self.id = id
        self.class = `class`
        self.name = name
        self.nameEn = nameEn
        self.coordinates = coordinates
        self.isTunnel = isTunnel
        self.isBridge = isBridge
    }
}

// MARK: - 3. Water Name Layer (https://openmaptiles.org/schema/#water_name)

struct OMTWaterNameFeature: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let nameEn: String?
    let coordinate: Coordinate
    let `class`: OMTWaterFeature.WaterClass
    let angleDegrees: Double

    init(
        id: String,
        name: String,
        nameEn: String? = nil,
        coordinate: Coordinate,
        class: OMTWaterFeature.WaterClass,
        angleDegrees: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.nameEn = nameEn
        self.coordinate = coordinate
        self.class = `class`
        self.angleDegrees = angleDegrees
    }
}

// MARK: - 4. Landcover Layer (https://openmaptiles.org/schema/#landcover)

struct OMTLandcoverFeature: Identifiable, Sendable, Equatable {
    enum LandcoverClass: String, Sendable, Equatable {
        case wood = "wood"
        case scrub = "scrub"
        case grass = "grass"
        case crop = "crop"
        case sand = "sand"
        case wetland = "wetland"
        case rock = "rock"
        case farmland = "farmland"
    }

    let id: String
    let `class`: LandcoverClass
    let coordinates: [Coordinate]

    init(id: String, class: LandcoverClass, coordinates: [Coordinate]) {
        self.id = id
        self.class = `class`
        self.coordinates = coordinates
    }
}

// MARK: - 5. Park Layer (https://openmaptiles.org/schema/#park)

struct OMTParkFeature: Identifiable, Sendable, Equatable {
    enum ParkClass: String, Sendable, Equatable {
        case nationalPark = "national_park"
        case natureReserve = "nature_reserve"
        case cityPark = "park"
        case protectedArea = "protected_area"
    }

    let id: String
    let name: String
    let `class`: ParkClass
    let coordinates: [Coordinate]

    init(id: String, name: String, class: ParkClass = .cityPark, coordinates: [Coordinate]) {
        self.id = id
        self.name = name
        self.class = `class`
        self.coordinates = coordinates
    }
}

// MARK: - 6. Boundary Layer (https://openmaptiles.org/schema/#boundary)

struct OMTBoundaryFeature: Identifiable, Sendable, Equatable {
    enum AdminLevel: Int, Sendable, Equatable {
        case country = 2
        case province = 4
        case regencyOrCounty = 6
        case district = 8
    }

    let id: String
    let name: String
    let adminLevel: AdminLevel
    let centerCoordinate: Coordinate
    let boundaryCoordinates: [Coordinate]

    init(
        id: String,
        name: String,
        adminLevel: AdminLevel = .regencyOrCounty,
        centerCoordinate: Coordinate,
        boundaryCoordinates: [Coordinate]
    ) {
        self.id = id
        self.name = name
        self.adminLevel = adminLevel
        self.centerCoordinate = centerCoordinate
        self.boundaryCoordinates = boundaryCoordinates
    }
}

// MARK: - 7. Transportation Layer (https://openmaptiles.org/schema/#transportation)

struct OMTTransportationFeature: Identifiable, Sendable, Equatable {
    enum TransportationClass: String, Sendable, Equatable {
        case motorway = "motorway"
        case trunk = "trunk"
        case primary = "primary"
        case secondary = "secondary"
        case tertiary = "tertiary"
        case minor = "minor"
        case path = "path"
        case pedestrian = "pedestrian"
        case service = "service"
        case track = "track"
        case alley = "alley"
    }

    let id: String
    let name: String
    let `class`: TransportationClass
    let coordinates: [Coordinate]
    let isBridge: Bool
    let isTunnel: Bool
    let labelOffset: Double? // 0.0 to 1.0 along line

    init(
        id: String,
        name: String,
        class: TransportationClass = .secondary,
        coordinates: [Coordinate],
        isBridge: Bool = false,
        isTunnel: Bool = false,
        labelOffset: Double? = 0.5
    ) {
        self.id = id
        self.name = name
        self.class = `class`
        self.coordinates = coordinates
        self.isBridge = isBridge
        self.isTunnel = isTunnel
        self.labelOffset = labelOffset
    }
}

// MARK: - 8. Building Layer (https://openmaptiles.org/schema/#building)

struct OMTBuildingFeature: Identifiable, Sendable, Equatable {
    enum BuildingClass: String, Sendable, Equatable {
        case residential = "residential"
        case commercial = "commercial"
        case religious = "religious"
        case royalPalace = "palace"
        case templeCompound = "temple"
        case market = "market"
        case parcel = "parcel"
    }

    let id: String
    let name: String?
    let `class`: BuildingClass
    let coordinates: [Coordinate]
    let renderHeightM: Double?

    init(
        id: String,
        name: String? = nil,
        class: BuildingClass = .parcel,
        coordinates: [Coordinate],
        renderHeightM: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.class = `class`
        self.coordinates = coordinates
        self.renderHeightM = renderHeightM
    }
}

// MARK: - 9. Place Layer (https://openmaptiles.org/schema/#place)

struct OMTPlaceFeature: Identifiable, Sendable, Equatable {
    enum PlaceClass: String, Sendable, Equatable {
        case country = "country"
        case province = "province"
        case city = "city"
        case town = "town"
        case village = "village"
        case island = "island"
        case suburb = "suburb"
        case hamlet = "hamlet"
    }

    let id: String
    let name: String
    let nameEn: String?
    let `class`: PlaceClass
    let coordinate: Coordinate
    let rank: Int

    init(
        id: String,
        name: String,
        nameEn: String? = nil,
        class: PlaceClass,
        coordinate: Coordinate,
        rank: Int = 1
    ) {
        self.id = id
        self.name = name
        self.nameEn = nameEn
        self.class = `class`
        self.coordinate = coordinate
        self.rank = rank
    }
}

// MARK: - 10. POI Layer (https://openmaptiles.org/schema/#poi)

struct OMTPOIFeature: Identifiable, Sendable, Equatable {
    enum POIClass: String, Sendable, Equatable {
        case placeOfWorship = "place_of_worship"
        case historic = "historic"
        case monument = "monument"
        case museum = "museum"
        case attraction = "attraction"
        case viewpoint = "viewpoint"
        case townhall = "townhall"
    }

    enum POISubclass: String, Sendable, Equatable {
        case pura = "hindu_temple"
        case puri = "palace"
        case monument = "monument"
        case museum = "museum"
        case holySpring = "spring"
        case riceTerrace = "terrace"
        case ancientVillage = "village"
        case waterPalace = "water_palace"
    }

    let id: String
    let name: String
    let nameEn: String?
    let `class`: POIClass
    let subclass: POISubclass
    let coordinate: Coordinate
    let summary: String
    let hasWalkingQuest: Bool

    init(
        id: String,
        name: String,
        nameEn: String? = nil,
        class: POIClass,
        subclass: POISubclass,
        coordinate: Coordinate,
        summary: String = "",
        hasWalkingQuest: Bool = false
    ) {
        self.id = id
        self.name = name
        self.nameEn = nameEn
        self.class = `class`
        self.subclass = subclass
        self.coordinate = coordinate
        self.summary = summary
        self.hasWalkingQuest = hasWalkingQuest
    }
}

// MARK: - 11. Mountain Peak Layer (https://openmaptiles.org/schema/#mountain_peak)

struct OMTMountainPeakFeature: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let nameEn: String?
    let coordinate: Coordinate
    let elevationM: Int
    let rank: Int

    init(
        id: String,
        name: String,
        nameEn: String? = nil,
        coordinate: Coordinate,
        elevationM: Int,
        rank: Int = 1
    ) {
        self.id = id
        self.name = name
        self.nameEn = nameEn
        self.coordinate = coordinate
        self.elevationM = elevationM
        self.rank = rank
    }
}
