import ContentKit

/// One quest marker on the illustrated map, at its start point.
///
/// A pin per quest rather than per Place: the map is a discovery surface, and a traveller choosing a
/// walk wants to see where walks *begin*. Marking all five stops of every quest would draw the
/// route's shape onto a map that is explicitly not a navigation aid (`FR-MAP-03`).
struct RegionMapPin: Sendable, Identifiable, Equatable {
    let questID: String
    let title: String
    let placeName: String
    let point: MapPoint
    let accessibilityLabel: String

    var id: String { questID }
}
