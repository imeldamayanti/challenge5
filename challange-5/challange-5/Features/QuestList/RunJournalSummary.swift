import ContentKit
import Foundation
import RunEngine
import UIStringsKit

/// What the home screen knows about the walker's own history: the walk still under way, and the
/// walks already finished.
///
/// Built from `Run` snapshots rather than from content, so it renders with no content lookup and
/// keeps naming a quest that has since been withdrawn (`FR-DONE-05`, `FR-RUN-06`).
struct RunJournalSummary: Sendable, Equatable {

    struct Entry: Sendable, Equatable, Identifiable {
        let id: UUID
        /// The quest the walk belongs to, so a catalogue card can show its own state — an open
        /// walk hangs the ongoing tag on its quest (`850:2289`) without joining onto content.
        let questID: String
        let title: String
        let progressText: String

        init(id: UUID, questID: String = "", title: String, progressText: String) {
            self.id = id
            self.questID = questID
            self.title = title
            self.progressText = progressText
        }
    }

    let activeRun: Entry?
    let completed: [Entry]
    /// Every quest with a walk still open. A set, not the single most recent entry, because the
    /// tag answers "is *this* quest under way" and the store may hold more than one draft.
    let activeQuestIDs: Set<String>

    static let empty = RunJournalSummary(activeRun: nil, completed: [], activeQuestIDs: [])

    init(activeRun: Entry?, completed: [Entry], activeQuestIDs: Set<String> = []) {
        self.activeRun = activeRun
        self.completed = completed
        self.activeQuestIDs = activeQuestIDs
    }

    @MainActor
    init(store: any RunStore, language: ContentLanguage) {
        func entry(_ run: Run) -> Entry {
            Entry(
                id: run.id,
                questID: run.questID,
                title: run.snapshotQuestTitle,
                progressText: String(
                    format: UIStrings.string(.checkpointProgress, language),
                    run.reachedCount, run.checkpointCount))
        }
        let all = (try? store.runs()) ?? []
        activeRun = ((try? store.mostRecentActiveRun()) ?? nil).map(entry)
        completed = ((try? store.completedRuns()) ?? []).map(entry)
        activeQuestIDs = Set(all.filter { $0.state == .active }.map(\.questID))
    }
}
