import ContentKit
import Foundation

// MARK: - Bali Landmark Category

enum HisploraBaliLandmarkCategory: String, Sendable, CaseIterable, Identifiable {
    case all = "All"
    case pura = "Temples (Pura)"
    case puri = "Palaces (Puri)"
    case nature = "Mountains & Lakes"
    case village = "Heritage Villages"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .all: "map.fill"
        case .pura: "sparkles"
        case .puri: "crown.fill"
        case .nature: "mountain.2.fill"
        case .village: "house.lodge.fill"
        }
    }
}

// MARK: - Bali Landmark Presentation Model

struct HisploraBaliLandmark: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let regency: String
    let category: HisploraBaliLandmarkCategory
    let coordinate: Coordinate
    let summary: String
    let hasWalkingQuest: Bool
    let elevationM: Double?
    var distanceM: Double?

    var formattedDistance: String? {
        guard let dist = distanceM else { return nil }
        if dist < 1000 {
            return "\(Int(dist.rounded())) m away"
        } else {
            return String(format: "%.1f km away", dist / 1000.0)
        }
    }
}

// MARK: - Mountain Peak Model

struct HisploraMountainPeak: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let coordinate: Coordinate
    let elevationM: Int
}

// MARK: - Lake Polygon Model

struct HisploraLakePolygon: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let coordinates: [Coordinate]
}

// MARK: - Regency Boundary Model

struct HisploraRegencyBoundary: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let centerCoordinate: Coordinate
    let boundaryPoints: [Coordinate]
}

// MARK: - Highway Segment Model

struct HisploraHighwaySegment: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let coordinates: [Coordinate]
}

// MARK: - Whole Bali Geographic Dataset

enum HisploraBaliGeoData {

    /// Geographic bounding box of Bali and outlying islands.
    static let baliBounds: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) = (
        minLat: -8.900,
        maxLat: -8.050,
        minLon: 114.400,
        maxLon: 115.750
    )

    /// Center coordinate of Bali island (near Bedugul highlands).
    static let islandCenter = Coordinate(lat: -8.450, lon: 115.180)

    // MARK: - Mainland Bali Coastline Vector (High-Precision Polyline)

    static let mainlandCoastline: [Coordinate] = [
        // 1. Northwest Cape (Prapat Agung / West Bali National Park)
        Coordinate(lat: -8.140, lon: 114.440),
        Coordinate(lat: -8.125, lon: 114.475),
        Coordinate(lat: -8.130, lon: 114.530),
        Coordinate(lat: -8.150, lon: 114.600),

        // 2. North Coast (Buleleng / Lovina / Singaraja)
        Coordinate(lat: -8.165, lon: 114.720),
        Coordinate(lat: -8.180, lon: 114.850),
        Coordinate(lat: -8.160, lon: 114.980),
        Coordinate(lat: -8.145, lon: 115.050), // Lovina
        Coordinate(lat: -8.115, lon: 115.090), // Singaraja Port
        Coordinate(lat: -8.090, lon: 115.170), // Sangsit
        Coordinate(lat: -8.085, lon: 115.240), // Kubutambahan
        Coordinate(lat: -8.110, lon: 115.340), // Tejakula
        Coordinate(lat: -8.150, lon: 115.420), // Sambirenteng
        Coordinate(lat: -8.200, lon: 115.490), // Tianyar
        Coordinate(lat: -8.260, lon: 115.570), // Kubu

        // 3. Northeast & East Cape (Karangasem / Tulamben / Amed / Tanjung Seraya)
        Coordinate(lat: -8.280, lon: 115.600), // Tulamben
        Coordinate(lat: -8.320, lon: 115.640),
        Coordinate(lat: -8.345, lon: 115.685), // Amed
        Coordinate(lat: -8.370, lon: 115.710),
        Coordinate(lat: -8.410, lon: 115.720), // Tanjung Seraya (Easternmost point)
        Coordinate(lat: -8.460, lon: 115.680), // Ujung Water Palace coast
        Coordinate(lat: -8.490, lon: 115.630), // Candidasa
        Coordinate(lat: -8.530, lon: 115.510), // Padangbai Harbour

        // 4. Southeast Coast (Klungkung & Gianyar / Kusamba / Sanur)
        Coordinate(lat: -8.555, lon: 115.440), // Kusamba
        Coordinate(lat: -8.570, lon: 115.370), // Lebih Beach
        Coordinate(lat: -8.600, lon: 115.310), // Ketewel / Sukawati coast
        Coordinate(lat: -8.640, lon: 115.275), // Sanur North
        Coordinate(lat: -8.690, lon: 115.265), // Sanur Beach
        Coordinate(lat: -8.720, lon: 115.245), // Serangan / Benoa Inlet

        // 5. Southern Peninsula (Bukit Peninsula / Nusa Dua / Uluwatu)
        Coordinate(lat: -8.760, lon: 115.230), // Tanjung Benoa
        Coordinate(lat: -8.800, lon: 115.235), // Nusa Dua
        Coordinate(lat: -8.840, lon: 115.190), // Pandawa / Kutuh
        Coordinate(lat: -8.850, lon: 115.150), // Ungasan (Southernmost point)
        Coordinate(lat: -8.835, lon: 115.085), // Pura Uluwatu Cliff
        Coordinate(lat: -8.795, lon: 115.105), // Balangan / Dreamland
        Coordinate(lat: -8.765, lon: 115.145), // Jimbaran Bay

        // 6. Southwest Coast (Kuta / Seminyak / Canggu / Tabanan)
        Coordinate(lat: -8.730, lon: 115.165), // Tuban / Airport
        Coordinate(lat: -8.715, lon: 115.168), // Kuta Beach
        Coordinate(lat: -8.685, lon: 115.150), // Seminyak
        Coordinate(lat: -8.655, lon: 115.130), // Canggu
        Coordinate(lat: -8.620, lon: 115.085), // Tanah Lot
        Coordinate(lat: -8.580, lon: 115.030), // Kediri Coast
        Coordinate(lat: -8.540, lon: 114.970), // Antosari Coast
        Coordinate(lat: -8.510, lon: 114.900), // Balian Beach

        // 7. West Coast (Jembrana / Medewi / Negara / Gilimanuk)
        Coordinate(lat: -8.460, lon: 114.810), // Medewi
        Coordinate(lat: -8.410, lon: 114.710), // Yeh Embang
        Coordinate(lat: -8.375, lon: 114.610), // Perancak / Negara
        Coordinate(lat: -8.320, lon: 114.510), // Candikusuma
        Coordinate(lat: -8.240, lon: 114.440), // Melaya
        Coordinate(lat: -8.165, lon: 114.430), // Gilimanuk Ferry Port
        Coordinate(lat: -8.140, lon: 114.440)  // Close loop back to Prapat Agung
    ]

    // MARK: - Outlying Islands

    /// Nusa Penida Coastline
    static let nusaPenidaCoastline: [Coordinate] = [
        Coordinate(lat: -8.670, lon: 115.500), // Toyapakeh
        Coordinate(lat: -8.665, lon: 115.545), // Sampalan / Buyuk
        Coordinate(lat: -8.680, lon: 115.580), // Ped
        Coordinate(lat: -8.710, lon: 115.610), // Suana
        Coordinate(lat: -8.770, lon: 115.620), // Atuh / Diamond Beach
        Coordinate(lat: -8.810, lon: 115.580), // Tanglad
        Coordinate(lat: -8.815, lon: 115.530), // Peguyangan Waterfall
        Coordinate(lat: -8.775, lon: 115.480), // Kelingking T-Rex Cliff
        Coordinate(lat: -8.730, lon: 115.445), // Crystal Bay / Broken Beach
        Coordinate(lat: -8.690, lon: 115.465),
        Coordinate(lat: -8.670, lon: 115.500)
    ]

    /// Nusa Lembongan Coastline
    static let nusaLembonganCoastline: [Coordinate] = [
        Coordinate(lat: -8.660, lon: 115.435),
        Coordinate(lat: -8.665, lon: 115.455),
        Coordinate(lat: -8.685, lon: 115.460),
        Coordinate(lat: -8.700, lon: 115.440),
        Coordinate(lat: -8.685, lon: 115.425),
        Coordinate(lat: -8.660, lon: 115.435)
    ]

    /// Nusa Ceningan Coastline
    static let nusaCeninganCoastline: [Coordinate] = [
        Coordinate(lat: -8.690, lon: 115.445),
        Coordinate(lat: -8.695, lon: 115.460),
        Coordinate(lat: -8.715, lon: 115.455),
        Coordinate(lat: -8.710, lon: 115.440),
        Coordinate(lat: -8.690, lon: 115.445)
    ]

    /// Pulau Menjangan (West Bali Marine Sanctuary)
    static let pulauMenjanganCoastline: [Coordinate] = [
        Coordinate(lat: -8.095, lon: 114.500),
        Coordinate(lat: -8.090, lon: 114.530),
        Coordinate(lat: -8.105, lon: 114.535),
        Coordinate(lat: -8.105, lon: 114.505),
        Coordinate(lat: -8.095, lon: 114.500)
    ]

    // MARK: - Sacred Volcanic Peaks & Mountains

    static let mountainPeaks: [HisploraMountainPeak] = [
        HisploraMountainPeak(
            id: "gunung-agung",
            name: "Gunung Agung",
            coordinate: Coordinate(lat: -8.343, lon: 115.508),
            elevationM: 3142
        ),
        HisploraMountainPeak(
            id: "gunung-batur",
            name: "Gunung Batur",
            coordinate: Coordinate(lat: -8.242, lon: 115.375),
            elevationM: 1717
        ),
        HisploraMountainPeak(
            id: "gunung-abang",
            name: "Gunung Abang",
            coordinate: Coordinate(lat: -8.283, lon: 115.429),
            elevationM: 2151
        ),
        HisploraMountainPeak(
            id: "gunung-batukaru",
            name: "Gunung Batukaru",
            coordinate: Coordinate(lat: -8.337, lon: 115.088),
            elevationM: 2276
        ),
        HisploraMountainPeak(
            id: "gunung-bratan",
            name: "Puncak Mangu / Bratan",
            coordinate: Coordinate(lat: -8.272, lon: 115.176),
            elevationM: 2020
        ),
        HisploraMountainPeak(
            id: "gunung-catur",
            name: "Gunung Catur",
            coordinate: Coordinate(lat: -8.261, lon: 115.195),
            elevationM: 2096
        )
    ]

    // MARK: - Sacred Highland Crater Lakes

    static let lakes: [HisploraLakePolygon] = [
        // Danau Batur (Crescent caldera lake in Kintamani)
        HisploraLakePolygon(
            id: "danau-batur",
            name: "Danau Batur",
            coordinates: [
                Coordinate(lat: -8.250, lon: 115.390),
                Coordinate(lat: -8.240, lon: 115.410),
                Coordinate(lat: -8.255, lon: 115.430),
                Coordinate(lat: -8.280, lon: 115.435),
                Coordinate(lat: -8.305, lon: 115.420),
                Coordinate(lat: -8.295, lon: 115.400),
                Coordinate(lat: -8.270, lon: 115.395),
                Coordinate(lat: -8.250, lon: 115.390)
            ]
        ),
        // Danau Beratan (Bedugul temple lake)
        HisploraLakePolygon(
            id: "danau-beratan",
            name: "Danau Beratan",
            coordinates: [
                Coordinate(lat: -8.270, lon: 115.160),
                Coordinate(lat: -8.265, lon: 115.175),
                Coordinate(lat: -8.280, lon: 115.185),
                Coordinate(lat: -8.295, lon: 115.170),
                Coordinate(lat: -8.285, lon: 115.155),
                Coordinate(lat: -8.270, lon: 115.160)
            ]
        ),
        // Danau Buyan
        HisploraLakePolygon(
            id: "danau-buyan",
            name: "Danau Buyan",
            coordinates: [
                Coordinate(lat: -8.240, lon: 115.130),
                Coordinate(lat: -8.235, lon: 115.155),
                Coordinate(lat: -8.250, lon: 115.160),
                Coordinate(lat: -8.255, lon: 115.135),
                Coordinate(lat: -8.240, lon: 115.130)
            ]
        ),
        // Danau Tamblingan
        HisploraLakePolygon(
            id: "danau-tamblingan",
            name: "Danau Tamblingan",
            coordinates: [
                Coordinate(lat: -8.245, lon: 115.095),
                Coordinate(lat: -8.240, lon: 115.110),
                Coordinate(lat: -8.255, lon: 115.115),
                Coordinate(lat: -8.260, lon: 115.100),
                Coordinate(lat: -8.245, lon: 115.095)
            ]
        )
    ]

    // MARK: - Major Island Arterial Highways & Heritage Roads

    static let highways: [HisploraHighwaySegment] = [
        // 1. South to West Main Highway: Denpasar -> Tabanan -> Negara -> Gilimanuk
        HisploraHighwaySegment(
            id: "highway-south-west",
            name: "Jalur Denpasar – Gilimanuk",
            coordinates: [
                Coordinate(lat: -8.656, lon: 115.212), // Denpasar
                Coordinate(lat: -8.540, lon: 115.120), // Tabanan
                Coordinate(lat: -8.500, lon: 115.000), // Antosari
                Coordinate(lat: -8.450, lon: 114.820), // Medewi
                Coordinate(lat: -8.360, lon: 114.620), // Negara
                Coordinate(lat: -8.240, lon: 114.470), // Melaya
                Coordinate(lat: -8.165, lon: 114.435)  // Gilimanuk
            ]
        ),
        // 2. Central Ridge Highway: Denpasar -> Mengwi -> Bedugul -> Gitgit -> Singaraja
        HisploraHighwaySegment(
            id: "highway-central-north",
            name: "Jalur Denpasar – Singaraja (Bedugul)",
            coordinates: [
                Coordinate(lat: -8.656, lon: 115.212), // Denpasar
                Coordinate(lat: -8.580, lon: 115.170), // Mengwi
                Coordinate(lat: -8.440, lon: 115.180), // Baturiti
                Coordinate(lat: -8.280, lon: 115.165), // Bedugul
                Coordinate(lat: -8.200, lon: 115.140), // Gitgit
                Coordinate(lat: -8.115, lon: 115.090)  // Singaraja
            ]
        ),
        // 3. East Coast Highway: Denpasar -> Gianyar -> Klungkung -> Padangbai -> Amlapura
        HisploraHighwaySegment(
            id: "highway-south-east",
            name: "Jalur Denpasar – Amlapura",
            coordinates: [
                Coordinate(lat: -8.656, lon: 115.212), // Denpasar
                Coordinate(lat: -8.540, lon: 115.325), // Gianyar
                Coordinate(lat: -8.535, lon: 115.405), // Klungkung (Semarapura)
                Coordinate(lat: -8.530, lon: 115.510), // Padangbai
                Coordinate(lat: -8.490, lon: 115.610), // Candidasa
                Coordinate(lat: -8.450, lon: 115.615)  // Amlapura (Karangasem)
            ]
        ),
        // 4. Kintamani Highlands Highway: Denpasar -> Ubud -> Payangan -> Kintamani -> Singaraja
        HisploraHighwaySegment(
            id: "highway-kintamani",
            name: "Jalur Ubud – Kintamani",
            coordinates: [
                Coordinate(lat: -8.656, lon: 115.212), // Denpasar
                Coordinate(lat: -8.505, lon: 115.263), // Ubud
                Coordinate(lat: -8.410, lon: 115.255), // Payangan
                Coordinate(lat: -8.260, lon: 115.345), // Penelokan / Kintamani
                Coordinate(lat: -8.115, lon: 115.090)  // Singaraja
            ]
        ),
        // 5. North Coast Highway: Singaraja -> Kubutambahan -> Tejakula -> Tulamben -> Amed
        HisploraHighwaySegment(
            id: "highway-north-coast",
            name: "Jalur Pesisir Utara",
            coordinates: [
                Coordinate(lat: -8.115, lon: 115.090), // Singaraja
                Coordinate(lat: -8.085, lon: 115.240), // Kubutambahan
                Coordinate(lat: -8.110, lon: 115.340), // Tejakula
                Coordinate(lat: -8.280, lon: 115.600), // Tulamben
                Coordinate(lat: -8.345, lon: 115.685)  // Amed
            ]
        ),
        // 6. South Peninsula Highway: Denpasar -> Jimbaran -> Uluwatu / Nusa Dua
        HisploraHighwaySegment(
            id: "highway-south-peninsula",
            name: "Jalur Bukit & Nusa Dua",
            coordinates: [
                Coordinate(lat: -8.656, lon: 115.212), // Denpasar
                Coordinate(lat: -8.720, lon: 115.170), // Tuban
                Coordinate(lat: -8.770, lon: 115.160), // Jimbaran
                Coordinate(lat: -8.800, lon: 115.225), // Nusa Dua
                Coordinate(lat: -8.835, lon: 115.085)  // Uluwatu
            ]
        )
    ]

    // MARK: - 9 Regency Cultural Capitals & Hubs

    static let regencies: [HisploraRegencyBoundary] = [
        HisploraRegencyBoundary(
            id: "regency-denpasar",
            name: "Kota Denpasar",
            centerCoordinate: Coordinate(lat: -8.6565, lon: 115.2125),
            boundaryPoints: [Coordinate(lat: -8.62, lon: 115.18), Coordinate(lat: -8.62, lon: 115.27), Coordinate(lat: -8.72, lon: 115.25), Coordinate(lat: -8.70, lon: 115.18)]
        ),
        HisploraRegencyBoundary(
            id: "regency-badung",
            name: "Kab. Badung",
            centerCoordinate: Coordinate(lat: -8.5800, lon: 115.1700),
            boundaryPoints: [Coordinate(lat: -8.45, lon: 115.18), Coordinate(lat: -8.50, lon: 115.22), Coordinate(lat: -8.85, lon: 115.15), Coordinate(lat: -8.65, lon: 115.12)]
        ),
        HisploraRegencyBoundary(
            id: "regency-gianyar",
            name: "Kab. Gianyar",
            centerCoordinate: Coordinate(lat: -8.5400, lon: 115.3250),
            boundaryPoints: [Coordinate(lat: -8.35, lon: 115.30), Coordinate(lat: -8.40, lon: 115.38), Coordinate(lat: -8.60, lon: 115.30), Coordinate(lat: -8.50, lon: 115.24)]
        ),
        HisploraRegencyBoundary(
            id: "regency-tabanan",
            name: "Kab. Tabanan",
            centerCoordinate: Coordinate(lat: -8.5400, lon: 115.1200),
            boundaryPoints: [Coordinate(lat: -8.28, lon: 115.15), Coordinate(lat: -8.35, lon: 115.00), Coordinate(lat: -8.58, lon: 115.03), Coordinate(lat: -8.55, lon: 115.15)]
        ),
        HisploraRegencyBoundary(
            id: "regency-bangli",
            name: "Kab. Bangli",
            centerCoordinate: Coordinate(lat: -8.4500, lon: 115.3500),
            boundaryPoints: [Coordinate(lat: -8.20, lon: 115.35), Coordinate(lat: -8.25, lon: 115.42), Coordinate(lat: -8.50, lon: 115.36), Coordinate(lat: -8.45, lon: 115.32)]
        ),
        HisploraRegencyBoundary(
            id: "regency-klungkung",
            name: "Kab. Klungkung",
            centerCoordinate: Coordinate(lat: -8.5350, lon: 115.4050),
            boundaryPoints: [Coordinate(lat: -8.50, lon: 115.38), Coordinate(lat: -8.52, lon: 115.45), Coordinate(lat: -8.56, lon: 115.42), Coordinate(lat: -8.55, lon: 115.38)]
        ),
        HisploraRegencyBoundary(
            id: "regency-karangasem",
            name: "Kab. Karangasem",
            centerCoordinate: Coordinate(lat: -8.4500, lon: 115.6150),
            boundaryPoints: [Coordinate(lat: -8.20, lon: 115.50), Coordinate(lat: -8.40, lon: 115.72), Coordinate(lat: -8.53, lon: 115.51), Coordinate(lat: -8.40, lon: 115.45)]
        ),
        HisploraRegencyBoundary(
            id: "regency-buleleng",
            name: "Kab. Buleleng",
            centerCoordinate: Coordinate(lat: -8.1150, lon: 115.0900),
            boundaryPoints: [Coordinate(lat: -8.10, lon: 114.45), Coordinate(lat: -8.08, lon: 115.25), Coordinate(lat: -8.25, lon: 115.15), Coordinate(lat: -8.20, lon: 114.70)]
        ),
        HisploraRegencyBoundary(
            id: "regency-jembrana",
            name: "Kab. Jembrana",
            centerCoordinate: Coordinate(lat: -8.3600, lon: 114.6200),
            boundaryPoints: [Coordinate(lat: -8.16, lon: 114.43), Coordinate(lat: -8.25, lon: 114.90), Coordinate(lat: -8.46, lon: 114.81), Coordinate(lat: -8.35, lon: 114.50)]
        )
    ]

    // MARK: - Cultural Heritage Landmarks & Quest Hubs Across Bali

    static let landmarks: [HisploraBaliLandmark] = [
        // 1. Pura Besakih (The Mother Temple of Bali)
        HisploraBaliLandmark(
            id: "pura-besakih",
            name: "Pura Besakih",
            regency: "Karangasem",
            category: .pura,
            coordinate: Coordinate(lat: -8.3739, lon: 115.4522),
            summary: "The holiest and grandest temple complex in Bali, perched on the sacred slopes of Gunung Agung.",
            hasWalkingQuest: true,
            elevationM: 900
        ),
        // 2. Pura Ulun Danu Beratan
        HisploraBaliLandmark(
            id: "pura-ulun-danu-beratan",
            name: "Pura Ulun Danu Beratan",
            regency: "Tabanan",
            category: .pura,
            coordinate: Coordinate(lat: -8.2750, lon: 115.1650),
            summary: "Iconic floating water temple dedicated to Dewi Danu on the misty volcanic Lake Beratan.",
            hasWalkingQuest: true,
            elevationM: 1240
        ),
        // 3. Pura Tanah Lot
        HisploraBaliLandmark(
            id: "pura-tanah-lot",
            name: "Pura Tanah Lot",
            regency: "Tabanan",
            category: .pura,
            coordinate: Coordinate(lat: -8.6212, lon: 115.0868),
            summary: "Ancient sea temple built atop an offshore rock formation by Dang Hyang Nirartha in the 16th century.",
            hasWalkingQuest: true,
            elevationM: 15
        ),
        // 4. Pura Luhur Uluwatu
        HisploraBaliLandmark(
            id: "pura-luhur-uluwatu",
            name: "Pura Luhur Uluwatu",
            regency: "Badung",
            category: .pura,
            coordinate: Coordinate(lat: -8.8291, lon: 115.0849),
            summary: "One of Bali's six key spiritual pillars (Sad Kahyangan), standing dramatically on a 70-meter limestone sea cliff.",
            hasWalkingQuest: true,
            elevationM: 70
        ),
        // 5. Puri Saren Agung (Ubud Royal Palace)
        HisploraBaliLandmark(
            id: "puri-saren-agung-ubud",
            name: "Puri Saren Agung",
            regency: "Gianyar",
            category: .puri,
            coordinate: Coordinate(lat: -8.5069, lon: 115.2625),
            summary: "Historical royal residence and epicenter of Balinese classical dance, architecture, and literature in Ubud.",
            hasWalkingQuest: true,
            elevationM: 200
        ),
        // 6. Pura Tirta Empul
        HisploraBaliLandmark(
            id: "pura-tirta-empul",
            name: "Pura Tirta Empul",
            regency: "Gianyar",
            category: .pura,
            coordinate: Coordinate(lat: -8.4150, lon: 115.3150),
            summary: "Sacred water temple founded in 962 AD around a natural holy spring revered for ritual purification (Melukat).",
            hasWalkingQuest: true,
            elevationM: 450
        ),
        // 7. Jatiluwih UNESCO Rice Terraces
        HisploraBaliLandmark(
            id: "jatiluwih-rice-terraces",
            name: "Jatiluwih Rice Terraces",
            regency: "Tabanan",
            category: .nature,
            coordinate: Coordinate(lat: -8.3694, lon: 115.1311),
            summary: "Living UNESCO Cultural Landscape demonstrating the ancient communal Subak irrigation philosophy of Tri Hita Karana.",
            hasWalkingQuest: true,
            elevationM: 700
        ),
        // 8. Desa Adat Penglipuran
        HisploraBaliLandmark(
            id: "desa-penglipuran",
            name: "Desa Adat Penglipuran",
            regency: "Bangli",
            category: .village,
            coordinate: Coordinate(lat: -8.4528, lon: 115.3575),
            summary: "Immaculately preserved traditional Balinese village renowned for uniform bamboo gates (angkul-angkul) and ancestral order.",
            hasWalkingQuest: true,
            elevationM: 620
        ),
        // 9. Pura Lempuyang Luhur
        HisploraBaliLandmark(
            id: "pura-lempuyang-luhur",
            name: "Pura Lempuyang Luhur",
            regency: "Karangasem",
            category: .pura,
            coordinate: Coordinate(lat: -8.3917, lon: 115.6300),
            summary: "Revered mountain sanctuary overlooking Gunung Agung through its iconic Candibentar split gateway.",
            hasWalkingQuest: true,
            elevationM: 1050
        ),
        // 10. Goa Gajah (Elephant Cave)
        HisploraBaliLandmark(
            id: "goa-gajah",
            name: "Goa Gajah & Yeh Pulu",
            regency: "Gianyar",
            category: .pura,
            coordinate: Coordinate(lat: -8.5233, lon: 115.2872),
            summary: "11th-century rock-cut sanctuary with demonic face portal, meditation niches, and ancient relic bathing pools.",
            hasWalkingQuest: true,
            elevationM: 180
        ),
        // 11. Taman Ayun Mengwi
        HisploraBaliLandmark(
            id: "taman-ayun-mengwi",
            name: "Pura Taman Ayun",
            regency: "Badung",
            category: .puri,
            coordinate: Coordinate(lat: -8.5392, lon: 115.1725),
            summary: "The royal water temple of the Mengwi Kingdom, built in 1634 with multi-tiered Meru shrines surrounded by lotus moats.",
            hasWalkingQuest: true,
            elevationM: 140
        ),
        // 12. Kerta Gosa Pavilion
        HisploraBaliLandmark(
            id: "kerta-gosa",
            name: "Kerta Gosa & Taman Gili",
            regency: "Klungkung",
            category: .puri,
            coordinate: Coordinate(lat: -8.5356, lon: 115.4039),
            summary: "Historic 18th-century hall of state justice featuring classic Kamasan-style ceiling frescoes depicting karmic law.",
            hasWalkingQuest: true,
            elevationM: 80
        ),
        // 13. Desa Adat Tenganan Pegringsingan
        HisploraBaliLandmark(
            id: "desa-tenganan",
            name: "Tenganan Pegringsingan",
            regency: "Karangasem",
            category: .village,
            coordinate: Coordinate(lat: -8.4756, lon: 115.5658),
            summary: "Ancient Bali Aga settlement maintaining pre-Majapahit customs, stone architecture, and sacred double-ikat weaving.",
            hasWalkingQuest: true,
            elevationM: 150
        ),
        // 14. Tirta Gangga Water Palace
        HisploraBaliLandmark(
            id: "tirta-gangga",
            name: "Taman Tirta Gangga",
            regency: "Karangasem",
            category: .puri,
            coordinate: Coordinate(lat: -8.4122, lon: 115.5872),
            summary: "Lavish 1946 royal water garden built by the last Raja of Karangasem with stepping stones across lotus fountains.",
            hasWalkingQuest: true,
            elevationM: 280
        ),
        // 15. Pura Pulaki & Menjangan
        HisploraBaliLandmark(
            id: "pura-pulaki",
            name: "Pura Pulaki & Menjangan",
            regency: "Buleleng",
            category: .pura,
            coordinate: Coordinate(lat: -8.1472, lon: 114.6750),
            summary: "Coastal cliffside temple guarding the northwest sea passage, associated with Dang Hyang Nirartha and sacred deer.",
            hasWalkingQuest: true,
            elevationM: 30
        ),
        // 16. Denpasar Historic Heritage District
        HisploraBaliLandmark(
            id: "denpasar-heritage-district",
            name: "Puri Agung Pemecutan & Catur Muka",
            regency: "Kota Denpasar",
            category: .puri,
            coordinate: Coordinate(lat: -8.6565, lon: 115.2125),
            summary: "The historical royal core of Denpasar, birthplace of the Badung kingdom, Puputan monument, and ancient market squares.",
            hasWalkingQuest: true,
            elevationM: 35
        )
    ]
}
