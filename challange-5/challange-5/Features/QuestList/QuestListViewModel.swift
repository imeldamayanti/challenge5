import ContentKit
import Foundation

/// `FR-DISC-01` — browsing works at any location on earth, with no network, and with location
/// permission denied. There is nothing in this type that could want any of the three.
@MainActor
@Observable
final class QuestListViewModel {

    private(set) var rows: [QuestListRow] = []
    /// A content problem must leave the screen usable rather than take the app down
    /// (`NFR-REL-04`).
    private(set) var loadFailed = false

    /// What the reader has typed into the Home design's search field. Filtering happens over the
    /// rows already in memory: `FR-DISC-01` and `AD-3` mean browsing works in airplane mode, and a
    /// search that queried anything would be the first thing in the app that does not.
    var searchText: String = ""

    let language: ContentLanguage

    init(
        repository: any ContentRepository,
        language: ContentLanguage,
        suppressedQuestIDs: Set<String> = [],
        suppressedPlaceIDs: Set<String> = []
    ) {
        self.language = language
        let formatter = ContentFormatter(language: language)
        do {
            let quests = try repository.quests(
                suppressingQuestIDs: suppressedQuestIDs,
                suppressingPlaceIDs: suppressedPlaceIDs)
            rows = quests.map { quest in
                QuestListRow(
                    questID: quest.id,
                    title: quest.title.value(for: language),
                    region: quest.region,
                    distanceText: formatter.distance(metres: quest.route.totalDistanceM),
                    walkingTimeText: formatter.duration(minutes: quest.route.walkingTimeMin),
                    totalDurationText: formatter.duration(minutes: quest.route.totalDurationMin),
                    costText: formatter.cost(
                        amount: quest.estimatedCost.amount, currency: quest.estimatedCost.currency),
                    showsCostOnCard: !quest.estimatedCost.isFree,
                    checkpointCount: quest.checkpointCount,
                    checkpointCountText: formatter.checkpointCount(quest.checkpointCount),
                    heroImageURL: quest.heroImageAsset.flatMap { (try? repository.assetURL($0)) ?? nil })
            }
        } catch {
            rows = []
            loadFailed = true
        }
    }

    var isEmpty: Bool { rows.isEmpty }

    /// The rows the list draws. Order is the authored order (`FR-DISC-03`) with non-matches
    /// removed — never a relevance ranking, which would make the same content appear in a
    /// different sequence depending on what was typed.
    var visibleRows: [QuestListRow] {
        let query = Self.fold(searchText)
        guard !query.isEmpty else { return rows }
        return rows.filter { row in
            Self.fold(row.title).contains(query) || Self.fold(row.region).contains(query)
        }
    }

    /// True only when a search is active and matched nothing, so the screen can say so. Showing
    /// everything on no match would leave the reader unable to tell "no match" from "broken".
    var hasNoSearchResults: Bool {
        !Self.fold(searchText).isEmpty && visibleRows.isEmpty
    }

    /// Case- and diacritic-insensitive, because Indonesian place names carry marks the reader will
    /// not type.
    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
