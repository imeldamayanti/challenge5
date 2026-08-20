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
    /// The same `Place.loreStandalone` as `placeDescription`, but as labelled claims rather than
    /// joined prose — what `QuestExplanationScreen` (`1:4609`) prints, with the accuracy label and
    /// the citation `FR-CP-05` asks for.
    ///
    /// Both forms are carried because the two screens want different things: the place notice sets
    /// the description as a paragraph of scene-setting before a walker steps in, and the explanation
    /// screen presents the same sentences as sourced claims after a task. That the words are
    /// identical is a content gap, not a rendering one — see the note on `QuestExplanationScreen`.
    let standaloneClaims: [LoreClaimPresentation]
    let clueToNext: String?
    let tasks: [ContentTask]
    let taskPrompts: [String: String]
    let coordinate: Coordinate
    let arrivalRadiusM: Int
    let isFinal: Bool
    /// The plan of these grounds, when the Place ships one (`452:3028`). Nil for the four stops that
    /// are a temple wall, a market floor, a road junction and a museum — none of which the content
    /// tree carries a plan for, and none of which should show an empty frame where one would be.
    let siteMap: SiteMapPresentation?
    /// The drawn map of the streets around these grounds, when the Place ships one (`1:4458`). Nil
    /// for every stop the content tree carries no approach map for — the Location Verified screen
    /// then falls back to the run's own projected route, which is what it drew before any place had
    /// one.
    let approachMap: ApproachMapPresentation?
}
