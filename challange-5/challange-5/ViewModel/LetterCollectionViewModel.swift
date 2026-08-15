import ContentKit
import Foundation
import RunEngine
import UIStringsKit

/// The collection screen (`FR-SIDE-08`, `FR-SIDE-09`).
///
/// It takes the engine, not the repository plus the store: one caller, one rule set. Progress is
/// computed on every read and never stored — a second source of truth for "how far am I" drifts the
/// first time a record is deleted by erasure (`FR-SET-02`).
@MainActor
@Observable
final class LetterCollectionViewModel {

    private let engine: SideQuestEngine
    private let repository: any ContentRepository
    private let language: ContentLanguage
    private let collectionID: String

    private(set) var presentation: LetterCollectionPresentation?
    private(set) var message: String?

    init(
        engine: SideQuestEngine,
        repository: any ContentRepository,
        language: ContentLanguage,
        collectionID: String
    ) {
        self.engine = engine
        self.repository = repository
        self.language = language
        self.collectionID = collectionID
        reload()
    }

    /// Rebuilt whenever the screen appears, because a letter may have been earned since it was last
    /// on screen.
    func reload() {
        do {
            let progress = try engine.progress(collectionID: collectionID, language: language)
            let collection = (try? repository.collection(id: collectionID)) ?? nil
            presentation = Self.map(
                progress, collection: collection, language: language)
        } catch {
            message = String(describing: error)
        }
    }

    private static func map(
        _ progress: LetterCollectionProgress,
        collection: LetterCollection?,
        language: ContentLanguage
    ) -> LetterCollectionPresentation {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .id ? "id_ID" : "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let blankWord = UIStrings.string(.collectionBlankLetter, language)
        let lockedText = UIStrings.string(.collectionSlotLocked, language)

        let slots = progress.slots.map { slot -> LetterSlotPresentation in
            let dateText = slot.completedAt.map { formatter.string(from: $0) }
            // `NFR-A11Y-01` — an earned slot is spoken as its letter and its place; an unearned one
            // names the place and says it is not found yet. Neither reads as an underscore, and the
            // unearned one never carries the letter, not even in the label.
            let label = slot.isEarned
                ? [slot.letter, slot.placeName, dateText].compactMap { $0 }.joined(separator: ", ")
                : [lockedText, slot.placeName].compactMap { $0 }.joined(separator: ", ")
            return LetterSlotPresentation(
                id: slot.index,
                letter: slot.letter,
                placeName: slot.placeName,
                dateText: dateText,
                isEarned: slot.isEarned,
                sideQuestID: slot.sideQuestID,
                accessibilityLabel: label)
        }

        return LetterCollectionPresentation(
            id: progress.collectionID,
            title: collection?.title.value(for: language)
                ?? UIStrings.string(.collectionHeading, language),
            caption: collection?.caption.value(for: language) ?? "",
            maskedPhrase: progress.maskedPhrase(),
            spokenPhrase: String(
                format: UIStrings.string(.collectionPhraseAccessibility, language),
                progress.spelledOutPhrase(blankWord: blankWord)),
            progressText: String(
                format: UIStrings.string(.collectionProgress, language),
                progress.earnedCount, progress.totalCount),
            slots: slots,
            isComplete: progress.isComplete,
            // `FR-SIDE-09` — present only once every slot is filled, and derived upstream so
            // "awarded once" is true by construction rather than by a guard.
            badgeText: progress.badge.map {
                String(format: UIStrings.string(.collectionBadgeAwarded, language), $0.snapshotName)
            })
    }

    func dismissMessage() { message = nil }
}
