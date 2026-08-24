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
    /// The bar's clock glyph — replays the "You Made History Come Alive!" carousel
    /// (`TripRecapCarouselScreen`) for this same walk, rather than the fresh-finish flow that
    /// carousel normally opens from. `KultaraRootView` owns the presentation, since assembling the
    /// carousel's stat tile needs the run store this screen deliberately does not carry (`AD-4`).
    let onShowCompletion: () -> Void
    let onClose: () -> Void

    /// The minted link, once minting finishes. `nil` means no link exists **right now** — nothing
    /// has been shared yet, the walker stopped sharing, or a mint failed — and is what puts the
    /// share control back to `.readyToPrepare`.
    @State private var mintedShareURL: URL?
    /// True for the span of a mint. `TripPageBar` shows a spinner rather than a second tap target,
    /// so a walker cannot start a second upload while the first is still in flight.
    @State private var isPreparingShare = false
    /// A mint that failed once is not retried silently — the control falls back to plain text for
    /// the rest of this presentation rather than offering a spinner that always ends the same way.
    @State private var shareMintFailed = false
    /// The walker's own choice, off by default. `ShareCardArtwork`'s own doc comment states the
    /// rule this exists to hold: consent to share once is not consent to share always, and the
    /// absence of a control must not read as silent consent — so the default has to be "no", and
    /// the choice has to be visible before the walker ever taps share, not discovered afterwards.
    @State private var includeReflections = false
    @State private var isConfirmingStopSharing = false
    @State private var stopSharingConfirmationText: String?

    private var language: ContentLanguage { model.language }

    /// Every written answer this walk actually has — never a photo task, never a skip, never an
    /// empty string a walker left blank. Empty means there is nothing to offer including, and the
    /// toggle does not appear rather than appearing over nothing.
    private var candidateReflections: [String] {
        model.run.orderedCheckpointResults
            .flatMap(\.taskResults)
            .compactMap { task -> String? in
                guard task.type != .photo, !task.skipped,
                      let text = task.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty
                else { return nil }
                return text
            }
    }

    private var shareState: TripShareState {
        if let mintedShareURL { return .link(mintedShareURL) }
        if isPreparingShare { return .preparing }
        if shareCards.isAvailable, !shareMintFailed {
            return .readyToPrepare(action: { Task { await prepareShare() } })
        }
        return .textOnly(shareText)
    }

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
                    onShowRecap: onShowCompletion,
                    recapLabel: UIStrings.string(.journeySavedRecapAction, language),
                    shareState: shareState,
                    shareLabel: UIStrings.string(.tripShare, language),
                    preparingLabel: UIStrings.string(.tripSharePreparing, language),
                    onBack: onClose)

                shareOptionsBanner

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
        .kultaraDialog(
            isPresented: $isConfirmingStopSharing,
            title: UIStrings.string(.tripShareStopSharing, language),
            message: UIStrings.string(.tripShareStopSharingConfirm, language),
            actions: [
                KultaraDialogAction(
                    title: UIStrings.string(.tripShareStopSharing, language),
                    kind: .destructive) { Task { await stopSharing() } },
                KultaraDialogAction(
                    title: UIStrings.string(.tripShareCancel, language),
                    kind: .cancel) { isConfirmingStopSharing = false },
            ])
    }

    /// No frame draws this — the recap card did not exist when `791:6414` was drawn — so it is
    /// built to disappear rather than to fill space: `EmptyView` when there is nothing to offer or
    /// nothing to stop, which is most of the time this screen is open.
    @ViewBuilder private var shareOptionsBanner: some View {
        VStack(spacing: 8) {
            if !candidateReflections.isEmpty, mintedShareURL == nil {
                Toggle(isOn: $includeReflections) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(UIStrings.string(.tripShareReflectionsToggle, language))
                            .kultaraFont(.body)
                        Text(UIStrings.string(.tripShareReflectionsHint, language))
                            .kultaraFont(.metadata)
                            .foregroundStyle(palette.inkQuiet.color)
                    }
                }
                .tint(palette.brownMid.color)
            }
            if mintedShareURL != nil {
                Button(UIStrings.string(.tripShareStopSharing, language)) {
                    isConfirmingStopSharing = true
                }
                .buttonStyle(.hisploraTextLink)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let stopSharingConfirmationText {
                Text(stopSharingConfirmationText)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkQuiet.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, KultaraMetrics.lg)
        .padding(.top, candidateReflections.isEmpty && mintedShareURL == nil
            && stopSharingConfirmationText == nil ? 0 : KultaraMetrics.sm)
    }

    /// Renders the card off-screen, uploads it, and stores the link the bar switches to. Every
    /// value on it is the Run's own snapshot (`AD-4`) except `reflections`, which is the walker's
    /// own choice from `shareOptionsBanner` — see `ShareCardArtwork`'s own account of the rest of
    /// what is deliberately left off.
    ///
    /// **Called only from a tap**, never automatically: minting is an upload to a public URL, and
    /// nothing here decides on the walker's behalf that a walk is worth publishing.
    private func prepareShare() async {
        guard !isPreparingShare, mintedShareURL == nil else { return }
        stopSharingConfirmationText = nil
        isPreparingShare = true
        let artwork = ShareCardArtwork(
            questTitle: model.title,
            placeNames: model.run.orderedCheckpointResults.map(\.snapshotPlaceName),
            stampCount: model.run.awards.filter { $0.type == .stamp }.count,
            dayText: Self.dayText(for: model.run.completedAt ?? model.run.startedAt, language: language),
            reflections: includeReflections ? candidateReflections : [],
            language: language,
            palette: palette)
        guard let png = artwork.pngData() else {
            isPreparingShare = false
            shareMintFailed = true
            return
        }
        let url = await shareCards.mint(ShareCardDraft(
            runID: model.run.id, png: png, template: "recap-v1"))
        isPreparingShare = false
        if let url {
            mintedShareURL = url
        } else {
            // Falls back to plain text for the rest of this presentation rather than a dead
            // spinner the walker would have to give up on themselves.
            shareMintFailed = true
        }
    }

    /// `revoke` is a real network call and can fail; a failure leaves `mintedShareURL` exactly as
    /// it was, so the bar still shows a live link rather than one that quietly stopped being real.
    private func stopSharing() async {
        isConfirmingStopSharing = false
        guard await shareCards.revoke(runID: model.run.id) else { return }
        mintedShareURL = nil
        shareMintFailed = false
        stopSharingConfirmationText = UIStrings.string(.tripShareStoppedConfirmation, language)
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
