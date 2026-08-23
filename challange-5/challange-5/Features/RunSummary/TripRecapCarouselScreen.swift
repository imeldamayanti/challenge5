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
    /// Opens the share-story picker (`921:2543`'s header). The card images are rendered *there*,
    /// when this turns true — never here, where a swipe through the carousel would pay for two
    /// 1080 px renders nobody asked for yet.
    @State private var showsShareStory = false

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
        .sheet(isPresented: $showsShareStory) { shareStorySheet }
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
            .padding(.top, 8)
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
        VStack(spacing: 16) {
            Spacer(minLength: 100)

            HisploraTripArtworkImage(HisploraTripArtwork.emblem)
                .frame(width: 239, height: 239)
                .accessibilityHidden(true)

            Spacer(minLength: 24)

            pageHeadline(UIStrings.string(.tripRecapHeadlineTitle, language))

            Text(UIStrings.string(.tripRecapHeadlineBody, language))
                .font(.system(size: 17))
                .tracking(-0.34)
                .foregroundStyle(SRGBColor(hex: "#DED7C2").color.opacity(0.62))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 50)
        .padding(.top, 60)
    }

    // MARK: - Completion 2 (`205:151`) — the stat grid

    private var glancePage: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 100)

            pageHeadline(UIStrings.string(.tripRecapGlanceTitle, language))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                HisploraCompletionStatTile(
                    systemImage: "location.fill",
                    label: UIStrings.string(.tripRecapStatExploredPlaces, language),
                    value: "\(summary.placesExploredCount)",
                    fill: SRGBColor(hex: "#93C6DE"), border: SRGBColor(hex: "#A9D6EA"),
                    ink: SRGBColor(hex: "#69311E"))
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
        .padding(.top, 60)
    }

    // MARK: - Completion 3 (`205:205`) — the stamp collage

    private var stampsPage: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 100)

            pageHeadline(exploredTitle)
                .padding(.horizontal, 43)

            Spacer(minLength: 40)

            stampCollage
                .accessibilityElement(children: .contain)

            Spacer()
        }
        .padding(.top, 60)
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
        VStack(spacing: 24) {
            Spacer(minLength: 100)

            pageHeadline(UIStrings.string(.tripRecapMemoriesTitle, language))
                .padding(.horizontal, 43)

            ScrollView {
                VStack(spacing: 32) {
                    featuredLegend
                    photoGrid
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 24)
            }
        }
        .padding(.top, 60)
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
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 32) {
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
        VStack(spacing: 20) {
            Spacer(minLength: 90)

            pageHeadline(UIStrings.string(.tripRecapMemoriesTitle, language))
                .padding(.horizontal, 43)

            postcard
                .accessibilityElement(children: .contain)

            Spacer()

            actionButtons
        }
        .padding(.top, 60)
        .padding(.bottom, 24)
    }

    /// The tilted kraft envelope behind the card and the walker's photograph riding half out of
    /// it — Figma's own `close_letter` (three layered paper exports plus a wax seal) and `Stamp`
    /// (`921:2917`) groups, reproduced with the Journal's real `HisploraEnvelope` and
    /// `HisploraStampShape` rather than a fourth flat export of the same paper: sealed, closed,
    /// nothing rising out of it — the postcard is what is stuck to the front, not what the
    /// envelope is carrying inside.
    private var postcard: some View {
        ZStack {
            HisploraEnvelope(stage: .sealed) { EmptyView() }
                .frame(width: 320)
                .rotationEffect(.degrees(8))
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                postcardCard
                postcardPhotoStamp
                    .padding(.top, -50)
            }
        }
    }

    private var postcardCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(UIStrings.string(.tripRecapPostcardTitle, language))
                        .font(.system(size: 16, design: .serif))
                        .tracking(-0.48)
                        .foregroundStyle(.black)
                    Text(String(
                        format: UIStrings.string(.tripRecapPostcardFrom, language),
                        region.isEmpty ? summary.title : region))
                        .font(.custom("Snell Roundhand", size: 21, relativeTo: .body))
                        .foregroundStyle(SRGBColor(hex: "#A33921").color)
                }
                Spacer(minLength: 0)
                postcardStamp
            }

            if let journalText = summary.run.journalEntry?.text, !journalText.isEmpty {
                Text(journalText)
                    .font(.system(size: 13))
                    .foregroundStyle(SRGBColor(hex: "#221D1D").color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
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
        }
        .padding(20)
        .frame(width: 300)
        .background(SRGBColor(hex: "#F5F1E5").color)
    }

    private func postcardFact(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(SRGBColor(hex: "#58453E").color)
            Text(value)
                .font(.system(size: 13))
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
            if let path {
                TripPhotoImage(photoStore: photoStore, relativePath: path)
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }
        }
        .frame(width: 279, height: 205)
        .clipShape(HisploraStampShape(teethAcross: 20), style: HisploraStampShape.fillStyle)
        .rotationEffect(.degrees(5.41))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    /// The small franked stamp and its postmark in the postcard's corner — one of the walk's own
    /// stamps standing in for the frame's `pemecutan-stamp2`, so the postcard always names a real
    /// place rather than one hardcoded regardless of which quest was walked.
    @ViewBuilder private var postcardStamp: some View {
        if let firstStamp = stamps.first {
            ZStack(alignment: .topTrailing) {
                HisploraStampCard(
                    title: firstStamp.placeName, subtitle: firstStamp.region,
                    showsFranking: false, artworkName: firstStamp.artworkName)
                    .frame(width: 44)
                    .rotationEffect(.degrees(3))
                HisploraTripArtworkImage(HisploraTripArtwork.emblem)
                    .frame(width: 28, height: 28)
                    .offset(x: 10, y: -10)
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - The postcard's two actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button { showsShareStory = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up.fill")
                    Text(UIStrings.string(.tripRecapShareAction, language))
                        .fontWeight(.semibold)
                }
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
                .foregroundStyle(SRGBColor(hex: "#151311").color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color.white, in: Capsule())
        }
        .padding(.horizontal, 20)
    }

    // MARK: - The share-story picker (`921:2543`)

    /// Built here, when the sheet opens — which is what makes the photograph's read from the store
    /// lazy too. The ground the input carries is the caller's own decision: the walker's selfie if
    /// there is one, the place photo otherwise, brown when there is neither — the same
    /// selfie-then-place-photo rule `postcardPhotoStamp` follows.
    private var shareStorySheet: some View {
        ShareStoryPickerSheet(
            language: language,
            input: ShareStoryCard.Input(
                regionTitle: region.isEmpty ? summary.title : region,
                journalText: summary.run.journalEntry?.text,
                placesCount: summary.placesExploredCount,
                durationMinutes: summary.durationMinutes,
                stamp: stamps.first.map {
                    ShareStoryCard.Input.Stamp(
                        placeName: $0.placeName, region: $0.region, artworkName: $0.artworkName)
                },
                postmarkArtworkName: HisploraTripArtwork.emblem,
                language: language,
                ground: photoPath
                    .flatMap { photoStore.image(atRelativePath: $0) }
                    .map(ShareStoryCard.Input.Ground.photo) ?? .brown),
            fallbackText: shareText)
    }

    private var photoPath: String? {
        summary.run.journalEntry?.selfiePhotoRelativePath
            ?? summary.run.journalEntry?.placePhotoRelativePath
    }

    /// What Share hands over if both card renders somehow come back nil — plain text, the move
    /// this button used before the card existed — so the control can never dead-end. The normal
    /// path never touches it.
    private var shareText: String {
        [UIStrings.string(.tripRecapMemoriesTitle, language),
         "\u{201C}\(summary.title)\u{201D}",
         "\(UIStrings.string(.tripRecapStatExploredPlaces, language)): \(summary.placesExploredCount)",
         "\(UIStrings.string(.tripDuration, language)): \(summary.durationMinutes) "
            + UIStrings.string(.tripRecapDurationUnit, language)]
            .joined(separator: "\n")
    }
}
