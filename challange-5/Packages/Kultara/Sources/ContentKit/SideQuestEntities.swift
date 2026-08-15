import Foundation

// The sidequest content model (`schema.md` §A.10–A.11, PRD §5.15 `FR-SIDE-*`).
//
// A sidequest is a single-place activity outside any Run: one story, one challenge, one letter of
// a collectible phrase (`FR-SIDE-01`). Like everything else in this target it is a value type with
// no reference to a user record — the link runs the other way, by string id plus the pinned
// `contentBundleVersion` (`system-design.md` §4, `AD-4`, `FR-SIDE-10`).
//
// Note the name: `ContentKit.SideQuest` used to mean a checkpoint-level optional prompt. That type
// is now `BonusPrompt` (`s0` D2, PRD glossary), because two entities called sidequest in one
// codebase is a defect waiting to be written.

// MARK: - Challenge

/// The mechanics a sidequest can offer, as a closed enum with a `type` discriminator. An unknown
/// mechanic is therefore a decode failure rather than a silently ignored challenge — and
/// `FR-TASK-05`'s constraint at sacred places is satisfied by construction, since quiz is the
/// "single light question", photo is photo, and nothing else is representable.
///
/// `TaskType` is deliberately not reused. It belongs to checkpoint tasks, whose `blocksProgression`
/// rule (`AD-2`, V8) must keep meaning exactly what it means today; hanging a second concept off it
/// would make V8 ambiguous. A sidequest challenge gates only its own letter (`FR-SIDE-05`).
public enum SideQuestChallenge: Codable, Sendable, Equatable {
    case quiz(QuizChallenge)
    case photo(PhotoChallenge)

    /// The authored discriminator. Stored as a raw `String`, never an integer — a persisted
    /// integer becomes unreadable the moment someone reorders a case.
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case quiz, photo
    }

    public var kind: Kind {
        switch self {
        case .quiz: .quiz
        case .photo: .photo
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .quiz: self = .quiz(try QuizChallenge(from: decoder))
        case .photo: self = .photo(try PhotoChallenge(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .type)
        switch self {
        case .quiz(let challenge): try challenge.encode(to: encoder)
        case .photo(let challenge): try challenge.encode(to: encoder)
        }
    }
}

public struct QuizChallenge: Codable, Sendable, Equatable, Hashable {
    public let question: LocalizedText
    /// 2–4 options, distinct (V22). Four is the ceiling because these are read one-handed, in
    /// daylight, by someone standing in a street.
    public let options: [LocalizedText]
    public let correctIndex: Int
    /// Shown after the answer, right or wrong. It is the point of the question — the fact the
    /// walker leaves with — so it is required, not optional. `FR-SIDE-06` also reveals it after
    /// three wrong attempts, which is only possible because it always exists.
    public let explanation: LocalizedText

    public init(
        question: LocalizedText,
        options: [LocalizedText],
        correctIndex: Int,
        explanation: LocalizedText
    ) {
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
    }
}

public struct PhotoChallenge: Codable, Sendable, Equatable, Hashable {
    public let prompt: LocalizedText

    public init(prompt: LocalizedText) {
        self.prompt = prompt
    }
}

// MARK: - SideQuest

public struct SideQuest: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    /// The Place this sits at. A string id — never an object (`system-design.md` §4). Pointing at
    /// an ordinary `Place` is also what makes V2, V4, V5, V13 and V15 cover a sidequest's place
    /// with no new rule at all.
    public let placeId: String
    public let title: LocalizedText
    /// What the notification and the notice card say. Deliberately short: it is read on a lock
    /// screen by someone walking (`FR-SIDE-11`).
    public let synopsis: LocalizedText
    /// The history, as labelled claims. Same rule as `Checkpoint.loreSegment`: there is no field
    /// for an unlabelled sentence (`FR-CP-05`, `FR-SIDE-04`).
    public let lore: [LoreBlock]
    public let challenge: SideQuestChallenge
    /// Inside this radius, and with a fix at least this good, the sidequest opens — the same
    /// two-condition gate as checkpoint arrival (`FR-ARR-01`, `FR-SIDE-02`). 30–250 m, rule V20.
    public let triggerRadiusM: Int
    /// The monitored region. Larger than `triggerRadiusM` — the alert warns on approach, it does
    /// not confirm arrival (the `FR-PROX-11` argument, rule V20).
    public let noticeRadiusM: Int
    public let heroImageAsset: String?

    public init(
        id: String,
        placeId: String,
        title: LocalizedText,
        synopsis: LocalizedText,
        lore: [LoreBlock],
        challenge: SideQuestChallenge,
        triggerRadiusM: Int,
        noticeRadiusM: Int,
        heroImageAsset: String? = nil
    ) {
        self.id = id
        self.placeId = placeId
        self.title = title
        self.synopsis = synopsis
        self.lore = lore
        self.challenge = challenge
        self.triggerRadiusM = triggerRadiusM
        self.noticeRadiusM = noticeRadiusM
        self.heroImageAsset = heroImageAsset
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        placeId = try c.decode(String.self, forKey: .placeId)
        title = try c.decode(LocalizedText.self, forKey: .title)
        synopsis = try c.decode(LocalizedText.self, forKey: .synopsis)
        lore = try c.decode([LoreBlock].self, forKey: .lore)
        challenge = try c.decode(SideQuestChallenge.self, forKey: .challenge)
        triggerRadiusM = try c.decode(Int.self, forKey: .triggerRadiusM)
        noticeRadiusM = try c.decode(Int.self, forKey: .noticeRadiusM)
        heroImageAsset = try c.decodeIfPresent(String.self, forKey: .heroImageAsset)
    }
}

// There is deliberately no `contentVersion` on a `SideQuest`. A `Quest` carries one because a Run
// pins it at start; a sidequest record pins `manifest.contentBundleVersion` at the moment it is
// discovered (`FR-SIDE-10`), which is the same fact without a second place to keep it.

// MARK: - LetterCollection

public struct LetterSlot: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var id: Int { index }
    public let index: Int
    /// One character. Stored as `String` rather than `Character` because `Character` has no stable
    /// JSON representation and because a future phrase may need a digraph. Rule V25 compares it
    /// against the phrase position by position; a digraph phrase would need V25 revisited.
    public let letter: String
    public let sideQuestId: String

    public init(index: Int, letter: String, sideQuestId: String) {
        self.index = index
        self.letter = letter
        self.sideQuestId = sideQuestId
    }
}

public struct LetterCollection: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let region: String
    /// Not a `LocalizedText`, and that is a product constraint rather than an oversight (`s0` D7,
    /// PRD §5.15 decision 2, accepted 2026-08-15): translating the phrase changes its letter count,
    /// which changes the number of places, which forks the content tree per language. Spaces are
    /// display only and get no slot — `BALI THE EXPLORER` is 15 letters and therefore 15 places.
    public let phrase: String
    public let title: LocalizedText
    /// The explanation beside the phrase, which *is* localized — `NFR-I18N-01` still holds for
    /// every sentence the user reads.
    public let caption: LocalizedText
    public let badgeId: String
    public let slots: [LetterSlot]

    public init(
        id: String,
        region: String,
        phrase: String,
        title: LocalizedText,
        caption: LocalizedText,
        badgeId: String,
        slots: [LetterSlot]
    ) {
        self.id = id
        self.region = region
        self.phrase = phrase
        self.title = title
        self.caption = caption
        self.badgeId = badgeId
        self.slots = slots
    }

    /// The phrase without its display spaces — one character per slot (V25).
    public var phraseLetters: [String] {
        phrase.filter { !$0.isWhitespace }.map(String.init)
    }

    public var orderedSlots: [LetterSlot] {
        slots.sorted { $0.index < $1.index }
    }
}
