import ContentKit
import Foundation

/// Geographic models representing vector elements (streets, waterways, parks, heritage sites)
/// in the Badung / Denpasar cultural heritage district.
enum HisploraRoadType: Sendable, Equatable {
    case major
    case secondary
    case alley
}

struct HisploraRoadSegment: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let type: HisploraRoadType
    let coordinates: [Coordinate]
    let labelOffset: Double? // 0.0 to 1.0 along line where label is positioned

    init(
        id: String,
        name: String,
        type: HisploraRoadType = .secondary,
        coordinates: [Coordinate],
        labelOffset: Double? = 0.5
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.coordinates = coordinates
        self.labelOffset = labelOffset
    }
}

struct HisploraWaterwaySegment: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let coordinates: [Coordinate]
    let widthM: Double

    init(id: String, name: String, coordinates: [Coordinate], widthM: Double = 14) {
        self.id = id
        self.name = name
        self.coordinates = coordinates
        self.widthM = widthM
    }
}

struct HisploraPolygonArea: Identifiable, Sendable, Equatable {
    enum Kind: Sendable, Equatable {
        case park
        case palaceCompound
        case templeCourtyard
        case marketComplex
    }

    let id: String
    let name: String
    let kind: Kind
    let coordinates: [Coordinate]

    init(id: String, name: String, kind: Kind, coordinates: [Coordinate]) {
        self.id = id
        self.name = name
        self.kind = kind
        self.coordinates = coordinates
    }
}

struct HisploraParcelSketch: Identifiable, Sendable, Equatable {
    let id: String
    let coordinates: [Coordinate]

    init(id: String, coordinates: [Coordinate]) {
        self.id = id
        self.coordinates = coordinates
    }
}

struct HisploraRoundabout: Identifiable, Sendable, Equatable {
    let id: String
    let coordinate: Coordinate
    let radiusM: Double
}

struct HisploraTransitBadge: Identifiable, Sendable, Equatable {
    let id: String
    let symbol: String
    let coordinate: Coordinate
}

struct HisploraCalligraphicLandmark: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let coordinate: Coordinate
    let labelOffsetPoints: CGPoint
    let textColorHex: String
    let circleColorHex: String
    let pinColorHex: String
    let circleRadiusM: Double
}

enum HisploraDenpasarDistrict {

    static let districtBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) = (
        minLat: -8.6655,
        maxLat: -8.6505,
        minLon: 115.2030,
        maxLon: 115.2215
    )

    static let centerCoordinate = Coordinate(lat: -8.6565, lon: 115.2125)

    // MARK: - Waterways (Tukad Badung & Tributary)

    static let waterways: [HisploraWaterwaySegment] = [
        HisploraWaterwaySegment(
            id: "tukad-badung-main",
            name: "Tukad Badung",
            coordinates: [
                Coordinate(lat: -8.6505, lon: 115.2114),
                Coordinate(lat: -8.6520, lon: 115.2118),
                Coordinate(lat: -8.6538, lon: 115.2115),
                Coordinate(lat: -8.6552, lon: 115.2112),
                Coordinate(lat: -8.6568, lon: 115.2116),
                Coordinate(lat: -8.6582, lon: 115.2120),
                Coordinate(lat: -8.6596, lon: 115.2118),
                Coordinate(lat: -8.6612, lon: 115.2123),
                Coordinate(lat: -8.6630, lon: 115.2128),
                Coordinate(lat: -8.6655, lon: 115.2134)
            ],
            widthM: 16
        ),
        HisploraWaterwaySegment(
            id: "tukad-badung-branch",
            name: "Tukad Badung Barat",
            coordinates: [
                Coordinate(lat: -8.6525, lon: 115.2118),
                Coordinate(lat: -8.6542, lon: 115.2109),
                Coordinate(lat: -8.6565, lon: 115.2104),
                Coordinate(lat: -8.6585, lon: 115.2108),
                Coordinate(lat: -8.6610, lon: 115.2115)
            ],
            widthM: 10
        ),
        HisploraWaterwaySegment(
            id: "tukad-east-branch",
            name: "Saluran Timur Made Putra",
            coordinates: [
                Coordinate(lat: -8.6610, lon: 115.2175),
                Coordinate(lat: -8.6625, lon: 115.2190),
                Coordinate(lat: -8.6645, lon: 115.2210)
            ],
            widthM: 8
        )
    ]

    // MARK: - Road Network

    static let roads: [HisploraRoadSegment] = [
        // Primary East-West Arterial: Jl. Gajah Mada / Jl. Surapati
        HisploraRoadSegment(
            id: "jl-gajah-mada-surapati",
            name: "Jl. Gajah Mada",
            type: .major,
            coordinates: [
                Coordinate(lat: -8.6568, lon: 115.2075),
                Coordinate(lat: -8.6565, lon: 115.2095),
                Coordinate(lat: -8.6560, lon: 115.2115),
                Coordinate(lat: -8.6552, lon: 115.2140),
                Coordinate(lat: -8.6545, lon: 115.2160),
                Coordinate(lat: -8.6542, lon: 115.2185),
                Coordinate(lat: -8.6540, lon: 115.2210)
            ],
            labelOffset: 0.4
        ),

        // Jl. Hasanuddin (South East-West axis)
        HisploraRoadSegment(
            id: "jl-hasanuddin",
            name: "Jl. Hasanuddin",
            type: .major,
            coordinates: [
                Coordinate(lat: -8.6598, lon: 115.2055),
                Coordinate(lat: -8.6595, lon: 115.2077),
                Coordinate(lat: -8.6598, lon: 115.2100),
                Coordinate(lat: -8.6603, lon: 115.2120),
                Coordinate(lat: -8.6605, lon: 115.2145),
                Coordinate(lat: -8.6608, lon: 115.2175)
            ],
            labelOffset: 0.35
        ),

        // Jl. Thamrin (West North-South axis by Puri Pemecutan)
        HisploraRoadSegment(
            id: "jl-thamrin",
            name: "Jl. Thamrin",
            type: .major,
            coordinates: [
                Coordinate(lat: -8.6650, lon: 115.2070),
                Coordinate(lat: -8.6625, lon: 115.2073),
                Coordinate(lat: -8.6595, lon: 115.2077),
                Coordinate(lat: -8.6568, lon: 115.2075),
                Coordinate(lat: -8.6535, lon: 115.2072),
                Coordinate(lat: -8.6510, lon: 115.2070)
            ],
            labelOffset: 0.5
        ),

        // Jl. Veteran (East North-South axis by Lapangan Puputan / Catur Muka)
        HisploraRoadSegment(
            id: "jl-veteran",
            name: "Jl. Veteran",
            type: .major,
            coordinates: [
                Coordinate(lat: -8.6505, lon: 115.2160),
                Coordinate(lat: -8.6525, lon: 115.2160),
                Coordinate(lat: -8.6545, lon: 115.2160),
                Coordinate(lat: -8.6565, lon: 115.2160),
                Coordinate(lat: -8.6590, lon: 115.2160),
                Coordinate(lat: -8.6620, lon: 115.2160)
            ],
            labelOffset: 0.3
        ),

        // Jl. Wahidin & Jl. Gambuh (North-West Loop)
        HisploraRoadSegment(
            id: "jl-wahidin",
            name: "Jl. Wahidin",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6568, lon: 115.2075),
                Coordinate(lat: -8.6548, lon: 115.2045),
                Coordinate(lat: -8.6530, lon: 115.2048)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-gambuh",
            name: "Jl. Gambuh",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6530, lon: 115.2048),
                Coordinate(lat: -8.6528, lon: 115.2082),
                Coordinate(lat: -8.6552, lon: 115.2080),
                Coordinate(lat: -8.6568, lon: 115.2075)
            ],
            labelOffset: 0.4
        ),

        // Jl. Kumbakarna & Jl. Sahadewa
        HisploraRoadSegment(
            id: "jl-kumbakarna",
            name: "Jl. Kumbakarna",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6530, lon: 115.2082),
                Coordinate(lat: -8.6533, lon: 115.2115),
                Coordinate(lat: -8.6535, lon: 115.2135)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-sahadewa",
            name: "Jl. Sahadewa",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6542, lon: 115.2115),
                Coordinate(lat: -8.6545, lon: 115.2140),
                Coordinate(lat: -8.6548, lon: 115.2160)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-nakula",
            name: "Jl. Nakula",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6515, lon: 115.2115),
                Coordinate(lat: -8.6518, lon: 115.2145),
                Coordinate(lat: -8.6520, lon: 115.2160)
            ],
            labelOffset: 0.5
        ),

        // Jl. Beliton (Mid South link)
        HisploraRoadSegment(
            id: "jl-beliton",
            name: "Jl. Beliton",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6590, lon: 115.2118),
                Coordinate(lat: -8.6588, lon: 115.2145),
                Coordinate(lat: -8.6585, lon: 115.2170)
            ],
            labelOffset: 0.5
        ),

        // Puputan & Eastern Streets: Jl. Kresna, Jl. Kaliasem, Jl. Kepundung
        HisploraRoadSegment(
            id: "jl-kresna",
            name: "Jl. Kresna",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6520, lon: 115.2142),
                Coordinate(lat: -8.6550, lon: 115.2143),
                Coordinate(lat: -8.6580, lon: 115.2144)
            ],
            labelOffset: 0.45
        ),
        HisploraRoadSegment(
            id: "jl-kaliasem",
            name: "Jl. Kaliasem",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6530, lon: 115.2178),
                Coordinate(lat: -8.6555, lon: 115.2177),
                Coordinate(lat: -8.6585, lon: 115.2176)
            ],
            labelOffset: 0.4
        ),
        HisploraRoadSegment(
            id: "jl-kepundung",
            name: "Jl. Kepundung",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6525, lon: 115.2202),
                Coordinate(lat: -8.6555, lon: 115.2200),
                Coordinate(lat: -8.6585, lon: 115.2198)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-rambutan",
            name: "Jl. Rambutan",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6528, lon: 115.2160),
                Coordinate(lat: -8.6527, lon: 115.2185),
                Coordinate(lat: -8.6526, lon: 115.2205)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-durian",
            name: "Jl. Durian",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6540, lon: 115.2160),
                Coordinate(lat: -8.6538, lon: 115.2185),
                Coordinate(lat: -8.6537, lon: 115.2205)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-kedondong",
            name: "Jl. Kedondong",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6515, lon: 115.2168),
                Coordinate(lat: -8.6514, lon: 115.2205)
            ],
            labelOffset: 0.5
        ),

        // Southern Connections
        HisploraRoadSegment(
            id: "jl-gunung-merapi",
            name: "Jl. Gunung Merapi",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6580, lon: 115.2045),
                Coordinate(lat: -8.6610, lon: 115.2050),
                Coordinate(lat: -8.6635, lon: 115.2055)
            ],
            labelOffset: 0.4
        ),
        HisploraRoadSegment(
            id: "jl-bukit-barisan",
            name: "Jl. Bukit Barisan",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6605, lon: 115.2095),
                Coordinate(lat: -8.6630, lon: 115.2098)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-diponegoro",
            name: "Jl. Diponegoro",
            type: .major,
            coordinates: [
                Coordinate(lat: -8.6608, lon: 115.2128),
                Coordinate(lat: -8.6635, lon: 115.2132),
                Coordinate(lat: -8.6655, lon: 115.2135)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-sujana",
            name: "Jl. Sujana",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6585, lon: 115.2176),
                Coordinate(lat: -8.6620, lon: 115.2175)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "jl-made-putra",
            name: "Jl. Made Putra",
            type: .secondary,
            coordinates: [
                Coordinate(lat: -8.6585, lon: 115.2198),
                Coordinate(lat: -8.6625, lon: 115.2195)
            ],
            labelOffset: 0.5
        ),

        // Minor Alleys / Gangs
        HisploraRoadSegment(
            id: "gg-iv-north",
            name: "Gg. IV",
            type: .alley,
            coordinates: [
                Coordinate(lat: -8.6538, lon: 115.2095),
                Coordinate(lat: -8.6555, lon: 115.2093)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "gg-vi",
            name: "Gg. VI",
            type: .alley,
            coordinates: [
                Coordinate(lat: -8.6548, lon: 115.2094),
                Coordinate(lat: -8.6549, lon: 115.2112)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "gg-iv-east",
            name: "Gg. IV",
            type: .alley,
            coordinates: [
                Coordinate(lat: -8.6522, lon: 115.2185),
                Coordinate(lat: -8.6522, lon: 115.2202)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "gg-d",
            name: "Gg. D",
            type: .alley,
            coordinates: [
                Coordinate(lat: -8.6525, lon: 115.2202),
                Coordinate(lat: -8.6525, lon: 115.2215)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "gg-a",
            name: "Gg. A",
            type: .alley,
            coordinates: [
                Coordinate(lat: -8.6534, lon: 115.2188),
                Coordinate(lat: -8.6534, lon: 115.2210)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "gg-iii-south",
            name: "Gg. III",
            type: .alley,
            coordinates: [
                Coordinate(lat: -8.6600, lon: 115.2085),
                Coordinate(lat: -8.6620, lon: 115.2085)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "gg-ii-south",
            name: "Gg. II",
            type: .alley,
            coordinates: [
                Coordinate(lat: -8.6604, lon: 115.2115),
                Coordinate(lat: -8.6625, lon: 115.2118)
            ],
            labelOffset: 0.5
        ),
        HisploraRoadSegment(
            id: "gg-ii-east",
            name: "Gg. II",
            type: .alley,
            coordinates: [
                Coordinate(lat: -8.6570, lon: 115.2188),
                Coordinate(lat: -8.6570, lon: 115.2205)
            ],
            labelOffset: 0.5
        )
    ]

    // MARK: - Heritage Areas & Public Spaces

    static let areas: [HisploraPolygonArea] = [
        // Lapangan Puputan Badung (Puputan Square)
        HisploraPolygonArea(
            id: "lapangan-puputan-badung",
            name: "Lapangan Puputan Badung",
            kind: .park,
            coordinates: [
                Coordinate(lat: -8.6548, lon: 115.2162),
                Coordinate(lat: -8.6548, lon: 115.2185),
                Coordinate(lat: -8.6575, lon: 115.2185),
                Coordinate(lat: -8.6575, lon: 115.2162)
            ]
        ),
        // Puri Agung Pemecutan Compound
        HisploraPolygonArea(
            id: "puri-agung-pemecutan-compound",
            name: "Puri Agung Pemecutan",
            kind: .palaceCompound,
            coordinates: [
                Coordinate(lat: -8.6588, lon: 115.2062),
                Coordinate(lat: -8.6588, lon: 115.2082),
                Coordinate(lat: -8.6608, lon: 115.2082),
                Coordinate(lat: -8.6608, lon: 115.2062)
            ]
        ),
        // Museum Bali & Pura Jagatnatha Grounds
        HisploraPolygonArea(
            id: "museum-bali-compound",
            name: "Kompleks Museum Bali & Jagatnatha",
            kind: .templeCourtyard,
            coordinates: [
                Coordinate(lat: -8.6550, lon: 115.2188),
                Coordinate(lat: -8.6550, lon: 115.2205),
                Coordinate(lat: -8.6572, lon: 115.2205),
                Coordinate(lat: -8.6572, lon: 115.2188)
            ]
        ),
        // Pasar Badung riverside market area
        HisploraPolygonArea(
            id: "pasar-badung-complex",
            name: "Pasar Badung",
            kind: .marketComplex,
            coordinates: [
                Coordinate(lat: -8.6535, lon: 115.2105),
                Coordinate(lat: -8.6535, lon: 115.2125),
                Coordinate(lat: -8.6550, lon: 115.2125),
                Coordinate(lat: -8.6550, lon: 115.2105)
            ]
        )
    ]

    // MARK: - Hand-drawn Parcel Sketch Linework (Vintage Cartographic Subdivisions)

    static let parcelSketches: [HisploraParcelSketch] = [
        // Northwest urban block parcel lines
        HisploraParcelSketch(id: "p1", coordinates: [Coordinate(lat: -8.6540, lon: 115.2052), Coordinate(lat: -8.6540, lon: 115.2072)]),
        HisploraParcelSketch(id: "p2", coordinates: [Coordinate(lat: -8.6555, lon: 115.2050), Coordinate(lat: -8.6555, lon: 115.2070)]),
        HisploraParcelSketch(id: "p3", coordinates: [Coordinate(lat: -8.6545, lon: 115.2060), Coordinate(lat: -8.6565, lon: 115.2060)]),

        // West River block parcel lines
        HisploraParcelSketch(id: "p4", coordinates: [Coordinate(lat: -8.6575, lon: 115.2085), Coordinate(lat: -8.6575, lon: 115.2105)]),
        HisploraParcelSketch(id: "p5", coordinates: [Coordinate(lat: -8.6588, lon: 115.2088), Coordinate(lat: -8.6588, lon: 115.2108)]),
        HisploraParcelSketch(id: "p6", coordinates: [Coordinate(lat: -8.6560, lon: 115.2095), Coordinate(lat: -8.6585, lon: 115.2095)]),

        // Northeast block parcel lines (around Jl. Durian / Jl. Rambutan)
        HisploraParcelSketch(id: "p7", coordinates: [Coordinate(lat: -8.6520, lon: 115.2170), Coordinate(lat: -8.6545, lon: 115.2170)]),
        HisploraParcelSketch(id: "p8", coordinates: [Coordinate(lat: -8.6520, lon: 115.2195), Coordinate(lat: -8.6545, lon: 115.2195)]),
        HisploraParcelSketch(id: "p9", coordinates: [Coordinate(lat: -8.6532, lon: 115.2165), Coordinate(lat: -8.6532, lon: 115.2205)]),

        // Southeast block parcel lines
        HisploraParcelSketch(id: "p10", coordinates: [Coordinate(lat: -8.6595, lon: 115.2150), Coordinate(lat: -8.6595, lon: 115.2170)]),
        HisploraParcelSketch(id: "p11", coordinates: [Coordinate(lat: -8.6590, lon: 115.2185), Coordinate(lat: -8.6590, lon: 115.2205)]),
        HisploraParcelSketch(id: "p12", coordinates: [Coordinate(lat: -8.6600, lon: 115.2180), Coordinate(lat: -8.6620, lon: 115.2180)])
    ]

    // MARK: - Hand-drawn Roundabouts & Junctions (Matching Reference)

    static let roundabouts: [HisploraRoundabout] = [
        HisploraRoundabout(
            id: "rb-puputan-veteran",
            coordinate: Coordinate(lat: -8.6555, lon: 115.2160),
            radiusM: 7.5
        ),
        HisploraRoundabout(
            id: "rb-wahidin-gambuh",
            coordinate: Coordinate(lat: -8.6542, lon: 115.2075),
            radiusM: 5.0
        )
    ]

    // MARK: - Transit & Heritage Badges (Matching Reference)

    static let transitBadges: [HisploraTransitBadge] = [
        HisploraTransitBadge(
            id: "badge-gambuh-north",
            symbol: "M",
            coordinate: Coordinate(lat: -8.6518, lon: 115.2048)
        ),
        HisploraTransitBadge(
            id: "badge-kumbakarna",
            symbol: "M",
            coordinate: Coordinate(lat: -8.6522, lon: 115.2082)
        ),
        HisploraTransitBadge(
            id: "badge-veteran-puputan",
            symbol: "KL",
            coordinate: Coordinate(lat: -8.6542, lon: 115.2160)
        ),
        HisploraTransitBadge(
            id: "badge-thamrin-gate",
            symbol: "T",
            coordinate: Coordinate(lat: -8.6582, lon: 115.2075)
        )
    ]

    // MARK: - Calligraphic Landmark Highlights (Matching Reference Style)

    static let calligraphicLandmarks: [HisploraCalligraphicLandmark] = [
        HisploraCalligraphicLandmark(
            id: "cal-puri-pemecutan",
            title: "PURI AGUNG\nPEMECUTAN",
            coordinate: Coordinate(lat: -8.6595, lon: 115.2077),
            labelOffsetPoints: CGPoint(x: -82, y: 12),
            textColorHex: "#2D4C6B", // Slate Navy
            circleColorHex: "#4C7456", // Sage Green
            pinColorHex: "#2D4C6B",
            circleRadiusM: 20.0
        ),
        HisploraCalligraphicLandmark(
            id: "cal-lapangan-puputan",
            title: "LAPANGAN\nPUPUTAN\nBADUNG",
            coordinate: Coordinate(lat: -8.6562, lon: 115.2178),
            labelOffsetPoints: CGPoint(x: -85, y: -8),
            textColorHex: "#295C38", // Forest Green
            circleColorHex: "#4C7456", // Sage Green
            pinColorHex: "#A33020", // Red
            circleRadiusM: 26.0
        )
    ]

    // MARK: - GeoLibre 2.5D Building Footprints & Architectural Structures

    static let buildings: [GeoLibreBuilding] = [
        // 1. Puri Agung Pemecutan Complex
        GeoLibreBuilding(
            id: "bldg-pemecutan-bale-kulkul",
            name: "Bale Kulkul Puri Pemecutan",
            class: .royalPalace,
            coordinates: [
                Coordinate(lat: -8.6593, lon: 115.2074),
                Coordinate(lat: -8.6593, lon: 115.2076),
                Coordinate(lat: -8.6595, lon: 115.2076),
                Coordinate(lat: -8.6595, lon: 115.2074)
            ],
            heightM: 14.0,
            levels: 3,
            roofType: .balineseMeru,
            architecturalStyle: "Traditional Balinese Royal Tower",
            historyNote: "The historic wooden slit-drum watchtower guarding the northern gate of the Pemecutan kingdom."
        ),
        GeoLibreBuilding(
            id: "bldg-pemecutan-wantilan",
            name: "Bale Wantilan Puri Pemecutan",
            class: .royalPalace,
            coordinates: [
                Coordinate(lat: -8.6597, lon: 115.2065),
                Coordinate(lat: -8.6597, lon: 115.2072),
                Coordinate(lat: -8.6603, lon: 115.2072),
                Coordinate(lat: -8.6603, lon: 115.2065)
            ],
            heightM: 9.0,
            levels: 2,
            roofType: .limasan,
            architecturalStyle: "Grand Balinese Open Pavilion",
            historyNote: "The royal ceremonial open-air assembly pavilion with carved teak columns and terracotta tile roof."
        ),
        GeoLibreBuilding(
            id: "bldg-pemecutan-inner-puri",
            name: "Puri Agung Pemecutan (Main Sanctum)",
            class: .royalPalace,
            coordinates: [
                Coordinate(lat: -8.6590, lon: 115.2064),
                Coordinate(lat: -8.6590, lon: 115.2073),
                Coordinate(lat: -8.6595, lon: 115.2073),
                Coordinate(lat: -8.6595, lon: 115.2064)
            ],
            heightM: 7.5,
            levels: 1,
            roofType: .limasan,
            architecturalStyle: "Classical Balinese Royal Compound",
            historyNote: "The residential and ceremonial heart of the Pemecutan dynasty."
        ),

        // 2. Pasar Badung Arcades
        GeoLibreBuilding(
            id: "bldg-pasar-badung",
            name: "Pasar Seni Badung",
            class: .marketHall,
            coordinates: [
                Coordinate(lat: -8.6538, lon: 115.2106),
                Coordinate(lat: -8.6538, lon: 115.2114),
                Coordinate(lat: -8.6548, lon: 115.2114),
                Coordinate(lat: -8.6548, lon: 115.2106)
            ],
            heightM: 13.0,
            levels: 4,
            roofType: .pitched,
            architecturalStyle: "Multi-level Traditional Riverside Market",
            historyNote: "Denpasar's central artisan and cultural craft market overlooking the Tukad Badung heritage riverbank."
        ),
        GeoLibreBuilding(
            id: "bldg-pasar-badung",
            name: "Pasar Badung Heritage Arcade",
            class: .marketHall,
            coordinates: [
                Coordinate(lat: -8.6538, lon: 115.2116),
                Coordinate(lat: -8.6538, lon: 115.2124),
                Coordinate(lat: -8.6548, lon: 115.2124),
                Coordinate(lat: -8.6548, lon: 115.2116)
            ],
            heightM: 14.0,
            levels: 4,
            roofType: .pitched,
            architecturalStyle: "Modernized Balinese Market Architecture",
            historyNote: "The oldest and largest traditional market in Bali, operating continuously since the 18th century."
        ),

        // 3. Museum Bali & Pura Agung Jagatnatha
        GeoLibreBuilding(
            id: "bldg-museum-bali-karangasem",
            name: "Museum Bali — Gedung Karangasem",
            class: .civic,
            coordinates: [
                Coordinate(lat: -8.6552, lon: 115.2190),
                Coordinate(lat: -8.6552, lon: 115.2198),
                Coordinate(lat: -8.6558, lon: 115.2198),
                Coordinate(lat: -8.6558, lon: 115.2190)
            ],
            heightM: 8.0,
            levels: 2,
            roofType: .balineseMeru,
            architecturalStyle: "Karangasem Royal Palace Style",
            historyNote: "Built in 1931 by Curt Grundler and Balinese master builders, showcasing sacred royal treasures."
        ),
        GeoLibreBuilding(
            id: "bldg-museum-bali-tabanan",
            name: "Museum Bali — Gedung Tabanan",
            class: .civic,
            coordinates: [
                Coordinate(lat: -8.6560, lon: 115.2190),
                Coordinate(lat: -8.6560, lon: 115.2198),
                Coordinate(lat: -8.6566, lon: 115.2198),
                Coordinate(lat: -8.6566, lon: 115.2190)
            ],
            heightM: 7.5,
            levels: 1,
            roofType: .limasan,
            architecturalStyle: "Tabanan Classical Architecture",
            historyNote: "Displays traditional Balinese musical gamelan instruments, dance masks, and shadow puppets."
        ),
        GeoLibreBuilding(
            id: "bldg-pura-jagatnatha-padmasana",
            name: "Padmasana Pura Agung Jagatnatha",
            class: .templeShrine,
            coordinates: [
                Coordinate(lat: -8.6568, lon: 115.2192),
                Coordinate(lat: -8.6568, lon: 115.2196),
                Coordinate(lat: -8.6572, lon: 115.2196),
                Coordinate(lat: -8.6572, lon: 115.2192)
            ],
            heightM: 16.0,
            levels: 5,
            roofType: .balineseMeru,
            architecturalStyle: "Sacred White Coral Padmasana Tower",
            historyNote: "The towering white stone lotus throne dedicated to Sang Hyang Widhi Wasa, the Supreme God."
        ),

        // 4. Jl. Gajah Mada Historic Shophouse Rows (Commercial Heritage)
        GeoLibreBuilding(
            id: "bldg-gajah-mada-north-shophouses",
            name: "Pertokoan Kuno Gajah Mada (Utara)",
            class: .commercialShophouse,
            coordinates: [
                Coordinate(lat: -8.6558, lon: 115.2085),
                Coordinate(lat: -8.6558, lon: 115.2105),
                Coordinate(lat: -8.6562, lon: 115.2105),
                Coordinate(lat: -8.6562, lon: 115.2085)
            ],
            heightM: 6.5,
            levels: 2,
            roofType: .shophouse,
            architecturalStyle: "Colonial Sino-Balinese Shophouse Arcade",
            historyNote: "Historic merchant storefronts with five-foot walkways (kaki lima) from the 1920s spice trade era."
        ),
        GeoLibreBuilding(
            id: "bldg-gajah-mada-south-shophouses",
            name: "Pertokoan Kuno Gajah Mada (Selatan)",
            class: .commercialShophouse,
            coordinates: [
                Coordinate(lat: -8.6566, lon: 115.2085),
                Coordinate(lat: -8.6566, lon: 115.2105),
                Coordinate(lat: -8.6570, lon: 115.2105),
                Coordinate(lat: -8.6570, lon: 115.2085)
            ],
            heightM: 6.5,
            levels: 2,
            roofType: .shophouse,
            architecturalStyle: "Colonial Sino-Balinese Shophouse Arcade",
            historyNote: "Traditional fabric, gold, and spice merchant stores along the primary heritage walking spine."
        ),

        // 5. Catur Muka & Municipal Quad Buildings
        GeoLibreBuilding(
            id: "bldg-kantor-pos-denpasar",
            name: "Kantor Pos Bersejarah Denpasar",
            class: .civic,
            coordinates: [
                Coordinate(lat: -8.6548, lon: 115.2150),
                Coordinate(lat: -8.6548, lon: 115.2158),
                Coordinate(lat: -8.6554, lon: 115.2158),
                Coordinate(lat: -8.6554, lon: 115.2150)
            ],
            heightM: 7.0,
            levels: 2,
            roofType: .limasan,
            architecturalStyle: "Dutch East Indies Colonial Indisch",
            historyNote: "The historic central telegraph and postal station constructed in 1920."
        ),
        GeoLibreBuilding(
            id: "bldg-jayasabha-residence",
            name: "Gedung Jayasabha (Kediaman Gubernur)",
            class: .civic,
            coordinates: [
                Coordinate(lat: -8.6538, lon: 115.2162),
                Coordinate(lat: -8.6538, lon: 115.2172),
                Coordinate(lat: -8.6544, lon: 115.2172),
                Coordinate(lat: -8.6544, lon: 115.2162)
            ],
            heightM: 8.5,
            levels: 2,
            roofType: .limasan,
            architecturalStyle: "Heritage Civic Indisch Architecture",
            historyNote: "Historic executive residence overlooking Lapangan Puputan Badung."
        ),
        
        // 6. Pura Maospahit (Trace 2)
        GeoLibreBuilding(
            id: "bldg-pura-maospahit",
            name: "Pura Maospahit",
            class: .templeShrine,
            coordinates: [
                Coordinate(lat: -8.6568, lon: 115.2083),
                Coordinate(lat: -8.6568, lon: 115.2087),
                Coordinate(lat: -8.6572, lon: 115.2087),
                Coordinate(lat: -8.6572, lon: 115.2083)
            ],
            heightM: 12.0,
            levels: 4,
            roofType: .balineseMeru,
            architecturalStyle: "Majapahit Terracotta Architecture",
            historyNote: "A rare Majapahit-era terracotta brick temple tucked inside the old quarter, adorned with ancient garuda motifs."
        ),

        // 7. Patung Catur Muka (Trace 4)
        GeoLibreBuilding(
            id: "bldg-catur-muka",
            name: "Patung Catur Muka",
            class: .templeShrine,
            coordinates: [
                Coordinate(lat: -8.65345, lon: 115.21595),
                Coordinate(lat: -8.65345, lon: 115.21605),
                Coordinate(lat: -8.65355, lon: 115.21605),
                Coordinate(lat: -8.65355, lon: 115.21595)
            ],
            heightM: 9.0,
            levels: 2,
            roofType: .balineseMeru,
            architecturalStyle: "Granite Statue Monument",
            historyNote: "The sacred catus patha intersection where four faces of Brahma gaze outward, marking the cosmological and administrative pivot of Denpasar."
        )
    ]
}
