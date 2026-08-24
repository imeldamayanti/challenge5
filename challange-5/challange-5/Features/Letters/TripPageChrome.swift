import DesignSystem
import SwiftUI

/// The bar both Journal pages carry, and the counter tile and place card the Trip Summary builds
/// out of (`791:6414`, `791:6537`).
///
/// Everything here is set at the frame's own point sizes, weights, tracking and line heights rather
/// than through `KultaraTypography`'s roles. That is the same trade `TripFrameLayout.swift` records
/// for the History canvas and it is made for the same reason: the owner asked for the frames
/// reproduced exactly, and a role that scales with Dynamic Type is a role that does not reproduce a
/// 15-point label beside a 21-point figure at the ratio somebody drew.

// MARK: - The bar

/// Back on the left, the page's own name in the middle, share on the right — `791:6488`/`791:6489`
/// /`791:6490` and `791:6540`/`791:6541`/`791:6542`. SF Pro 19, tracked −0.38, near-black.
///
/// What the share control shows, decided by whoever owns the mint — `TripPageBar` itself is dumb
/// and only renders whichever case it is handed.
///
/// **Minting is lazy, on purpose.** Nothing uploads a walker's recap to a public URL until they
/// tap share — an eager mint on screen-open would publish a shareable link to a walk the walker
/// never asked to share. `readyToPrepare` is the tap that starts it; `preparing` covers the brief
/// upload; `link` is what a real `ShareLink` hands the system sheet once it lands. `textOnly` is
/// every case where a link either cannot or did not happen — no backend, a failed mint — and is
/// exactly the plain-text behaviour this control always had before the card existed.
enum TripShareState {
    /// No share control at all — the screens that use this bar without anything shareable on them.
    case hidden
    case readyToPrepare(action: () -> Void)
    case preparing
    case link(URL)
    case textOnly(String)
}

/// **The share control is a real `ShareLink`.** It hands the system sheet the recap card's public
/// link where one has been minted (`c2` phase 5, `FR-DONE-06`), and a plain-text recap of the page
/// everywhere else. Either way the control does a thing it actually does, and the text case works
/// offline (`AD-3`).
///
/// Both controls are a fixed 44 points (`NFR-A11Y-06`) and carry spoken labels, because a shape is
/// not a name (`NFR-A11Y-05`).
struct TripPageBar: View {
    @Environment(\.hisploraPalette) private var palette

    let title: String
    let backLabel: String
    /// Reopens the "You Made History Come Alive!" completion carousel for this walk — `nil` on
    /// every bar but the Trip Summary's, which is the only page with a walk-level recap to replay.
    var onShowRecap: (() -> Void)? = nil
    var recapLabel: String = ""
    var shareState: TripShareState = .hidden
    var shareLabel: String = ""
    var preparingLabel: String = ""
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 19))
                .tracking(-0.38)
                .foregroundStyle(palette.inkDark.color)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(palette.inkDark.color)
                        .frame(width: KultaraMetrics.minimumTapTarget,
                               height: KultaraMetrics.minimumTapTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(backLabel)
                Spacer(minLength: 0)
                if let onShowRecap {
                    Button(action: onShowRecap) {
                        Image(systemName: "clock")
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(palette.inkDark.color)
                            .frame(width: KultaraMetrics.minimumTapTarget,
                                   height: KultaraMetrics.minimumTapTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(recapLabel)
                }
                shareControl
            }
        }
        .frame(height: KultaraMetrics.minimumTapTarget)
        .padding(.horizontal, KultaraMetrics.lg)
    }

    @ViewBuilder private var shareControl: some View {
        switch shareState {
        case .hidden:
            EmptyView()
        case .textOnly(let text):
            ShareLink(item: text) { shareGlyph }
                .accessibilityLabel(shareLabel)
        case .link(let url):
            ShareLink(item: url) { shareGlyph }
                .accessibilityLabel(shareLabel)
        case .preparing:
            ProgressView()
                .frame(width: KultaraMetrics.minimumTapTarget,
                       height: KultaraMetrics.minimumTapTarget)
                .accessibilityLabel(preparingLabel)
        case .readyToPrepare(let action):
            Button(action: action) { shareGlyph }
                .buttonStyle(.plain)
                .accessibilityLabel(shareLabel)
        }
    }

    private var shareGlyph: some View {
        Image(systemName: "square.and.arrow.up.fill")
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(palette.inkDark.color)
            .frame(width: KultaraMetrics.minimumTapTarget, height: KultaraMetrics.minimumTapTarget)
    }
}

// MARK: - One counter

/// `791:6495`, `791:6516`, `791:6525` — a 19-point rounded tile on `paperTile`, 16 × 12 inside,
/// carrying a 40-point disc, a 15-point label and a 21-point bold figure.
///
/// The disc is `brownStone` with `inkCream` on it, a pair the palette already measures; the frame's
/// own ellipse is an ungraded SVG of the same brown. The glyph is decoration over a label that
/// already says the same thing, so it is hidden rather than announced as "location, filled" beside
/// the words "Places Explored".
struct TripStatTile<Trailing: View>: View {
    @Environment(\.hisploraPalette) private var palette

    let systemImage: String
    let label: String
    let value: String
    /// The word after the figure — "collected", "mins" — or `nil` where the figure stands alone.
    let unit: String?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(palette.brownStone.color)
                Image(systemName: systemImage)
                    .font(.system(size: 19))
                    .foregroundStyle(palette.inkCream.color)
            }
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 15))
                    .tracking(-0.45)
                    .lineSpacing(15 * 1.4 - 15 * 1.19)
                    .foregroundStyle(palette.brownStone.color)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 21, weight: .bold))
                        .tracking(-0.63)
                        .foregroundStyle(palette.buttonFill.color)
                    if let unit {
                        // `#808080` as the frame draws it measures 3.56:1 on this tile, under the
                        // 4.5 body text wants, so the theme yields and the deviation is recorded
                        // (`NFR-A11Y-03`, `docs/hisplora-tokens.md`).
                        Text(unit)
                            .font(.system(size: 15))
                            .tracking(-0.45)
                            .foregroundStyle(palette.inkMuted.color)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperTile.color, in: RoundedRectangle(cornerRadius: 19))
        // One spoken phrase for the tile, in the order a person would say it. Three separate
        // elements would read "Places Explored", "5" as two unrelated stops.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unit.map { "\(label): \(value) \($0)" } ?? "\(label): \(value)")
    }
}

extension TripStatTile where Trailing == EmptyView {
    init(systemImage: String, label: String, value: String, unit: String? = nil) {
        self.init(systemImage: systemImage, label: label, value: value, unit: unit) { EmptyView() }
    }
}

// MARK: - One place on the brown band

/// `791:6420` — a washed card 16 × 20 inside, hairlined in warm grey at 46%: a place's name in
/// gilt New York 19, a line of its own lore in italic SF 15 under it, and the stamp it earned
/// tilted off the right edge.
///
/// **The blurb is the place's first lore snapshot, not a hook written for this screen.** The frames
/// invent a one-sentence summary per place; nothing in `ContentKit` authors one, and adding a field
/// for it would be a schema change, a validator rule, a `contentBundleVersion` bump and five newly
/// sourced passages — a content decision with an owner. What the walk actually holds is the lore it
/// unlocked, so the card prints the opening of that, clipped to three lines.
struct TripPieceCard: View {
    @Environment(\.hisploraPalette) private var palette

    let placeName: String
    let blurb: String?
    /// What the walker wrote at this place, in the order they were asked.
    ///
    /// **It is on this card because this page is the walk.** `JournalPaperPresentation.Kind` splits
    /// the two papers as *where the reader went and what they wrote down* against *the lore they
    /// unlocked*, so the answers belong beside the place rather than beside its history. The frames
    /// draw no slot for them — they draw a count of "memories" and stop — and a redesign that
    /// silently dropped the one thing on the page nobody authored would lose the walker's own hand.
    let writtenAnswers: [(prompt: String, text: String)]
    let artworkName: String?
    /// Alternating ±6°, as the frame sets them.
    let tilt: Angle
    /// "What you wrote", already localized.
    let reflectionHeading: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(placeName)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .tracking(-0.57)
                    .lineSpacing(19 * 1.0 - 19 * 1.19)
                    .foregroundStyle(palette.inkGilt.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let blurb {
                    Text(blurb)
                        .font(.system(size: 15).italic())
                        .tracking(-0.3)
                        .lineSpacing(15 * 1.4 - 15 * 1.19)
                        .foregroundStyle(palette.inkCard.color)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !writtenAnswers.isEmpty { answers }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HisploraStampCard(
                title: placeName,
                subtitle: "",
                showsFranking: false,
                artworkName: artworkName)
                .frame(width: 67.556)
                .rotationEffect(tilt)
                .frame(width: 73.875, height: 70.711)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .overlay {
            Rectangle().stroke(palette.buttonRing.color.opacity(0.46),
                               lineWidth: KultaraMetrics.hairline)
        }
    }

    /// The walker's own hand, set apart from the lore above it because it is the one thing here
    /// nobody authored. Cream on the brown rather than the card ink: a person's own words are not
    /// apparatus.
    private var answers: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(reflectionHeading.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(palette.inkCard.color)
            ForEach(Array(writtenAnswers.enumerated()), id: \.offset) { _, answer in
                VStack(alignment: .leading, spacing: 2) {
                    Text(answer.prompt)
                        .font(.system(size: 13))
                        .tracking(-0.3)
                        .foregroundStyle(palette.inkCard.color)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(answer.text)
                        .font(.system(size: 15))
                        .tracking(-0.3)
                        .lineSpacing(15 * 1.4 - 15 * 1.19)
                        .foregroundStyle(palette.inkCream.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - One collectible

/// `791:6480` and its four siblings: a gilt frame with a picture set into its window, and a caption
/// under it.
///
/// The frames put a portrait of a named historical figure in every window and caption the featured
/// one with his name. What the app has instead is the stamp the walk earned at that place — the
/// same object the Journal and the Explorer's Card already show — set into the frame's own window at
/// the frame's own inset, so the composition is the design's and the picture is the walker's.
struct TripCollectionMedallion<Picture: View>: View {
    @Environment(\.hisploraPalette) private var palette

    enum Frame {
        /// `791:6463` — 134.048 × 167.5, window at (20.94, 21.98) 96.836 × 123.531.
        case tall
        /// `791:6468` — 147 × 147, window at (23, 12) 102 × 124.
        case square

        var size: CGSize {
            switch self {
            case .tall: CGSize(width: 134.048, height: 167.5)
            case .square: CGSize(width: 147, height: 147)
            }
        }

        var window: CGRect {
            switch self {
            case .tall: CGRect(x: 20.94, y: 21.98, width: 96.836, height: 123.531)
            case .square: CGRect(x: 23, y: 12, width: 102, height: 124)
            }
        }

        var artworkName: String {
            switch self {
            case .tall: HisploraTripArtwork.medallionTall
            case .square: HisploraTripArtwork.medallionSquare
            }
        }
    }

    let frame: Frame
    /// The italic serif line over the name, on the featured medallion only (`791:6485`).
    let eyebrow: String?
    let caption: String
    /// `791:6460` sets the tall frame's caption a point under it; `791:6465` gives the square one 11.
    var captionGap: CGFloat = 1
    @ViewBuilder let picture: Picture

    var body: some View {
        VStack(spacing: captionGap) {
            ZStack(alignment: .topLeading) {
                picture
                    .frame(width: frame.window.width, height: frame.window.height)
                    .clipShape(Ellipse())
                    .offset(x: frame.window.minX, y: frame.window.minY)
                HisploraTripArtworkImage(frame.artworkName)
                    .frame(width: frame.size.width, height: frame.size.height)
            }
            .frame(width: frame.size.width, height: frame.size.height)

            VStack(spacing: 0) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.system(size: 15, design: .serif).italic())
                        .tracking(-0.3)
                        .lineSpacing(15 * 1.4 - 15 * 1.19)
                        .foregroundStyle(palette.inkDark.color)
                }
                Text(caption)
                    .font(.system(size: 15))
                    .tracking(-0.3)
                    .lineSpacing(15 * 1.4 - 15 * 1.19)
                    .foregroundStyle(palette.inkDark.color)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The walker's own photograph, read back by the path the `TaskResult` carries.
///
/// A missing file draws nothing — a photograph deleted from Settings (`FR-SET-02`) or lost to a
/// partial restore leaves an empty mount rather than a broken-image glyph.
struct TripPhotoImage: View {
    let photoStore: any PhotoStore
    let relativePath: String

    var body: some View {
        if let image = photoStore.image(atRelativePath: relativePath) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }
}

private extension Font {
    func italic(_ isItalic: Bool) -> Font { isItalic ? self.italic() : self }
}
