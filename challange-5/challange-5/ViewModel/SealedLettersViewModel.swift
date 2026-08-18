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

    let language: ContentLanguage

    private let store: any RunStore
    private let repository: any ContentRepository
    private var openingTask: Task<Void, Never>?

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
        letters = runs.map(presentation)
        if !letters.indices.contains(selectedIndex) { selectedIndex = 0 }
    }

    /// Move the shelf. Any opening in flight is abandoned and the envelope re-seals, because the
    /// stage belongs to the centred card and the centred card has changed.
    func select(_ index: Int) {
        guard letters.indices.contains(index), index != selectedIndex else { return }
        cancelOpening()
        selectedIndex = index
    }

    /// Run the opening: flap, hold, the page out of the pocket, the slow zoom. `onFinish` is called
    /// once the zoom has run, and is where the screen hands over to the walk itself.
    ///
    /// Under Reduce Motion or VoiceOver every beat is zero-length, so this is a cut to the
    /// destination rather than a skipped animation — see `HisploraEnvelopeSequence`.
    func unseal(rendersImmediately: Bool, onFinish: @escaping (UUID) -> Void) {
        guard stage == .sealed, let letter = selectedLetter else { return }
        let sequence = HisploraEnvelopeSequence(rendersImmediately: rendersImmediately)
        openingTask?.cancel()
        openingTask = Task { [weak self] in
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
        }
    }

    func cancelOpening() {
        openingTask?.cancel()
        openingTask = nil
        stage = .sealed
    }

    // MARK: - Building one letter

    private func presentation(_ run: Run) -> SealedLetterPresentation {
        let quest = (try? repository.quest(id: run.questID)) ?? nil
        let region = quest?.region ?? ""
        let stamps = run.awards
            .filter { $0.type == .stamp }
            .sorted { $0.awardedAt < $1.awardedAt }
            .map { StampPresentation(id: $0.sourceID, placeName: $0.snapshotName, region: region) }
        let progress = String(
            format: UIStrings.string(.checkpointProgress, language),
            run.reachedCount, run.checkpointCount)
        return SealedLetterPresentation(
            id: run.id,
            questID: run.questID,
            title: run.snapshotQuestTitle,
            progressText: progress,
            isComplete: run.state == .completed,
            stamps: stamps,
            heroImageURL: quest?.heroImageAsset
                .flatMap { (try? repository.assetURL($0)) ?? nil },
            accessibilityLabel: "\(run.snapshotQuestTitle), \(progress)")
    }
}
