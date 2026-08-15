import Foundation

struct ErasureSummary: Sendable, Equatable {
    let deletedRuns: Int
    /// Sidequest records, counted separately from Runs because they *are* separate — a different
    /// aggregate in a different directory (`FR-SIDE-01`, `s0` D1). Folding them into `deletedRuns`
    /// would make the confirmation name a number of walks that never happened.
    let deletedSideQuests: Int
    /// `ProximityAlert` rows — counted separately for the same reason `deletedSideQuests` is: a
    /// different aggregate, in a different file (`s3` §2, `NFR-PRIV-09`).
    let deletedProximityAlerts: Int
    let deletedPhotos: Int
    let deletedTelemetryEvents: Int
    let clearedPreferences: Bool

    init(
        deletedRuns: Int,
        deletedSideQuests: Int = 0,
        deletedProximityAlerts: Int = 0,
        deletedPhotos: Int,
        deletedTelemetryEvents: Int,
        clearedPreferences: Bool
    ) {
        self.deletedRuns = deletedRuns
        self.deletedSideQuests = deletedSideQuests
        self.deletedProximityAlerts = deletedProximityAlerts
        self.deletedPhotos = deletedPhotos
        self.deletedTelemetryEvents = deletedTelemetryEvents
        self.clearedPreferences = clearedPreferences
    }
}
