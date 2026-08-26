import ContentKit
// For `HisploraEnvelopeStage` and its timings alone — the opening's beats are a value type, and
// the sequence belongs to the model that drives it rather than to the view that draws it. The same
// dependency `QuestRunViewModel` and `SideQuestFlowViewModel` already carry.
import DesignSystem
import Foundation
import RunEngine
import UIStringsKit

/// The Journal tab's shelf of sealed letters, and where the opening of one has got to.
///
/// `AD-3` applies here as everywhere: there is no loading state, no refresh and no reachability
/// check. The shelf is read from the Run store on the main actor and is either there or empty.
@MainActor
@Observable
final class SealedLettersViewModel {

    private(set) var letters: [SealedLetterPresentation] = []
    /// Which envelope is centred. An index rather than an id so the carousel can step past the
    /// ends without a lookup.
    var selectedIndex: Int = 0
    /// How far the centred envelope is through its opening. Reset whenever the selection moves,
    /// because an envelope that stayed open behind the reader's back would be a lie the next time
    /// they swiped back to it.
    private(set) var stage: HisploraEnvelopeStage = .sealed
    /// Which way round the centred envelope is standing (`791:5637`). Reset with the selection for
    /// the same reason the stage is.
    private(set) var flip: HisploraEnvelopeFlip = .front

    let language: ContentLanguage

    private let store: any RunStore
    private let repository: any ContentRepository
    private var openingTask: Task<Void, Never>?
    private var flipTask: Task<Void, Never>?

    init(store: any RunStore, repository: any ContentRepository, language: ContentLanguage) {
        self.store = store
        self.repository = repository
        self.language = language
        reload()
    }

    var isEmpty: Bool { letters.isEmpty }

    var selectedLetter: SealedLetterPresentation? {
        letters.indices.contains(selectedIndex) ? letters[selectedIndex] : nil
    }

    /// True while the envelope is closed and there is more than one to swipe between — the only
    /// moment the nudge says something the reader does not already know.
    var showsSwipeHint: Bool { stage == .sealed && letters.count > 1 }

    /// A letter may have been finished since this screen was last looked at.
    func reload() {
        let runs = ((try? store.runs()) ?? [])
            // Most recent first, with a walk still under way at the front of the shelf: the letter
            // a reader is most likely to want is the one they are in the middle of.
            .sorted { lhs, rhs in
                if (lhs.state == .active) != (rhs.state == .active) { return lhs.state == .active }
                return lhs.updatedAt > rhs.updatedAt
            }
        // Built once for the whole shelf rather than per letter: the content lookup behind it is
        // the expensive half, and the counting it does is per-Run.
        let artwork = StampArtworkResolver(runs: runs, repository: repository)
        letters = runs.map { presentation($0, artwork: artwork) }
        if !letters.indices.contains(selectedIndex) { selectedIndex = 0 }
    }

    /// Move the shelf. Any opening in flight is abandoned and the envelope re-seals, because the
    /// stage belongs to the centred card and the centred card has changed.
    func select(_ index: Int) {
        guard letters.indices.contains(index), index != selectedIndex else { return }
        cancelOpening()
        selectedIndex = index
    }

    // MARK: - The idle turn

    /// Turn the sealed card over and back, on a loop, until something stops it (`791:5637`).
    ///
    /// **Skipped rather than collapsed under Reduce Motion.** Every other sequence here runs its
    /// beats in zero time so the screen still arrives where it was going; this one has nowhere to
    /// arrive. An idle animation collapsed to a cut is a card that snaps to its back and stays
    /// there, which is worse than a card that simply does not turn.
    func startFlipCycle(rendersImmediately: Bool) {
        flipTask?.cancel()
        guard !rendersImmediately, stage == .sealed else {
            flip = .front
            flipTask = nil
            return
        }
        let sequence = HisploraEnvelopeSequence(rendersImmediately: false)
        flipTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: HisploraEnvelopeSequence.flipInterval)
                guard let self, !Task.isCancelled, self.stage == .sealed else { return }
                // One whole turn: out to the addressed side, held, and back.
                for _ in 0..<4 {
                    guard !Task.isCancelled, self.stage == .sealed else { return }
                    let next = self.flip.next
                    self.flip = next
                    try? await Task.sleep(for: sequence.duration(ofFlip: next))
                }
            }
        }
    }

    func cancelFlipCycle() {
        flipTask?.cancel()
        flipTask = nil
    }

    /// Bring the card back to its front, one beat at a time, and answer once it is there.
    ///
    /// This is the rule the designer's note asks for: *if the user clicks open while we flip the
    /// envelope we have to flip it back first then open the envelope*. It is not a nicety — the
    /// flap and the wax are drawn on the front, so an opening that started on the back would swing
    /// a flap the reader cannot see.
    private func returnToFront(sequence: HisploraEnvelopeSequence) async {
        for beat in flip.returningToFront {
            flip = beat
            try? await Task.sleep(for: sequence.duration(ofFlip: beat))
            if Task.isCancelled { return }
        }
        flip = .front
    }

    /// Run the opening: flap, hold, the page out of the pocket, the slow zoom. `onFinish` is called
    /// once the zoom has run, and is where the screen hands over to the walk itself.
    ///
    /// Under Reduce Motion or VoiceOver every beat is zero-length, so this is a cut to the
    /// destination rather than a skipped animation — see `HisploraEnvelopeSequence`.
    func unseal(rendersImmediately: Bool, onFinish: @escaping (UUID) -> Void) {
        guard stage == .sealed, let letter = selectedLetter else { return }
        let sequence = HisploraEnvelopeSequence(rendersImmediately: rendersImmediately)
        cancelFlipCycle()
        openingTask?.cancel()
        openingTask = Task { [weak self] in
            // The card finishes turning back before the first beat of the opening. Under Reduce
            // Motion the turn never ran, so this is a no-op and the flap opens immediately.
            await self?.returnToFront(sequence: HisploraEnvelopeSequence(rendersImmediately: false))
            var current = HisploraEnvelopeStage.sealed
            while let next = current.next {
                guard let self, !Task.isCancelled else { return }
                self.stage = next
                current = next
                try? await Task.sleep(for: sequence.duration(of: next))
            }
            guard let self, !Task.isCancelled else { return }
            onFinish(letter.id)
            // Re-sealed behind the reader, so coming back from the walk shows a shelf rather than
            // an envelope frozen mid-zoom.
            self.stage = .sealed
            // And turning again. The cycle was cancelled at the top of this method and the screen
            // never disappeared, so without this the card stands still for the rest of the session
            // — the shelf loses its one idle animation the first time a reader opens anything.
            self.startFlipCycle(rendersImmediately: rendersImmediately)
        }
    }

    func cancelOpening() {
        openingTask?.cancel()
        openingTask = nil
        cancelFlipCycle()
        stage = .sealed
        flip = .front
    }

    // MARK: - Building one letter

    private func presentation(_ run: Run, artwork: StampArtworkResolver) -> SealedLetterPresentation {
        let quest = (try? repository.quest(id: run.questID)) ?? nil
        let region = quest?.region ?? ""
        let stamps = run.awards
            .filter { $0.type == .stamp }
            .sorted { $0.awardedAt < $1.awardedAt }
            .map {
                StampPresentation(
                    id: $0.sourceID,
                    placeName: $0.snapshotName,
                    region: region,
                    artworkName: artwork.artworkName(run: run, stampSourceID: $0.sourceID))
            }
        let progress = String(
            format: UIStrings.string(.checkpointProgress, language),
            run.reachedCount, run.checkpointCount)
        // The quest may be gone from under a finished walk (`FR-RUN-06`), and the papers still have
        // to be able to name where it went. The Run's own title is what is left when it is.
        let place = region.isEmpty ? run.snapshotQuestTitle : region
        return SealedLetterPresentation(
            id: run.id,
            questID: run.questID,
            title: run.snapshotQuestTitle,
            progressText: progress,
            isComplete: run.state == .completed,
            stamps: stamps,
            heroImageURL: quest?.heroImageAsset
                .flatMap { (try? repository.assetURL($0)) ?? nil },
            papers: papers(place: place),
            addressLines: addressLines(run: run, place: place),
            accessibilityLabel: "\(run.snapshotQuestTitle), \(progress)")
    }

    /// The two sheets in the pocket (`791:5568`, `791:5814`).
    ///
    /// The artwork names are the packaged defaults and are the one thing here that is not the
    /// walk's own data — see `JournalPaperPresentation.artworkName` for why that is a table rather
    /// than a content field, and what it will cost when a second quest ships.
    private func papers(place: String) -> [JournalPaperPresentation] {
        [
            JournalPaperPresentation(
                kind: .summary,
                eyebrow: UIStrings.string(.journalPaperSummaryEyebrow, language),
                title: String(format: UIStrings.string(.journalPaperSummaryTitle, language), place),
                actionTitle: UIStrings.string(.journalPaperSummaryAction, language),
                artworkName: "journal-summary-emblem",
                artworkStyle: .roundel),
            JournalPaperPresentation(
                kind: .history,
                eyebrow: UIStrings.string(.journalPaperHistoryEyebrow, language),
                title: String(format: UIStrings.string(.journalPaperHistoryTitle, language), place),
                actionTitle: UIStrings.string(.journalPaperHistoryAction, language),
                artworkName: "journal-history-plate",
                artworkStyle: .plate)
        ]
    }

    /// What is written on the back (`791:5657`).
    ///
    /// The date is the day the walk ended, or the day it was last touched while it is still going —
    /// the same fact the shelf sorts on, so a letter's address and its place in the row agree.
    private func addressLines(run: Run, place: String) -> [String] {
        let date = (run.completedAt ?? run.updatedAt).formatted(
            .dateTime.day().month(.wide).year().locale(Locale(identifier: language.rawValue)))
        return [
            UIStrings.string(.journalEnvelopeSalutation, language),
            run.snapshotQuestTitle,
            place,
            date
        ]
    }
}
