import ContentKit
import Foundation

/// What the collection screen renders: one slot per letter of the phrase, filled or blank.
///
/// Computed from the content collection plus the user's records — never stored. Storing it would
/// create a second source of truth for "how far am I", and the two would drift the first time a
/// record was deleted by erasure (`FR-SET-02`).
public struct LetterCollectionProgress: Sendable, Equatable {

    public struct Slot: Sendable, Equatable, Identifiable {
        public var id: Int { index }
        public let index: Int
        public let sideQuestID: String
        /// `nil` until earned. A place the walker has never been to must not reveal its letter
        /// (`FR-SIDE-08`) — the blank is the whole game.
        public let letter: String?
        /// Named whether or not the slot is earned, so a traveller can plan a visit (`FR-SIDE-08`,
        /// PRD §5.15 decision 3, accepted 2026-08-15). `nil` only when the content that would name
        /// it is gone — a withdrawn place (`AD-5`) rather than an unearned one.
        public let placeName: String?
        public let completedAt: Date?

        public var isEarned: Bool { letter != nil }

        public init(
            index: Int,
            sideQuestID: String,
            letter: String?,
            placeName: String?,
            completedAt: Date?
        ) {
            self.index = index
            self.sideQuestID = sideQuestID
            self.letter = letter
            self.placeName = placeName
            self.completedAt = completedAt
        }
    }

    public let collectionID: String
    /// Not localized (`s0` D7, PRD §5.15 decision 2): translating it changes the letter count,
    /// which changes the number of places.
    public let phrase: String
    public let slots: [Slot]
    public var earnedCount: Int
    public var totalCount: Int
    public var isComplete: Bool
    /// `FR-SIDE-09` — awarded on the last letter and not before, and derived rather than stored so
    /// "once" is true by construction rather than by a guard. Its `awardedAt` is the moment the
    /// final slot was completed, which is when it was in fact earned.
    public let badge: Award?

    public init(
        collectionID: String,
        phrase: String,
        slots: [Slot],
        badge: Award? = nil
    ) {
        self.collectionID = collectionID
        self.phrase = phrase
        self.slots = slots
        earnedCount = slots.filter(\.isEarned).count
        totalCount = slots.count
        isComplete = !slots.isEmpty && slots.allSatisfy(\.isEarned)
        self.badge = badge
    }

    /// `B _ L I   T H _   _ _ _ _ _ _ _ _`, spaces preserved from the phrase.
    ///
    /// An unearned slot renders the placeholder, not a dimmed letter: a dimmed letter is the answer
    /// with a lower opacity (`FR-SIDE-08`).
    public func maskedPhrase(placeholder: String = "_") -> String {
        tokens(placeholder: placeholder).joined(separator: " ")
    }

    /// The accessibility reading of the same phrase (`NFR-A11Y-01`). VoiceOver reading a row of
    /// underscores says nothing useful, so earned letters are spelled out and the rest are named.
    ///
    /// `blankWord` is passed in rather than looked up: nothing in this layer knows the interface
    /// language, and every string the user hears is the caller's to localize (`NFR-I18N-01`).
    public func spelledOutPhrase(blankWord: String, separator: String = ", ") -> String {
        tokens(placeholder: blankWord)
            .filter { !$0.allSatisfy(\.isWhitespace) }
            .joined(separator: separator)
    }

    /// One token per character of the phrase; a phrase space becomes a space token, which the
    /// `" "` join widens into the gap between words.
    private func tokens(placeholder: String) -> [String] {
        var remaining = slots.sorted { $0.index < $1.index }.map(\.letter)
        var result: [String] = []
        for character in phrase {
            if character.isWhitespace {
                result.append(" ")
                continue
            }
            let letter = remaining.isEmpty ? nil : remaining.removeFirst()
            result.append(letter ?? placeholder)
        }
        return result
    }
}

public extension LetterCollectionProgress {

    /// Builds progress from content plus records. The only place the two meet.
    ///
    /// `language` resolves the place names of **unearned** slots, which `FR-SIDE-08` requires to be
    /// visible. Earned slots use their own snapshot instead, in the language they were read in
    /// (`NFR-I18N-04`) — so a record survives the interface language changing under it.
    static func make(
        collection: LetterCollection,
        records: [SideQuestRecord],
        placeName: (String) -> String?,
        language: ContentLanguage
    ) -> LetterCollectionProgress {
        let bySideQuestID = Dictionary(
            records.map { ($0.sideQuestID, $0) }, uniquingKeysWith: { first, _ in first })

        let slots = collection.orderedSlots.map { slot -> Slot in
            let record = bySideQuestID[slot.sideQuestId]
            let isEarned = record?.isCompleted == true
            return Slot(
                index: slot.index,
                sideQuestID: slot.sideQuestId,
                // The authored letter is never read for an unearned slot. Reading it and hiding it
                // in the view is how a letter ends up in an accessibility label.
                letter: isEarned ? (record?.letter ?? slot.letter) : nil,
                placeName: isEarned ? record?.snapshotPlaceName : placeName(slot.sideQuestId),
                completedAt: isEarned ? record?.completedAt : nil)
        }

        let isComplete = !slots.isEmpty && slots.allSatisfy(\.isEarned)
        let badge: Award? = isComplete
            ? Award(
                id: derivedAwardID(collection.badgeId),
                type: .badge,
                sourceID: collection.badgeId,
                snapshotName: collection.phrase,
                awardedAt: slots.compactMap(\.completedAt).max() ?? Date(timeIntervalSince1970: 0))
            : nil

        return LetterCollectionProgress(
            collectionID: collection.id,
            phrase: collection.phrase,
            slots: slots,
            badge: badge)
    }

    /// A stable identity for a *derived* award.
    ///
    /// `Award.id` defaults to a fresh `UUID`, which is right for something that happened once and
    /// was written down. The collection badge is recomputed on every render instead, so a fresh id
    /// each time would make two computations of the same progress compare unequal and make the
    /// badge row re-insert itself in the view on every redraw. FNV-1a over the seed, twice, for the
    /// sixteen bytes — this is an identity, never a checksum, so a cryptographic hash would buy
    /// nothing.
    static func derivedAwardID(_ seed: String) -> UUID {
        func fnv1a(_ bytes: some Sequence<UInt8>) -> UInt64 {
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3
            }
            return hash
        }
        let forward = fnv1a(Array(seed.utf8))
        let backward = fnv1a(Array(seed.utf8).reversed())
        var bytes: [UInt8] = []
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: forward >> UInt64(shift)))
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: backward >> UInt64(shift)))
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
