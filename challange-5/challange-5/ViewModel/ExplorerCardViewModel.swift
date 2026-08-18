import ContentKit
import Foundation
import RunEngine
import UIStringsKit

/// The Explorer's Card: what the reader has walked, stamped and been given, counted from their own
/// records.
///
/// Two stores, never joined: Runs and sidequest records are separate aggregates and one must not
/// reference the other (`FR-SIDE-01`, `s0` D1). They are read side by side here and summed, which
/// is a presentation concern and not a relationship.
@MainActor
@Observable
final class ExplorerCardViewModel {

    private(set) var presentation: ExplorerCardPresentation = .empty
    var tab: ExplorerCardPresentation.Tab = .quests

    let language: ContentLanguage

    private let runStore: any RunStore
    private let sideQuestStore: any SideQuestStore
    private let repository: any ContentRepository

    init(
        runStore: any RunStore,
        sideQuestStore: any SideQuestStore,
        repository: any ContentRepository,
        language: ContentLanguage
    ) {
        self.runStore = runStore
        self.sideQuestStore = sideQuestStore
        self.repository = repository
        self.language = language
        reload()
    }

    /// A walk or a sidequest may have finished since this screen was last looked at.
    func reload() {
        let runs = (try? runStore.runs()) ?? []
        let records = (try? sideQuestStore.records()) ?? []

        // Stamps: one per checkpoint actually reached, newest walk first so the card opens on what
        // the reader just did.
        let stampAwards = runs
            .flatMap { run in run.awards.filter { $0.type == .stamp }.map { (run, $0) } }
            .sorted { $0.1.awardedAt > $1.1.awardedAt }
        // Built once for the whole card: which of a place's three drawings the reader has earned is
        // a question about every Run, not about the one this stamp came from.
        let artwork = StampArtworkResolver(runs: runs, repository: repository)
        let stamps = stampAwards.map { run, award in
            StampPresentation(
                id: "\(run.id)-\(award.sourceID)",
                placeName: award.snapshotName,
                region: (try? repository.quest(id: run.questID))??.region ?? "",
                artworkName: artwork.artworkName(
                    questID: run.questID, stampSourceID: award.sourceID))
        }

        // Badges: a finished walk (`FR-DONE-01`) and a completed collection (`FR-SIDE-09`). Both
        // are `Award`s of the same type, written by two engines into two stores.
        let badgeAwards = (runs.flatMap(\.awards) + records.flatMap(\.awards))
            .filter { $0.type == .badge }
            .sorted { $0.awardedAt > $1.awardedAt }
        let badges = badgeAwards.enumerated().map { index, award in
            BadgePresentation(id: award.id.uuidString, name: award.snapshotName, waxIndex: index)
        }

        // The Quests tab: walks under way, most recently touched first. Not a list of everything
        // the reader has ever done — a finished walk is a badge and a sealed letter already, and
        // an abandoned one was explicitly put down (`FR-RUN-05`).
        let inProgress = runs
            .filter { $0.state == .active }
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { run in
                InProgressQuestPresentation(
                    id: run.id,
                    title: run.snapshotQuestTitle,
                    detail: String(
                        format: UIStrings.string(.checkpointProgress, language),
                        run.reachedCount, run.checkpointCount))
            }

        presentation = ExplorerCardPresentation(
            name: UIStrings.string(.profileExplorerName, language),
            questCount: runs.filter { $0.state == .completed }.count,
            stampCount: stamps.count,
            badgeCount: badges.count,
            inProgressQuests: inProgress,
            stamps: stamps,
            badges: badges)
    }
}
