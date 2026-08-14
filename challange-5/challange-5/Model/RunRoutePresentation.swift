import ContentKit

/// One stop as the run map draws it.
struct RunRouteStop: Identifiable, Equatable {
    var id: Int { orderIndex }
    let orderIndex: Int
    let coordinate: Coordinate
    /// Already walked. Drawn filled, so the sequence reads as progress and not as a list of pins.
    let isReached: Bool
    /// The one being walked to now.
    let isTarget: Bool
}

/// Everything `FR-MAP-02` asks the run map to show, resolved from content and the last fix:
/// the ordered checkpoint sequence, the walker's position relative to the next checkpoint, and the
/// straight-line distance remaining.
///
/// No lore and no clue text reaches this type. Drawing the route reveals the sequence of stops,
/// which the preview already reveals (`FR-DISC-04` withholds the story, not the map) — but the
/// story itself stays where it is.
struct RunRoutePresentation: Equatable {
    /// The authored walking line, for drawing only. Distances are never measured off it —
    /// `NFR-CONT-05` reserves route length for real walking directions.
    let line: [Coordinate]
    let stops: [RunRouteStop]
    let target: Coordinate?
    let targetRadiusM: Double
    /// The last fix, or nil when there is none yet. With no fix the map still draws the route and
    /// the stops, which is the location preview the walk otherwise lacks.
    let userPosition: Coordinate?
    /// Formatted by the same formatter the status card uses, so the two cannot print different
    /// numbers for the same gap.
    let distanceRemainingText: String?
    let targetName: String
}
