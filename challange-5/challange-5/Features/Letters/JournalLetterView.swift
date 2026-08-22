import SwiftUI

/// The letter, opened — and since `791:6414` / `791:6537`, two pages rather than one.
///
/// **This used to be a single scroll, and the frames changed that decision.** Before the New
/// Hisplora board drew them, the two cards in the papers modal opened the same sheet at two scroll
/// offsets: the walk and the lore it unlocked are both records of one Run, and splitting them meant
/// two screens printing halves of one set of snapshots. The board then drew each half as its own
/// screen, with its own masthead, its own grounds and its own furniture — the summary's counters and
/// stamp collection have nowhere to live on a lore page, and the history's alternating bands have
/// nothing to do with a set of counts. So the split is now real, and this type is the switch.
///
/// Both pages are built the same way and hold the same line: everything on them is the Run's own
/// snapshot, never a content lookup (`FR-DONE-04`, `FR-DONE-05`, `AD-4`, `FR-RUN-06`), and neither
/// prints a word or a picture the frames invented for a quest that does not exist. Each screen's
/// own documentation says which of the frame's contents it refused and why.
struct JournalLetterView: View {
    private let model: RunSummaryViewModel
    /// The shelf's own record of this walk — the hero picture, the franked stamps and the two
    /// papers' titles, none of which the summary model has a repository to look up.
    private let letter: SealedLetterPresentation
    /// Which paper the reader opened the letter from (`791:5551`), and therefore which page this is.
    private let section: JournalPaperPresentation.Kind
    /// Reads the walker's own photographs back for the summary's Trip Collection.
    private let photoStore: any PhotoStore
    /// Mints the summary's recap card (`c2` phase 5). The History page has no card of its own — it
    /// is an editorial narrative, not a summary, and keeps its own plain-text share.
    private let shareCards: any ShareCardMinting
    private let onClose: () -> Void

    init(model: RunSummaryViewModel,
         letter: SealedLetterPresentation,
         section: JournalPaperPresentation.Kind = .summary,
         photoStore: any PhotoStore,
         shareCards: any ShareCardMinting = NoShareCardMinting(),
         onClose: @escaping () -> Void) {
        self.model = model
        self.letter = letter
        self.section = section
        self.photoStore = photoStore
        self.shareCards = shareCards
        self.onClose = onClose
    }

    var body: some View {
        switch section {
        case .summary:
            TripSummaryScreen(model: model, letter: letter,
                              photoStore: photoStore, shareCards: shareCards, onClose: onClose)
        case .history:
            TripHistoryScreen(model: model, letter: letter, onClose: onClose)
        }
    }
}
