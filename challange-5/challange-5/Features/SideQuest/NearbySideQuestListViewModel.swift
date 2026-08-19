import ContentKit
import Foundation
import RunEngine
import UIStringsKit

/// "Places nearby", in the Quests tab.
///
/// Before notifications exist this is the only way in (Phase B). It survives Phase C as the manual
/// browse path — a walker who dismissed a notification needs a way back, and `FR-SIDE-07` promises
/// one.
///
/// **It does not sample location.** `NFR-BAT-04` confines sampling to the screen that is actually
/// waiting at a gate, and `AD-1` splits location by purpose; a browse list that switched the radios
/// on would be a second purpose nobody asked for. The last known coordinate is passed in — the one
/// the arrival screen already produced, if any — and without one the rows carry no distance and
/// keep the manifest's order rather than inventing a number.
@MainActor
@Observable
final class NearbySideQuestListViewModel {

    private let repository: any ContentRepository
    private let engine: SideQuestEngine
    private let language: ContentLanguage

    private(set) var rows: [NearbySideQuestRow] = []

    init(
        repository: any ContentRepository,
        engine: SideQuestEngine,
        language: ContentLanguage,
        lastKnownCoordinate: Coordinate? = nil
    ) {
        self.repository = repository
        self.engine = engine
        self.language = language
        reload(lastKnownCoordinate: lastKnownCoordinate)
    }

    func reload(lastKnownCoordinate: Coordinate? = nil) {
        let formatter = ContentFormatter(language: language)
        let completed = (try? engine.records())?
            .filter(\.isCompleted)
            .map(\.sideQuestID) ?? []
        let completedIDs = Set(completed)

        // Suppression sets are empty here rather than fetched: whoever owns the kill-switch owns
        // the fetch, and there is no reachability check anywhere in this codebase (`AD-3`,
        // `FR-SIDE-14`, `FR-SIDE-15`).
        let sideQuests = (try? repository.sideQuests(
            suppressingSideQuestIDs: [], suppressingPlaceIDs: [])) ?? []

        rows = sideQuests.compactMap { sideQuest -> NearbySideQuestRow? in
            guard let place = (try? repository.place(id: sideQuest.placeId)) ?? nil else {
                return nil
            }
            let metres = lastKnownCoordinate.map { Geo.distanceM($0, place.coordinate) }
            return NearbySideQuestRow(
                id: sideQuest.id,
                title: sideQuest.title.value(for: language),
                placeName: place.nameOfficial.value(for: language),
                distanceText: metres.map { formatter.distance(metres: Int($0.rounded())) },
                distanceM: metres ?? .infinity,
                // A completed sidequest still lists — `FR-SIDE-07` keeps the place openable, and
                // the read-back of a story somebody has read is the point of keeping the record.
                isCompleted: completedIDs.contains(sideQuest.id))
        }
        // A stable order without a fix: the manifest's, which `sideQuests()` already returns and
        // which does not reshuffle between machines.
        if lastKnownCoordinate != nil {
            rows.sort { $0.distanceM < $1.distanceM }
        }
    }

    var isEmpty: Bool { rows.isEmpty }
}
