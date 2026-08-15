import ContentKit
// `ChipAppearance` for the accuracy chip. `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` is on
// for this target, so a transitive import will not do — and no SwiftUI comes with it.
import DesignSystem
import Foundation
import RunEngine
import UIStringsKit

/// The whole sidequest flow, as `QuestRunViewModel` owns the run (PRD §5.15).
///
/// It holds a `SideQuestEngine` and nothing else that writes. **There is no call into `RunEngine`,
/// `RunStore` or a `Run` anywhere in this file**, which is how `FR-SIDE-01` is held — by there being
/// no call that could, rather than by a guard somebody can delete (`s0` D1).
@MainActor
@Observable
final class SideQuestFlowViewModel {

    /// The flow, one stage per screen.
    enum Stage: Equatable {
        /// Synopsis, and the question. `FR-TASK-05`'s dress code and photo policy come first at a
        /// sacred place, before any challenge is offered.
        case notice
        /// `FR-START-02` — the plain-language explanation that precedes the system prompt.
        case locationNotice
        /// `FR-SIDE-02` — the `FR-ARR-01` gate, with the 60 s override.
        case awaitingArrival
        case story
        case challenge
        case letter
        /// Backed out or finished. The screen dismisses itself; nothing is discarded.
        case done
    }

    // MARK: Inputs

    private let engine: SideQuestEngine
    private let repository: any ContentRepository
    let sampling: ArrivalSampling
    let language: ContentLanguage
    let sideQuestID: String

    // MARK: Observable state

    private(set) var stage: Stage = .notice
    private(set) var presentation: SideQuestPresentation
    private(set) var record: SideQuestRecord?
    private(set) var message: String?
    /// The option the walker has tapped but not yet submitted. Not an answer until `submitQuiz`,
    /// so a mis-tap costs nothing — and `attempts` in the record stays a count of real answers.
    var quizSelection: Int?
    private(set) var quizFeedback: QuizFeedback?
    /// Set when the challenge is settled, right or revealed (`FR-SIDE-05`).
    private(set) var awardedLetter: String?
    /// `FR-SIDE-08` — the phrase so far, shown on the letter screen. Recomputed rather than stored.
    private(set) var collectionProgressText: String?

    // MARK: Init

    init?(
        engine: SideQuestEngine,
        repository: any ContentRepository,
        locationProvider: any LocationProviding,
        sideQuestID: String,
        language: ContentLanguage,
        manualOverrideDelay: Duration = .seconds(60)
    ) {
        guard let sideQuest = (try? repository.sideQuest(id: sideQuestID)) ?? nil,
              let presentation = Self.presentation(
                for: sideQuest, repository: repository, language: language)
        else { return nil }

        self.engine = engine
        self.repository = repository
        self.sideQuestID = sideQuestID
        self.language = language
        self.presentation = presentation
        self.sampling = ArrivalSampling(
            locationProvider: locationProvider,
            language: language,
            manualOverrideDelay: manualOverrideDelay)
        self.record = (try? engine.record(sideQuestID: sideQuestID)) ?? nil

        sampling.onArrival = { [weak self] method, accuracyM in
            self?.discover(method: method, accuracyM: accuracyM)
        }
    }

    // MARK: The notice — FR-SIDE-11, FR-TASK-05

    /// "No" costs nothing and records nothing (`FR-SIDE-07` — the place stays openable forever, and
    /// a decline is not a state worth keeping). The alert row that *is* kept belongs to the
    /// notification path, which is `s3`.
    func decline() {
        sampling.stop()
        stage = .done
    }

    /// "Yes".
    ///
    /// A sidequest already discovered goes straight to its story rather than back through the gate.
    /// `FR-SIDE-02` gates *opening* the story, and it was opened; re-gating would make a completed
    /// sidequest unreadable from the collection screen, which `FR-SIDE-07` and `s4` §5's read-back
    /// both require. The story shown is the record's own snapshot either way (`FR-SIDE-10`).
    func accept() {
        if record != nil {
            openStory()
        } else if sampling.authorization == .notRequested {
            stage = .locationNotice
        } else {
            stage = .awaitingArrival
            beginSampling()
        }
    }

    /// `FR-START-02` — the explanation comes before the system prompt, never after it.
    func acknowledgeLocationNoticeAndRequestPermission() {
        stage = .awaitingArrival
        sampling.requestWhenInUseAuthorization()
        beginSampling()
    }

    // MARK: Sampling lifecycle — FR-ARR-02, NFR-BAT-04

    func screenAppeared() {
        guard stage == .awaitingArrival else { return }
        beginSampling()
    }

    func screenDisappeared() {
        sampling.stop()
    }

    private func beginSampling() {
        sampling.start(
            target: presentation.coordinate, radiusM: presentation.triggerRadiusM)
    }

    /// `FR-SIDE-03`, `FR-ARR-04` — one tap, and a manual entry is not a lesser one. Unlike a quest
    /// start there is no named presence confirmation: `FR-START-09` exists because starting from
    /// the wrong place ruins a route of five stops, and a sidequest has one stop and nothing
    /// downstream to ruin (`s0` D3).
    func useManualOverride() {
        sampling.arriveManually()
    }

    func presentManualOverride() { sampling.presentManualOverride() }

    func dismissManualOverride() { sampling.dismissManualOverride() }

    func confirmManualOverrideFromSheet() {
        sampling.dismissManualOverride()
        sampling.arriveManually()
    }

    // MARK: Discovery — FR-SIDE-02, FR-SIDE-10

    private func discover(method: ArrivalMethod, accuracyM: Double?) {
        sampling.finish()
        do {
            record = try engine.discover(
                sideQuestID: sideQuestID,
                language: language,
                method: method,
                accuracyM: accuracyM)
            openStory()
        } catch {
            message = String(describing: error)
        }
    }

    private func openStory() {
        stage = .story
        // `FR-CP-04`'s sidequest counterpart — recorded once; re-reads are re-reads.
        record = (try? engine.markLoreOpened(sideQuestID: sideQuestID)) ?? record
    }

    // MARK: The story — FR-SIDE-04, s0 D6

    /// The claims the story screen draws, **from the record's snapshot rather than from content**.
    ///
    /// This is `FR-SIDE-10` in one property: correcting a sentence must not rewrite what somebody
    /// read last month, and withdrawing a place must not blank a letter they earned. The accuracy
    /// label and the citations come with it, because the run flow's unlabelled Story Reveal is a
    /// signed exception that does not extend to a new surface by inference (`s0` D6).
    var storyClaims: [LoreClaimPresentation] {
        let formatter = ContentFormatter(language: language)
        let blocks = record?.snapshotLore ?? []
        return blocks.enumerated().map { offset, block in
            LoreClaimPresentation(
                id: offset,
                block: LoreBlockPresentation(
                    id: offset,
                    text: block.text,
                    accuracyLabel: formatter.accuracyLabel(block.accuracy),
                    appearance: block.accuracy == .documented ? .documented : .oral,
                    ink: block.accuracy == .documented ? .documented : .oral),
                citations: block.sourceCitations)
        }
    }

    var storyText: String {
        (record?.snapshotLore ?? []).map(\.text).joined(separator: "\n\n")
    }

    var placeName: String { record?.snapshotPlaceName ?? presentation.placeName }

    var title: String { record?.snapshotTitle ?? presentation.title }

    func advanceFromStory() {
        stage = .challenge
        // Re-opening a settled challenge shows what happened rather than asking again
        // (`FR-SIDE-05` — at most one letter, ever).
        if record?.isCompleted == true, case .quiz = presentation.challenge {
            replayStoredQuizOutcome()
        } else if record?.isCompleted == true {
            awardedLetter = record?.letter
        }
    }

    func retreatFromStory() {
        stage = .notice
    }

    // MARK: The challenge — FR-SIDE-05, FR-SIDE-06

    func selectOption(_ index: Int) {
        guard case .quiz(let quiz) = presentation.challenge,
              quiz.options.indices.contains(index) else { return }
        quizSelection = index
    }

    /// `FR-SIDE-06` — unlimited attempts, no penalty, and the answer revealed after three wrong
    /// ones with the letter awarded anyway. The rule itself is `SideQuestQuiz.grade` behind the
    /// engine; this only asks and draws.
    func submitQuiz() {
        guard let selection = quizSelection else { return }
        do {
            let outcome = try engine.answerQuiz(sideQuestID: sideQuestID, optionIndex: selection)
            record = (try? engine.record(sideQuestID: sideQuestID)) ?? record
            apply(outcome)
        } catch {
            message = String(describing: error)
        }
    }

    private func apply(_ outcome: QuizOutcome) {
        if outcome.isCorrect {
            quizFeedback = .correct(
                message: UIStrings.string(.sideQuestQuizCorrect, language),
                explanation: outcome.explanationText ?? "")
        } else if outcome.isRevealed {
            quizFeedback = .revealed(
                message: UIStrings.string(.sideQuestQuizRevealed, language),
                correctOptionText: outcome.correctOptionText ?? "",
                explanation: outcome.explanationText ?? "")
        } else {
            quizFeedback = .wrong(message: UIStrings.string(.sideQuestQuizWrong, language))
            return
        }
        awardedLetter = outcome.awardedLetter
        refreshCollectionProgress()
    }

    private func replayStoredQuizOutcome() {
        // Answering again on a completed record returns the stored outcome untouched rather than
        // recording a further attempt — the engine's own idempotency, not a rule repeated here.
        guard let outcome = try? engine.answerQuiz(
            sideQuestID: sideQuestID, optionIndex: 0) else { return }
        apply(outcome)
    }

    /// Phase D is the photo pipeline; until it lands a photo challenge states its prompt, says
    /// photographs are not in this build, and awards the letter on acknowledgement — the same shape
    /// M6 used for photo tasks (`s4` §7). `FR-TASK-06`'s runtime gate still applies: a photo
    /// challenge is not offered at all where photography is prohibited, filtered in `presentation`.
    func acknowledgePhotoChallenge() {
        do {
            record = try engine.completePhoto(sideQuestID: sideQuestID, relativePath: nil)
            awardedLetter = record?.letter
            refreshCollectionProgress()
            stage = .letter
        } catch {
            message = String(describing: error)
        }
    }

    /// Phase D's writer hands back a path relative to the app container, never absolute
    /// (`NFR-REL-05`, `FR-SIDE-13`). Present now so the engine call has exactly one caller when the
    /// capture pipeline arrives.
    func attachPhoto(_ relativePath: String) {
        do {
            record = try engine.completePhoto(
                sideQuestID: sideQuestID, relativePath: relativePath)
            awardedLetter = record?.letter
            refreshCollectionProgress()
            stage = .letter
        } catch {
            message = String(describing: error)
        }
    }

    /// Whether the answer is settled and the letter screen is reachable.
    var isChallengeSettled: Bool {
        switch quizFeedback {
        case .correct, .revealed: true
        case .wrong, .none: record?.isCompleted == true
        }
    }

    func advanceFromChallenge() {
        guard isChallengeSettled else { return }
        stage = .letter
    }

    func retreatFromChallenge() {
        stage = .story
    }

    // MARK: The letter — FR-SIDE-05, FR-SIDE-08

    private func refreshCollectionProgress() {
        guard let collectionID = record?.collectionID,
              let progress = try? engine.progress(collectionID: collectionID, language: language)
        else { return }
        collectionProgressText = String(
            format: UIStrings.string(.sideQuestLetterProgress, language),
            progress.earnedCount, progress.totalCount)
    }

    var collectionID: String? { record?.collectionID }

    func finish() {
        sampling.stop()
        stage = .done
    }

    func dismissMessage() { message = nil }

    // MARK: Content → presentation

    private static func presentation(
        for sideQuest: SideQuest,
        repository: any ContentRepository,
        language: ContentLanguage
    ) -> SideQuestPresentation? {
        let place = (try? repository.place(id: sideQuest.placeId)) ?? nil
        let formatter = ContentFormatter(language: language)

        let claims = sideQuest.lore.enumerated().map { offset, block in
            LoreClaimPresentation(
                id: offset,
                block: LoreBlockPresentation(
                    id: offset,
                    text: block.text.value(for: language),
                    accuracyLabel: formatter.accuracyLabel(block.accuracy),
                    appearance: block.accuracy == .documented ? .documented : .oral,
                    ink: block.accuracy == .documented ? .documented : .oral),
                citations: block.sourceRefs.compactMap { ref in
                    guard let place, place.sources.indices.contains(ref) else { return nil }
                    return place.sources[ref].citation
                })
        }

        // `FR-TASK-06`, `s0` D11 — a photo challenge is not offered where photography is
        // prohibited. Rule V23 is the build-time half; this is the half that matters when content
        // is corrected after a build, and it degrades to a quiz-less read rather than to a prompt
        // the walker must break a rule to answer.
        let challenge: ChallengePresentation
        switch sideQuest.challenge {
        case .quiz(let quiz):
            challenge = .quiz(QuizPresentation(
                question: quiz.question.value(for: language),
                options: quiz.options.enumerated().map { index, option in
                    QuizOptionPresentation(id: index, text: option.value(for: language))
                },
                explanation: quiz.explanation.value(for: language)))
        case .photo(let photo):
            guard place?.photoPolicy.level != .prohibited else { return nil }
            challenge = .photo(prompt: photo.prompt.value(for: language))
        }

        return SideQuestPresentation(
            id: sideQuest.id,
            placeName: place?.nameOfficial.value(for: language) ?? sideQuest.placeId,
            title: sideQuest.title.value(for: language),
            synopsis: sideQuest.synopsis.value(for: language),
            isSacred: place?.isSacred ?? false,
            dressCodeText: place?.dressCode.value(for: language) ?? "",
            photoPolicyText: place.map { formatter.photoPolicy($0.photoPolicy.level) } ?? "",
            claims: claims,
            challenge: challenge,
            heroImageURL: sideQuest.heroImageAsset
                .flatMap { (try? repository.assetURL($0)) ?? nil },
            triggerRadiusM: sideQuest.triggerRadiusM,
            coordinate: place?.coordinate ?? Coordinate(lat: 0, lon: 0))
    }
}
