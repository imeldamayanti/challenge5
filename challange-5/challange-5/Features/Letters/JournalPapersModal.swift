import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The two papers, read (`791:5551`).
///
/// **A modal over the shelf, not a screen pushed onto it.** The frame draws the Journal still
/// there behind a scrim, and the beat before this is an envelope zooming its own papers toward the
/// reader — a push would throw that away and slide something else in from the side. It is presented
/// by `KultaraRootView` for the one reason a tab's own overlay could not be: the floating tab bar
/// lives above the tab's content, and a modal with the tab bar on top of it is not a modal.
///
/// Each card's action opens the letter itself, at the part of it the card is about.
struct JournalPapersModal: View {
    @Environment(\.hisploraPalette) private var palette

    let letter: SealedLetterPresentation
    let language: ContentLanguage
    /// Which paper the reader chose, which is what the letter opens at.
    let onOpen: (JournalPaperPresentation.Kind) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // `791:5567`: near-black at 80%. `inkDark` rather than a colour of its own — the
            // frame's `#1A1A1A` and the palette's `#1D1D1D` are the same ink to within a step, and
            // a scrim is not a token anyone measures type against.
            palette.inkDark.color
                .opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            ScrollView {
                VStack(spacing: HisploraJournalPaperMetrics.spacing) {
                    ForEach(letter.papers) { paper in
                        JournalPaperCard(paper: paper) { onOpen(paper.kind) }
                    }
                }
                .padding(.horizontal, HisploraJournalPaperMetrics.screenInset)
                // `791:5568` starts at 130 from the top of the frame, less the 62-point status
                // bar the safe area already holds.
                .padding(.top, 68)
                .padding(.bottom, KultaraMetrics.xxl)
            }
            .scrollIndicators(.hidden)
            // The cards are the reader's own zoom arriving: they come in a little over-size and
            // settle, which is the motion the envelope's last beat was already making.
            .scrollBounceBehavior(.basedOnSize)

            closeControl
        }
        .accessibilityAddTraits(.isModal)
    }

    /// `791:5584`. A cross has to be named, because a shape is not a label (`NFR-A11Y-05`).
    private var closeControl: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.inkOnButton.color)
                .kultaraTapTarget()
        }
        .accessibilityLabel(UIStrings.string(.journalPapersClose, language))
        .padding(.trailing, KultaraMetrics.lg)
        .padding(.top, KultaraMetrics.sm)
    }
}
