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

    var wasAbandoned: Bool { run.state == .abandoned }

    // MARK: - The three counts on the Trip Summary (`791:6494`)

    /// How many checkpoints the walk actually reached — `791:6502`.
    var placesExploredCount: Int { run.reachedCount }

    /// How many tasks the walker resolved with something of their own — `791:6523`.
    ///
    /// A skip is a resolution and not a memory (`AD-2`), and neither is an empty field, so both are
    /// counted out. A photograph counts even when nothing was written beside it: the picture is the
    /// keepsake.
    var memoriesCount: Int {
        run.orderedCheckpointResults.reduce(0) { total, result in
            total + result.taskResults.filter { task in
                guard !task.skipped else { return false }
                if let text = task.text, !text.isEmpty { return true }
                return task.photoRelativePath != nil
            }.count
        }
    }

    /// The photographs the walker took, in the order they were taken — `791:6460` and its
    /// siblings, the Trip Collection's grid.
    ///
    /// **The collection is what the walker made, not what the app gave them.** The frame draws five
    /// medallions of the same painted portrait and captions them with invented names; what the walk
    /// actually produced is the pictures they stopped and took, so the grid is exactly as long as
    /// that list — three photographs, three medallions, and a walk with none shows the legend alone.
    /// A skipped photo task contributes nothing (`AD-2`).
    ///
    /// The path is carried, never the image: loading fifteen JPEGs to build a presentation model
    /// would put file IO in a type whose whole point is that it does none.
    var capturedPhotos: [(id: String, placeName: String, relativePath: String)] {
        run.orderedCheckpointResults.flatMap { result in
            result.taskResults.compactMap { task in
                guard !task.skipped, let path = task.photoRelativePath else { return nil }
                return (id: task.id.uuidString, placeName: result.snapshotPlaceName, relativePath: path)
            }
        }
    }

    /// How long the walk took, in whole minutes — `791:6532`.
    ///
    /// End to end, from the moment the Run was written to the moment it was finished; a walk still
    /// under way measures to the last thing that touched it, which is the same fact the Journal's
    /// shelf sorts on. Floored at 1 rather than shown as 0: a finished walk took *some* time, and a
    /// summary that says it took none reads as a bug rather than as a fast walker.
    var durationMinutes: Int {
        let end = run.completedAt ?? run.abandonedAt ?? run.updatedAt
        let seconds = max(0, end.timeIntervalSince(run.startedAt))
        return max(1, Int((seconds / 60).rounded()))
    }
}
