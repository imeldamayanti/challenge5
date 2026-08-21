import Foundation
import RunEngine
import TelemetryKit

/// The app's call sites for anonymous telemetry (`system-design.md` §10, design §6.2,
/// `NFR-OBS-01`, `c2` phase 0).
///
/// `TelemetryKit` owns the durable queue, the batch caps and the flush. This is the layer that
/// knows what the app's events are called and what they carry — `schema.md` §B.7's catalogue,
/// built one constructor per row so a caller cannot invent a shape.
///
/// **Nothing here identifies a person.** `ops.events` has no user column and must never acquire one
/// (design §2.4). What travels is a walk's own pseudonymous key, minted on device, kept beside the
/// walk, and never written to any synced table — so a funnel stays analysable without a join back
/// to anybody. `TelemetryPayloadBoundaryTests` scans this file for the alternative.
///
/// **No coordinate leaves the device.** An arrival reports a checkpoint id and an accuracy *band*
/// (`NFR-PRIV-02`); there is no constructor here that takes a position, and `TelemetryKit` cannot
/// import anything that carries one.
///
/// **Optional at runtime.** With no backend configured, every method here is a no-op and the app
/// behaves exactly as it does today. Nothing waits on a flush and nothing reads its result
/// (`AD-3`).
@MainActor
final class AppTelemetry {

    private let service: TelemetryService?
    private let queueStore: any TelemetryQueueStore
    private let runKeys: RunKeyStore
    /// Work handed to the actor, chained so it runs in the order it was asked for.
    ///
    /// Not a detail: `record` and `flush` are both fire-and-forget, and unchained they race — the
    /// flush after a finished walk could reach the actor before the `quest_completed` it exists to
    /// carry, which would silently hold the most interesting row back until the next foreground.
    private var pending: Task<Void, Never> = Task {}

    init(
        configuration: BackendConfiguration?,
        store: any TelemetryQueueStore = FileTelemetryQueueStore(
            directory: GovernanceGate.defaultDirectory()),
        transport: any TelemetryTransport = URLSessionTelemetryTransport(),
        runKeys: RunKeyStore = RunKeyStore()
    ) {
        self.queueStore = store
        self.runKeys = runKeys
        service = configuration.map {
            TelemetryService(url: $0.ingestURL, transport: transport, store: store)
        }
    }

    // MARK: The catalogue

    /// `quest_started` — the completion-rate denominator.
    func questStarted(questID: String, contentVersion: String, language: String, runID: UUID) {
        record(TelemetryEvent(
            id: .v7(),
            name: "quest_started",
            params: ["questID": questID, "contentVersion": contentVersion, "language": language],
            runKey: runKeys.key(for: runID)))
    }

    /// `checkpoint_arrived` — drop-off, and how often the `FR-ARR-01` gate fails in the field.
    ///
    /// Metres are turned into a band **here, at the boundary**, and the band is what the type can
    /// carry onwards. `TelemetryEvent.arrival` is deliberately the only arrival constructor and
    /// takes no overload for a raw figure.
    func checkpointArrived(
        checkpointID: String, accuracyMetres: Double, arrivalMethod: String, runID: UUID
    ) {
        record(.arrival(
            id: .v7(),
            checkpointID: checkpointID,
            band: AccuracyBand(metres: accuracyMetres),
            method: arrivalMethod,
            runKey: runKeys.key(for: runID)))
    }

    /// `quest_completed` — the completion-rate numerator.
    func questCompleted(
        questID: String, durationMinutes: Int, manualOverrideCount: Int, runID: UUID
    ) {
        record(TelemetryEvent(
            id: .v7(),
            name: "quest_completed",
            params: [
                "questID": questID,
                "durationMin": String(durationMinutes),
                "manualOverrideCount": String(manualOverrideCount),
            ],
            runKey: runKeys.key(for: runID)))
    }

    /// `quest_abandoned` — drop-off diagnosis, including a walk the kill-switch ended (`AD-5`).
    func questAbandoned(questID: String, lastOrderIndex: Int, reason: String, runID: UUID) {
        record(TelemetryEvent(
            id: .v7(),
            name: "quest_abandoned",
            params: [
                "questID": questID,
                "lastOrderIndex": String(lastOrderIndex),
                "reason": reason,
            ],
            runKey: runKeys.key(for: runID)))
    }

    // MARK: Queue

    /// Durable before the caller's next line runs, from the caller's point of view: the write
    /// happens inside the actor and nothing here awaits it, which is what keeps a screen
    /// transition off the disk's critical path.
    private func record(_ event: TelemetryEvent) {
        enqueue { await $0.record(event) }
    }

    /// One opportunistic flush. Foreground, background, and after a walk finishes — never on a
    /// timer and never on a transition somebody is waiting for. Telemetry is the first thing that
    /// will look like a battery bug.
    func flush() {
        enqueue { await $0.flush() }
    }

    /// Waits for everything asked for so far. Tests only — nothing in the app waits on telemetry,
    /// which is the whole reason the calls above return immediately.
    func settled() async {
        await pending.value
    }

    private func enqueue(_ work: @escaping @Sendable (TelemetryService) async -> Void) {
        guard let service else { return }
        let previous = pending
        pending = Task { [service] in
            await previous.value
            await work(service)
        }
    }

    /// `FR-SET-02` — the queue is local data like any other, and "delete all local data" that left
    /// unsent rows standing would be a lie by the width of whatever had not flushed.
    @discardableResult
    func eraseQueue() -> Int {
        runKeys.removeAll()
        let queued = queueStore.load()
        queueStore.save(TelemetryQueueFile())
        // The file is the durable copy, so it is emptied first and the actor is told afterwards.
        // `TelemetryService.reload` explains why this is not an `erase()` on the actor itself.
        if let service { Task { await service.reload() } }
        return queued.events.count + queued.surveyResponses.count
    }
}

/// One pseudonymous key per walk, minted on device (`c1` D6, design §2.4).
///
/// Random and unrelated to the Run's own id, kept in a file beside the Run store, and **never
/// written to any synced table** — the point is that events group into a walk without the walk
/// being attributable to anybody. Erased with everything else by `FR-SET-02`.
@MainActor
final class RunKeyStore {

    private let url: URL
    private var keys: [String: UUID]

    init(url: URL = RunKeyStore.defaultURL()) {
        self.url = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: UUID].self, from: data) {
            keys = decoded
        } else {
            keys = [:]
        }
    }

    func key(for runID: UUID) -> UUID {
        let index = runID.uuidString
        if let existing = keys[index] { return existing }
        // Random, not derived. A key derived from the walk's id would be reversible by anyone
        // holding both, which is the whole property being bought here.
        let minted = UUID()
        keys[index] = minted
        save()
        return minted
    }

    func removeAll() {
        keys = [:]
        try? FileManager.default.removeItem(at: url)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(keys) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func defaultURL() -> URL {
        GovernanceGate.defaultDirectory().appendingPathComponent("run-keys.json")
    }
}
