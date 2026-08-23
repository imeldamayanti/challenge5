import ContentKit
import DesignSystem
import Foundation

/// One discovered sidequest, resolved for the popup and the page it opens (`1108:2780`,
/// `949:2461`).
///
/// A presentation model on this feature's own terms: strings already localized, no repository, no
/// palette, no engine. It carries `claims` because the fallback page prints them with their
/// accuracy labels and citations (`FR-CP-05`, `FR-CP-06`) — the drawn page does not, and the note
/// on `SideQuestDiscoveryText` says why that is a recorded decision rather than an omission.
struct SideQuestDiscoveryPresentation: Sendable, Equatable, Identifiable {
    let sideQuestID: String
    let title: String
    let placeName: String
    /// What the notification carried, and what the watch's long look printed.
    let synopsis: String
    let claims: [LoreClaimPresentation]
    let language: ContentLanguage

    var id: String { sideQuestID }
}

/// Resolves a sidequest id into the pair of screens' input.
///
/// A free function rather than an `@Observable` view model: nothing here changes after it is read,
/// there is no store to write and no sampling to start. The popup and the page are read-only
/// surfaces over content that is already in the bundle.
enum SideQuestDiscoveryResolver {

    /// `nil` when content has no such sidequest — a kill-switch withdrawal between the region
    /// firing and the tap arriving, or a notification from a build with different content. The
    /// caller shows nothing rather than an empty popup.
    static func resolve(
        sideQuestID: String,
        repository: any ContentRepository,
        language: ContentLanguage
    ) -> SideQuestDiscoveryPresentation? {
        guard let sideQuest = (try? repository.sideQuest(id: sideQuestID)) ?? nil else {
            return nil
        }
        let place = (try? repository.place(id: sideQuest.placeId)) ?? nil
        let formatter = ContentFormatter(language: language)

        let claims = sideQuest.lore.enumerated().map { offset, block in
            LoreClaimPresentation(
                id: offset,
                block: LoreBlockPresentation(
                    id: offset,
                    text: block.text.value(for: language),
                    accuracyLabel: formatter.accuracyLabel(block.accuracy),
                    appearance: block.accuracy == .documented ? .documented : .oral,
                    ink: block.accuracy == .documented ? .documented : .oral),
                citations: block.sourceRefs.compactMap { ref in
                    guard let place, place.sources.indices.contains(ref) else { return nil }
                    return place.sources[ref].citation
                })
        }

        return SideQuestDiscoveryPresentation(
            sideQuestID: sideQuest.id,
            title: sideQuest.title.value(for: language),
            placeName: place?.nameOfficial.value(for: language) ?? sideQuest.placeId,
            synopsis: sideQuest.synopsis.value(for: language),
            claims: claims,
            language: language)
    }
}
