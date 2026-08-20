import SwiftUI

/// The paper cards the Journal's envelope holds — `791:5568` ("Trip summary") and `791:5814`
/// ("History"), read full size in the modal `791:5551` and drawn at half size inside the envelope
/// on `791:5585`.
///
/// **One card, two sizes, and the text is never baked in.** The frames export each card as a flat
/// picture; shipping those would freeze the quest's name into a PNG, which is the thing `AD-4` and
/// `FR-RUN-06` exist to prevent — screens render from the walk's own snapshots and never from a
/// drawing with a name in it. So the card is drawn here: the eyebrow, the title, the artwork and
/// the action are all parameters, and `HisploraJournalPaperThumbnail` is this same view scaled and
/// cropped rather than a second composition.
///
/// The only packaged parts are the ones that depict nothing about a particular quest: the torn
/// sheet the card is printed on, and the two default artworks a caller may replace with content's
/// own picture.
public struct HisploraJournalPaperCard<Artwork: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let eyebrow: String
    private let title: String
    private let actionTitle: String
    private let action: (() -> Void)?
    private let artwork: Artwork

    /// - Parameters:
    ///   - action: `nil` draws the pill as a label rather than a control, which is what the
    ///     thumbnail inside the envelope needs — a button at 50% scale is a 29-point tap target
    ///     the reader is not meant to hit (`NFR-A11Y-06`).
    public init(
        eyebrow: String,
        title: String,
        actionTitle: String,
        action: (() -> Void)? = nil,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
        self.artwork = artwork()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Text(eyebrow)
                .kultaraFont(.eyebrow)
                .foregroundStyle(palette.brownMid.color)
                .multilineTextAlignment(.center)

            Text(title)
                .kultaraFont(.journalPaperTitle)
                .foregroundStyle(palette.inkDark.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, HisploraJournalPaperMetrics.titleGap)

            artwork
                .padding(.top, HisploraJournalPaperMetrics.artworkGap)
                .accessibilityHidden(true)

            pill
                // The frame prints the control over the foot of the picture rather than under it,
                // which is what makes the card read as a page with something stuck to it.
                .padding(.top, -HisploraJournalPaperMetrics.actionOverlap)
        }
        .padding(.horizontal, HisploraJournalPaperMetrics.horizontalInset)
        .padding(.top, HisploraJournalPaperMetrics.topInset)
        .padding(.bottom, HisploraJournalPaperMetrics.bottomInset)
        // 321 as drawn — a floor rather than a height, so a longer title or a larger text size
        // makes the card taller instead of being clipped by it (`NFR-A11Y-01`).
        .frame(maxWidth: .infinity, minHeight: HisploraJournalPaperMetrics.height)
        .background { HisploraJournalPaperGround() }
        // The card is `overflow-clip` in both frames: the artwork bleeds past its edges and is cut
        // by the sheet rather than hanging off it.
        .clipped()
        // **`clipped()` clips drawing, not touches.** The sheet under this card is laid in at
        // 708 × 480 and the plate is drawn to fill a box narrower than itself, so both claim a hit
        // region far larger than the card — and the topmost of them silently swallowed every tap
        // meant for the card above it, including its own "Read Summary". Both are decoration and
        // are marked so at the source; this line is the belt to that brace, and it is what keeps a
        // future decorative layer from re-opening the same defect.
        .contentShape(Rectangle())
    }

    @ViewBuilder private var pill: some View {
        if let action {
            Button(actionTitle, action: action)
                .buttonStyle(.hisploraCompactPill)
        } else {
            Text(actionTitle)
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.34)
                .foregroundStyle(palette.inkOnButton.color)
                .padding(.horizontal, HisploraJournalPaperMetrics.pillHorizontalPadding)
                .padding(.vertical, HisploraJournalPaperMetrics.pillVerticalPadding)
                .background(palette.buttonFill.color, in: Capsule())
        }
    }
}

/// The same card, at the size the envelope holds it (`791:5595`, `791:5596`).
///
/// A scaled copy of the real card rather than a picture of one — so a walk's title is the walk's
/// title here too, and the two never drift.
///
/// **The whole card, not the frame's crop of it.** `791:5595` is 172.5 × 113.5 because the export
/// stops where the pocket covers the sheet; cutting the view there instead ships a card with its
/// picture and its "Read Summary" sliced off, and the slice shows the moment the sheet rises clear
/// of the envelope. The card is drawn entire at its own ratio and the envelope hides the rest.
public struct HisploraJournalPaperThumbnail<Artwork: View>: View {
    private let card: HisploraJournalPaperCard<Artwork>
    private let width: CGFloat

    public init(width: CGFloat, card: HisploraJournalPaperCard<Artwork>) {
        self.width = width
        self.card = card
    }

    public var body: some View {
        let scale = width / HisploraJournalPaperMetrics.width
        card
            .frame(width: HisploraJournalPaperMetrics.width)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: width,
                   height: width / HisploraJournalPaperMetrics.cardAspectRatio,
                   alignment: .topLeading)
            .clipped()
            .shadow(color: .black.opacity(0.25), radius: 5.35, y: 4)
            // Decoration inside a photographed object: at this size the frame's own type is under
            // seven points and the modal says all of it at full size (`NFR-A11Y-01`).
            .accessibilityHidden(true)
    }
}

/// The sheet the card is printed on: the frame's fill with `791:5569`'s torn paper laid over it.
public struct HisploraJournalPaperGround: View {
    @Environment(\.hisploraPalette) private var palette

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // The card grows with the reader's text size, so the sheet is laid in against whichever
            // of its two dimensions has stretched further. Undersizing it would show the flat fill
            // along an edge, which is precisely what the texture is there to prevent.
            let unit = max(size.width / HisploraJournalPaperMetrics.width,
                           size.height / HisploraJournalPaperMetrics.height)
            ZStack {
                Rectangle().fill(palette.paperCard.color)
                if let paper = HisploraJournalPaperMetrics.paperImage {
                    // `791:5569` lays the sheet in at 708.6 × 480 from (−150, −83.4) of a 344 × 321
                    // card, turned a quarter to the left — which is what puts the torn edge along
                    // the foot and the bottom-left corner. It is drawn into the upright box the
                    // frame gives it and *then* turned, which is why the numbers below read
                    // transposed.
                    paper
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: HisploraJournalPaperMetrics.groundBox.height * unit,
                               height: HisploraJournalPaperMetrics.groundBox.width * unit)
                        .rotationEffect(.degrees(-90))
                        .offset(x: HisploraJournalPaperMetrics.groundOffset.x * unit,
                                y: HisploraJournalPaperMetrics.groundOffset.y * unit)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
        .accessibilityHidden(true)
        // Paper, not a control: the sheet is drawn far larger than the card it fills, and a
        // decorative layer that big sitting in front of a button is how "Read Summary" stopped
        // responding.
        .allowsHitTesting(false)
    }
}

/// One of the two artworks the frames print on these cards.
///
/// **Both are defaults, not content.** `791:5573` is a drawn roundel and `791:5819` is a
/// photograph of a painting; neither is authored, sourced or consented, and neither names a place
/// the way a lore claim does. A caller that has the quest's own picture should pass that instead —
/// which is the whole reason this takes an `Image` rather than reaching for one.
public struct HisploraJournalPaperArtwork: View {
    /// How the picture is set on the sheet.
    public enum Style: String, Sendable, CaseIterable {
        /// `791:5573`: a disc, turned a little clockwise, with nothing around it.
        case roundel
        /// `791:5819`: a landscape window with a gilt edge, turned a little the other way.
        case plate

        /// The box the frame draws it in, before rotation.
        public var size: CGSize {
            switch self {
            case .roundel: CGSize(width: 131.824, height: 131.824)
            case .plate: CGSize(width: 209.58, height: 145)
            }
        }

        /// How far the frame turns it.
        public var rotation: Double {
            switch self {
            case .roundel: 8.82
            case .plate: -2.91
            }
        }
    }

    @Environment(\.hisploraPalette) private var palette

    private let image: Image?
    private let style: Style

    public init(image: Image?, style: Style) {
        self.image = image
        self.style = style
    }

    /// The same thing by resource name, which is how a caller that only has a presentation model
    /// reaches a packaged drawing — the pattern `HisploraStampCard(artworkName:)` already uses, so
    /// no view outside this module has to know where the images live.
    public init(artworkName: String?, style: Style) {
        self.init(image: artworkName.flatMap { HisploraWaxSealMetrics.image(named: $0) },
                  style: style)
    }

    public var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: style == .roundel ? .fit : .fill)
            } else {
                // A dropped export costs the card its picture and not its meaning — the eyebrow and
                // the title above it say what the card is. The same trade `PortraitFrame` makes.
                Rectangle().fill(palette.paperWarm.color)
            }
        }
        .frame(width: style.size.width, height: style.size.height)
        .clipped()
        .overlay {
            if style == .plate {
                // `791:5819`'s gilt edge. A hairline, not a mount: the frame draws the painting
                // as a print laid on the page rather than as a hung picture.
                Rectangle().stroke(palette.highlight.color.opacity(0.75),
                                   lineWidth: KultaraMetrics.hairline)
            }
        }
        .rotationEffect(.degrees(style.rotation))
        // Same reason as the ground: `.fill` draws the picture past the box that holds it, and
        // `clipped()` does not clip touches.
        .allowsHitTesting(false)
    }
}

/// The cards' measurements and their packaged papers, kept out of the view for the reason
/// `HisploraEnvelopeMetrics` is: a generic type cannot hold stored statics, and a proportion is
/// worth testing without building a view to read it.
public enum HisploraJournalPaperMetrics {

    /// 344 × 321 in `791:5568` and `791:5814`.
    public static let width: CGFloat = 344
    public static let height: CGFloat = 321
    /// The two cards are 20 apart on `791:5551` (451 → 471).
    public static let spacing: CGFloat = 20
    /// And inset 29 from each edge of a 402-point screen.
    public static let screenInset: CGFloat = 29

    /// 36 either side of a 271.5-wide text column, 28 down to the eyebrow.
    public static let horizontalInset: CGFloat = 36
    public static let topInset: CGFloat = 28
    /// 305 → 321 under the pill.
    public static let bottomInset: CGFloat = 16
    /// The 12 the frame's auto-layout puts between the eyebrow and the title.
    public static let titleGap: CGFloat = 12
    /// Title block ends at 110, the artwork starts at 124.
    public static let artworkGap: CGFloat = 14
    /// The pill's top edge (247) against the foot of the artwork.
    public static let actionOverlap: CGFloat = 26

    /// `791:5574`: 34 by 17 around a 17-point label, which is what makes the drawn 58-point pill.
    public static let pillHorizontalPadding: CGFloat = 34
    public static let pillVerticalPadding: CGFloat = 17

    /// The card's own shape, which is what the envelope's thumbnail keeps. `791:5595`'s
    /// 172.5 × 113.5 is the head of this card, not a card of its own — see
    /// `HisploraJournalPaperThumbnail`.
    public static let cardAspectRatio: CGFloat = width / height
    /// The frame's crop, kept for the pocket geometry that was measured against it.
    public static let thumbnailAspectRatio: CGFloat = 172.5 / 113.5

    /// `791:5569`'s torn sheet: a 708.6 × 480 box whose top-left corner sits at (−150, −83.4) of
    /// the card. Its centre is therefore 32.3 right of the card's and 3.9 above it, which is the
    /// offset below — kept as the arithmetic rather than as two magic numbers, so a change to the
    /// frame's box is one edit.
    public static let groundBox = CGSize(width: 708.6, height: 480)
    public static let groundOrigin = CGPoint(x: -150, y: -83.4)
    public static let groundOffset = CGPoint(
        x: groundOrigin.x + groundBox.width / 2 - width / 2,
        y: groundOrigin.y + groundBox.height / 2 - height / 2)

    public static let paperImage: Image? = HisploraWaxSealMetrics.image(named: "journal-card-paper")
    /// The default artworks. Replaceable by the caller — see `HisploraJournalPaperArtwork`.
    public static let summaryEmblem: Image? =
        HisploraWaxSealMetrics.image(named: "journal-summary-emblem")
    public static let historyPlate: Image? =
        HisploraWaxSealMetrics.image(named: "journal-history-plate")

    public static var allResourceNames: [String] {
        ["journal-card-paper", "journal-summary-emblem", "journal-history-plate"]
    }

    /// Whether every packaged paper resolved. Asserted by `HisploraJournalCardTests`, so dropping
    /// one fails the suite instead of quietly flattening the card.
    public static var allAreAvailable: Bool {
        allResourceNames.allSatisfy { HisploraWaxSealMetrics.url(named: $0) != nil }
    }
}

/// The card's own action: the hugging capsule `791:5574` draws, rather than the full-width pill the
/// story flow uses.
///
/// No ring, unlike `HisploraPillButtonStyle`. That one needs a boundary because a near-black pill
/// on mid-brown measures 2.04:1; this one is printed on `paperCard`, where it measures past 16:1.
public struct HisploraCompactPillButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .tracking(-0.34)
            .foregroundStyle(palette.inkOnButton.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, HisploraJournalPaperMetrics.pillHorizontalPadding)
            .padding(.vertical, HisploraJournalPaperMetrics.pillVerticalPadding)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.buttonFill.color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

public extension ButtonStyle where Self == HisploraCompactPillButtonStyle {
    static var hisploraCompactPill: HisploraCompactPillButtonStyle {
        HisploraCompactPillButtonStyle()
    }
}
