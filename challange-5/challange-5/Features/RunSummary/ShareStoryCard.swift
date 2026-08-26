import ContentKit
import DesignSystem
import SwiftUI
import UIKit
import UIStringsKit

/// One shareable story-card image, in two ground variants (`FR-DONE-06`; Figma `921:2654`
/// "Instagram story - 1" and `921:2960` "Completion 6").
///
/// The card is the completion carousel's on-screen postcard re-cut at render scale — same envelope,
/// same paper, same facts — so a walker shares what they were just looking at. The composition is
/// identical across both grounds; only what sits behind it changes.
///
/// **Everything on it comes from the Run's own snapshots** (`AD-4`, `FR-RUN-06`), passed in as
/// plain strings by the caller — never live content, and no quest or place name is baked in here.
///
/// What is deliberately **not** on it, each a privacy decision rather than a layout one, mirroring
/// `ShareCardArtwork`'s list:
///
/// - **No coordinates and no accuracy.** Neither ever leaves the device in a shareable form
///   (`NFR-PRIV-02`); a shared card is the one artefact designed to leave it entirely.
/// - **No timestamp at all.** A time of day plus a named place is a statement about where a person
///   was and when; this card carries none, not even the day.
/// - **No written answers beyond the journal entry the walker already chose to keep**, which the
///   summary screen shows in exactly the same words.
struct ShareStoryCard: View {

    /// Everything the card needs, resolved before it exists. A value type so a caller can hold one
    /// and derive variants from it, and `Sendable` for the reason every presentation model here is:
    /// it makes storing a repository or a palette in it structurally impossible.
    struct Input: Sendable {
        /// What sits behind the composition. The walker's photograph aspect-filled under a 45%
        /// black wash (`921:2654`), or the brown gradient (`921:2960`) — Figma's fourteen-slice
        /// glass texture over it stands in as flat colour, deliberately: it is noise, not content.
        enum Ground: Sendable {
            case photo(UIImage)
            case brown

            /// The photograph the input carries regardless of which ground draws — the perforated
            /// die reads it on *both* grounds. `nil` is a walk with no photograph, and the die's
            /// dark pane is its honest-empty state, the rule the on-screen postcard documents.
            var photograph: UIImage? {
                if case .photo(let image) = self { return image }
                return nil
            }

            /// `921:2654` prints the footer's first words at full strength over a photograph;
            /// `921:2960` washes them to 48% over its own gradient.
            var footerInkIsFullOpacity: Bool {
                if case .photo = self { return true }
                return false
            }
        }

        /// The region the walk happened in, falling back to the quest title when the region is
        /// empty — the same rule the on-screen postcard follows. Never a hardcoded name (`AD-4`).
        let regionTitle: String
        /// The walker's journal text. Empty or missing is a real state and stays one: the ruled
        /// lines are the empty state, never a placeholder sentence.
        let journalText: String?
        let placesCount: Int
        let durationMinutes: Int
        /// The walk's first stamp, or nil when the walk earned none — absent means absent, never a
        /// placeholder stamp naming somewhere else.
        let stamp: Stamp?

        struct Stamp: Sendable, Equatable {
            let placeName: String
            let region: String
            /// The walk's own tiered drawing for this stamp, resolved where a repository is in
            /// scope. nil renders aged paper in the window.
            let artworkName: String?
        }

        /// The round postmark over the stamp. A constant today — `HisploraTripArtwork.emblem` at
        /// every call site — but carried rather than read inside, so the artwork stays data like
        /// everything else on the card.
        let postmarkArtworkName: String

        let language: ContentLanguage
        let ground: Ground

        init(
            regionTitle: String,
            journalText: String?,
            placesCount: Int,
            durationMinutes: Int,
            stamp: Stamp?,
            postmarkArtworkName: String,
            language: ContentLanguage,
            ground: Ground
        ) {
            self.regionTitle = regionTitle
            self.journalText = journalText
            self.placesCount = placesCount
            self.durationMinutes = durationMinutes
            self.stamp = stamp
            self.postmarkArtworkName = postmarkArtworkName
            self.language = language
            self.ground = ground
        }

        /// The same card on another ground — how the picker derives the second variant from the
        /// one input the carousel builds.
        func withGround(_ ground: Ground) -> Input {
            Input(
                regionTitle: regionTitle, journalText: journalText,
                placesCount: placesCount, durationMinutes: durationMinutes,
                stamp: stamp, postmarkArtworkName: postmarkArtworkName,
                language: language, ground: ground)
        }
    }

    /// A fixed canvas rather than a rendered screen, after `ShareCardArtwork`'s argument: a share
    /// card is an image with one job, and letting it reflow would make every walker's card a
    /// different picture. 246 × 437 points, the frames' ~9:16 story shape.
    static let size = CGSize(width: 246, height: 437)
    /// Renders ~1080 px wide — Instagram-story scale — from the point canvas.
    static let rendererScale = CGFloat(1080.0 / 246.0)

    // MARK: - Frame measurements (Figma `921:2654`, canvas coordinates)

    private static let envelopeWidth: CGFloat = 198
    private static let envelopeTopLeft = CGPoint(x: 28.5, y: 75)
    private static let envelopeRotation: Double = 8

    private static let postcardRect = CGRect(x: 41.2, y: 105.33, width: 172.2, height: 113.4)
    private static let postcardInset: CGFloat = 11.5
    /// Where the printed labels end and the writing area begins, from the postcard's left edge.
    private static let writingColumnX: CGFloat = 84
    private static let ruledLineWidth: CGFloat = 64.8
    private static let ruledLinePitch: CGFloat = 7.2
    private static let ruledLineCount = 7
    private static let handwritingWidth: CGFloat = 69

    private static let dieSize = CGSize(width: 164, height: 121)
    private static let dieCentre = CGPoint(x: 123, y: 249)
    private static let dieRotation: Double = 5.41
    /// How much of the die the picture takes, leaving the rest as printed paper — the carousel's
    /// own 250.9 x 181.5 photo on a 279.185 x 205.7 die, kept as fractions so this canvas and that
    /// one cut the same object at two sizes.
    private static let diePictureWidthRatio: CGFloat = 250.9 / 279.185
    private static let diePictureHeightRatio: CGFloat = 181.5 / 205.7

    private static let footerCentre = CGPoint(x: 123, y: 351)
    /// Who the card is from. A working title rather than a settled product name — the one string
    /// on this card that is not a snapshot, and the one place to change it when the app is named.
    private static let brandName = "Hisplora"

    let input: Input

    var body: some View {
        ZStack {
            ground
            envelopeGroup
            postcard.position(
                x: Self.postcardRect.midX, y: Self.postcardRect.midY)
            photoDie
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: - Ground

    @ViewBuilder private var ground: some View {
        switch input.ground {
        case .photo(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Self.size.width, height: Self.size.height)
                .clipped()
                .overlay(Color.black.opacity(0.45))
        case .brown:
            LinearGradient(
                stops: [
                    .init(color: SRGBColor(hex: "#1C0F0B").color, location: 0),
                    .init(color: SRGBColor(hex: "#86361D").color, location: 0.86),
                ],
                startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Envelope behind the postcard

    /// The tilted kraft envelope, drawn exactly the way `TripRecapCarouselScreen.postcard` draws
    /// it — sealed, closed, nothing rising out of it — scaled to the card's canvas.
    private var envelopeGroup: some View {
        HisploraEnvelope(stage: .sealed) { EmptyView() }
            .frame(width: Self.envelopeWidth)
            .rotationEffect(.degrees(Self.envelopeRotation))
            .accessibilityHidden(true)
            .position(
                x: Self.envelopeTopLeft.x + Self.envelopeWidth / 2,
                y: Self.envelopeTopLeft.y
                    + Self.envelopeWidth / HisploraEnvelopeMetrics.aspectRatio / 2)
    }

    // MARK: - The postcard

    private var postcard: some View {
        ZStack(alignment: .topLeading) {
            SRGBColor(hex: "#F5F1E5").color

            header
                .padding(.top, 9)
                .padding(.leading, Self.postcardInset)

            divider
                .padding(.leading, Self.writingColumnX - 0.4)
                .padding(.top, 8.7)

            writingColumn
                .padding(.leading, Self.writingColumnX + 5)
                .padding(.top, 27)

            facts
                .padding(.leading, Self.postcardInset)
                .padding(.bottom, 9)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            stampCorner
                .padding(.trailing, 5)
                .padding(.top, 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: Self.postcardRect.width, height: Self.postcardRect.height)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 1.2) {
            Text(UIStrings.string(.tripRecapPostcardTitle, input.language))
                .font(postcardPrintFont(9.6))
                .tracking(-0.288)
                .foregroundStyle(.black)
            fromLine
        }
    }

    /// "from <region>" — the localized format split around its placeholder so the connective can
    /// sit small while the place name leans large, without either language losing its word order.
    private var fromLine: Text {
        let template = UIStrings.string(.tripRecapPostcardFrom, input.language)
        let parts = template.components(separatedBy: "%@")
        let scriptFont = Font.custom("Snell Roundhand", size: 7.2)
        let nameFont = Font.custom("Snell Roundhand", size: 12)
        guard parts.count > 1 else {
            // No placeholder in the table: print the whole line at the name size rather than drop
            // the region.
            return Text(template).font(nameFont)
        }
        var line = Text(parts[0]).font(scriptFont)
        line = line + Text(input.regionTitle).font(nameFont)
        if !parts[1].isEmpty {
            line = line + Text(parts[1]).font(scriptFont)
        }
        return line.foregroundStyle(SRGBColor(hex: "#A33921").color)
    }

    /// Hairline between the printed labels and the writing area.
    private var divider: some View {
        Capsule()
            .fill(SRGBColor(hex: "#221D1D").color.opacity(0.25))
            .frame(width: 0.8, height: Self.postcardRect.height - 17.4)
    }

    /// Seven ruled lines with the walker's handwriting over them. **The lines are the empty
    /// state**: a journal left unwritten prints as paper waiting, not as a placeholder sentence.
    private var writingColumn: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: Self.ruledLinePitch - 0.8) {
                ForEach(0..<Self.ruledLineCount, id: \.self) { _ in
                    Capsule()
                        .fill(SRGBColor(hex: "#221D1D").color.opacity(0.18))
                        .frame(width: Self.ruledLineWidth, height: 0.8)
                }
            }
            .padding(.top, 7)

            if let journalText = input.journalText?.trimmingCharacters(in: .whitespacesAndNewlines),
               !journalText.isEmpty {
                Text(journalText)
                    .font(handwritingFont(5.1))
                    .foregroundStyle(SRGBColor(hex: "#221D1D").color)
                    .lineSpacing(1.4)
                    .frame(width: Self.handwritingWidth, alignment: .topLeading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The two printed facts, label and value set in different faces — the engraving against the
    /// hand — exactly as the on-screen postcard pairs them.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 2.5) {
            fact(
                label: UIStrings.string(.tripRecapMemoLabel, input.language),
                value: String(
                    format: UIStrings.string(.tripRecapPlacesUnit, input.language),
                    input.placesCount))
            fact(
                label: UIStrings.string(.tripDuration, input.language),
                value: String(
                    format: UIStrings.string(.tripRecapMinutesUnit, input.language),
                    input.durationMinutes))
        }
    }

    private func fact(label: String, value: String) -> some View {
        HStack(spacing: 2) {
            Text("\(label):")
                .font(postcardPrintFont(5.6))
                .foregroundStyle(SRGBColor(hex: "#58453E").color)
            Text(value)
                .font(handwritingFont(5.6))
                .foregroundStyle(SRGBColor(hex: "#A33921").color)
        }
    }

    /// The walk's first stamp with its postmark — the same move as the carousel's own
    /// `postcardStamp`, scaled to this canvas. Omitted whole when the walk earned no stamps.
    @ViewBuilder private var stampCorner: some View {
        if let stamp = input.stamp {
            ZStack(alignment: .topTrailing) {
                HisploraStampCard(
                    title: stamp.placeName, subtitle: stamp.region,
                    showsFranking: false, artworkName: stamp.artworkName)
                    .frame(width: 22)
                    .rotationEffect(.degrees(2.92))
                HisploraTripArtworkImage(input.postmarkArtworkName)
                    .frame(width: 14, height: 14)
                    .offset(x: 5, y: -5)
            }
        }
    }

    // MARK: - The photograph's die

    /// The walker's own photograph in the perforated die every stamp in this app uses, riding half
    /// over the postcard's lower edge. No photograph is the dark pane, not an empty gap — there is
    /// no camera-less fallback anywhere else in the design system either, and the same argument the
    /// on-screen version records applies here.
    ///
    /// **The picture is inset onto white paper and the perforation is cut into the paper**, which
    /// is what makes the object read as a stamp. Clipping the photograph itself to the die — which
    /// is what this drew first — leaves the teeth cut out of the picture, and on the photo ground
    /// the bites are then dark-on-dark: the die loses its edge entirely and comes out a scalloped
    /// smudge rather than a franked object. The margin is the stamp.
    ///
    /// The cut is `921:2938`/`2943`'s own vector — nine bites across, thirteen down, spaced apart —
    /// the same one `TripRecapCarouselScreen.postcardPhotoStamp` sets on screen, so the shared card
    /// and the card the walker was just looking at are the same die at two sizes. A count derived
    /// from this canvas instead (the twenty touching bites that shipped) is a different object.
    private var photoDie: some View {
        ZStack {
            Color.white
            picture
                .frame(
                    width: Self.dieSize.width * Self.diePictureWidthRatio,
                    height: Self.dieSize.height * Self.diePictureHeightRatio)
                .clipped()
        }
        .frame(width: Self.dieSize.width, height: Self.dieSize.height)
        .clipShape(
            HisploraStampShape(teethAcross: 9, teethDown: 13, biteSpan: 0.71),
            style: HisploraStampShape.fillStyle)
        .rotationEffect(.degrees(Self.dieRotation))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .accessibilityHidden(true)
        .position(x: Self.dieCentre.x, y: Self.dieCentre.y)
    }

    /// What the die prints: the walk's photograph, or the documented dark pane when it has none.
    @ViewBuilder private var picture: some View {
        if let photo = input.ground.photograph {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            SRGBColor(hex: "#221D1D").color
        }
    }

    // MARK: - Footer

    private var footer: some View {
        brandLine.position(x: Self.footerCentre.x, y: Self.footerCentre.y)
    }

    /// "story from *Hisplora*" — the localized format split around its placeholder so the brand
    /// leans in the serif while the connective stays quiet, without either language losing its
    /// word order. The same move `fromLine` makes on the postcard above.
    ///
    /// **Split, never substituted and then drawn again.** Formatting the name *into* the template
    /// and printing a second italic copy beside it is what set "story from Hisplora Hisplora"
    /// across the foot of every card.
    private var brandLine: Text {
        let template = UIStrings.string(.shareStoryFromBrand, input.language)
        let parts = template.components(separatedBy: "%@")
        let connectiveFont = Font.system(size: 12)
        let quiet = SRGBColor(hex: "#FDF2DE").color
            .opacity(input.ground.footerInkIsFullOpacity ? 1 : 0.48)
        let brand = Text(Self.brandName)
            .font(.system(size: 12, weight: .medium, design: .serif))
            .italic()
            .foregroundStyle(Color.white)
        guard parts.count > 1 else {
            // No placeholder in the table: print the line and then the name, rather than sign the
            // card with nothing.
            return Text(template).font(connectiveFont).foregroundStyle(quiet)
                + Text(" ").font(connectiveFont) + brand
        }
        var line = Text(parts[0]).font(connectiveFont).foregroundStyle(quiet) + brand
        if !parts[1].isEmpty {
            line = line + Text(parts[1]).font(connectiveFont).foregroundStyle(quiet)
        }
        return line
    }

    // MARK: - Faces

    /// Bodoni Moda sets the postcard's printing. A system serif keeps the layout if the face did
    /// not register, because the printing was drawn engraved and upright — the substitution that
    /// changes least.
    private func postcardPrintFont(_ size: CGFloat) -> Font {
        KultaraFonts.bodoniIsAvailable
            ? .custom(KultaraFonts.bodoniName, size: size)
            : .system(size: size, weight: .semibold, design: .serif)
    }

    /// Shadows Into Light Two stands in for the hand. Its fallback is rounded by design: the
    /// handwriting was drawn personal, so a missing face costs the costume and not the words.
    private func handwritingFont(_ size: CGFloat) -> Font {
        KultaraFonts.handwritingIsAvailable
            ? .custom(KultaraFonts.handwritingName, size: size)
            : .system(size: size, design: .rounded)
    }

    // MARK: - Accessibility

    /// The card is one image to VoiceOver, described rather than enumerated — its contents are all
    /// decorative layers of a picture being handed to somebody else.
    private var accessibilitySummary: String {
        String(
            format: UIStrings.string(.shareStoryPreviewLabel, input.language),
            UIStrings.string(
                input.ground.photograph == nil
                    ? .shareStoryVariantBrown : .shareStoryVariantPhoto,
                input.language))
    }

    // MARK: - Rendering

    /// Renders the card to an image at the fixed canvas size, after the `ShareCardArtwork`
    /// pattern: `ImageRenderer` because this view has no interaction and no environment beyond
    /// what it is handed, `proposedSize` pinned to the frame's canvas, and `scale` set so the
    /// output lands at story width (~1080 px). Rendering is entirely local — `AD-3` intact, and
    /// sharing never gates anything (`AD-2`).
    @MainActor func render() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.proposedSize = ProposedViewSize(Self.size)
        renderer.scale = Self.rendererScale
        return renderer.uiImage
    }
}
