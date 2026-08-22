import Foundation
import PostgREST
import RunEngine

/// Sends finished and in-progress walks to the server. `c2` phase 3.
///
/// **Nothing reads this.** It is not injected into `RunEngine`, no view model calls it, and deleting
/// the type removes syncing and breaks nothing else. If that stops being true, the design has
/// drifted — the walk is local-first and the server is a copy of it (`AD-3`, `01-architecture.md`).
nonisolated protocol RunSyncing: Sendable {
    /// Push whatever has changed since the last successful push. Returns immediately in the sense
    /// that matters: no caller waits on the result, and there is no result to wait on.
    func push() async
}

/// What a push needs that a `Run` does not carry.
nonisolated struct SyncIdentity: Sendable {
    let userID: UUID
    let deviceID: UUID
}

/// The one thing that writes a walk to `app.*`.
///
/// Four properties are the design, and each of them is a decision:
///
/// - **Idempotent by construction.** Every write is an upsert on the row's own UUID, so pushing the
///   same walk twice is a no-op. That is the whole retry story.
/// - **A walk is the unit, not a row.** If any part of a walk fails, the walk stays dirty and the
///   whole of it is re-sent next time. Resuming mid-sequence would be per-table bookkeeping that
///   saves a few kilobytes and adds the one kind of state that can be wrong with nothing to detect
///   it (phase 3's trim).
/// - **No reachability check** (`AD-3`). It attempts the write and reads the outcome; being offline
///   and the server being down are the same event, and both mean "still dirty, try later".
/// - **Not `@MainActor`.** Serialising a walk's records on the main actor would be visible in
///   whatever is on screen.
actor SyncCoordinator: RunSyncing {

    /// `RunStore` is `@MainActor` (`RunStore.swift` says why), and this is not — so the walks
    /// arrive as a snapshot taken on the main actor rather than through a reference this actor
    /// would have to hop for. `Run` is `Sendable`, which is what makes the snapshot legal.
    private let loadRuns: @Sendable @MainActor () throws -> [Run]
    private let session: any SupabaseSessionProviding
    private let configuration: BackendConfiguration?
    private let state: SyncStateStore
    private let photoUploader: (any PhotoUploading)?
    /// A closure rather than the preference store itself, so this actor takes no `@MainActor`
    /// dependency it would have to hop to on every push. Supplied by the composition root, which is
    /// the only place that can see preferences.
    private let deviceID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    /// Guards against a foreground and a completion pushing at once — the second would re-send rows
    /// the first is mid-way through, and both would mark the same walk clean.
    private var inFlight: Task<Void, Never>?
    /// How long to wait before the next attempt after a failure. Doubles to the cap and resets on
    /// success. Not a timer: nothing schedules a retry, this only refuses to try again too soon
    /// when a trigger happens to fire.
    private var backoff: TimeInterval = 0
    private var nextAttemptAllowedAt: Date = .distantPast

    private static let firstBackoff: TimeInterval = 15
    private static let maximumBackoff: TimeInterval = 10 * 60

    init(
        loadRuns: @escaping @Sendable @MainActor () throws -> [Run],
        session: any SupabaseSessionProviding,
        configuration: BackendConfiguration?,
        state: SyncStateStore = FileSyncStateStore(),
        photoUploader: (any PhotoUploading)? = nil,
        deviceID: @escaping @Sendable () -> UUID,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.loadRuns = loadRuns
        self.session = session
        self.configuration = configuration
        self.state = state
        self.photoUploader = photoUploader
        self.deviceID = deviceID
        self.now = now
    }

    func push() async {
        if let inFlight { return await inFlight.value }
        let task = Task { await performPush() }
        inFlight = task
        await task.value
        inFlight = nil
    }

    private func performPush() async {
        guard let configuration, now() >= nextAttemptAllowedAt else { return }
        guard let token = await session.accessToken(), let userID = await session.userID() else {
            // No session is the ordinary offline case, not a failure worth backing off from: the
            // next foreground will have one or it will not, and either way nothing is wrong.
            return
        }

        let dirty: [Run]
        do {
            dirty = try await pushable()
        } catch {
            return
        }
        guard !dirty.isEmpty else {
            succeeded()
            return
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

        var allLanded = true
        for run in dirty {
            do {
                try await push(run, to: client, identity: SyncIdentity(
                    userID: userID, deviceID: deviceID()))
                state.markPushed(runID: run.id, updatedAt: run.updatedAt)
            } catch {
                // The walk stays dirty. Nothing is surfaced: a push that did not land is not
                // something a walker did wrong, or can do anything about (R4).
                allLanded = false
            }
        }
        allLanded ? succeeded() : failed()
    }

    /// Walks worth sending: started, and changed since they last landed.
    ///
    /// `notStarted` is excluded because the server's check constraint has no such state and a Run in
    /// it has not been walked. Tombstoned walks do not exist (phase 2's cut list) — the only delete
    /// is erase-all, which takes the account with it.
    private func pushable() async throws -> [Run] {
        let loadRuns = self.loadRuns
        let all = try await MainActor.run { try loadRuns() }
        return all
            .filter { $0.state != .notStarted }
            .filter { state.needsPush(runID: $0.id, updatedAt: $0.updatedAt) }
    }

    /// Fixed by foreign keys, not by preference: migration 0006 creates `photos` before
    /// `task_results` because a task result may point at a photograph.
    ///
    /// `runs` → `photos` → `checkpoint_results` → `task_results` → `awards`. `app.profiles` is not
    /// in the sequence; it carries no `server_seq` and is absent from the design's push order.
    private func push(
        _ run: Run, to client: PostgrestClient, identity: SyncIdentity
    ) async throws {
        let stamp = SyncStamp(
            deviceID: identity.deviceID, createdAt: run.startedAt, updatedAt: run.updatedAt)
        try await client.from("runs")
            .upsert(RunRow(run, userID: identity.userID, stamp: stamp))
            .execute()

        // Phase 4. Nil until then, and the empty step is kept so the order above stays whole.
        let photoIDs = try await photoUploader?.upload(
            photosFor: run, identity: identity, configuration: configuration) ?? [:]

        let checkpoints = run.orderedCheckpointResults
        if !checkpoints.isEmpty {
            try await client.from("checkpoint_results")
                .upsert(checkpoints.map {
                    CheckpointResultRow(
                        $0, runID: run.id, userID: identity.userID, deviceID: identity.deviceID)
                })
                .execute()
        }

        let tasks = checkpoints.flatMap { checkpoint in
            checkpoint.taskResults.map { task in
                TaskResultRow(
                    task,
                    checkpointResultID: checkpoint.id,
                    runID: run.id,
                    userID: identity.userID,
                    deviceID: identity.deviceID,
                    photoID: task.photoRelativePath.flatMap { photoIDs[$0] })
            }
        }
        if !tasks.isEmpty {
            try await client.from("task_results").upsert(tasks).execute()
        }

        if !run.awards.isEmpty {
            try await client.from("awards")
                .upsert(run.awards.map {
                    AwardRow($0, runID: run.id, userID: identity.userID, deviceID: identity.deviceID)
                })
                .execute()
        }
    }

    private func succeeded() {
        backoff = 0
        nextAttemptAllowedAt = .distantPast
    }

    private func failed() {
        backoff = backoff == 0
            ? Self.firstBackoff
            : min(backoff * 2, Self.maximumBackoff)
        nextAttemptAllowedAt = now().addingTimeInterval(backoff)
    }
}

/// Phase 4's seam, declared here so phase 3's push order has the step it needs and phase 3's tests
/// can leave it out.
nonisolated protocol PhotoUploading: Sendable {
    /// Uploads whatever this walk's photographs need and answers with
    /// `photoRelativePath -> app.photos.id`, so a task result can carry `photo_id`.
    func upload(
        photosFor run: Run,
        identity: SyncIdentity,
        configuration: BackendConfiguration?
    ) async throws -> [String: UUID]
}

/// Does nothing, on purpose. Nothing syncs when there is no backend, and every caller must behave
/// the same way as when there is one and the radio is off.
nonisolated struct NoRunSyncing: RunSyncing {
    func push() async {}
}

/// Erasing the server copy, so `FR-SET-02` is not a claim about this device only.
///
/// A protocol rather than a method on `SyncCoordinator`, because the two do opposite things and the
/// eraser has no business holding something that can push.
nonisolated protocol AccountDeleting: Sendable {
    /// Answers whether the rows are gone. **The caller reports a `false`** — see `DataEraser` for
    /// why this is the one place R4's silence does not apply.
    @discardableResult func deleteAccount() async -> Bool
}

/// Calls the deployed `delete-account` function (`verify_jwt = true`), which is the only thing that
/// can remove a user's rows: the app holds a publishable key, and RLS lets a walker delete their own
/// rows one table at a time but not the `auth.users` row underneath them.
nonisolated struct EdgeFunctionAccountDeleter: AccountDeleting {

    let configuration: BackendConfiguration
    let session: any SupabaseSessionProviding
    let urlSession: URLSession

    init(
        configuration: BackendConfiguration,
        session: any SupabaseSessionProviding,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.urlSession = urlSession
    }

    @discardableResult func deleteAccount() async -> Bool {
        guard let token = await session.accessToken() else { return false }
        var request = URLRequest(url: configuration.functionURL("delete-account"))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (_, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse
        else { return false }
        // The function is idempotent and answers 200 for an account it has already removed, so a
        // second erasure is not a failure.
        return (200..<300).contains(http.statusCode)
    }
}
