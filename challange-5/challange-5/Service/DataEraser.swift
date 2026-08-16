import ContentKit
import Foundation
import RunEngine

/// `FR-SET-02`. The protocol is the whole point: M5 has no Runs, photos, reflections, awards or
/// queued telemetry to delete, so the implementation here clears preferences and reports zero for
/// the rest. M6 and M7 supply the real one behind the same call, and the UI copy already tells the
/// user what this build actually holds rather than implying it holds everything.
@MainActor
protocol LocalDataEraser {
    func eraseAllLocalData() throws -> ErasureSummary
}

@MainActor
final class PreferencesOnlyDataEraser: LocalDataEraser {
    private let store: any AppPreferencesStore

    init(store: any AppPreferencesStore) {
        self.store = store
    }

    func eraseAllLocalData() throws -> ErasureSummary {
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
@MainActor
final class RunAndPreferencesDataEraser: LocalDataEraser {

    private let store: any RunStore
    private let sideQuestStore: (any SideQuestStore)?
    private let proximityMonitor: (any ProximityMonitoring)?
    private let photoStore: (any PhotoStore)?
    private let preferences: any AppPreferencesStore

    init(
        store: any RunStore,
        sideQuestStore: (any SideQuestStore)? = nil,
        proximityMonitor: (any ProximityMonitoring)? = nil,
        photoStore: (any PhotoStore)? = nil,
        preferences: any AppPreferencesStore
    ) {
        self.store = store
        self.sideQuestStore = sideQuestStore
        self.proximityMonitor = proximityMonitor
        self.photoStore = photoStore
        self.preferences = preferences
    }

    func eraseAllLocalData() throws -> ErasureSummary {
        let deletedRuns = try store.deleteAll()
        // Letters go with them. A collection is a record of where somebody has been, and
        // "delete all local data" that left it standing would be the plainest possible lie.
        let deletedSideQuests = try sideQuestStore?.deleteAll() ?? 0
        let deletedProximityAlerts = try proximityMonitor?.deleteAllAlerts() ?? 0
        let deletedPhotos = try photoStore?.deleteAll() ?? 0
        preferences.removeAll()
        return ErasureSummary(
            deletedRuns: deletedRuns,
            deletedSideQuests: deletedSideQuests,
            deletedProximityAlerts: deletedProximityAlerts,
            deletedPhotos: deletedPhotos,
            deletedTelemetryEvents: 0,
            clearedPreferences: true)
    }
}
