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
    /// Whether the server copy went too (`c2` phase 3). `nil` when there was nothing on a server to
    /// delete — no backend configured, or no session ever obtained — which is a different answer
    /// from "we tried and could not", and the difference is the whole reason this is an optional.
    ///
    /// **`false` must be shown to the walker.** It is the one case where
    /// `01-architecture.md` R4's silence is wrong: a walker told their data is gone, while it is
    /// not, cannot act on something only they can decide about.
    let serverDataDeleted: Bool?

    init(
        deletedRuns: Int,
        deletedSideQuests: Int = 0,
        deletedProximityAlerts: Int = 0,
        deletedPhotos: Int,
        deletedTelemetryEvents: Int,
        clearedPreferences: Bool,
        serverDataDeleted: Bool? = nil
    ) {
        self.deletedRuns = deletedRuns
        self.deletedSideQuests = deletedSideQuests
        self.deletedProximityAlerts = deletedProximityAlerts
        self.deletedPhotos = deletedPhotos
        self.deletedTelemetryEvents = deletedTelemetryEvents
        self.clearedPreferences = clearedPreferences
        self.serverDataDeleted = serverDataDeleted
    }
}
