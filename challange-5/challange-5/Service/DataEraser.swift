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
/// Preferences *and* Runs, in one call, because a language override that survives "delete all local
/// data" is a surprise and a completed walk that survives it is a privacy failure. Photos are not
/// listed because this build writes none; when photo tasks ship, the photo directory has to be
/// removed here too — deleting rows alone leaves image files on disk, which passes every database
/// test and fails the requirement.
@MainActor
final class RunAndPreferencesDataEraser: LocalDataEraser {

    private let store: any RunStore
    private let preferences: any AppPreferencesStore

    init(store: any RunStore, preferences: any AppPreferencesStore) {
        self.store = store
        self.preferences = preferences
    }

    func eraseAllLocalData() throws -> ErasureSummary {
        let deletedRuns = try store.deleteAll()
        preferences.removeAll()
        return ErasureSummary(
            deletedRuns: deletedRuns,
            deletedPhotos: 0,
            deletedTelemetryEvents: 0,
            clearedPreferences: true)
    }
}
