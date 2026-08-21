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

/// Adding a case to a raw-`String` enum is safe for stored data; adding one to a raw-`Int` enum is
/// not, which is why `schema.md`'s Appendix requires string raws in the first place. `letter` is
/// the sidequest award (`FR-SIDE-05`) and arrived with PRD §5.15.
public enum AwardType: String, Codable, Sendable, CaseIterable {
    case stamp, badge, letter
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

    /// Copies a story out of content and into a user record, citations resolved to text.
    ///
    /// Lives on the snapshot rather than on either engine because both aggregates need it and
    /// neither may reach into the other: `FR-SIDE-01` is held by `SideQuestEngine` having no call
    /// into `RunEngine`, and a shared helper on the shared value type is how that stays true.
    public static func snapshot(
        _ blocks: [LoreBlock],
        place: Place?,
        language: ContentLanguage
    ) -> [LoreBlockSnapshot] {
        blocks.map { block in
            let citations = block.sourceRefs.compactMap { index -> String? in
                guard let place, place.sources.indices.contains(index) else { return nil }
                return place.sources[index].citation
            }
            return LoreBlockSnapshot(
                text: block.text.value(for: language),
                accuracy: block.accuracy,
                sourceCitations: citations)
        }
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
    /// `stampId` or `badgeId` from content — and, for a `letter`, the slot's `sideQuestId`
    /// (`FR-SIDE-05`); for a collection badge, the collection's `badgeId` (`FR-SIDE-09`).
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

// MARK: - JournalEntry

/// The walker's own closing reflection on a finished walk — free text plus up to two keepsake
/// photographs, written from the Summary screen rather than during the walk.
///
/// A single optional field on `Run` rather than a list: unlike a `TaskResult`, this is not tied to
/// a checkpoint, and there is exactly one journal entry per walk. Saving again replaces it rather
/// than appending, the same choice `recordTaskResult` makes for a re-answered task.
public struct JournalEntry: Codable, Sendable, Equatable {
    public var text: String
    /// Relative to the app container, never absolute (`NFR-REL-05`), the same rule every other
    /// photo path in this store follows.
    public var placePhotoRelativePath: String?
    public var selfiePhotoRelativePath: String?
    public var savedAt: Date

    public init(
        text: String,
        placePhotoRelativePath: String? = nil,
        selfiePhotoRelativePath: String? = nil,
        savedAt: Date
    ) {
        self.text = text
        self.placePhotoRelativePath = placePhotoRelativePath
        self.selfiePhotoRelativePath = selfiePhotoRelativePath
        self.savedAt = savedAt
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
    /// `nil` until the walker writes one from the Summary screen. Optional so every `Run` already
    /// on disk before this field existed decodes unchanged rather than needing a migration.
    public var journalEntry: JournalEntry?

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
        awards: [Award] = [],
        journalEntry: JournalEntry? = nil
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
        self.journalEntry = journalEntry
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
