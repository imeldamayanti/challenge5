import ContentKit
import Foundation
import Testing
@testable import RunEngine

/// The sidequest rules, all of which fail quietly and none of which the app target could test
/// (`s0` D10).
@MainActor
struct SideQuestEngineTests {

    private func engine(
        repository: StubContentRepository = SideQuestFixture.repository(),
        store: any SideQuestStore = InMemorySideQuestStore(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> SideQuestEngine {
        SideQuestEngine(repository: repository, store: store, now: now)
    }

    // MARK: - Discovery

    @Test func discoveringCopiesTheStoryAndItsCitationsIntoTheRecord() throws {
        // `s0` D8, `FR-SIDE-10` — snapshot at discovery, content version pinned.
        let record = try engine().discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)

        #expect(record.snapshotPlaceName == "Puri Contoh")
        #expect(record.snapshotTitle == "Judul sq-quiz")
        #expect(record.snapshotSynopsis == "Sinopsis sq-quiz")
        #expect(record.snapshotLore.count == 2)
        #expect(record.snapshotLore[0].accuracy == .documented)
        #expect(record.snapshotLore[0].sourceCitations == ["Arsip Kota, 1938"])
        #expect(record.snapshotLore[1].accuracy == .oral)
        #expect(record.snapshotLore[1].sourceCitations == ["Wawancara pemangku, 2026"])
        #expect(record.contentVersion == "2026.09.0")
        #expect(record.collectionID == SideQuestFixture.collectionID)
        #expect(record.slotIndex == 0)
        #expect(record.letter == "A")
        #expect(record.state == .discovered)
        #expect(record.arrivalMethod == .gps)
        #expect(record.gpsAccuracyM == 9)
    }

    @Test func aSecondDiscoveryOfTheSamePlaceChangesNothing() throws {
        // `FR-SIDE-05` — a walker who passes a place twice on the same afternoon gets one row.
        let store = InMemorySideQuestStore()
        let engine = engine(store: store)

        let first = try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)
        let second = try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .en, method: .manual, accuracyM: 400)

        #expect(first == second)
        #expect(try store.records().count == 1)
        // Not re-pinned, not re-snapshotted, not re-languaged.
        #expect(second.language == .id)
        #expect(second.arrivalMethod == .gps)
    }

    @Test func aManualEntryIsRecordedWithItsLastKnownAccuracyAndRewardedTheSame() throws {
        // `FR-SIDE-03`, `FR-ARR-04` — manual is a legitimate path, not a lesser one.
        let engine = engine()
        let record = try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .manual, accuracyM: 480)
        #expect(record.arrivalMethod == .manual)
        #expect(record.gpsAccuracyM == 480)

        let outcome = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)
        #expect(outcome.awardedLetter == "A")
    }

    @Test func theStoryIsMarkedOpenedOnceAndStaysOpenableAfterCompletion() throws {
        // `FR-CP-04`'s counterpart, plus the completed-record rule `RunEngine.markLoreOpened` has.
        let clock = TestClock(Date(timeIntervalSince1970: 1_000))
        let engine = engine(now: { clock.now })
        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)

        let opened = try engine.markLoreOpened(sideQuestID: SideQuestFixture.quizID)
        let firstOpen = try #require(opened.loreFirstOpenedAt)

        clock.advance(by: 600)
        #expect(try engine.markLoreOpened(sideQuestID: SideQuestFixture.quizID)
            .loreFirstOpenedAt == firstOpen)

        _ = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)
        // Completed records stay readable — the walker is still standing there.
        #expect(try engine.markLoreOpened(sideQuestID: SideQuestFixture.quizID)
            .loreFirstOpenedAt == firstOpen)
    }

    // MARK: - The quiz

    @Test func theLetterIsAwardedOnceEvenWhenTheQuizIsReopened() throws {
        // `FR-SIDE-05` — re-opening a completed sidequest must not award a second letter.
        let store = InMemorySideQuestStore()
        let engine = engine(store: store)
        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)

        let first = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)
        #expect(first.isCorrect)
        #expect(first.awardedLetter == "A")

        let reopened = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 0)
        #expect(reopened.isCorrect)
        #expect(reopened.attempts == 1)
        #expect(reopened.awardedLetter == "A")

        let record = try #require(try store.record(sideQuestID: SideQuestFixture.quizID))
        #expect(record.awards.filter { $0.type == .letter }.count == 1)
        #expect(record.awards.first?.sourceID == SideQuestFixture.quizID)
        #expect(record.challenge?.attempts == 1)
    }

    @Test func aWrongAnswerAwardsNothingAndBlocksNothing() throws {
        // `s0` D4 — no penalty, no lockout, and the answer is not leaked on the way out.
        let store = InMemorySideQuestStore()
        let engine = engine(store: store)
        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)

        let outcome = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 0)
        #expect(!outcome.isCorrect)
        #expect(!outcome.isRevealed)
        #expect(outcome.attempts == 1)
        #expect(outcome.awardedLetter == nil)
        #expect(outcome.correctOptionText == nil)
        #expect(outcome.explanationText == nil)

        let record = try #require(try store.record(sideQuestID: SideQuestFixture.quizID))
        #expect(record.state == .discovered)
        #expect(record.awards.isEmpty)
        #expect(record.completedAt == nil)
        // Still openable, indefinitely (`FR-SIDE-07`).
        #expect(try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)
            .isCorrect)
    }

    @Test func theAnswerIsRevealedOnTheThirdAttemptAndTheLetterIsStillAwarded() throws {
        // `FR-SIDE-06`, `s0` D5.
        let store = InMemorySideQuestStore()
        let engine = engine(store: store)
        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)

        let first = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 0)
        let second = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 2)
        #expect(!first.isRevealed)
        #expect(!second.isRevealed)
        #expect(second.attempts == 2)

        let third = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 0)
        #expect(third.attempts == SideQuestQuiz.revealAfterAttempts)
        #expect(third.isRevealed)
        #expect(!third.isCorrect)
        #expect(third.correctOptionText == "Empat")
        #expect(third.explanationText == "Catur Muka berarti empat wajah.")
        #expect(third.awardedLetter == "A")

        let record = try #require(try store.record(sideQuestID: SideQuestFixture.quizID))
        #expect(record.state == .completed)
        #expect(record.challenge?.wasRevealed == true)
        #expect(record.challenge?.isCorrect == false)
        #expect(record.awards.count == 1)
    }

    @Test func aQuizAnswerIsRecordedWithTheQuestionAndTheOptionAsTheyWereAsked() throws {
        let store = InMemorySideQuestStore()
        let engine = engine(store: store)
        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .en, method: .gps, accuracyM: 9)
        _ = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 2)

        let challenge = try #require(
            try store.record(sideQuestID: SideQuestFixture.quizID)?.challenge)
        #expect(challenge.kind == .quiz)
        #expect(challenge.promptSnapshot == "How many faces?")
        #expect(challenge.chosenOptionSnapshot == "Eight")
    }

    @Test func answeringAQuizOnAPhotoChallengeIsRejectedRatherThanGraded() throws {
        let engine = engine()
        try engine.discover(
            sideQuestID: SideQuestFixture.photoID, language: .id, method: .gps, accuracyM: 9)

        #expect(throws: SideQuestEngineError.challengeMismatch(expected: .quiz, actual: .photo)) {
            try engine.answerQuiz(sideQuestID: SideQuestFixture.photoID, optionIndex: 0)
        }
    }

    // MARK: - The photo challenge

    @Test func aPhotoChallengeStoresARelativePathAndAwardsItsLetterOnce() throws {
        // `FR-SIDE-13`, `NFR-REL-05` — relative to the app container, never absolute.
        let store = InMemorySideQuestStore()
        let engine = engine(store: store)
        try engine.discover(
            sideQuestID: SideQuestFixture.photoID, language: .id, method: .gps, accuracyM: 9)

        let completed = try engine.completePhoto(
            sideQuestID: SideQuestFixture.photoID, relativePath: "sidequests/sq-photo/1.jpg")
        #expect(completed.state == .completed)
        #expect(completed.challenge?.photoRelativePath == "sidequests/sq-photo/1.jpg")
        #expect(completed.challenge?.promptSnapshot == "Foto gerbangnya.")
        #expect(completed.awards.count == 1)

        let again = try engine.completePhoto(
            sideQuestID: SideQuestFixture.photoID, relativePath: "sidequests/sq-photo/2.jpg")
        #expect(again.challenge?.photoRelativePath == "sidequests/sq-photo/1.jpg")
        #expect(again.awards.count == 1)
    }

    // MARK: - Surviving content

    @Test func aRecordStillRendersAfterThePlaceIsWithdrawn() throws {
        // `FR-SIDE-10`, `FR-SIDE-14` — a letter already earned is retained, and the story with it.
        let store = InMemorySideQuestStore()
        try SideQuestEngine(repository: SideQuestFixture.repository(), store: store)
            .discover(sideQuestID: SideQuestFixture.quizID, language: .id,
                      method: .gps, accuracyM: 9)
        _ = try SideQuestEngine(repository: SideQuestFixture.repository(), store: store)
            .answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)

        // The content release that follows has neither the sidequest nor its place.
        let afterWithdrawal = SideQuestEngine(
            repository: SideQuestFixture.repository(sideQuests: [], places: []), store: store)
        let record = try #require(try afterWithdrawal.record(sideQuestID: SideQuestFixture.quizID))
        #expect(record.snapshotPlaceName == "Puri Contoh")
        #expect(record.snapshotLore.first?.sourceCitations == ["Arsip Kota, 1938"])
        #expect(record.letter == "A")
        #expect(record.awards.count == 1)
    }

    @Test func theSnapshotIsInTheRecordsPinnedLanguageNotTheAppsCurrentOne() throws {
        // `NFR-I18N-04`.
        let store = InMemorySideQuestStore()
        let engine = engine(store: store)
        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .en, method: .gps, accuracyM: 9)
        _ = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 0)

        let record = try #require(try store.record(sideQuestID: SideQuestFixture.quizID))
        #expect(record.language == .en)
        #expect(record.snapshotTitle == "Title sq-quiz")
        #expect(record.snapshotLore.first?.text == "Documented claim")
        #expect(record.challenge?.promptSnapshot == "How many faces?")

        // The collection is rendered in Indonesian; the record does not follow it.
        let progress = try engine.progress(
            collectionID: SideQuestFixture.collectionID, language: .id)
        #expect(progress.slots[1].placeName == "Pasar Contoh")
    }

    @Test func completingASidequestChangesNoRun() throws {
        // `FR-SIDE-01`. Separate stores, separate engines, and no call between them.
        let repository = SideQuestFixture.repository()
        let runStore = InMemoryRunStore()
        let run = try RunEngine(repository: repository, store: runStore)
            .start(questID: Fixture.questID, language: .id, method: .gps, accuracyM: 8)

        let sideQuests = SideQuestEngine(
            repository: repository, store: InMemorySideQuestStore())
        try sideQuests.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)
        _ = try sideQuests.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)

        let after = try #require(try runStore.run(id: run.id))
        #expect(after == run)
        #expect(after.awards.allSatisfy { $0.type != .letter })
        #expect(try runStore.runs().count == 1)
    }

    // MARK: - Collection progress

    @Test func anUnearnedSlotRendersABlankAndNotItsLetter() throws {
        // `FR-SIDE-08` — the blank is the whole game, and the place is still named so a traveller
        // can plan a visit (PRD §5.15 decision 3).
        let engine = engine()
        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)
        _ = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)

        let progress = try engine.progress(
            collectionID: SideQuestFixture.collectionID, language: .id)
        #expect(progress.slots[0].letter == "A")
        #expect(progress.slots[1].letter == nil)
        #expect(progress.slots[1].placeName == "Pasar Contoh")
        #expect(progress.earnedCount == 1)
        #expect(progress.totalCount == 2)
        #expect(!progress.isComplete)
        #expect(progress.maskedPhrase() == "A _")
        #expect(progress.spelledOutPhrase(blankWord: "kosong") == "A, kosong")
        // The unearned letter must not appear anywhere the view could read it.
        #expect(!progress.maskedPhrase().contains("B"))
    }

    @Test func theCollectionBadgeIsAwardedOnTheLastLetterAndNotBefore() throws {
        // `FR-SIDE-09`.
        let engine = engine()
        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)
        _ = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)
        #expect(try engine.progress(collectionID: SideQuestFixture.collectionID, language: .id)
            .badge == nil)

        try engine.discover(
            sideQuestID: SideQuestFixture.photoID, language: .id, method: .gps, accuracyM: 9)
        _ = try engine.completePhoto(
            sideQuestID: SideQuestFixture.photoID, relativePath: "sidequests/sq-photo/1.jpg")

        let progress = try engine.progress(
            collectionID: SideQuestFixture.collectionID, language: .id)
        #expect(progress.isComplete)
        #expect(progress.maskedPhrase() == "A B")
        let badge = try #require(progress.badge)
        #expect(badge.type == .badge)
        #expect(badge.sourceID == "badge-collection-fixture")
        #expect(badge.snapshotName == "AB")
        // Derived, so "once" is true by construction: computing it twice gives the same award.
        #expect(try engine.progress(collectionID: SideQuestFixture.collectionID, language: .id)
            .badge == badge)
    }

    @Test func aPhraseWithSpacesKeepsThemInBothRenderings() throws {
        // `s2` §5 — `B _ L I   T H _`, spaces preserved from the phrase and given no slot.
        let letters = ["B", "A", "L", "I", "T", "H", "E"]
        let progress = LetterCollectionProgress(
            collectionID: "c",
            phrase: "BALI THE",
            slots: letters.enumerated().map { index, letter in
                LetterCollectionProgress.Slot(
                    index: index,
                    sideQuestID: "sq-\(index)",
                    // Only B, L, I, T and H are earned.
                    letter: [1, 6].contains(index) ? nil : letter,
                    placeName: "Tempat \(index)",
                    completedAt: nil)
            })
        #expect(progress.maskedPhrase() == "B _ L I   T H _")
        #expect(progress.spelledOutPhrase(blankWord: "kosong")
            == "B, kosong, L, I, T, H, kosong")
        #expect(progress.earnedCount == 5)
        #expect(!progress.isComplete)
    }

    @Test func discoveringASidequestWithNoCollectionSlotIsRejected() throws {
        // Rule V24 makes this unreachable in valid content; reaching it means the bundle did not
        // pass the validator, and a silent letterless record would be worse than a throw.
        let engine = engine(repository: SideQuestFixture.repository(collections: []))
        #expect(throws: SideQuestEngineError.noCollectionSlot(SideQuestFixture.quizID)) {
            try engine.discover(
                sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)
        }
    }

    // MARK: - Monitoring candidates

    @Test func aCompletedSidequestIsNotACandidateForMonitoring() throws {
        // `s0` D9, `FR-SIDE-12` — deregistered the way a completed quest's start region is.
        let engine = engine()
        #expect(try engine.monitoringCandidates().map(\.id)
            == [SideQuestFixture.quizID, SideQuestFixture.photoID])

        try engine.discover(
            sideQuestID: SideQuestFixture.quizID, language: .id, method: .gps, accuracyM: 9)
        // Discovered but unfinished is still a candidate: `FR-SIDE-07` keeps it openable.
        #expect(try engine.monitoringCandidates().count == 2)

        _ = try engine.answerQuiz(sideQuestID: SideQuestFixture.quizID, optionIndex: 1)
        #expect(try engine.monitoringCandidates().map(\.id) == [SideQuestFixture.photoID])
    }

    @Test func aSuppressedSidequestIsNotACandidateButItsLetterIsKept() throws {
        // `AD-5`, `FR-SIDE-14`.
        let store = InMemorySideQuestStore()
        let engine = engine(store: store)
        try engine.discover(
            sideQuestID: SideQuestFixture.photoID, language: .id, method: .gps, accuracyM: 9)
        _ = try engine.completePhoto(
            sideQuestID: SideQuestFixture.photoID, relativePath: "sidequests/sq-photo/1.jpg")

        let candidates = try engine.monitoringCandidates(
            suppressingSideQuestIDs: [SideQuestFixture.quizID])
        #expect(candidates.isEmpty)
        #expect(try store.record(sideQuestID: SideQuestFixture.photoID)?.letter == "B")
    }

    @Test func aMonitoringCandidateUsesTheNoticeRadiusNotTheTriggerRadius() throws {
        // `FR-PROX-11` — the alert warns on approach; it does not confirm arrival.
        let candidate = try #require(try engine().monitoringCandidates().first)
        #expect(candidate.radiusM == 200)
        #expect(candidate.priority == RegionBudget.sideQuestPriority)
        #expect(candidate.coordinate == Coordinate(lat: -8.6570, lon: 115.2160))
    }
}

/// The grading rule on its own, because "unlimited attempts, and the answer after three" is a
/// product promise and a promise made in an `if` inside a view model is one nobody can check.
struct SideQuestQuizTests {

    @Test func aRightAnswerIsNeverRevealedNoMatterHowLateItArrives() {
        // `FR-SIDE-06` — revelation is what happens instead of a fourth guess, not a label put on
        // a walker who took a while.
        let late = SideQuestQuiz.grade(chosenIndex: 1, correctIndex: 1, priorAttempts: 5)
        #expect(late.isCorrect)
        #expect(!late.isRevealed)
        #expect(late.attempts == 6)
    }

    @Test func theAnswerIsRevealedOnTheThirdWrongAttemptAndNotTheSecond() {
        #expect(!SideQuestQuiz.grade(chosenIndex: 0, correctIndex: 1, priorAttempts: 0).isRevealed)
        #expect(!SideQuestQuiz.grade(chosenIndex: 0, correctIndex: 1, priorAttempts: 1).isRevealed)
        #expect(SideQuestQuiz.grade(chosenIndex: 0, correctIndex: 1, priorAttempts: 2).isRevealed)
        #expect(SideQuestQuiz.grade(chosenIndex: 0, correctIndex: 1, priorAttempts: 2).attempts
                == SideQuestQuiz.revealAfterAttempts)
    }

    @Test func attemptsNeverGoBackwardsFromAMalformedPriorCount() {
        #expect(SideQuestQuiz.grade(chosenIndex: 0, correctIndex: 1, priorAttempts: -4).attempts
                == 1)
    }
}
