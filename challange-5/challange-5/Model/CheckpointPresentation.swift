import ContentKit
import Foundation

/// Everything the checkpoint screen draws, resolved once when the checkpoint is reached.
struct CheckpointPresentation: Sendable, Equatable, Identifiable {
    let id: String
    let orderIndex: Int
    let placeName: String
    /// `Place.loreStandalone`, joined — the place's own general description, independent of the
    /// walk's narrative order. Authored and validated (`ContentValidator`'s `loreStandalone`
    /// citation check) since the schema shipped, but unrendered anywhere until the place-notice
    /// screen (`50:137`) gave it somewhere to appear.
    let placeDescription: String
    let isSacred: Bool
    /// `FR-TASK-05` — at a sacred Place the dress code and photo policy are shown *before* any task
    /// is offered. Held here so the view cannot render the tasks without them.
    let dressCodeText: String
    let photoPolicyText: String
    let claims: [LoreClaimPresentation]
    let clueToNext: String?
    let tasks: [ContentTask]
    let taskPrompts: [String: String]
    let coordinate: Coordinate
    let arrivalRadiusM: Int
    let isFinal: Bool
}
