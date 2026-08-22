import ContentKit

/// One quest marker on the discovery map, at its start point.
///
/// A pin per quest rather than per Place: the map is a discovery surface, and a traveller choosing a
/// walk wants to see where walks *begin*. Marking all five stops of every quest would draw the
/// route's shape onto a map that is explicitly not a navigation aid (`FR-MAP-03`).
///
/// It carries **both** positions, because the discovery map now has two grounds. `point` is the
/// authored `MapPoint`, which is what the illustration alone is drawn against and the only thing
/// the offline surface can use. `coordinate` is where the place actually is, which is what a real
/// basemap needs. Neither is derived from the other (`ContentKit.MapPoint`).
struct RegionMapPin: Sendable, Identifiable, Equatable {
    let questID: String
    let title: String
    let placeName: String
    /// The city (falling back to the region) a walk starts in — what `1026:3514`'s popover prints
    /// beside the pin. The start Place's official name is too long for that card.
    let regionName: String
    /// The quest's own total, in minutes (`route.totalDurationMin`).
    let durationMin: Int
    /// How many checkpoints the walk has.
    let stopCount: Int
    let point: MapPoint
    let coordinate: Coordinate
    let accessibilityLabel: String

    init(
        questID: String,
        title: String,
        placeName: String,
        regionName: String = "",
        durationMin: Int = 0,
        stopCount: Int = 0,
        point: MapPoint,
        coordinate: Coordinate,
        accessibilityLabel: String
    ) {
        self.questID = questID
        self.title = title
        self.placeName = placeName
        self.regionName = regionName
        self.durationMin = durationMin
        self.stopCount = stopCount
        self.point = point
        self.coordinate = coordinate
        self.accessibilityLabel = accessibilityLabel
    }

    var id: String { questID }
}
