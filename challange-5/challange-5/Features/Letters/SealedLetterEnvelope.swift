import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// One walk drawn as a sealed letter: the packaged envelope from `DesignSystem`, franked with what
/// this particular walk actually earned.
///
/// **The franking moved to the back** (`791:5601` → `791:5637`). The sealed card the shelf shows is
/// now bare paper and a wax seal; the stamps and the hand that addressed it are on the other side,
/// which is what the idle turn exists to show. Drawing them on both faces would make the turn say
/// nothing.
///
/// **Everything on the back is decoration and says so.** Every mark is set at the size the frame
/// photographs it, which is too small to be read at an accessibility size and would wreck the
/// object if it grew. It is therefore `accessibilityHidden`, and the same information is carried at
/// full size by the title under the envelope, by the two papers' modal, and by the card's own
/// spoken label. Nothing here is the only place something is said (`NFR-A11Y-01`).
struct SealedLetterEnvelope: View {
    @Environment(\.hisploraPalette) private var palette

    let letter: SealedLetterPresentation
    let language: ContentLanguage
    var stage: HisploraEnvelopeStage = .sealed
    var flip: HisploraEnvelopeFlip = .front
    var wiggles: Bool = false
    /// Passed through so Reduce Motion reaches the papers' own reveal, which is the one beat the
    /// envelope times for itself rather than taking from the caller.
    var sequence: HisploraEnvelopeSequence = HisploraEnvelopeSequence(rendersImmediately: false)

    var body: some View {
        HisploraEnvelope(stage: stage, flip: flip, wiggles: wiggles, sequence: sequence) {
            EmptyView()
        } back: {
            addressedSide
        } paper: {
            thumbnail(letter.papers.first)
        } companion: {
            thumbnail(letter.papers.dropFirst().first)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letter.accessibilityLabel)
    }

    /// One of the two sheets, at the size the pocket holds it.
    @ViewBuilder private func thumbnail(_ paper: JournalPaperPresentation?) -> some View {
        if let paper {
            GeometryReader { proxy in
                HisploraJournalPaperThumbnail(
                    width: proxy.size.width,
                    card: JournalPaperCard(paper: paper, action: nil).card)
            }
        }
    }

    // MARK: - The addressed side (`791:5641`)

    /// What is written on the back: the stamps this walk earned, and the address in the frame's
    /// hand.
    private var addressedSide: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                stamps(size: size)
                address(size: size)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }

    /// Up to five stamps, in the three-then-two block the frame franks the back with (`791:5645`).
    /// A sixth checkpoint is not drawn — the Explorer's Card is where the whole set is listed.
    private func stamps(size: CGSize) -> some View {
        ForEach(Array(letter.stamps.prefix(BackFranking.slots.count).enumerated()),
                id: \.element.id) { index, stamp in
            let slot = BackFranking.slots[index]
            // The drawing, but no franking. At this size the frame's own caption is under three
            // points high — texture, not words — so the names are printed on the Explorer's Card,
            // where the same stamp is set six times larger.
            HisploraStampCard(
                title: stamp.placeName,
                subtitle: stamp.region,
                showsFranking: false,
                artworkName: stamp.artworkName)
                .frame(height: size.height * BackFranking.stampHeightRatio)
                .rotationEffect(.degrees(slot.rotation))
                .position(x: size.width * slot.centre.x, y: size.height * slot.centre.y)
        }
    }

    /// The four lines the frame writes on the back: a salutation, the walk's own title, where it
    /// was walked and when.
    private func address(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(letter.addressLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .font(HisploraHandwriting.font(size: max(8, size.height * BackFranking.handSizeRatio)))
        .foregroundStyle(palette.inkDark.color)
        .lineSpacing(size.height * BackFranking.handSizeRatio * 0.4)
        .frame(width: size.width * BackFranking.addressWidthRatio, alignment: .leading)
        .offset(x: size.width * BackFranking.addressOrigin.x,
                y: size.height * BackFranking.addressOrigin.y)
    }

    /// The back's own measurements, read off `791:5641` (356.669 × 214) and kept as ratios so they
    /// survive the card being drawn at whatever width the carousel gives it.
    private enum BackFranking {
        struct Slot {
            let centre: CGPoint
            let rotation: Double
        }

        /// Three across the top, two under the right of them — the block `791:5645` draws, in the
        /// order a walk earns its stamps.
        static let slots: [Slot] = [
            Slot(centre: CGPoint(x: 205.87 / 356.669, y: 34.60 / 214), rotation: -3),
            Slot(centre: CGPoint(x: 263.17 / 356.669, y: 34.41 / 214), rotation: 2),
            Slot(centre: CGPoint(x: 319.41 / 356.669, y: 34.86 / 214), rotation: -1),
            Slot(centre: CGPoint(x: 262.57 / 356.669, y: 91.24 / 214), rotation: -2),
            Slot(centre: CGPoint(x: 319.57 / 356.669, y: 90.82 / 214), rotation: 1)
        ]

        /// 48.09 of the card's 214. The die is portrait (`152 × 206`) where the frame's own stamp is
        /// nearly square, so the height is what is matched and the width follows from the die —
        /// re-cutting the stamp for one face would give the Explorer's Card a different object.
        static let stampHeightRatio: CGFloat = 48.091 / 214

        static let addressOrigin = CGPoint(x: 26 / 356.669, y: 123 / 214)
        static let addressWidthRatio: CGFloat = 200 / 356.669
        /// 12.299 on a 214-tall card, at the frame's 1.4 line height.
        static let handSizeRatio: CGFloat = 12.299 / 214
    }
}
