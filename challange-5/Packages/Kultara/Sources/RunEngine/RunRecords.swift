import ContentKit
import Foundation

// The device-authored user store (`schema.md` Part B). Everything here is a value type, `Codable`,
// and carries a UUID plus timestamps from day one, so v2 sync is a schema addition rather than an
// identity migration (`NFR-MAINT-04`).
//
// The rule that shapes every type below: **no reference into content**. A `Run` names its quest by
// `questID: String` and pins `contentVersion`. Replacing the content bundle — by an app update now,
// by a CMS fetch in v3 — must not orphan, rewrite, or cascade-delete a walk somebody finished
// (`system-design.md` §4).

public enum RunState: String, Codable, Sendable, CaseIterable {
    case notStarted, active, completed, abandoned
}

public enum AbandonReason: String, Codable, Sendable, CaseIterable {
    case userChoice, placeSuppressed
}

/// `FR-ARR-04` — `manual` is a legitimate path, not a lesser one. Nothing in this module reads this
/// value to reduce a reward; it exists because `FR-ARR-03` requires it to be recorded.
public enum ArrivalMethod: String, Codable, Sendable, CaseIterable {
    case gps, manual
}

public enum AwardType: String, Codable, Sendable, CaseIterable {
    case stamp, badge
}

// MARK: - Snapshots

/// One claim, already resolved to the Run's language, with its accuracy label and citations copied
/// alongside it (`system-design.md` §4.1).
///
/// The citations are copied as text rather than as indices into the Place's `sources` array,
/// because an index is a reference into content by another name: renumbering `sources` in a
/// correction would silently re-attribute a claim in somebody's finished walk.
public struct LoreBlockSnapshot: Codable, Sendable, Equatable {
    public let text: String
    public let accuracy: AccuracyLabel
    public let sourceCitations: [String]

    public init(text: String, accuracy: AccuracyLabel, sourceCitations: [String]) {
        self.text = text
        self.accuracy = accuracy
        self.sourceCitations = sourceCitations
    }
}

// MARK: - TaskResult

public struct TaskResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let taskID: String
    public let type: TaskType
    /// The prompt as the user was asked it, so the summary reads back the question that produced
    /// the answer even after the wording is edited.
    public let promptSnapshot: String
    /// `AD-2` — a resolution, not a failure. Skipping is recorded the same way answering is.
    public let skipped: Bool
    public let text: String?
    /// Relative to the app container, never absolute: an absolute path resolves to nothing after a
    /// restore from backup, and the user's photographs appear to have vanished (`NFR-REL-05`).
    /// Unused until photo tasks ship; the field exists so the store does not need migrating then.
    public let photoRelativePath: String?
    public let completedAt: Date

    public init(
        id: UUID = UUID(),
        taskID: String,
        type: TaskType,
        promptSnapshot: String,
        skipped: Bool,
        text: String? = nil,
        photoRelativePath: String? = nil,
        completedAt: Date
    ) {
        self.id = id
        self.taskID = taskID
        self.type = type
        self.promptSnapshot = promptSnapshot
        self.skipped = skipped
        self.text = text
        self.photoRelativePath = photoRelativePath
        self.completedAt = completedAt
    }
}

// MARK: - CheckpointResult

/// One checkpoint reached, with the story the user actually read copied into it.
///
/// This denormalization is the whole reason a summary renders identically forever, offline, after a
/// content correction and after a Place is withdrawn. It satisfies `FR-DONE-04`, `FR-DONE-05` and
/// `FR-RUN-06` at the cost of a few kilobytes.
public struct CheckpointResult: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let checkpointID: String
    public let orderIndex: Int

    public let arrivedAt: Date
    public let arrivalMethod: ArrivalMethod
    /// Recorded for a manual arrival too — the last known accuracy is what explains *why* the
    /// override was needed (`FR-ARR-03`).
    public let gpsAccuracyM: Double?
    public var loreFirstOpenedAt: Date?
    public var stampAwardedAt: Date?

    // ── Content snapshot, captured at arrival ──
    /// `NFR-I18N-04` — the official local form, whatever the interface language was.
    public let snapshotPlaceName: String
    public let snapshotLore: [LoreBlockSnapshot]
    /// `nil` at the final checkpoint, where content has no clue to give (V10).
    public let snapshotClueToNext: String?
    public let snapshotContentVersion: String

    public var taskResults: [TaskResult]

    public init(
        id: UUID = UUID(),
        checkpointID: String,
        orderIndex: Int,
        arrivedAt: Date,
        arrivalMethod: ArrivalMethod,
        gpsAccuracyM: Double?,
        loreFirstOpenedAt: Date? = nil,
        stampAwardedAt: Date? = nil,
        snapshotPlaceName: String,
        snapshotLore: [LoreBlockSnapshot],
        snapshotClueToNext: String?,
        snapshotContentVersion: String,
        taskResults: [TaskResult] = []
    ) {
        self.id = id
        self.checkpointID = checkpointID
        self.orderIndex = orderIndex
        self.arrivedAt = arrivedAt
        self.arrivalMethod = arrivalMethod
        self.gpsAccuracyM = gpsAccuracyM
        self.loreFirstOpenedAt = loreFirstOpenedAt
        self.stampAwardedAt = stampAwardedAt
        self.snapshotPlaceName = snapshotPlaceName
        self.snapshotLore = snapshotLore
        self.snapshotClueToNext = snapshotClueToNext
        self.snapshotContentVersion = snapshotContentVersion
        self.taskResults = taskResults
    }
}

// MARK: - Award

public struct Award: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let type: AwardType
    /// `stampId` or `badgeId` from content.
    public let sourceID: String
    /// Carried so an award still has a name after the content that defined it is gone.
    public let snapshotName: String
    public let awardedAt: Date

    public init(
        id: UUID = UUID(),
        type: AwardType,
        sourceID: String,
        snapshotName: String,
        awardedAt: Date
    ) {
        self.id = id
        self.type = type
        self.sourceID = sourceID
        self.snapshotName = snapshotName
        self.awardedAt = awardedAt
    }
}

// MARK: - Run

public struct Run: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    /// A content reference, by string. Never an object (`system-design.md` §4).
    public let questID: String
    /// Pinned at start and never rewritten (`AD-4`).
    public let contentVersion: String
    public let language: ContentLanguage
    /// Carried so the home screen can name an active or finished Run without a content lookup.
    public let snapshotQuestTitle: String
    public let checkpointCount: Int

    public var state: RunState
    /// The checkpoint the walker is at, or is walking towards. Whether they have *reached* it is
    /// answered by `checkpointResults`, not by this number — one fact, one place.
    public var currentCheckpointIndex: Int

    public let startedAt: Date
    public var updatedAt: Date
    public var completedAt: Date?
    public var abandonedAt: Date?
    public var abandonReason: AbandonReason?

    public var checkpointResults: [CheckpointResult]
    public var awards: [Award]

    public init(
        id: UUID = UUID(),
        questID: String,
        contentVersion: String,
        language: ContentLanguage,
        snapshotQuestTitle: String,
        checkpointCount: Int,
        state: RunState = .active,
        currentCheckpointIndex: Int = 0,
        startedAt: Date,
        updatedAt: Date,
        completedAt: Date? = nil,
        abandonedAt: Date? = nil,
        abandonReason: AbandonReason? = nil,
        checkpointResults: [CheckpointResult] = [],
        awards: [Award] = []
    ) {
        self.id = id
        self.questID = questID
        self.contentVersion = contentVersion
        self.language = language
        self.snapshotQuestTitle = snapshotQuestTitle
        self.checkpointCount = checkpointCount
        self.state = state
        self.currentCheckpointIndex = currentCheckpointIndex
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.abandonedAt = abandonedAt
        self.abandonReason = abandonReason
        self.checkpointResults = checkpointResults
        self.awards = awards
    }

    public var orderedCheckpointResults: [CheckpointResult] {
        checkpointResults.sorted { $0.orderIndex < $1.orderIndex }
    }

    public func result(forOrderIndex index: Int) -> CheckpointResult? {
        checkpointResults.first { $0.orderIndex == index }
    }

    public func result(forCheckpointID id: String) -> CheckpointResult? {
        checkpointResults.first { $0.checkpointID == id }
    }

    /// `FR-CP-08` — progress is a count of checkpoints reached, never a distance. Real walking
    /// distance is not measured, so a distance bar would be a fiction rendered precisely.
    public var reachedCount: Int { checkpointResults.count }

    /// True once the walker has arrived at the checkpoint they are currently on.
    public var hasArrivedAtCurrentCheckpoint: Bool {
        result(forOrderIndex: currentCheckpointIndex) != nil
    }
}
