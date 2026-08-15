import ContentKit
import Foundation

/// The three extra cards the Ngalcer Home frame draws below the first one (`28:99`, `28:122`,
/// `28:145`), so the screen can be seen the way it was designed.
///
/// **These are not content.** The shipped content tree holds exactly one authored quest
/// (`badung-empat-wajah`) and the frame draws four cards. Everything below is filler: there is no
/// place record, no consent record, no route, no coordinate and no citation behind any of it, and
/// the titles and figures are the frame's own placeholder copy. Nothing here reaches
/// `ContentRepository`, nothing is persisted, and the cards do not open — a card that looked
/// walkable and went nowhere would be worse than a gap.
///
/// Two structural consequences, both deliberate:
///
/// - It lives in `Support/` beside `WireframeCatalog`, which holds the same kind of thing for the
///   unbuilt screens, and **not** in `ContentKit`. Authoring it as content would have to clear
///   rules V1–V18 and a consent record per place, which is exactly the gate it must not slip past.
/// - The photographs are `dummy-quest-*` imagesets in the app target's asset catalogue, not
///   `Content/assets/`. Content assets are replaced wholesale by a content update; these travel
///   with the build and are deleted with this file.
///
/// The photographs came out of the Figma frame and their provenance is unrecorded — they must not
/// survive into anything public. See `docs/consent-log.md` for the same problem in the content
/// tree.
struct PlaceholderQuest: Identifiable, Sendable, Equatable {
    let id: String
    let title: LocalizedText
    let region: LocalizedText
    /// The frame's figure, in minutes. Not measured, not walked, not derived from a route.
    let walkingTimeMin: Int
    /// The frame labels these "quests"; `FR-CP-08` counts progress in checkpoints and so does the
    /// real card, so the filler counts them by the same name rather than inventing a second unit.
    let checkpointCount: Int
    /// An imageset in the app target's asset catalogue, never a content asset.
    let imageName: String
}

enum PlaceholderQuestCatalog {

    static let all: [PlaceholderQuest] = [
        PlaceholderQuest(
            id: "placeholder-gods-dance",
            title: LocalizedText(id: "Tempat Para Dewa Menari",
                                 en: "Where the Gods Come to Dance"),
            region: LocalizedText(id: "Ubud", en: "Ubud"),
            walkingTimeMin: 50,
            checkpointCount: 7,
            imageName: "dummy-quest-1"),
        PlaceholderQuest(
            id: "placeholder-serpent-shrine",
            title: LocalizedText(id: "Pura Pasang Surut Sang Naga",
                                 en: "The Serpent's Tidal Shrine"),
            region: LocalizedText(id: "Denpasar", en: "Denpasar"),
            walkingTimeMin: 30,
            checkpointCount: 5,
            imageName: "dummy-quest-2"),
        PlaceholderQuest(
            id: "placeholder-mother-temple",
            title: LocalizedText(id: "Janji yang Terlupakan di Pura Ibu",
                                 en: "The Mother Temple's Forgotten Vow"),
            region: LocalizedText(id: "Besakih", en: "Besakih"),
            walkingTimeMin: 30,
            checkpointCount: 4,
            imageName: "dummy-quest-3"),
    ]
}
