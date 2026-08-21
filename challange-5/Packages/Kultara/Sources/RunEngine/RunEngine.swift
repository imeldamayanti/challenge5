import ContentKit
import Foundation

public enum RunEngineError: Error, Equatable, CustomStringConvertible {
    case questNotFound(String)
    case runNotFound(UUID)
    case runNotActive(RunState)
    case checkpointNotFound(String)
    /// `FR-ARR-06` — carries what the app must say, rather than leaving the caller to work it out.
    case outOfSequence(expectedCheckpointID: String, expectedOrderIndex: Int)
    case alreadyArrived(checkpointID: String)
    /// `FR-START-06` — the caller must offer resume or restart rather than quietly opening a second.
    case activeRunExists(runID: UUID)
    case noNextCheckpoint

    public var description: String {
        switch self {
        case .questNotFound(let id): "No quest with id \"\(id)\"."
        case .runNotFound(let id): "No run with id \(id.uuidString)."
        case .runNotActive(let state): "The run is \(state.rawValue), not active."
        case .checkpointNotFound(let id): "No checkpoint with id \"\(id)\"."
        case .outOfSequence(let id, let index):
            "Out of sequence: checkpoint \(index + 1) (\"\(id)\") is the one expected."
        case .alreadyArrived(let id): "Arrival at \"\(id)\" is already recorded."
        case .activeRunExists(let id): "A draft run already exists: \(id.uuidString)."
        case .noNextCheckpoint: "This is the last checkpoint; there is nothing to advance to."
        }
    }
}

/// The rules that decide what a Run may do next, and the only thing that writes user data.
///
/// Every rule it holds is one the PRD states with a reason: checkpoints complete in order
/// (`FR-CP-01`), arrival out of sequence changes nothing (`FR-ARR-06`), a stamp is awarded on
/// arrival regardless of tasks (`FR-CP-07`), tasks never gate anything (`AD-2`), and what the user
/// read is copied into their record at the moment they read it (`system-design.md` §4.1).
///
/// Nothing here knows about location hardware, permissions, or connectivity — arrival arrives as a
/// decided fact. That is what makes these rules testable on a laptop, which matters because this is
/// where correctness bugs would otherwise hide until somebody is standing in a market in Denpasar.
@MainActor
public struct RunEngine {

    private let repository: any ContentRepository
    private let store: any RunStore
    private let now: @Sendable () -> Date

    public init(
        repository: any ContentRepository,
        store: any RunStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.store = store
        self.now = now
    }

    // MARK: - Queries

    public func activeRun(questID: String) throws -> Run? {
        try store.activeRun(questID: questID)
    }

    public func run(id: UUID) throws -> Run? {
        try store.run(id: id)
    }

    public func mostRecentActiveRun() throws -> Run? {
        try store.mostRecentActiveRun()
    }

    public func completedRuns() throws -> [Run] {
        try store.completedRuns()
    }

    // MARK: - Starting

    /// `FR-START-01/05` — a Run begins by arriving at the first checkpoint, and pins its content
    /// version and language on the way in.
    ///
    /// The arrival is passed in already established. This type does not decide whether somebody is
    /// standing at the gate; it decides what happens once they are, which keeps `FR-START-08`
    /// enforceable in one place — the screen that owns the location — rather than in two.
    @discardableResult
    public func start(
        questID: String,
        language: ContentLanguage,
        method: ArrivalMethod,
        accuracyM: Double?
    ) throws -> Run {
        guard let quest = try repository.quest(id: questID) else {
            throw RunEngineError.questNotFound(questID)
        }
        if let existing = try store.activeRun(questID: questID) {
            throw RunEngineError.activeRunExists(runID: existing.id)
        }
        guard let first = quest.orderedCheckpoints.first else {
            throw RunEngineError.checkpointNotFound(questID)
        }

        let timestamp = now()
        var run = Run(
            questID: quest.id,
            contentVersion: quest.contentVersion,
            language: language,
            snapshotQuestTitle: quest.title.value(for: language),
            checkpointCount: quest.checkpointCount,
            state: .active,
            currentCheckpointIndex: first.orderIndex,
            startedAt: timestamp,
            updatedAt: timestamp)

        try applyArrival(
            to: &run, quest: quest, checkpoint: first,
            method: method, accuracyM: accuracyM, at: timestamp)
        try store.save(run)
        return run
    }

    /// `FR-START-06` — restarting discards the draft, and the caller is required to have warned the
    /// user that its photos and reflections go with it. Deleting rather than marking abandoned:
    /// this is the user saying the attempt did not happen, not that they gave up on it.
    @discardableResult
    public func restart(
        questID: String,
        language: ContentLanguage,
        method: ArrivalMethod,
        accuracyM: Double?
    ) throws -> Run {
        if let existing = try store.activeRun(questID: questID) {
            try store.delete(id: existing.id)
        }
        return try start(
            questID: questID, language: language, method: method, accuracyM: accuracyM)
    }

    // MARK: - Progressing

    /// `FR-ARR-06`, `FR-CP-01` — arrival anywhere other than the expected checkpoint is rejected
    /// with the expected one named, and changes no state at all.
    @discardableResult
    public func recordArrival(
        runID: UUID,
        checkpointID: String,
        method: ArrivalMethod,
        accuracyM: Double?
    ) throws -> Run {
        var run = try activeRunOrThrow(runID)
        let quest = try questOrThrow(run.questID)

        guard let checkpoint = quest.checkpoints.first(where: { $0.id == checkpointID }) else {
            throw RunEngineError.checkpointNotFound(checkpointID)
        }
        let expected = quest.orderedCheckpoints.first {
            $0.orderIndex == run.currentCheckpointIndex
        }
        guard let expected else { throw RunEngineError.noNextCheckpoint }
        guard checkpoint.id == expected.id else {
            throw RunEngineError.outOfSequence(
                expectedCheckpointID: expected.id, expectedOrderIndex: expected.orderIndex)
        }
        guard run.result(forCheckpointID: checkpoint.id) == nil else {
            throw RunEngineError.alreadyArrived(checkpointID: checkpoint.id)
        }

        try applyArrival(
            to: &run, quest: quest, checkpoint: checkpoint,
            method: method, accuracyM: accuracyM, at: now())
        try store.save(run)
        return run
    }

    /// Moves the walker on to the next checkpoint, which they then have to reach.
    ///
    /// Separate from `recordArrival` because the two are different moments: arriving is what earns
    /// the stamp and opens the story, leaving is what starts the next walk. Collapsing them would
    /// make `FR-CP-03` — re-read the clue later without re-triggering arrival — impossible to hold.
    @discardableResult
    public func advanceToNextCheckpoint(runID: UUID) throws -> Run {
        var run = try activeRunOrThrow(runID)
        let quest = try questOrThrow(run.questID)

        guard run.hasArrivedAtCurrentCheckpoint else {
            let expected = quest.orderedCheckpoints.first {
                $0.orderIndex == run.currentCheckpointIndex
            }
            throw RunEngineError.outOfSequence(
                expectedCheckpointID: expected?.id ?? "",
                expectedOrderIndex: run.currentCheckpointIndex)
        }
        let nextIndex = run.currentCheckpointIndex + 1
        guard quest.orderedCheckpoints.contains(where: { $0.orderIndex == nextIndex }) else {
            throw RunEngineError.noNextCheckpoint
        }

        run.currentCheckpointIndex = nextIndex
        run.updatedAt = now()
        try store.save(run)
        return run
    }

    /// `FR-CP-04` and the dwell half of `NFR-OBS-06`. Recorded once — the first opening is the one
    /// that means something; re-reads are re-reads.
    @discardableResult
    public func markLoreOpened(runID: UUID, checkpointID: String) throws -> Run {
        var run = try openRunOrThrow(runID)
        guard let index = run.checkpointResults.firstIndex(where: {
            $0.checkpointID == checkpointID
        }) else {
            throw RunEngineError.checkpointNotFound(checkpointID)
        }
        guard run.checkpointResults[index].loreFirstOpenedAt == nil else { return run }

        run.checkpointResults[index].loreFirstOpenedAt = now()
        run.updatedAt = now()
        try store.save(run)
        return run
    }

    /// `AD-2`, `FR-TASK-01/02` — a task result never touches `state`, `currentCheckpointIndex`, or
    /// any award. Skipping is recorded the same way answering is, and the type makes that symmetry
    /// hard to break: `skipped` is a stored fact, not the absence of one.
    @discardableResult
    public func recordTaskResult(
        runID: UUID,
        checkpointID: String,
        taskID: String,
        skipped: Bool,
        text: String? = nil,
        /// Where `PhotoStore` wrote the walker's photograph, relative to the app container — never
        /// absolute (`NFR-REL-05`). The field has been on `TaskResult` since the store shipped; this
        /// is the parameter that finally fills it, for `1:4827`'s photo task.
        photoRelativePath: String? = nil
    ) throws -> Run {
        var run = try openRunOrThrow(runID)
        let quest = try questOrThrow(run.questID)

        guard let resultIndex = run.checkpointResults.firstIndex(where: {
            $0.checkpointID == checkpointID
        }) else {
            throw RunEngineError.checkpointNotFound(checkpointID)
        }
        guard let checkpoint = quest.checkpoints.first(where: { $0.id == checkpointID }),
              let task = checkpoint.tasks.first(where: { $0.id == taskID }) else {
            throw RunEngineError.checkpointNotFound(taskID)
        }

        let record = TaskResult(
            taskID: task.id,
            type: task.type,
            promptSnapshot: task.prompt.value(for: run.language),
            skipped: skipped,
            text: skipped ? nil : text,
            // A skip discards the photograph the same way it discards the words: `AD-2` makes the
            // two resolutions symmetric, and a "skipped" result still holding an answer would make
            // the summary contradict itself.
            photoRelativePath: skipped ? nil : photoRelativePath,
            completedAt: now())

        // One result per task: answering after skipping replaces the skip rather than stacking.
        run.checkpointResults[resultIndex].taskResults
            .removeAll { $0.taskID == task.id }
        run.checkpointResults[resultIndex].taskResults.append(record)
        run.updatedAt = now()
        try store.save(run)
        return run
    }

    /// The walker's closing reflection, written from the Summary screen rather than during the
    /// walk. Allowed on a completed Run for the same reason `recordTaskResult` is
    /// (`FR-TASK-07`'s argument, `openRunOrThrow`) — the walk finishes on arrival at the last
    /// checkpoint, while the walker is still standing there with this still unwritten. Saving again
    /// replaces the entry rather than appending: there is one journal entry per walk.
    @discardableResult
    public func saveJournalEntry(
        runID: UUID,
        text: String,
        placePhotoRelativePath: String? = nil,
        selfiePhotoRelativePath: String? = nil
    ) throws -> Run {
        var run = try openRunOrThrow(runID)
        run.journalEntry = JournalEntry(
            text: text,
            placePhotoRelativePath: placePhotoRelativePath,
            selfiePhotoRelativePath: selfiePhotoRelativePath,
            savedAt: now())
        run.updatedAt = now()
        try store.save(run)
        return run
    }

    // MARK: - Ending

    /// `FR-RUN-04` / `FR-RUN-06`. The summary survives either way — an abandoned walk keeps every
    /// checkpoint it reached, because those happened.
    @discardableResult
    public func abandon(runID: UUID, reason: AbandonReason) throws -> Run {
        var run = try activeRunOrThrow(runID)
        run.state = .abandoned
        run.abandonedAt = now()
        run.abandonReason = reason
        run.updatedAt = now()
        try store.save(run)
        return run
    }

    // MARK: - Arrival, applied

    /// The single place a checkpoint becomes reached: snapshot, stamp, and — at the last
    /// checkpoint — completion and the badge.
    private func applyArrival(
        to run: inout Run,
        quest: Quest,
        checkpoint: Checkpoint,
        method: ArrivalMethod,
        accuracyM: Double?,
        at timestamp: Date
    ) throws {
        let place = (try? repository.place(id: checkpoint.placeId)) ?? nil

        let result = CheckpointResult(
            checkpointID: checkpoint.id,
            orderIndex: checkpoint.orderIndex,
            arrivedAt: timestamp,
            arrivalMethod: method,
            gpsAccuracyM: accuracyM,
            // `FR-CP-07` — the stamp lands here, on arrival, before any task exists to complete.
            stampAwardedAt: timestamp,
            snapshotPlaceName: place?.nameOfficial.value(for: run.language) ?? checkpoint.placeId,
            snapshotLore: LoreBlockSnapshot.snapshot(
                checkpoint.loreSegment, place: place, language: run.language),
            snapshotClueToNext: checkpoint.clueToNext?.value(for: run.language),
            snapshotContentVersion: quest.contentVersion)

        run.checkpointResults.append(result)
        run.currentCheckpointIndex = checkpoint.orderIndex
        run.awards.append(Award(
            type: .stamp,
            sourceID: checkpoint.stampId,
            snapshotName: result.snapshotPlaceName,
            awardedAt: timestamp))
        run.updatedAt = timestamp

        // `FR-DONE-01/02` — the walk completes on arrival at the final checkpoint, independent of
        // tasks, and the badge is awarded with it.
        let isFinal = quest.orderedCheckpoints.last?.orderIndex == checkpoint.orderIndex
        if isFinal {
            run.state = .completed
            run.completedAt = timestamp
            run.awards.append(Award(
                type: .badge,
                sourceID: quest.badgeId,
                snapshotName: run.snapshotQuestTitle,
                awardedAt: timestamp))
        }
    }

    // MARK: - Helpers

    private func activeRunOrThrow(_ id: UUID) throws -> Run {
        guard let run = try store.run(id: id) else { throw RunEngineError.runNotFound(id) }
        guard run.state == .active else { throw RunEngineError.runNotActive(run.state) }
        return run
    }

    /// Reading and task-answering stay open on a completed Run.
    ///
    /// The final checkpoint completes the walk the instant it is reached (`FR-DONE-01`), but the
    /// user is still standing there with the last of the story unread and the closing reflection
    /// unanswered — and `FR-TASK-07` requires that reflection to reach the summary. Gating these
    /// two calls on `active` would make completion swallow the ending.
    private func openRunOrThrow(_ id: UUID) throws -> Run {
        guard let run = try store.run(id: id) else { throw RunEngineError.runNotFound(id) }
        guard run.state == .active || run.state == .completed else {
            throw RunEngineError.runNotActive(run.state)
        }
        return run
    }

    private func questOrThrow(_ id: String) throws -> Quest {
        guard let quest = try repository.quest(id: id) else {
            throw RunEngineError.questNotFound(id)
        }
        return quest
    }
}
