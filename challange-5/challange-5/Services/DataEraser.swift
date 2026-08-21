import ContentKit
import Foundation
import RunEngine

/// `FR-SET-02`. The protocol is the whole point: M5 has no Runs, photos, reflections, awards or
/// queued telemetry to delete, so the implementation here clears preferences and reports zero for
/// the rest. M6 and M7 supply the real one behind the same call, and the UI copy already tells the
/// user what this build actually holds rather than implying it holds everything.
@MainActor
protocol LocalDataEraser {
    func eraseAllLocalData() async throws -> ErasureSummary
}

@MainActor
final class PreferencesOnlyDataEraser: LocalDataEraser {
    private let store: any AppPreferencesStore

    init(store: any AppPreferencesStore) {
        self.store = store
    }

    func eraseAllLocalData() async throws -> ErasureSummary {
        store.removeAll()
        return ErasureSummary(
            deletedRuns: 0, deletedPhotos: 0, deletedTelemetryEvents: 0, clearedPreferences: true)
    }
}

/// `FR-SET-02` — the real eraser, now that there is something to erase.
///
/// Preferences, Runs *and* sidequest records, in one call, because a language override that
/// survives "delete all local data" is a surprise and a completed walk that survives it is a
/// privacy failure. Photos are not listed because this build writes none; when photo challenges
/// ship (`s4` §7, `FR-SIDE-13`), the photo directory has to be removed here too — deleting rows
/// alone leaves image files on disk, which passes every database test and fails the requirement.
///
/// The sidequest store is a *separate* store rather than more rows in the Run store (`FR-SIDE-01`,
/// `s0` D1), which is exactly why it has to be named here: `FR-SET-02` is about everything on the
/// device, and a second aggregate is a second thing to forget.
///
/// The proximity monitor is named for the same reason: its alert rows are a third aggregate
/// (`s3` §2), and `NFR-PRIV-09` treats them as the closest thing this app keeps to a movement
/// history, which is exactly what "delete all local data" must not leave standing.
///
/// The photo store is a fourth: deleting a sidequest record alone leaves its image file on disk,
/// which passes every database test and fails `FR-SET-02` — the exact mistake `s4` §7 warns about
/// (`NFR-PRIV-01`).
///
/// The telemetry queue is a fifth (`c2` phase 0). It holds no identifier and no coordinate by
/// construction — that is what `ops.events` having no user column means on this side of the wire —
/// but unsent rows are still local data, and leaving them would make the summary's count of deleted
/// events a number that is true only because nothing counted.
@MainActor
final class RunAndPreferencesDataEraser: LocalDataEraser {

    private let store: any RunStore
    private let sideQuestStore: (any SideQuestStore)?
    private let proximityMonitor: (any ProximityMonitoring)?
    private let photoStore: (any PhotoStore)?
    private let telemetry: AppTelemetry?
    private let session: (any SupabaseSessionProviding)?
    /// `c2` phase 3. Once rows exist on the server, local-only erasure makes Settings say something
    /// untrue (`FR-SET-02`).
    private let accountDeleter: (any AccountDeleting)?
    private let syncState: (any SyncStateStore)?
    private let preferences: any AppPreferencesStore

    init(
        store: any RunStore,
        sideQuestStore: (any SideQuestStore)? = nil,
        proximityMonitor: (any ProximityMonitoring)? = nil,
        photoStore: (any PhotoStore)? = nil,
        telemetry: AppTelemetry? = nil,
        session: (any SupabaseSessionProviding)? = nil,
        accountDeleter: (any AccountDeleting)? = nil,
        syncState: (any SyncStateStore)? = nil,
        preferences: any AppPreferencesStore
    ) {
        self.store = store
        self.sideQuestStore = sideQuestStore
        self.proximityMonitor = proximityMonitor
        self.photoStore = photoStore
        self.telemetry = telemetry
        self.session = session
        self.accountDeleter = accountDeleter
        self.syncState = syncState
        self.preferences = preferences
    }

    func eraseAllLocalData() async throws -> ErasureSummary {
        let deletedRuns = try store.deleteAll()
        // Letters go with them. A collection is a record of where somebody has been, and
        // "delete all local data" that left it standing would be the plainest possible lie.
        let deletedSideQuests = try sideQuestStore?.deleteAll() ?? 0
        let deletedProximityAlerts = try proximityMonitor?.deleteAllAlerts() ?? 0
        let deletedPhotos = try photoStore?.deleteAll() ?? 0
        // A fifth aggregate as of `c2` phase 0: rows queued for the anonymous ingest endpoint, and
        // the per-walk pseudonymous keys beside them. Neither identifies anybody, and both are
        // still local data somebody asked to be rid of.
        let deletedTelemetryEvents = telemetry?.eraseQueue() ?? 0
        // `c2` phase 1. The stored session is a bearer credential for this walker's own history;
        // leaving it behind would mean the next launch silently resumes as the same `auth.users`
        // row somebody just asked to be disconnected from. Detached because erasure is synchronous
        // and must not start waiting on the Keychain — and because nothing here can fail in a way
        // the summary should report.
        // `c2` phase 3. The server copy goes first, then the local session — in that order,
        // because `delete-account` needs the token the sign-out is about to forget.
        //
        // **Awaited, unlike every other network call in this app.** A deletion that did not land is
        // a walker who has been told their data is gone while it is not, and only they can decide
        // what to do about that — so this is the one place `01-architecture.md` R4's silence is
        // wrong, and the outcome goes into the summary rather than into a `try?`.
        var serverDataDeleted: Bool?
        if let accountDeleter {
            serverDataDeleted = await accountDeleter.deleteAccount()
        }
        await session?.signOut()
        // Forgetting what has already been pushed is not optional: without it, a walk written after
        // erasure could be judged "already sent" against a row that no longer exists.
        syncState?.forgetAll()
        // `preferences.removeAll()` takes `deviceID` with it, so the next launch is a new install
        // as far as `schema.md` §C.2 is concerned. Deliberate: a walker who erases should not stay
        // the same device to the server.
        preferences.removeAll()
        return ErasureSummary(
            deletedRuns: deletedRuns,
            deletedSideQuests: deletedSideQuests,
            deletedProximityAlerts: deletedProximityAlerts,
            deletedPhotos: deletedPhotos,
            deletedTelemetryEvents: deletedTelemetryEvents,
            clearedPreferences: true,
            serverDataDeleted: serverDataDeleted)
    }
}
