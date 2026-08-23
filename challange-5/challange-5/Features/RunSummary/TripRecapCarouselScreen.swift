import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// The "Strava-style" trip-completion carousel `JourneySavedScreen`'s "See Journey Recap" opens
/// into, before the walk's real Trip Summary (Figma `205:121`/`151`/`205` from the "Ngalcer" file,
/// plus `921:2823`/`2867` from the "Hisplora" file — "Completion 1" through "5").
///
/// **All five segments the progress bar draws now have a page.** `921:2867`'s "Close Summary"
/// hands off into the existing papers picker (`921:2346`, "Modal Cerita" — this app's own
/// `JournalPapersModal`), not a sixth page here; `KultaraRootView.finishCompletionRecap` is what
/// opens it.
///
struct TripRecapCarouselScreen: View {
    let language: ContentLanguage
    let summary: RunSummaryViewModel
    let completedQuestsCount: Int
    let region: String
    let stamps: [TripRecapStampPresentation]
    let photoStore: any PhotoStore
    let onFinish: () -> Void

    @State private var page = 0

    private static let totalPages = 5

    var body: some View {
        HisploraCompletionStage {
            ZStack(alignment: .top) {
                TabView(selection: $page) {
                    headlinePage.tag(0)
                    glancePage.tag(1)
                    stampsPage.tag(2)
                    memoriesPage.tag(3)
                    postcardPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                topBar
            }
        }
        .navigationBarBackButtonHidden()
        .statusBarHidden(false)
    }

    // MARK: - Chrome shared by every page

    private var topBar: some View {
        HisploraCompletionProgress(
            completed: page + 1,
            total: Self.totalPages,
            accessibilityLabel: String(
                format: UIStrings.string(.onboardingProgress, language),
                page + 1, Self.totalPages))
            .padding(.horizontal, 20)
            // The frames draw the segments 47 points below the safe-area top (y 106 on their
            // 874-point canvas, under a 59-point status bar) — not hugging it.
            .padding(.top, 47)
    }

    private var pageHeadlineColor: Color { SRGBColor(hex: "#FDF2DE").color }

    private func pageHeadline(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 31, weight: .semibold, design: .serif))
            .tracking(-0.93)
            .foregroundStyle(pageHeadlineColor)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Completion 1 (`205:121`) — the headline

    private var headlinePage: some View {
        // The frame's verticals: emblem centred at y≈299 of 874, the text block starting at 447 —
        // 48 below the artwork — and everything after left to the bottom spacer.
        VStack(spacing: 16) {
            Spacer(minLength: 140)

            // `921:2689`'s `Ellipse 531` — a blurred warm disc standing behind the artwork, the
            // halo the frame draws under its emblem (a 485-point circle behind a 200-point one).
            // Subtle on this gradient by design. The frame zooms its emblem to cover its box
            // (`921:2707`'s image is scaled past it); `.fit` would render the shipped asset's
            // 530×471 at 200×178 and the medallion reads a size too small.
            HisploraTripArtworkImage(HisploraTripArtwork.emblem, contentMode: .fill)
                .frame(width: 200, height: 200)
                .clipped()
                .background {
                    Circle()
                        .fill(SRGBColor(hex: "#6E3B26").color)
                        .blur(radius: 61.5)
                        .padding(-142.5)
                }
                .accessibilityHidden(true)

            Spacer(minLength: 32)

            // The frame breaks the headline after "History"; forced here rather than in the
            // string table, the same way the memories page breaks after "From".
            pageHeadline(
                UIStrings.string(.tripRecapHeadlineTitle, language)
                    .replacingOccurrences(of: " History ", with: " History\n"))

            Text(UIStrings.string(.tripRecapHeadlineBody, language))
                .font(.system(size: 17))
                .tracking(-0.34)
                .foregroundStyle(SRGBColor(hex: "#DED7C2").color.opacity(0.62))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 50)
    }

    // MARK: - Completion 2 (`205:151`) — the stat grid

    private var glancePage: some View {
        // Headline at the template's y≈151; the frame's grid starts at y 278, 52 below it.
        VStack(spacing: 52) {
            pageHeadline(UIStrings.string(.tripRecapGlanceTitle, language))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                HisploraCompletionStatTile(
                    systemImage: "location.fill",
                    label: UIStrings.string(.tripRecapStatExploredPlaces, language),
                    value: "\(summary.placesExploredCount)",
                    fill: SRGBColor(hex: "#93C6DE"), border: SRGBColor(hex: "#A9D6EA"),
                    ink: SRGBColor(hex: "#69311E"), textInk: SRGBColor(hex: "#61301A"))
                HisploraCompletionStatTile(
                    systemImage: "person.crop.circle.badge.clock.fill",
                    label: UIStrings.string(.tripRecapStatTripDuration, language),
                    value: "\(summary.durationMinutes)",
                    unit: UIStrings.string(.tripRecapDurationUnit, language),
                    fill: SRGBColor(hex: "#FEC964"), border: SRGBColor(hex: "#FDD790"),
                    ink: SRGBColor(hex: "#69311E"))
                HisploraCompletionStatTile(
                    systemImage: "apple.books.pages.fill",
                    label: UIStrings.string(.tripRecapStatCompletedQuests, language),
                    value: "\(completedQuestsCount)",
                    fill: SRGBColor(hex: "#B4965B"), border: SRGBColor(hex: "#C7AF7B"),
                    ink: SRGBColor(hex: "#FFFBDF"))
                HisploraCompletionStatTile(
                    systemImage: "photo.on.rectangle.angled.fill",
                    label: UIStrings.string(.tripRecapStatMemories, language),
                    value: "\(summary.memoriesCount)",
                    fill: SRGBColor(hex: "#FFF8CA"), border: SRGBColor(hex: "#F3E794"),
                    ink: SRGBColor(hex: "#806836"))
            }
            .padding(.horizontal, 53)

            Spacer()
        }
        .padding(.top, 89)
    }

    // MARK: - Completion 3 (`205:205`, re-drawn `921:2773`) — the stamp collage

    private var stampsPage: some View {
        VStack(spacing: 0) {
            pageHeadline(exploredTitle)
                .padding(.horizontal, 43)

            // The frame's collage centres at y≈488 of 874 — 98 points below the headline block.
            stampCollage
                .padding(.top, 98)
                .accessibilityElement(children: .contain)

            Spacer()
        }
        .padding(.top, 89)
    }

    private var exploredTitle: String {
        region.isEmpty
            ? String(format: UIStrings.string(.tripRecapExploredTitleNoRegion, language),
                     stamps.count)
            : String(format: UIStrings.string(.tripRecapExploredTitle, language),
                     stamps.count, region)
    }

    /// The five stamps' centres and tilts, read off `205:205` and re-expressed as an offset from
    /// the cluster's own centre — so the whole collage recentres itself under whatever heading
    /// wrapped above it, rather than repeating the frame's absolute, screen-width-specific
    /// coordinates.
    private static let placements: [(dx: CGFloat, dy: CGFloat, rotation: Double)] = [
        (dx: -89.1, dy: -128.9, rotation: -6.31),
        (dx: 105.7, dy: -151.1, rotation: 5.24),
        (dx: -101.1, dy: 62.1, rotation: 0),
        (dx: 57.9, dy: 17.1, rotation: 0),
        (dx: 30.5, dy: 200.8, rotation: -5.04),
    ]

    private var stampCollage: some View {
        ZStack {
            ForEach(Array(stamps.prefix(5).enumerated()), id: \.element.id) { index, stamp in
                let placement = Self.placements[index]
                HisploraStampCard(
                    title: stamp.placeName,
                    subtitle: stamp.region,
                    teethAcross: 9, teethDown: 13, biteSpan: 0.67,
                    artworkName: stamp.artworkName)
                    .frame(width: 114)
                    .rotationEffect(.degrees(placement.rotation))
                    .offset(x: placement.dx, y: placement.dy)
            }
        }
        .frame(height: 330)
    }

    // MARK: - Completion 4 (`921:2823`) — the memory grid

    /// **Exactly as many medallions as photographs, never the frame's six identical portraits.**
    /// The frame fills all six windows with the same placeholder rendering; this reuses the Trip
    /// Summary's own rule instead (`TripSummaryScreen.photoGrid`) — one gilt frame per photograph
    /// the walker actually took, captioned with the place, and the quest's own legend standing in
    /// alone when there are none, rather than an empty screen.
    private var memoriesPage: some View {
        // The frame pins its headline at y≈151 from the screen top (safe area + 89) and gives
        // the rest to the grid — the old leading `Spacer` negotiated with the greedy
        // ScrollView and let the headline float to mid-screen.
        VStack(spacing: 24) {
            // The frame breaks the headline after "From"; the string is shared with the
            // postcard page, so the break is forced here rather than in the string table.
            pageHeadline(
                UIStrings.string(.tripRecapMemoriesTitle, language)
                    .replacingOccurrences(of: " From ", with: " From\n"))
                .padding(.horizontal, 43)

            ScrollView {
                VStack(spacing: 32) {
                    featuredLegend
                    photoGrid
                }
                .padding(.horizontal, 57.5)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 89)
    }

    /// Standing alone, centred, exactly as `TripSummaryScreen.featuredLegend` draws it — never a
    /// cell in the two-column grid below, where it would land pinned to the left column instead of
    /// the middle of the screen.
    @ViewBuilder private var featuredLegend: some View {
        if summary.capturedPhotos.isEmpty,
           let legend = QuestHistoryText.byQuestID[summary.run.questID]?.legend {
            TripCollectionMedallion(frame: .tall, eyebrow: nil, caption: legend.value(for: language)) {
                HisploraTripArtworkImage(HisploraTripArtwork.legend, contentMode: .fill)
            }
            .frame(width: 175)
        }
    }

    @ViewBuilder private var photoGrid: some View {
        let photos = summary.capturedPhotos
        if !photos.isEmpty {
            // The frame's own cell metrics: 134.048-wide medallions on an 18.952 column gap and
            // a 10.5 row gap, the pair of columns centred on the screen (57/58 side margins).
            // Fixed columns rather than flexible ones, or the medallion floats in a wider cell
            // and the drawn gap doubles.
            LazyVGrid(
                columns: [
                    GridItem(.fixed(134.048), spacing: 18.952),
                    GridItem(.fixed(134.048)),
                ],
                spacing: 10.5
            ) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { _, photo in
                    TripCollectionMedallion(frame: .tall, eyebrow: nil, caption: photo.placeName) {
                        TripPhotoImage(photoStore: photoStore, relativePath: photo.relativePath)
                    }
                }
            }
        }
    }

    // MARK: - Completion 5 (`921:2867`) — the postcard

    private var postcardPage: some View {
        VStack(spacing: 27) {
            // Same headline placement as the memories page — y≈151, broken after "From".
            pageHeadline(
                UIStrings.string(.tripRecapMemoriesTitle, language)
                    .replacingOccurrences(of: " From ", with: " From\n"))
                .padding(.horizontal, 43)

            postcard
                .accessibilityElement(children: .contain)

            Spacer()

            actionButtons
        }
        .padding(.top, 89)
        .padding(.bottom, 28)
    }

    /// The tilted kraft envelope behind the card and the walker's photograph riding half out of
    /// it — Figma's own `close_letter` (three layered paper exports plus a wax seal) and `Stamp`
    /// (`921:2917`) groups, reproduced with the Journal's real `HisploraEnvelope` and
    /// `HisploraStampShape` rather than a fourth flat export of the same paper: sealed, closed,
    /// nothing rising out of it — the postcard is what is stuck to the front, not what the
    /// envelope is carrying inside.
    private var postcard: some View {
        ZStack {
            // The frame's kraft envelope is 337 points across, tilted the other way — its top
            // edge rises to the right, which is a negative angle here.
            HisploraEnvelope(stage: .sealed) { EmptyView() }
                .frame(width: 337)
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                postcardCard
                postcardPhotoStamp
                    .padding(.top, -51)
            }
        }
    }

    /// `921:2892`'s card at its own 292.7 × 192.8: the title block and the memo/duration facts
    /// down the left, the franked stamp up the right corner, and the walker's words written over
    /// ruled lines in the right column — the frame's address side, carrying the journal text
    /// instead of an address.
    private var postcardCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(UIStrings.string(.tripRecapPostcardTitle, language))
                        .font(.system(size: 16, design: .serif))
                        .tracking(-0.48)
                        .foregroundStyle(.black)
                    Text(String(
                        format: UIStrings.string(.tripRecapPostcardFrom, language),
                        region.isEmpty ? summary.title : region))
                        .font(.custom("Snell Roundhand", size: 20.4, relativeTo: .body))
                        .foregroundStyle(SRGBColor(hex: "#A33921").color)
                }
                Spacer(minLength: 0)
                postcardStamp
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    postcardFact(
                        label: UIStrings.string(.tripRecapMemoLabel, language),
                        value: String(
                            format: UIStrings.string(.tripRecapPlacesUnit, language),
                            summary.placesExploredCount))
                    postcardFact(
                        label: UIStrings.string(.tripDuration, language),
                        value: String(
                            format: UIStrings.string(.tripRecapMinutesUnit, language),
                            summary.durationMinutes))
                }
                Spacer(minLength: 0)
                journalOverLines
                    .frame(width: 120)
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(width: 292.74, height: 192.78, alignment: .top)
        .background(SRGBColor(hex: "#F5F1E5").color)
    }

    /// The right column: the journal text set over the frame's seven ruled lines (12.7 points
    /// apart). The lines stand whether or not there is anything written — an unwritten postcard
    /// still shows its address rules.
    private var journalOverLines: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 12.2) {
                ForEach(0..<7, id: \.self) { _ in
                    Rectangle()
                        .fill(SRGBColor(hex: "#58453E").color.opacity(0.35))
                        .frame(height: 0.5)
                }
            }
            Text(summary.run.journalEntry?.text ?? "")
                .font(.system(size: 10))
                .tracking(-0.17)
                .foregroundStyle(SRGBColor(hex: "#221D1D").color)
                .frame(width: 120, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func postcardFact(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(label) :")
                .font(.system(size: 10, design: .serif))
                .tracking(-0.57)
                .foregroundStyle(SRGBColor(hex: "#58453E").color)
            Text(value)
                .font(.custom("Snell Roundhand", size: 11, relativeTo: .body))
                .foregroundStyle(SRGBColor(hex: "#A33921").color)
        }
    }

    /// The walker's own photograph — the selfie if there is one, the place photo otherwise — set
    /// into the same perforated die every stamp in this carousel uses. Standing apart from the
    /// card and larger than it, riding half over its lower edge exactly as `921:2917` ("Stamp")
    /// draws it, rather than folded into the card's own content as a thumbnail. Falls back to a
    /// plain black pane instead of vanishing when the walk carries no photograph — there is no
    /// existing "camera-less" fallback for a photo stamp anywhere in the design system, and an
    /// empty gap where the frame always shows a photograph would read as a broken layout.
    private var postcardPhotoStamp: some View {
        let path = summary.run.journalEntry?.selfiePhotoRelativePath
            ?? summary.run.journalEntry?.placePhotoRelativePath
        return ZStack {
            Color.white
            if let path {
                TripPhotoImage(photoStore: photoStore, relativePath: path)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 250.9, height: 181.5)
                    .clipped()
            } else {
                Color.black
                    .frame(width: 250.9, height: 181.5)
            }
        }
        .frame(width: 279.185, height: 205.7)
        // The frame's big photo die is the same perforation as the Journey Saved stamps —
        // 9 bites across, 13 down, spaced — scaled up 1.96×, with the photo inset ~6% onto the
        // white paper rather than bleeding to the teeth.
        .clipShape(
            HisploraStampShape(teethAcross: 9, teethDown: 13, biteSpan: 0.71),
            style: HisploraStampShape.fillStyle)
        .rotationEffect(.degrees(5.41))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    /// The small franked stamp and its postmark in the postcard's corner — one of the walk's own
    /// stamps standing in for the frame's `pemecutan-stamp2`, so the postcard always names a real
    /// place rather than one hardcoded regardless of which quest was walked.
    @ViewBuilder private var postcardStamp: some View {
        if let firstStamp = stamps.first {
            // The frame's corner stamp (36.4 × 49.5 at 2.92°) with the bronze emblem riding its
            // *left* edge — 34 points, centred 29 left of and 5 above the stamp's centre.
            ZStack {
                HisploraStampCard(
                    title: firstStamp.placeName, subtitle: firstStamp.region,
                    showsFranking: false, artworkName: firstStamp.artworkName)
                    .frame(width: 37)
                    .rotationEffect(.degrees(2.92))
                HisploraTripArtworkImage(HisploraTripArtwork.emblem, contentMode: .fill)
                    .frame(width: 34, height: 34)
                    .clipShape(Circle())
                    .offset(x: -29, y: -5)
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - The postcard's two actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            ShareLink(item: shareText) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text(UIStrings.string(.tripRecapShareAction, language))
                        .fontWeight(.semibold)
                        .tracking(-0.34)
                }
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
            }
            .background(Color.black.opacity(0.5), in: Capsule())
            .overlay {
                Capsule().stroke(SRGBColor(hex: "#1A1A1A").color, lineWidth: 1)
            }

            Button(UIStrings.string(.tripRecapCloseAction, language)) { onFinish() }
                .font(.system(size: 17, weight: .medium))
                .tracking(-0.51)
                .foregroundStyle(SRGBColor(hex: "#151311").color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color.white, in: Capsule())
        }
        .padding(.horizontal, 20)
    }

    /// What the share sheet is handed — plain text, the same move `TripPageBar`'s own `ShareLink`
    /// makes: the recap *card* `FR-DONE-06` describes is still unbuilt.
    private var shareText: String {
        [UIStrings.string(.tripRecapMemoriesTitle, language),
         "\u{201C}\(summary.title)\u{201D}",
         "\(UIStrings.string(.tripRecapStatExploredPlaces, language)): \(summary.placesExploredCount)",
         "\(UIStrings.string(.tripDuration, language)): \(summary.durationMinutes) "
            + UIStrings.string(.tripRecapDurationUnit, language)]
            .joined(separator: "\n")
    }
}
