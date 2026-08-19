import ContentKit
import Foundation

/// One sidequest, resolved for the screens that show it (PRD §5.15).
///
/// A `Model/` type, so: strings already localized, distances already formatted, and no reference to
/// a repository, a store, an engine or a palette. It is **not** `ContentKit.SideQuest` mirrored —
/// the domain type keeps `LocalizedText`, `LoreBlock` and its authored radii, and none of those
/// belong in a view.
struct SideQuestPresentation: Sendable, Equatable, Identifiable {
    let id: String
    let placeName: String
    let title: String
    /// What the notice card says, read by someone standing in a street (`FR-SIDE-11`).
    let synopsis: String
    let isSacred: Bool
    /// `FR-TASK-05` — at a sacred Place the dress code and photo policy are shown *before* any
    /// challenge is offered. Held here so the view cannot draw the challenge without them.
    let dressCodeText: String
    let photoPolicyText: String
    /// `FR-SIDE-04`, `s0` D6 — the story with its accuracy labels and its citations, in the same
    /// shape the checkpoint screen uses, because the run flow's unlabelled Story Reveal is a signed
    /// exception that does not extend to a new surface by inference.
    let claims: [LoreClaimPresentation]
    let challenge: ChallengePresentation
    let heroImageURL: URL?
    let triggerRadiusM: Int
    let coordinate: Coordinate
}

/// Which mechanic this sidequest offers. Closed, mirroring `SideQuestChallenge` — there is no
/// "unknown" case, because a mechanic the app cannot draw is a content defect the validator
/// rejects, not a state a screen has to survive.
enum ChallengePresentation: Sendable, Equatable {
    case quiz(QuizPresentation)
    case photo(prompt: String)
}

struct QuizPresentation: Sendable, Equatable {
    let question: String
    let options: [QuizOptionPresentation]
    /// Shown once the answer is settled — right, or revealed after three wrong attempts
    /// (`FR-SIDE-06`). It is the fact the walker leaves with, so it is not optional.
    let explanation: String
}

/// **No `isCorrect`.** Grading lives in `RunEngine.SideQuestQuiz` behind the engine; a correctness
/// flag sitting in a value the view holds is a flag some future layout change renders, or that
/// VoiceOver reads out of a debug description.
struct QuizOptionPresentation: Sendable, Equatable, Identifiable {
    let id: Int
    let text: String
}

/// What came back from answering, in the terms the screen draws.
///
/// Right and wrong are carried as a case rather than a `Bool` plus a colour, because `NFR-A11Y-05`
/// requires the outcome in text as well — and a three-case enum is what makes "revealed" a state
/// the view has to handle rather than a wrong answer wearing a different tint.
enum QuizFeedback: Sendable, Equatable {
    case wrong(message: String)
    case correct(message: String, explanation: String)
    /// `FR-SIDE-06` — the answer after the third wrong attempt, with the letter awarded anyway.
    case revealed(message: String, correctOptionText: String, explanation: String)
}

/// One row of the nearby list — the way into a sidequest before notifications exist, and the way
/// back in afterwards for anyone who dismissed one (`FR-SIDE-07`).
struct NearbySideQuestRow: Sendable, Equatable, Identifiable {
    let id: String
    let title: String
    let placeName: String
    /// Already formatted by `ContentFormatter`; `nil` when there is no fix yet, in which case the
    /// row simply has no distance rather than a placeholder number.
    let distanceText: String?
    /// Sort key, kept out of the view. Straight-line metres, or `.infinity` with no fix so the
    /// unmeasurable rows sort last instead of first.
    let distanceM: Double
    let isCompleted: Bool
}
