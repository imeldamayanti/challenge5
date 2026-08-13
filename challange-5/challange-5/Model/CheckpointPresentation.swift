import ContentKit
import Foundation

/// Everything the checkpoint screen draws, resolved once when the checkpoint is reached.
struct CheckpointPresentation: Sendable, Equatable, Identifiable {
    let id: String
    let orderIndex: Int
    let placeName: String
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
