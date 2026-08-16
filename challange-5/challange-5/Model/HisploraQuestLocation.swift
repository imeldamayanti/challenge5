import ContentKit
import Foundation

/// State of a cultural trace / quest location on the heritage map.
enum HisploraTraceState: String, Sendable, Equatable {
    case uncompleted
    case active
    case completed
}

struct HisploraQuestLocation: Identifiable, Sendable, Equatable {
    let id: String
    let traceNumber: Int
    let title: String
    let subtitle: String
    let summary: String
    let coordinate: Coordinate
    let arrivalRadiusM: Double
    var state: HisploraTraceState
    var distanceM: Double?
    let placeId: String?

    init(
        id: String,
        traceNumber: Int,
        title: String,
        subtitle: String,
        summary: String = "",
        coordinate: Coordinate,
        arrivalRadiusM: Double = 75,
        state: HisploraTraceState = .uncompleted,
        distanceM: Double? = nil,
        placeId: String? = nil
    ) {
        self.id = id
        self.traceNumber = traceNumber
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.coordinate = coordinate
        self.arrivalRadiusM = arrivalRadiusM
        self.state = state
        self.distanceM = distanceM
        self.placeId = placeId
    }

    /// Formatted distance string (e.g., "280 m away", "1.2 km away").
    var distanceText: String? {
        guard let meters = distanceM else { return nil }
        if meters < 1000 {
            return "\(Int(meters.rounded())) m away"
        } else {
            return String(format: "%.1f km away", meters / 1000.0)
        }
    }

    /// Default heritage traces in Badung/Denpasar for the Badung Empat Wajah quest line.
    static let badungTraces: [HisploraQuestLocation] = [
        HisploraQuestLocation(
            id: "trace-01",
            traceNumber: 1,
            title: "PURI AGUNG PEMECUTAN",
            subtitle: "The Royal Gate",
            summary: "Standing on the western edge of old Denpasar, the royal seat of Pemecutan preserves centuries of royal lineage and ancient Balinese statecraft.",
            coordinate: Coordinate(lat: -8.6595, lon: 115.2077),
            arrivalRadiusM: 75,
            state: .completed,
            distanceM: 420,
            placeId: "badung-puri-agung-pemecutan"
        ),
        HisploraQuestLocation(
            id: "trace-02",
            traceNumber: 2,
            title: "PURA MAOSPAHIT",
            subtitle: "The Terracotta Sanctuary",
            summary: "A rare Majapahit-era terracotta brick temple tucked inside the old quarter, adorned with ancient garuda motifs and red earthen courtyards.",
            coordinate: Coordinate(lat: -8.6570, lon: 115.2085),
            arrivalRadiusM: 65,
            state: .active,
            distanceM: 280,
            placeId: "badung-pura-maospahit"
        ),
        HisploraQuestLocation(
            id: "trace-03",
            traceNumber: 3,
            title: "PASAR KUMBASARI",
            subtitle: "The River Marketplace",
            summary: "Lining the eastern bank of Tukad Badung, this multi-tiered traditional market has been the trading heart of Badung for generations.",
            coordinate: Coordinate(lat: -8.6540, lon: 115.2115),
            arrivalRadiusM: 80,
            state: .uncompleted,
            distanceM: 650,
            placeId: "badung-pasar-kumbasari"
        ),
        HisploraQuestLocation(
            id: "trace-04",
            traceNumber: 4,
            title: "PATUNG CATUR MUKA",
            subtitle: "Crossroads of Four Realms",
            summary: "The sacred catus patha intersection where four faces of Brahma gaze outward, marking the cosmological and administrative pivot of Denpasar.",
            coordinate: Coordinate(lat: -8.6535, lon: 115.2160),
            arrivalRadiusM: 70,
            state: .uncompleted,
            distanceM: 920,
            placeId: "badung-catur-muka"
        ),
        HisploraQuestLocation(
            id: "trace-05",
            traceNumber: 5,
            title: "LAPANGAN PUPUTAN BADUNG",
            subtitle: "Grounds of the Last Stand",
            summary: "The historic memorial field and Museum Bali compound where the 1906 Puputan occurred, marking the solemn transition into modern history.",
            coordinate: Coordinate(lat: -8.6560, lon: 115.2172),
            arrivalRadiusM: 90,
            state: .uncompleted,
            distanceM: 1150,
            placeId: "badung-museum-bali"
        )
    ]
}
