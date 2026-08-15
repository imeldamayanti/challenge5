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
        let title: String
        let progressText: String

        init(id: UUID, title: String, progressText: String) {
            self.id = id
            self.title = title
            self.progressText = progressText
        }
    }

    let activeRun: Entry?
    let completed: [Entry]

    static let empty = RunJournalSummary(activeRun: nil, completed: [])

    init(activeRun: Entry?, completed: [Entry]) {
        self.activeRun = activeRun
        self.completed = completed
    }

    @MainActor
    init(store: any RunStore, language: ContentLanguage) {
        func entry(_ run: Run) -> Entry {
            Entry(
                id: run.id,
                title: run.snapshotQuestTitle,
                progressText: String(
                    format: UIStrings.string(.checkpointProgress, language),
                    run.reachedCount, run.checkpointCount))
        }
        activeRun = ((try? store.mostRecentActiveRun()) ?? nil).map(entry)
        completed = ((try? store.completedRuns()) ?? []).map(entry)
    }
}
