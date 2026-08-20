import ContentKit
import Foundation
import RunEngine
import Testing
import UIStringsKit
@testable import challange_5

/// The three counts the Trip Summary prints (`791:6494`), and the paper the letter routes to.
///
/// The frame mocks the counts up as 5 / 7 / 45. These guard that they are read off the Run instead:
/// a screen that printed the frame's numbers would tell every walker they walked for 45 minutes.
struct TripPagesTests {

    private static let started = Date(timeIntervalSince1970: 1_770_000_000)

    private static func task(
        _ id: String,
        skipped: Bool = false,
        text: String? = nil,
        photo: String? = nil
    ) -> TaskResult {
        TaskResult(
            taskID: id,
            type: photo == nil ? .reflection : .photo,
            promptSnapshot: "Prompt for \(id)",
            skipped: skipped,
            text: text,
            photoRelativePath: photo,
            completedAt: started)
    }

    private static func checkpoint(_ index: Int, tasks: [TaskResult], lore: [LoreBlockSnapshot] = []) -> CheckpointResult {
        CheckpointResult(
            checkpointID: "cp\(index)",
            orderIndex: index,
            arrivedAt: started,
            arrivalMethod: .gps,
            gpsAccuracyM: 10,
            snapshotPlaceName: "Place \(index)",
            snapshotLore: lore,
            snapshotClueToNext: nil,
            snapshotContentVersion: "test",
            taskResults: tasks)
    }

    private static func run(
        checkpoints: [CheckpointResult],
        state: RunState = .completed,
        completedAt: Date? = started.addingTimeInterval(45 * 60)
    ) -> Run {
        Run(
            questID: "test-quest",
            contentVersion: "test",
            language: .en,
            snapshotQuestTitle: "A walk",
            checkpointCount: 5,
            state: state,
            currentCheckpointIndex: max(checkpoints.count - 1, 0),
            startedAt: started,
            updatedAt: completedAt ?? started,
            completedAt: completedAt,
            checkpointResults: checkpoints,
            awards: [])
    }

    // MARK: - Places explored

    @MainActor
    @Test func placesExploredIsHowManyCheckpointsWereReached() {
        let model = RunSummaryViewModel(run: Self.run(checkpoints: [
            Self.checkpoint(0, tasks: []),
            Self.checkpoint(1, tasks: []),
            Self.checkpoint(2, tasks: [])
        ]))
        // Three of the quest's five. The tile counts the walk, not the quest.
        #expect(model.placesExploredCount == 3)
    }

    // MARK: - Memories

    /// A memory is something the walker put there: a written answer or a photograph. A skip is a
    /// resolution and not a memory (`AD-2`), and neither is an answered-but-empty field.
    @MainActor
    @Test func memoriesCountOnlyWhatTheWalkerActuallyLeftBehind() {
        let model = RunSummaryViewModel(run: Self.run(checkpoints: [
            Self.checkpoint(0, tasks: [
                Self.task("a", text: "Canang on the step."),
                Self.task("b", skipped: true)
            ]),
            Self.checkpoint(1, tasks: [
                Self.task("c", text: ""),
                Self.task("d", photo: "photos/d.jpg")
            ])
        ]))
        // One answer and one photograph. The skip and the empty field are not counted.
        #expect(model.memoriesCount == 2)
    }

    /// A skipped task carrying stale text is still a skip. The two fields can both be set, and the
    /// resolution is what decides.
    @MainActor
    @Test func aSkipIsNotAMemoryEvenWhenTextSurvivedOnIt() {
        let model = RunSummaryViewModel(run: Self.run(checkpoints: [
            Self.checkpoint(0, tasks: [Self.task("a", skipped: true, text: "half-typed")])
        ]))
        #expect(model.memoriesCount == 0)
    }

    // MARK: - Duration

    @MainActor
    @Test func durationIsStartToFinishInWholeMinutes() {
        let model = RunSummaryViewModel(run: Self.run(
            checkpoints: [Self.checkpoint(0, tasks: [])],
            completedAt: Self.started.addingTimeInterval(45 * 60)))
        #expect(model.durationMinutes == 45)
    }

    /// A walk finished inside a minute took *some* time. Printing "0 mins" reads as a bug rather
    /// than as a fast walker, so the floor is one.
    @MainActor
    @Test func aWalkShorterThanAMinuteStillReportsOne() {
        let model = RunSummaryViewModel(run: Self.run(
            checkpoints: [Self.checkpoint(0, tasks: [])],
            completedAt: Self.started.addingTimeInterval(12)))
        #expect(model.durationMinutes == 1)
    }

    /// A walk still under way measures to the last thing that touched it — the same fact the
    /// Journal's shelf sorts on, so the letter's place in the row and its duration agree.
    @MainActor
    @Test func anUnfinishedWalkMeasuresToItsLastUpdate() {
        var run = Self.run(
            checkpoints: [Self.checkpoint(0, tasks: [])],
            state: .active,
            completedAt: nil)
        run.updatedAt = Self.started.addingTimeInterval(20 * 60)
        let model = RunSummaryViewModel(run: run)
        #expect(model.durationMinutes == 20)
    }

    // MARK: - The two pages

    /// The papers modal opens one of two screens, and `791:6414` / `791:6537` are two screens
    /// rather than two scroll offsets of one. The kinds are what the router switches on.
    @Test func thereAreExactlyTwoPapersAndBothNameAPage() {
        #expect(JournalPaperPresentation.Kind.allCases.count == 2)
        #expect(JournalPaperPresentation.Kind.allCases.contains(.summary))
        #expect(JournalPaperPresentation.Kind.allCases.contains(.history))
    }

    /// Both pages' strings exist in both languages. `UIStrings` has no fallback (`NFR-I18N-03`), so
    /// a missing translation is a crash on somebody's finished walk rather than a smaller bug.
    @Test func bothPagesCarryTheirStringsInBothLanguages() {
        let keys: [UIStringKey] = [
            .tripPageBack, .tripJourneyHeading, .tripPlacesExplored,
            .tripMemories, .tripMemoriesUnit, .tripDuration, .tripDurationUnit,
            .tripPiecesHeading, .tripCollectionHeading, .tripHistoryNoLore, .tripHistoryClosing
        ]
        for key in keys {
            for language in [ContentLanguage.id, .en] {
                #expect(!UIStrings.string(key, language).isEmpty, "\(key) is empty in \(language)")
            }
            #expect(UIStrings.string(key, .id) != UIStrings.string(key, .en),
                    "\(key) is the same string in both languages — probably untranslated")
        }
    }
}
