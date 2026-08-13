import Foundation

struct ErasureSummary: Sendable, Equatable {
    let deletedRuns: Int
    let deletedPhotos: Int
    let deletedTelemetryEvents: Int
    let clearedPreferences: Bool

    init(deletedRuns: Int, deletedPhotos: Int, deletedTelemetryEvents: Int, clearedPreferences: Bool) {
        self.deletedRuns = deletedRuns
        self.deletedPhotos = deletedPhotos
        self.deletedTelemetryEvents = deletedTelemetryEvents
        self.clearedPreferences = clearedPreferences
    }
}
