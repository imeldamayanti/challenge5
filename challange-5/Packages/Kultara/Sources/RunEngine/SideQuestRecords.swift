import ContentKit
import Foundation

// The user-data aggregate for sidequests (`schema.md` Part B, PRD §5.15).
//
// Separate from `Run` and stored separately, which is `FR-SIDE-01` expressed in the type system
// rather than in a guard: modelling a sidequest as a one-checkpoint Run would put sidequests into
// the home screen's resume entry (`FR-RUN-03`), break the one-active-Run-per-quest assumption for a
// place visited twice, and make `FR-PROX-08` suppress the very alerts the feature exists to send
// (`s0` D1).
//
// The rule that shapes everything below is the same one that shapes `Run`: **no reference into
// content**. String ids, a pinned `contentBundleVersion`, and the story copied in at discovery
// (`system-design.md` §4, `AD-4`, `FR-SIDE-10`).

public enum SideQuestState: String, Codable, Sendable, CaseIterable {
    /// Entered the radius and opened the notice. The story may or may not have been read.
    case discovered
    /// The challenge is done and the letter is awarded. Terminal.
    case completed
}

// MARK: - Challenge result

public struct SideQuestChallengeResult: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, CaseIterable { case quiz, photo }

    public let kind: Kind
    /// The question as it was asked, so the record still reads back after the wording is edited.
    public let promptSnapshot: String
    /// Every attempt, right or wrong. Kept because a question everyone gets wrong three times is a
    /// badly written question, and this is the only place that would show it.
    public let attempts: Int
    public let chosenOptionSnapshot: String?
    public let isCorrect: Bool?
    /// Whether the answer was revealed after three attempts (`FR-SIDE-06`, `s0` D5) rather than
    /// found. A revealed answer still earns the letter; the distinction exists for the content
    /// team, not for the walker.
    public let wasRevealed: Bool
    /// Relative to the app container, never absolute: an absolute path resolves to nothing after a
    /// restore from backup, and the user's photographs appear to have vanished (`NFR-REL-05`,
    /// `FR-SIDE-13`). Unused until photo challenges ship (Phase D); the field exists so the store
    /// does not need migrating then.
    public let photoRelativePath: String?
    public let answeredAt: Date

    public init(
        kind: Kind,
        promptSnapshot: String,
        attempts: Int,
        chosenOptionSnapshot: String? = nil,
        isCorrect: Bool? = nil,
        wasRevealed: Bool = false,
        photoRelativePath: String? = nil,
        answeredAt: Date
    ) {
        self.kind = kind
        self.promptSnapshot = promptSnapshot
        self.attempts = attempts
        self.chosenOptionSnapshot = chosenOptionSnapshot
        self.isCorrect = isCorrect
        self.wasRevealed = wasRevealed
        self.photoRelativePath = photoRelativePath
        self.answeredAt = answeredAt
    }
}

// MARK: - Record

/// One sidequest, discovered and possibly completed, with the story the user actually read copied
/// into it.
///
/// The denormalization is the whole reason a collection renders identically forever, offline, after
/// a content correction and after a Place is withdrawn (`FR-SIDE-10`, `s0` D8). The letter
/// especially: a collection is a record of where somebody has been, and it has to survive the
/// content that described those places.
public struct SideQuestRecord: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    /// Content references, by string. Never objects (`system-design.md` §4).
    public let sideQuestID: String
    public let placeID: String
    public let collectionID: String
    public let slotIndex: Int
    /// The letter, copied out of the collection slot at discovery.
    public let letter: String

    /// `NFR-I18N-04` — pinned, so the snapshot below stays in the language it was read in even
    /// after the interface language is changed.
    public let language: ContentLanguage
    /// `manifest.contentBundleVersion`, pinned at discovery (`AD-4`).
    public let contentVersion: String

    public let discoveredAt: Date
    /// `FR-ARR-04` / `FR-SIDE-03` — `manual` is a legitimate path, not a lesser one. Nothing here
    /// reads it to reduce a reward.
    public let arrivalMethod: ArrivalMethod
    /// Recorded for a manual entry too: the last known accuracy is what explains *why* the override
    /// was needed.
    public let gpsAccuracyM: Double?

    // ── Content snapshot, captured at discovery ──
    public let snapshotPlaceName: String
    public let snapshotTitle: String
    public let snapshotSynopsis: String
    public let snapshotLore: [LoreBlockSnapshot]

    public var state: SideQuestState
    public var loreFirstOpenedAt: Date?
    public var challenge: SideQuestChallengeResult?
    public var completedAt: Date?
    /// The letter award. Held on the record rather than derived, because an award is a thing that
    /// happened at a moment; the collection badge is the opposite case and is derived
    /// (`LetterCollectionProgress.badge`).
    public var awards: [Award]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sideQuestID: String,
        placeID: String,
        collectionID: String,
        slotIndex: Int,
        letter: String,
        language: ContentLanguage,
        contentVersion: String,
        discoveredAt: Date,
        arrivalMethod: ArrivalMethod,
        gpsAccuracyM: Double?,
        snapshotPlaceName: String,
        snapshotTitle: String,
        snapshotSynopsis: String,
        snapshotLore: [LoreBlockSnapshot],
        state: SideQuestState = .discovered,
        loreFirstOpenedAt: Date? = nil,
        challenge: SideQuestChallengeResult? = nil,
        completedAt: Date? = nil,
        awards: [Award] = [],
        updatedAt: Date
    ) {
        self.id = id
        self.sideQuestID = sideQuestID
        self.placeID = placeID
        self.collectionID = collectionID
        self.slotIndex = slotIndex
        self.letter = letter
        self.language = language
        self.contentVersion = contentVersion
        self.discoveredAt = discoveredAt
        self.arrivalMethod = arrivalMethod
        self.gpsAccuracyM = gpsAccuracyM
        self.snapshotPlaceName = snapshotPlaceName
        self.snapshotTitle = snapshotTitle
        self.snapshotSynopsis = snapshotSynopsis
        self.snapshotLore = snapshotLore
        self.state = state
        self.loreFirstOpenedAt = loreFirstOpenedAt
        self.challenge = challenge
        self.completedAt = completedAt
        self.awards = awards
        self.updatedAt = updatedAt
    }

    public var isCompleted: Bool { state == .completed }

    /// The one letter award, if it has been earned (`FR-SIDE-05` — at most one, ever).
    public var letterAward: Award? {
        awards.first { $0.type == .letter }
    }
}
