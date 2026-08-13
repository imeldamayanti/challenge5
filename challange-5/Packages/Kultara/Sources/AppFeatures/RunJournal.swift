import ContentKit
import DesignSystem
import Foundation
import RunEngine
import SwiftUI

/// What the home screen knows about the walker's own history: the walk still under way, and the
/// walks already finished.
///
/// Built from `Run` snapshots rather than from content, so it renders with no content lookup and
/// keeps naming a quest that has since been withdrawn (`FR-DONE-05`, `FR-RUN-06`).
public struct RunJournalSummary: Sendable, Equatable {

    public struct Entry: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let title: String
        public let progressText: String

        public init(id: UUID, title: String, progressText: String) {
            self.id = id
            self.title = title
            self.progressText = progressText
        }
    }

    public let activeRun: Entry?
    public let completed: [Entry]

    public static let empty = RunJournalSummary(activeRun: nil, completed: [])

    public init(activeRun: Entry?, completed: [Entry]) {
        self.activeRun = activeRun
        self.completed = completed
    }

    @MainActor
    public init(store: any RunStore, language: ContentLanguage) {
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

struct JournalEntryCard: View {
    @Environment(\.kultaraPalette) private var palette

    let heading: String
    let entry: RunJournalSummary.Entry
    let actionTitle: String
    let language: ContentLanguage
    let action: () -> Void

    var body: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                KultaraEyebrow(heading)
                Text(entry.title)
                    .kultaraFont(.questTitle)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.progressText)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                Button(actionTitle, action: action)
                    .buttonStyle(.ruled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// `FR-SET-02` — the real eraser, now that there is something to erase.
///
/// Preferences *and* Runs, in one call, because a language override that survives "delete all local
/// data" is a surprise and a completed walk that survives it is a privacy failure. Photos are not
/// listed because this build writes none; when photo tasks ship, the photo directory has to be
/// removed here too — deleting rows alone leaves image files on disk, which passes every database
/// test and fails the requirement.
@MainActor
public final class RunAndPreferencesDataEraser: LocalDataEraser {

    private let store: any RunStore
    private let preferences: any AppPreferencesStore

    public init(store: any RunStore, preferences: any AppPreferencesStore) {
        self.store = store
        self.preferences = preferences
    }

    public func eraseAllLocalData() throws -> ErasureSummary {
        let deletedRuns = try store.deleteAll()
        preferences.removeAll()
        return ErasureSummary(
            deletedRuns: deletedRuns,
            deletedPhotos: 0,
            deletedTelemetryEvents: 0,
            clearedPreferences: true)
    }
}
