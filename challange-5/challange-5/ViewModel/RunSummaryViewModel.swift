import ContentKit
import DesignSystem
import Foundation
import RunEngine
import UIStringsKit

/// The trip summary, built from the Run's own snapshots and nothing else.
///
/// There is deliberately no `ContentRepository` in this type. `FR-DONE-04` requires the summary to
/// render the pinned content version rather than current content, and `FR-DONE-05` requires it to
/// render offline forever — and the cheapest way to guarantee both is to leave the model no way to
/// look anything up. A place withdrawn under `AD-5` cannot blank a walk somebody finished, because
/// nothing here asks whether it still exists.
@MainActor
@Observable
final class RunSummaryViewModel {

    struct Stop: Sendable, Identifiable, Equatable {
        let id: String
        let orderIndex: Int
        let placeName: String
        let claims: [LoreClaimPresentation]
        let arrivalNote: String?
        /// Answers the walker wrote, in the order they were asked. Skipped tasks contribute
        /// nothing — a skip is a resolution, not an empty answer to print (`AD-2`).
        let writtenAnswers: [(prompt: String, text: String)]

        static func == (lhs: Stop, rhs: Stop) -> Bool {
            lhs.id == rhs.id && lhs.claims == rhs.claims
                && lhs.writtenAnswers.map(\.text) == rhs.writtenAnswers.map(\.text)
        }
    }

    let run: Run
    let language: ContentLanguage
    let stops: [Stop]

    init(run: Run) {
        self.run = run
        // The Run's own language, not the app's. Switching the interface to English after finishing
        // an Indonesian walk must not half-translate a summary; `NFR-I18N-03` forbids the mixture,
        // and the snapshot only holds one language anyway.
        self.language = run.language
        let formatter = ContentFormatter(language: run.language)

        stops = run.orderedCheckpointResults.map { result in
            Stop(
                id: result.checkpointID,
                orderIndex: result.orderIndex,
                placeName: result.snapshotPlaceName,
                claims: result.snapshotLore.enumerated().map { offset, snapshot in
                    LoreClaimPresentation(
                        id: offset,
                        block: LoreBlockPresentation(
                            id: offset,
                            text: snapshot.text,
                            accuracyLabel: formatter.accuracyLabel(snapshot.accuracy),
                            appearance: snapshot.accuracy == .documented ? .documented : .oral,
                            ink: snapshot.accuracy == .documented ? .documented : .oral),
                        citations: snapshot.sourceCitations)
                },
                arrivalNote: nil,
                writtenAnswers: result.taskResults
                    .filter { !$0.skipped }
                    .compactMap { task in
                        guard let text = task.text, !text.isEmpty else { return nil }
                        return (prompt: task.promptSnapshot, text: text)
                    })
        }
    }

    var title: String { run.snapshotQuestTitle }

    var stamps: [Award] { run.awards.filter { $0.type == .stamp } }

    var badges: [Award] { run.awards.filter { $0.type == .badge } }

    var progressText: String {
        String(format: UIStrings.string(.checkpointProgress, language),
               run.reachedCount, run.checkpointCount)
    }

    /// Names the pinned version, because a summary that silently disagrees with the current app is
    /// worse than one that says why (`AD-4`).
    var snapshotNote: String {
        String(format: UIStrings.string(.summarySnapshotNote, language), run.contentVersion)
    }

    var wasAbandoned: Bool { run.state == .abandoned }
}
