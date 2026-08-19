import DesignSystem

/// Which of the three packaged drawings the region map stands on a given quest.
///
/// The table lives here, in the app target, and not on `Quest` — for the same reason
/// `StampArtworkCatalog` does. The drawings are part of the visual direction and are replaced with
/// it; a `ContentKit` field for them would make the illustration a content decision and would have
/// to survive a content update that has nothing to say about it (`AD-4`).
///
/// A quest with no entry gets the temple, which is the frame's own default and is generic Balinese
/// architecture rather than a picture of somewhere the quest does not go. That is the honest
/// fallback and also the debt: a second authored quest gets the same drawing as the first until
/// this table is edited.
enum MapLandmarkCatalog {

    /// Figma `275:2309` stands the naga gate on "The Last Traces of Badung", the dancers on "Where
    /// the Gods Come to Dance", and the meru on the other two.
    private static let byQuestID: [String: MapLandmarkArtwork] = [
        "badung-empat-wajah": .naga,
    ]

    static func artwork(forQuestID id: String) -> MapLandmarkArtwork {
        byQuestID[id] ?? .temple
    }
}
