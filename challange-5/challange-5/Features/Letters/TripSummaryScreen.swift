import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The Trip Summary — Figma `791:6414`, what the envelope's first paper opens.
///
/// Three grounds down one scroll: the cream page carrying the masthead, the emblem and the three
/// counters; a brown band naming every place the walk reached; and a tan band holding the stamps it
/// earned under a scatter of paper cut-outs. Every measurement, size, weight, tracking and colour
/// below is the frame's own.
///
/// **It reflows where the History page does not, and that is the difference between the two.**
/// History is a fixed editorial spread with fixed words, so it is drawn at the frame's coordinates
/// and scaled. This page's contents are the walk's — a place name is as long as it is, a walker's
/// answer is as long as they made it, and a quest may have three stops or eight — so it is built as
/// stacks with the frame's spacings. The type is still pinned to the frame's point sizes rather
/// than to `KultaraTypography`'s roles, which costs Dynamic Type here too.
///
/// **Everything on it is the Run's own snapshot** (`FR-DONE-04`, `FR-DONE-05`, `AD-4`) — except the
/// one thing that is the quest's. The frame hard-codes a walk through Badung, a one-line summary per
/// place, and five collectibles called "The Iron Statue" and "Ancient Script" that exist nowhere in
/// the content tree. What is drawn instead is the walk: its checkpoints, the lore they unlocked, the
/// answers the walker wrote, the stamps they earned, and — in the Trip Collection's grid — the
/// photographs they actually took, one medallion each. The featured medallion is the exception: it
/// is the quest's legend, and it comes from `QuestHistoryText` under the sourcing decision recorded
/// there.
struct TripSummaryScreen: View {
    @Environment(\.hisploraPalette) private var palette

    let model: RunSummaryViewModel
    let letter: SealedLetterPresentation
    /// Reads the walker's own photographs back for the Trip Collection.
    let photoStore: any PhotoStore
    /// Mints the recap card's public link (`c2` phase 5). `NoShareCardMinting` with no backend.
    let shareCards: any ShareCardMinting
    let onClose: () -> Void

    /// The minted link, once minting finishes. `nil` is the ordinary state — no backend, minting
    /// still running, or it failed — and `TripPageBar` already falls back to `shareText` for all
    /// three, so there is nothing here to distinguish between them.
    @State private var mintedShareURL: URL?

    private var language: ContentLanguage { model.language }

    /// The summary paper's own title — "Your journey through Badung" — already localized and
    /// interpolated with the walk's region. Read from the paper rather than rebuilt so the page is
    /// headed exactly as the card that opened it.
    private var headline: String {
        letter.papers.first { $0.kind == .summary }?.title
            ?? String(format: UIStrings.string(.journalPaperSummaryTitle, language), letter.title)
    }

    var body: some View {
        HisploraStage(ground: \.paperTrip, grain: false) {
            VStack(spacing: 0) {
                TripPageBar(
                    title: UIStrings.string(.journalPaperSummaryEyebrow, language),
                    backLabel: UIStrings.string(.tripPageBack, language),
                    shareURL: mintedShareURL,
                    shareText: shareText,
                    shareLabel: UIStrings.string(.tripShare, language),
                    onBack: onClose)

                ScrollView {
                    VStack(spacing: 0) {
                        masthead
                        emblem
                        journeyCounts
                        piecesBand
                        collectionBand
                    }
                    // Hung off the content, not behind the scroll view: a background on the
                    // viewport is fixed to the viewport, so it slid under the page as the page
                    // scrolled and repainted the counters' ground halfway down.
                    .overscrollBleed(top: palette.paperTrip, bottom: palette.paperTan)
                }
                .scrollIndicators(.hidden)
            }
        }
        // One attempt per presentation, not per share tap: a walker who taps share twice while it
        // is still rendering gets the plain-text fallback both times rather than two uploads
        // racing to write the same row. `.task` cancels itself if the screen closes mid-render, so
        // a card is never finished uploading after the walker has already left.
        .task(id: model.run.id) { await mintShareCardIfAvailable() }
    }

    /// Renders the card off-screen, uploads it, and stores the link `TripPageBar` prefers over
    /// plain text. Every value on the card is the Run's own snapshot (`AD-4`) — see
    /// `ShareCardArtwork`'s own account of what is deliberately left off it.
    private func mintShareCardIfAvailable() async {
        guard shareCards.isAvailable, mintedShareURL == nil else { return }
        let artwork = ShareCardArtwork(
            questTitle: model.title,
            placeNames: model.run.orderedCheckpointResults.map(\.snapshotPlaceName),
            stampCount: model.run.awards.filter { $0.type == .stamp }.count,
            dayText: Self.dayText(for: model.run.completedAt ?? model.run.startedAt, language: language),
            // Nothing has opted in yet — there is no per-card opt-in control built, so the
            // conservative default is the one `ShareCardArtwork`'s own doc comment states:
            // consent to share once is not consent to share always, and the absence of a control
            // must not read as silent consent.
            reflections: [],
            language: language,
            palette: palette)
        guard let png = artwork.pngData() else { return }
        mintedShareURL = await shareCards.mint(ShareCardDraft(
            runID: model.run.id, png: png, template: "recap-v1"))
    }

    private static func dayText(for date: Date, language: ContentLanguage) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .id ? "id_ID" : "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - The cream page

    /// `791:6534` — the title at 35 solid, the walk's own name under it at 17 bold, 16 apart.
    private var masthead: some View {
        VStack(spacing: 16) {
            Text(headline)
                .font(.system(size: 35, design: .serif))
                .tracking(-1.05)
                .lineSpacing(35 * 1.0 - 35 * 1.19)
                .foregroundStyle(palette.inkDark.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // The walk's own title, in quotation marks as the frame sets it. This is the one line
            // on the page that names the quest, and it is the Run's snapshot of it — so it stays
            // right after a content correction and after the quest is withdrawn (`FR-RUN-06`).
            Text("“\(model.title)”")
                .font(.system(size: 17, weight: .bold))
                .tracking(-0.51)
                .lineSpacing(17 * 1.4 - 17 * 1.19)
                .foregroundStyle(palette.brownMid.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if model.wasAbandoned {
                // A walk that was put down says so. A summary that quietly printed it as finished
                // would be the journal claiming something the walker did not do.
                Text(UIStrings.string(.runAbandonedNote, language))
                    .font(.system(size: 15))
                    .foregroundStyle(palette.mapMarker.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 38)
    }

    /// `791:6491` — the roundel, 200 × 200, 40 under the masthead.
    private var emblem: some View {
        HisploraTripArtworkImage(HisploraTripArtwork.emblem)
            .frame(width: 200, height: 200)
            .padding(.top, 40)
            .accessibilityHidden(true)
    }

    /// `791:6492` — "Your Journey" at 17, then the counters 12 under it and 8 apart.
    private var journeyCounts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(UIStrings.string(.tripJourneyHeading, language))
                .font(.system(size: 17))
                .tracking(-0.51)
                .lineSpacing(17 * 1.4 - 17 * 1.19)
                .foregroundStyle(palette.buttonFill.color)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 8) {
                TripStatTile(
                    systemImage: "location.fill",
                    label: UIStrings.string(.tripPlacesExplored, language),
                    value: "\(model.placesExploredCount)",
                    unit: nil
                ) {
                    frankedRow
                }
                HStack(alignment: .top, spacing: 8) {
                    TripStatTile(
                        systemImage: "photo.on.rectangle.angled",
                        label: UIStrings.string(.tripMemories, language),
                        value: "\(model.memoriesCount)",
                        unit: UIStrings.string(.tripMemoriesUnit, language))
                    TripStatTile(
                        systemImage: "clock.fill",
                        label: UIStrings.string(.tripDuration, language),
                        value: "\(model.durationMinutes)",
                        unit: UIStrings.string(.tripDurationUnit, language))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 40)
    }

    /// `791:6503` — five stamps at 2.615 apart, tilted the frame's own 4.26° and −3.75°.
    ///
    /// Decoration: the number left of it is the fact, and the same stamps are printed at readable
    /// size two bands down — so the row is hidden rather than announced as five unnamed pictures.
    /// The frame sets them at 29.3 points; they ship at 24, because "Places Explored" needs about
    /// 115 of the tile's 258-point inner column and the frame's row wants 155, and the words are the
    /// tile. Deviation recorded in `docs/hisplora-tokens.md`.
    @ViewBuilder private var frankedRow: some View {
        if !letter.stamps.isEmpty {
            HStack(spacing: 2.615) {
                ForEach(Array(letter.stamps.prefix(5).enumerated()), id: \.element.id) { index, stamp in
                    HisploraStampCard(
                        title: stamp.placeName,
                        subtitle: "",
                        showsFranking: false,
                        artworkName: stamp.artworkName)
                        .frame(width: 24)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? 4.26 : -3.75))
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - The brown band (`791:6416`)

    private var piecesBand: some View {
        VStack(spacing: 0) {
            Text(UIStrings.string(.tripPiecesHeading, language))
                .font(.system(size: 25, weight: .medium, design: .serif).italic())
                .tracking(-0.75)
                .lineSpacing(25 * 1.0 - 25 * 1.19)
                .foregroundStyle(palette.inkCream.color)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 50)

            VStack(spacing: 24) {
                ForEach(Array(model.stops.enumerated()), id: \.element.id) { index, stop in
                    TripPieceCard(
                        placeName: stop.placeName,
                        blurb: stop.claims.first?.block.text,
                        writtenAnswers: stop.writtenAnswers,
                        artworkName: artworkName(forStopAt: index, named: stop.placeName),
                        tilt: .degrees(index.isMultiple(of: 2) ? 6 : -6),
                        reflectionHeading: UIStrings.string(.summaryReflectionHeading, language))
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 34)
            .padding(.bottom, 69)
        }
        .frame(maxWidth: .infinity)
        .kultaraSpeckledGround(palette.brownBand)
        .padding(.top, 40)
    }

    /// The stamp a stop earned. Matched by place name first and by position second: the awards and
    /// the checkpoint results are both in the order they happened, but a walk that reached a place
    /// without being awarded its stamp would slide every later card onto the wrong picture.
    private func artworkName(forStopAt index: Int, named placeName: String) -> String? {
        if let byName = letter.stamps.first(where: { $0.placeName == placeName }) {
            return byName.artworkName
        }
        return letter.stamps.indices.contains(index) ? letter.stamps[index].artworkName : nil
    }

    // MARK: - The tan band (`791:6451`)

    private var collectionBand: some View {
        VStack(spacing: 0) {
            Text(UIStrings.string(.tripCollectionHeading, language))
                .font(.system(size: 25, weight: .medium, design: .serif).italic())
                .tracking(-0.75)
                .lineSpacing(25 * 1.0 - 25 * 1.19)
                .foregroundStyle(palette.inkDark.color)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 62)

            featuredLegend
            photoGrid

            scatter
                .padding(.top, 42)
                // The colophon used to close the band and gave it its bottom edge; without it the
                // scatter would run flush into the overscroll bleed.
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity)
        .kultaraSpeckledGround(palette.paperTan)
    }

    /// `791:6480` — the collection's first medallion, and the only one the app supplies.
    ///
    /// **It is the quest's legend, not a stamp.** The frame sets a painted portrait here under "The
    /// Legends" and names the sitter; that is a fact about the *quest*, so it comes from
    /// `QuestHistoryText` keyed by quest id, alongside the History page's prose and under the same
    /// recorded sourcing decision. A quest with no entry shows no legend at all rather than
    /// borrowing another walk's portrait — the mount would be a claim with nothing behind it.
    @ViewBuilder private var featuredLegend: some View {
        if let legend = QuestHistoryText.byQuestID[letter.questID]?.legend {
            TripCollectionMedallion(
                frame: .tall,
                eyebrow: UIStrings.string(.tripCollectionLegend, language),
                caption: legend.value(for: language)
            ) {
                HisploraTripArtworkImage(HisploraTripArtwork.legend, contentMode: .fill)
            }
            .frame(width: 175)
            .padding(.top, 36)
        }
    }

    /// The rest of the collection: one medallion per photograph the walker actually took, captioned
    /// with the place they took it at.
    ///
    /// **Exactly as many as there are.** The frame draws four, all of the same painted portrait,
    /// captioned "The Iron Statue" and "Ancient Script" — objects that exist nowhere in the content
    /// tree. Three photographs give three medallions and a walk with none gives the legend on its
    /// own, which is the honest empty state: a collection is what the walker collected.
    ///
    /// The frames alternate a round mount and an oval one down the grid, and so does this.
    @ViewBuilder private var photoGrid: some View {
        let photos = model.capturedPhotos
        if !photos.isEmpty {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 29),
                          GridItem(.flexible(), spacing: 29)],
                spacing: 48
            ) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    TripCollectionMedallion(
                        frame: index.isMultiple(of: 2) ? .square : .tall,
                        eyebrow: nil,
                        caption: photo.placeName,
                        captionGap: index.isMultiple(of: 2) ? 11 : 1
                    ) {
                        TripPhotoImage(photoStore: photoStore, relativePath: photo.relativePath)
                    }
                }
            }
            .padding(.horizontal, 42)
            .padding(.top, 48)
        }
    }

    /// What the share sheet is handed (`791:6490`). Plain text, because the recap *card* is not
    /// built — see `TripPageBar`. Every line of it is the walk's own snapshot.
    private var shareText: String {
        [headline,
         "“\(model.title)”",
         "\(UIStrings.string(.tripPlacesExplored, language)): \(model.placesExploredCount)",
         "\(UIStrings.string(.tripMemories, language)): \(model.memoriesCount) "
            + UIStrings.string(.tripMemoriesUnit, language),
         "\(UIStrings.string(.tripDuration, language)): \(model.durationMinutes) "
            + UIStrings.string(.tripDurationUnit, language)]
            .joined(separator: "\n")
    }

    /// `791:6454`–`791:6459`: six cut-outs pinned across the foot of the band, in the frame's own
    /// coordinates — including `sheet-2-26`, the building signed "MUSEUM BALI".
    private var scatter: some View {
        HisploraStickerCollage(
            frameSize: CGSize(width: 402, height: 352),
            placements: [
                .init("sticker-3-16", center: CGPoint(x: 369.3, y: 51.5),
                      size: CGSize(width: 68.4, height: 94.4), rotation: .degrees(7.99)),
                .init("sticker-2-30", center: CGPoint(x: 97, y: 97.8),
                      size: CGSize(width: 144, height: 113)),
                .init("sticker-2-28", center: CGPoint(x: 249, y: 99.3),
                      size: CGSize(width: 134, height: 116)),
                .init("sticker-2-11", center: CGPoint(x: 343, y: 233.3),
                      size: CGSize(width: 140, height: 238)),
                .init("sticker-1-08", center: CGPoint(x: 71, y: 253.8),
                      size: CGSize(width: 92, height: 141)),
                .init("sticker-2-26", center: CGPoint(x: 200.5, y: 242.8),
                      size: CGSize(width: 127, height: 107))
            ])
    }

}
