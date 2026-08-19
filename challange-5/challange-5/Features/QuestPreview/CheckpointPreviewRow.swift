import Foundation

/// One row in the preview's checkpoint list.
///
/// There is deliberately no field here that could hold a lore segment or a clue. `FR-DISC-04` says
/// Place names and the map are shown and the story is not, and the cheapest way to keep that true is
/// to leave nowhere to put it.
struct CheckpointPreviewRow: Sendable, Identifiable, Equatable {
    let id: String
    let orderIndex: Int
    /// `NFR-I18N-04` — the official local form, in either interface language.
    let placeName: String
    let isSacred: Bool
    let dressCodeText: String
    let photoPolicyText: String
    /// `NFR-A11Y-07` — nil when the Place has no steps, so the disclosure is honest either way.
    let stepsText: String?
    let surfaceText: String
    let accessibilityNotes: String
    let openingText: String
}
