import Foundation

struct ErasureSummary: Sendable, Equatable {
    let deletedRuns: Int
    /// Sidequest records, counted separately from Runs because they *are* separate — a different
    /// aggregate in a different directory (`FR-SIDE-01`, `s0` D1). Folding them into `deletedRuns`
    /// would make the confirmation name a number of walks that never happened.
    let deletedSideQuests: Int
    let deletedPhotos: Int
    let deletedTelemetryEvents: Int
    let clearedPreferences: Bool

    init(
        deletedRuns: Int,
        deletedSideQuests: Int = 0,
        deletedPhotos: Int,
        deletedTelemetryEvents: Int,
        clearedPreferences: Bool
    ) {
        self.deletedRuns = deletedRuns
        self.deletedSideQuests = deletedSideQuests
        self.deletedPhotos = deletedPhotos
        self.deletedTelemetryEvents = deletedTelemetryEvents
        self.clearedPreferences = clearedPreferences
    }
}
