import ContentKit
import Foundation

public enum SideQuestEngineError: Error, Equatable, CustomStringConvertible {
    case sideQuestNotFound(String)
    case recordNotFound(String)
    /// V24 guarantees every sidequest fills exactly one slot in exactly one collection. Reaching
    /// this means the content in the bundle did not pass the validator.
    case noCollectionSlot(String)
    case collectionNotFound(String)
    /// Answering a quiz on a photo challenge, or the reverse.
    case challengeMismatch(expected: SideQuestChallenge.Kind, actual: SideQuestChallenge.Kind)
    case optionOutOfRange(index: Int, optionCount: Int)

    public var description: String {
        switch self {
        case .sideQuestNotFound(let id): "No sidequest with id \"\(id)\"."
        case .recordNotFound(let id): "Sidequest \"\(id)\" has not been discovered."
        case .noCollectionSlot(let id):
            "Sidequest \"\(id)\" fills no collection slot; content failed rule V24."
        case .collectionNotFound(let id): "No collection with id \"\(id)\"."
        case .challengeMismatch(let expected, let actual):
            "This sidequest's challenge is a \(actual.rawValue), not a \(expected.rawValue)."
        case .optionOutOfRange(let index, let count):
            "Option \(index) is outside the \(count) offered."
        }
    }
}

/// What a quiz answer produced, for the screen that asked the question.
public struct QuizOutcome: Sendable, Equatable {
    public let isCorrect: Bool
    public let attempts: Int
    /// True once the answer is shown after three wrong attempts (`FR-SIDE-06`, `s0` D5).
    public let isRevealed: Bool
    /// Non-nil only once the answer is settled — right, or revealed. Returning it beside a wrong
    /// answer would hand over the answer.
    public let correctOptionText: String?
    public let explanationText: String?
    /// The letter, once earned. Non-nil on every later call too, because re-opening a completed
    /// quiz returns the stored outcome rather than awarding again (`FR-SIDE-05`).
    public let awardedLetter: String?

    public init(
        isCorrect: Bool,
        attempts: Int,
        isRevealed: Bool,
        correctOptionText: String? = nil,
        explanationText: String? = nil,
        awardedLetter: String? = nil
    ) {
        self.isCorrect = isCorrect
        self.attempts = attempts
        self.isRevealed = isRevealed
        self.correctOptionText = correctOptionText
        self.explanationText = explanationText
        self.awardedLetter = awardedLetter
    }
}

/// The rules that decide what a sidequest may do next, and the only thing that writes sidequest
/// user data.
///
/// Mirrors `RunEngine` deliberately, including the part that matters most: arrival reaches it as a
/// decided fact — a method and an accuracy, never a `CLLocation`. `FR-SIDE-02`'s two-condition gate
/// is `ArrivalEvaluator`, unchanged, enforced by the screen that owns the location; this type
/// decides what happens once somebody is standing there.
///
/// **Nothing here touches `Run`, `RunStore`, or `RunEngine`.** `FR-SIDE-01` is held by there being
/// no call that could.
@MainActor
public struct SideQuestEngine {

    private let repository: any ContentRepository
    private let store: any SideQuestStore
    private let now: @Sendable () -> Date

    public init(
        repository: any ContentRepository,
        store: any SideQuestStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.store = store
        self.now = now
    }

    // MARK: - Queries

    public func record(sideQuestID: String) throws -> SideQuestRecord? {
        try store.record(sideQuestID: sideQuestID)
    }

    public func records() throws -> [SideQuestRecord] {
        try store.records()
    }

    /// Collection progress, computed from content plus records and never stored (`FR-SIDE-08`).
    ///
    /// The `language` parameter is a deliberate addition to `s2` §3's signature: `FR-SIDE-08`
    /// requires an unearned slot to name the place that fills it, and a place name is a
    /// `LocalizedText`. Earned slots ignore it and use their own snapshot (`NFR-I18N-04`).
    public func progress(
        collectionID: String,
        language: ContentLanguage
    ) throws -> LetterCollectionProgress {
        guard let collection = try repository.collection(id: collectionID) else {
            throw SideQuestEngineError.collectionNotFound(collectionID)
        }
        let records = try store.records(collectionID: collectionID)
        let repository = self.repository
        return LetterCollectionProgress.make(
            collection: collection,
            records: records,
            placeName: { sideQuestID in
                guard let sideQuest = (try? repository.sideQuest(id: sideQuestID)) ?? nil,
                      let place = (try? repository.place(id: sideQuest.placeId)) ?? nil
                else { return nil }
                return place.nameOfficial.value(for: language)
            },
            language: language)
    }

    /// The regions worth monitoring for sidequests right now (`FR-SIDE-16`, `s0` D9).
    ///
    /// Completed sidequests are dropped, the same way a completed quest's start region is
    /// (`FR-PROX-08`), and suppressed ones with them (`AD-5`, `FR-SIDE-14`) — a letter already
    /// earned is retained regardless, because it is in the record and not in the content.
    ///
    /// Suppression sets are passed in, never fetched: whoever owns the kill-switch owns the fetch,
    /// and there is no reachability check anywhere in this codebase (`AD-3`).
    public func monitoringCandidates(
        suppressingSideQuestIDs: Set<String> = [],
        suppressingPlaceIDs: Set<String> = [],
        priority: Int = RegionBudget.sideQuestPriority
    ) throws -> [RegionBudget.Candidate] {
        let completed = try store.completedSideQuestIDs()
        return try repository
            .sideQuests(
                suppressingSideQuestIDs: suppressingSideQuestIDs,
                suppressingPlaceIDs: suppressingPlaceIDs)
            .filter { !completed.contains($0.id) }
            .compactMap { sideQuest in
                guard let place = try repository.place(id: sideQuest.placeId) else { return nil }
                return RegionBudget.Candidate(
                    id: sideQuest.id,
                    coordinate: place.coordinate,
                    // The notice radius, not the trigger radius: the alert warns on approach, it
                    // does not confirm arrival (`FR-PROX-11`).
                    radiusM: sideQuest.noticeRadiusM,
                    priority: priority)
            }
    }

    // MARK: - Discovery

    /// `FR-SIDE-02`, `FR-SIDE-10` — the sidequest opens, and the story is copied into the record on
    /// the way in.
    ///
    /// **Idempotent.** Called on a record that exists it returns it untouched: no second snapshot,
    /// no re-pinned version, no duplicate letter. A walker who passes a place twice on the same
    /// afternoon must not get two rows, and the store's key is what makes that structural rather
    /// than a guard somebody can forget (`FR-SIDE-05`).
    @discardableResult
    public func discover(
        sideQuestID: String,
        language: ContentLanguage,
        method: ArrivalMethod,
        accuracyM: Double?
    ) throws -> SideQuestRecord {
        if let existing = try store.record(sideQuestID: sideQuestID) { return existing }

        guard let sideQuest = try repository.sideQuest(id: sideQuestID) else {
            throw SideQuestEngineError.sideQuestNotFound(sideQuestID)
        }
        guard let (collection, slot) = try slot(forSideQuestID: sideQuestID) else {
            throw SideQuestEngineError.noCollectionSlot(sideQuestID)
        }

        let place = (try? repository.place(id: sideQuest.placeId)) ?? nil
        let timestamp = now()
        let record = SideQuestRecord(
            sideQuestID: sideQuest.id,
            placeID: sideQuest.placeId,
            collectionID: collection.id,
            slotIndex: slot.index,
            // The letter is copied now rather than read from content when the collection renders:
            // a collection is a record of where somebody has been and has to survive the content
            // that described those places (`s0` D8).
            letter: slot.letter,
            language: language,
            contentVersion: (try? repository.contentBundleVersion()) ?? "",
            discoveredAt: timestamp,
            arrivalMethod: method,
            gpsAccuracyM: accuracyM,
            // `NFR-I18N-04` — the official local form, in the language this record is pinned to.
            snapshotPlaceName: place?.nameOfficial.value(for: language) ?? sideQuest.placeId,
            snapshotTitle: sideQuest.title.value(for: language),
            snapshotSynopsis: sideQuest.synopsis.value(for: language),
            snapshotLore: LoreBlockSnapshot.snapshot(
                sideQuest.lore, place: place, language: language),
            updatedAt: timestamp)

        try store.save(record)
        return record
    }

    /// `FR-CP-04`'s sidequest counterpart. Recorded once — the first opening is the one that means
    /// something; re-reads are re-reads.
    ///
    /// Accepts a completed record, for the same reason `RunEngine.markLoreOpened` accepts a
    /// completed Run: the user is still standing there and may reopen the screen.
    @discardableResult
    public func markLoreOpened(sideQuestID: String) throws -> SideQuestRecord {
        var record = try recordOrThrow(sideQuestID)
        guard record.loreFirstOpenedAt == nil else { return record }

        record.loreFirstOpenedAt = now()
        record.updatedAt = now()
        try store.save(record)
        return record
    }

    // MARK: - Challenges

    /// `FR-SIDE-05`, `FR-SIDE-06` — the only place a letter is awarded, and it awards at most one,
    /// ever.
    ///
    /// A wrong answer costs nothing: no penalty, no lockout, unlimited attempts. After the third
    /// wrong attempt the correct option and its explanation are revealed and the letter is awarded
    /// anyway (`s0` D5). Called on a completed record it returns the stored outcome rather than
    /// throwing — the walker may reopen the screen, and re-reading an answer is not a second
    /// attempt.
    @discardableResult
    public func answerQuiz(sideQuestID: String, optionIndex: Int) throws -> QuizOutcome {
        let record = try recordOrThrow(sideQuestID)
        let quiz = try quizOrThrow(sideQuestID)

        if record.isCompleted { return storedOutcome(for: record, quiz: quiz) }

        guard quiz.options.indices.contains(optionIndex) else {
            throw SideQuestEngineError.optionOutOfRange(
                index: optionIndex, optionCount: quiz.options.count)
        }

        let language = record.language
        let grade = SideQuestQuiz.grade(
            chosenIndex: optionIndex,
            correctIndex: quiz.correctIndex,
            priorAttempts: record.challenge?.attempts ?? 0)

        var updated = record
        updated.challenge = SideQuestChallengeResult(
            kind: .quiz,
            promptSnapshot: quiz.question.value(for: language),
            attempts: grade.attempts,
            chosenOptionSnapshot: quiz.options[optionIndex].value(for: language),
            isCorrect: grade.isCorrect,
            wasRevealed: grade.isRevealed,
            answeredAt: now())

        let isSettled = grade.isCorrect || grade.isRevealed
        if isSettled { award(&updated) }
        updated.updatedAt = now()
        try store.save(updated)

        return QuizOutcome(
            isCorrect: grade.isCorrect,
            attempts: grade.attempts,
            isRevealed: grade.isRevealed,
            correctOptionText: isSettled ? correctOptionText(quiz, language) : nil,
            explanationText: isSettled ? quiz.explanation.value(for: language) : nil,
            awardedLetter: isSettled ? updated.letter : nil)
    }

    /// `FR-SIDE-13` — the photograph stays on the device and is stored by a path relative to the
    /// app container. Capture itself is Phase D; this is the record half, and it is here so the
    /// letter rule has exactly one implementation rather than two.
    ///
    /// Idempotent for the same reason `answerQuiz` is: a completed record is returned untouched.
    ///
    /// `relativePath` is optional because the capture pipeline is Phase D and the flow ships before
    /// it (`s4` §7): until then a photo challenge states its prompt, says photographs are not in
    /// this build, and awards the letter on acknowledgement. A `nil` path records a completed
    /// challenge with no photograph, which is exactly what happened — rather than an empty string,
    /// which would later read as a file at the container root.
    @discardableResult
    public func completePhoto(
        sideQuestID: String,
        relativePath: String?
    ) throws -> SideQuestRecord {
        let record = try recordOrThrow(sideQuestID)
        guard let sideQuest = try repository.sideQuest(id: sideQuestID) else {
            throw SideQuestEngineError.sideQuestNotFound(sideQuestID)
        }
        guard case .photo(let challenge) = sideQuest.challenge else {
            throw SideQuestEngineError.challengeMismatch(
                expected: .photo, actual: sideQuest.challenge.kind)
        }
        if record.isCompleted { return record }

        var updated = record
        updated.challenge = SideQuestChallengeResult(
            kind: .photo,
            promptSnapshot: challenge.prompt.value(for: record.language),
            attempts: (record.challenge?.attempts ?? 0) + 1,
            photoRelativePath: relativePath,
            answeredAt: now())
        award(&updated)
        updated.updatedAt = now()
        try store.save(updated)
        return updated
    }

    // MARK: - The letter

    /// One letter, once (`FR-SIDE-05`). The `guard` is belt to the store's braces: the store keys
    /// on `sideQuestID`, so there is one record, and a completed record never reaches here.
    private func award(_ record: inout SideQuestRecord) {
        record.state = .completed
        let timestamp = now()
        record.completedAt = timestamp
        guard record.letterAward == nil else { return }
        record.awards.append(Award(
            type: .letter,
            sourceID: record.sideQuestID,
            snapshotName: record.snapshotTitle,
            awardedAt: timestamp))
    }

    // MARK: - Helpers

    private func storedOutcome(for record: SideQuestRecord, quiz: QuizChallenge) -> QuizOutcome {
        let language = record.language
        return QuizOutcome(
            isCorrect: record.challenge?.isCorrect ?? false,
            attempts: record.challenge?.attempts ?? 0,
            isRevealed: record.challenge?.wasRevealed ?? false,
            correctOptionText: correctOptionText(quiz, language),
            explanationText: quiz.explanation.value(for: language),
            awardedLetter: record.letter)
    }

    private func correctOptionText(_ quiz: QuizChallenge, _ language: ContentLanguage) -> String? {
        guard quiz.options.indices.contains(quiz.correctIndex) else { return nil }
        return quiz.options[quiz.correctIndex].value(for: language)
    }

    private func recordOrThrow(_ sideQuestID: String) throws -> SideQuestRecord {
        guard let record = try store.record(sideQuestID: sideQuestID) else {
            throw SideQuestEngineError.recordNotFound(sideQuestID)
        }
        return record
    }

    private func quizOrThrow(_ sideQuestID: String) throws -> QuizChallenge {
        guard let sideQuest = try repository.sideQuest(id: sideQuestID) else {
            throw SideQuestEngineError.sideQuestNotFound(sideQuestID)
        }
        guard case .quiz(let quiz) = sideQuest.challenge else {
            throw SideQuestEngineError.challengeMismatch(
                expected: .quiz, actual: sideQuest.challenge.kind)
        }
        return quiz
    }

    /// Which collection, and which slot, a sidequest fills. Scanned from `collections()` rather
    /// than asked of the repository, so `ContentRepository` gains no method for it — V24 already
    /// guarantees there is exactly one.
    private func slot(
        forSideQuestID sideQuestID: String
    ) throws -> (collection: LetterCollection, slot: LetterSlot)? {
        for collection in try repository.collections() {
            if let slot = collection.slots.first(where: { $0.sideQuestId == sideQuestID }) {
                return (collection, slot)
            }
        }
        return nil
    }
}
