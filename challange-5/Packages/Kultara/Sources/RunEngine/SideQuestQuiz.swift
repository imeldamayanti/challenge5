import Foundation

/// Quiz grading, as a pure value.
///
/// Three lines of logic, and worth its own type for one reason: "unlimited attempts, no penalty,
/// and the answer revealed after three wrong ones" (`FR-SIDE-06`, `s0` D5) is a product promise
/// about how forgiving the app is, and a promise made in an `if` inside a view model is a promise
/// nobody can check.
///
/// The reason behind the rule is the same one behind `FR-ARR-03`: this app is used by someone
/// standing in a street. A person stuck on a multiple-choice question in front of a temple gate
/// does not go away and study; they close the app.
public enum SideQuestQuiz {

    /// After this many wrong attempts the correct option and its explanation are shown, and the
    /// letter is awarded anyway (`FR-SIDE-06`).
    public static let revealAfterAttempts = 3

    /// - Parameter priorAttempts: attempts already recorded, right or wrong, before this one.
    /// - Returns: whether this answer was right, the running attempt count including this answer,
    ///   and whether the answer is now revealed.
    public static func grade(
        chosenIndex: Int,
        correctIndex: Int,
        priorAttempts: Int
    ) -> (isCorrect: Bool, attempts: Int, isRevealed: Bool) {
        let attempts = max(0, priorAttempts) + 1
        let isCorrect = chosenIndex == correctIndex
        // A correct answer is never "revealed" — the walker found it. Revelation is what happens
        // instead of a fourth guess.
        let isRevealed = !isCorrect && attempts >= revealAfterAttempts
        return (isCorrect, attempts, isRevealed)
    }
}
