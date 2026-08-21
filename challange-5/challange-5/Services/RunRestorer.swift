import ContentKit
import Foundation
import PostgREST
import RunEngine

/// Brings a walker's walks back onto a device that has none. `c2` phase 7.
///
/// **This is not the pull sync `00-scope.md` §6 rules out.** That bullet rejects pull because a
/// conflict has to be shown to somebody and no screen for one exists. This runs *only into an empty
/// store* and refuses otherwise, so there is no second writer and no conflict can exist — the same
/// argument phase 3 makes for push, from the other side. It happens once, at a known moment, not
/// continuously.
///
/// The empty-store guard is the whole safety argument, which is why it is a `guard` at the top of
/// the one entry point and a test rather than a comment.
nonisolated protocol RunRestoring: Sendable {
    /// Restores if — and only if — the local store is empty. Answers how many walks came back, or
    /// `nil` if it did not run at all.
    func restoreIfLocalStoreIsEmpty() async -> RestoreOutcome?
}

nonisolated struct RestoreOutcome: Sendable, Equatable {
    let restoredRuns: Int
    /// `false` when the read failed. **The caller must not treat this as "you had nothing"** — a
    /// walker cannot tell that apart from "we could not fetch it", and only one is recoverable by
    /// trying again. This is the second place `01-architecture.md` R4's silence is wrong, after
    /// `delete-account`.
    let succeeded: Bool
}

actor RunRestorer: RunRestoring {

    private let loadRuns: @Sendable @MainActor () throws -> [Run]
    private let saveRun: @Sendable @MainActor (Run) throws -> Void
    private let session: any SupabaseSessionProviding
    private let configuration: BackendConfiguration?
    private let state: SyncStateStore
    /// Two things a `Run` carries that are **content, not snapshots**, and so were never sent:
    /// the quest's title and how many checkpoints it has. Resolved from the bundle at restore time
    /// rather than pushed to the server, which is `AD-4` applied in the direction it is usually
    /// applied the other way — user data references content by id, and the id is what came back.
    ///
    /// A withdrawn quest resolves to nothing, and the walk then shows its id rather than a blank
    /// row. That is the honest fallback: the record is real, only its name is gone.
    private let resolveQuest: @Sendable (String) -> QuestFacts?

    init(
        loadRuns: @escaping @Sendable @MainActor () throws -> [Run],
        saveRun: @escaping @Sendable @MainActor (Run) throws -> Void,
        session: any SupabaseSessionProviding,
        configuration: BackendConfiguration?,
        state: SyncStateStore,
        resolveQuest: @escaping @Sendable (String) -> QuestFacts? = { _ in nil }
    ) {
        self.loadRuns = loadRuns
        self.saveRun = saveRun
        self.session = session
        self.configuration = configuration
        self.state = state
        self.resolveQuest = resolveQuest
    }

    func restoreIfLocalStoreIsEmpty() async -> RestoreOutcome? {
        guard let configuration else { return nil }

        // **The guard.** A walker who walked before signing in has local data that is already
        // theirs; restoring over it is the merge this phase refuses to do. Checked immediately
        // before the read rather than at launch, so a walk started in between is still seen.
        let loadRuns = self.loadRuns
        let existing = try? await MainActor.run { try loadRuns() }
        guard let existing, existing.isEmpty else { return nil }

        guard let token = await session.accessToken(), await session.userID() != nil else {
            // No session is the ordinary offline case, and there is nothing to report about it.
            return nil
        }

        let client = PostgrestClient(
            url: configuration.restURL,
            schema: "app",
            headers: [
                "apikey": configuration.publishableKey,
                "Authorization": "Bearer \(token)",
            ],
            encoder: SyncWireFormat.encoder,
            decoder: SyncWireFormat.decoder)

        do {
            // RLS already scopes every one of these to the caller, so none of them filters by
            // `user_id` — a query written as if it had to would be describing a guarantee it does
            // not provide.
            let runs: [RunRow] = try await client.from("runs")
                .select().is("deleted_at", value: nil).execute().value
            guard !runs.isEmpty else { return RestoreOutcome(restoredRuns: 0, succeeded: true) }

            let checkpoints: [CheckpointResultRow] = try await client.from("checkpoint_results")
                .select().is("deleted_at", value: nil).execute().value
            let tasks: [TaskResultRow] = try await client.from("task_results")
                .select().is("deleted_at", value: nil).execute().value
            let awards: [AwardRow] = try await client.from("awards")
                .select().is("deleted_at", value: nil).execute().value

            let assembled = RunAssembly.runs(
                from: runs, checkpoints: checkpoints, tasks: tasks, awards: awards,
                quest: resolveQuest)

            let saveRun = self.saveRun
            try await MainActor.run {
                for run in assembled { try saveRun(run) }
            }
            // Marked as landed at the value they came back with, so the first foreground after a
            // restore does not push every walk straight back at the server.
            for run in assembled {
                state.markPushed(runID: run.id, updatedAt: run.updatedAt)
            }
            return RestoreOutcome(restoredRuns: assembled.count, succeeded: true)
        } catch {
            return RestoreOutcome(restoredRuns: 0, succeeded: false)
        }
    }
}

/// Rows back into `Run` values.
///
/// A free function rather than initialisers on the DTOs, because assembling a walk needs all four
/// tables at once and a row does not know about its siblings.
nonisolated enum RunAssembly {

    static func runs(
        from runs: [RunRow],
        checkpoints: [CheckpointResultRow],
        tasks: [TaskResultRow],
        awards: [AwardRow],
        quest: (String) -> QuestFacts? = { _ in nil }
    ) -> [Run] {
        let tasksByCheckpoint = Dictionary(grouping: tasks, by: \.checkpoint_result_id)
        let checkpointsByRun = Dictionary(grouping: checkpoints, by: \.run_id)
        let awardsByRun = Dictionary(grouping: awards.filter { $0.run_id != nil }, by: { $0.run_id! })

        return runs.map { row in
            let results = (checkpointsByRun[row.id] ?? [])
                .sorted { $0.order_index < $1.order_index }
                .map { checkpoint in
                    CheckpointResult(
                        id: checkpoint.id,
                        checkpointID: checkpoint.checkpoint_id,
                        orderIndex: checkpoint.order_index,
                        arrivedAt: checkpoint.arrived_at,
                        arrivalMethod: ArrivalMethod(rawValue: checkpoint.arrival_method) ?? .manual,
                        // **The metre value does not come back, and must not be invented.** Only
                        // the band was ever sent (`NFR-PRIV-02`), and turning a band back into a
                        // number would put a fiction in a restored record.
                        gpsAccuracyM: nil,
                        loreFirstOpenedAt: checkpoint.lore_first_opened_at,
                        stampAwardedAt: checkpoint.stamp_awarded_at,
                        snapshotPlaceName: checkpoint.snapshot_place_name,
                        snapshotLore: checkpoint.snapshot_lore,
                        // No server column, by phase 2's decision: it is what the *next* screen
                        // prints during a walk, not part of the record, and a finished walk never
                        // shows it. Empty rather than invented.
                        snapshotClueToNext: nil,
                        snapshotContentVersion: checkpoint.snapshot_content_version,
                        taskResults: (tasksByCheckpoint[checkpoint.id] ?? [])
                            .sorted { $0.completed_at < $1.completed_at }
                            .map(taskResult))
                }

            return Run(
                id: row.id,
                questID: row.quest_id,
                contentVersion: row.content_version,
                language: ContentLanguage(rawValue: row.language) ?? .id,
                // Neither is a server column: both are content, resolved by id (`AD-4`). A
                // withdrawn quest leaves the id showing rather than a blank row — the walk is real,
                // only its name is gone.
                snapshotQuestTitle: quest(row.quest_id)?.title ?? row.quest_id,
                checkpointCount: quest(row.quest_id)?.checkpointCount
                    ?? max(results.count, row.current_checkpoint_index + 1),
                state: RunState(rawValue: row.state) ?? .completed,
                currentCheckpointIndex: row.current_checkpoint_index,
                startedAt: row.started_at,
                updatedAt: row.updated_at,
                completedAt: row.completed_at,
                abandonedAt: row.abandoned_at,
                abandonReason: row.abandon_reason.flatMap(AbandonReason.init(rawValue:)),
                checkpointResults: results,
                awards: (awardsByRun[row.id] ?? []).map(award))
        }
    }

    private static func taskResult(_ row: TaskResultRow) -> TaskResult {
        TaskResult(
            id: row.id,
            taskID: row.task_id,
            type: TaskType(rawValue: row.type) ?? .reflection,
            // No server column. The prompt is content, and a restored walk resolves it from the
            // content bundle when it can — an empty string here rather than a guess.
            promptSnapshot: "",
            skipped: row.skipped,
            text: row.answer_text,
            // Phase 4 uploads the bytes; a restored device downloads them lazily, so the local
            // path is not known until then.
            photoRelativePath: nil,
            completedAt: row.completed_at)
    }

    private static func award(_ row: AwardRow) -> Award {
        Award(
            id: row.id,
            type: AwardType(rawValue: row.type) ?? .stamp,
            sourceID: row.source_id,
            snapshotName: row.snapshot_name,
            awardedAt: row.awarded_at)
    }
}

/// The two content facts a restored `Run` needs and the server never held.
nonisolated struct QuestFacts: Sendable, Equatable {
    let title: String
    let checkpointCount: Int
}

/// Restores nothing. What the app uses with no backend, and what the tests use by default.
nonisolated struct NoRunRestoring: RunRestoring {
    func restoreIfLocalStoreIsEmpty() async -> RestoreOutcome? { nil }
}
