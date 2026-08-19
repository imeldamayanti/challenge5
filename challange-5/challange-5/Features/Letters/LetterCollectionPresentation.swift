import Foundation

/// One slot of a collection's phrase, ready to draw (`FR-SIDE-08`).
struct LetterSlotPresentation: Sendable, Equatable, Identifiable {
    let id: Int
    /// `nil` while unearned — the blank is the game. The authored letter is never read for an
    /// unearned slot, so it cannot end up in an accessibility label by accident.
    let letter: String?
    /// Named whether or not the slot is earned, so a traveller can plan a visit.
    ///
    /// **This is the opposite of what `s4` §5 proposed.** That draft hid the place name as well as
    /// the letter, on the grounds that a visible list of addresses makes the notification pointless.
    /// Product overruled it on 2026-08-15 and the decision is in the requirement itself rather than
    /// in a view — `FR-SIDE-08`: "**MUST NOT** reveal its letter, and **MUST** name the place that
    /// fills it". `nil` here therefore means the content that would name it is gone — a withdrawn
    /// place (`AD-5`) — not an unvisited one.
    let placeName: String?
    let dateText: String?
    let isEarned: Bool
    /// Which sidequest fills this slot, so an unearned row can open it (`FR-SIDE-07` — reachable
    /// from the collection screen without waiting for a notification).
    let sideQuestID: String
    /// `NFR-A11Y-01` — spoken as "B" or as "slot 3, not yet found, Pura Maospahit", never as an
    /// underscore.
    let accessibilityLabel: String
}

/// The collection screen's whole content, computed from `RunEngine.LetterCollectionProgress` and
/// never stored (`FR-SIDE-08`).
struct LetterCollectionPresentation: Sendable, Equatable {
    let id: String
    let title: String
    let caption: String
    /// `B _ L I   T H _ …`. The phrase itself is not localized (`s0` D7, PRD §5.15 decision 2):
    /// translating it changes the letter count, which changes the number of places.
    let maskedPhrase: String
    /// The same phrase for VoiceOver, with each blank named rather than read as punctuation
    /// (`NFR-A11Y-01`).
    let spokenPhrase: String
    /// `"7 / 15"`.
    let progressText: String
    let slots: [LetterSlotPresentation]
    let isComplete: Bool
    /// `FR-SIDE-09` — present only once every slot is filled. Derived upstream rather than stored,
    /// so "once" is true by construction.
    let badgeText: String?
}
