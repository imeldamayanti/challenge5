import SwiftUI

/// The cut-out paper stickers the Trip Summary and the History screen scatter over their grounds
/// (Figma section `791:6917`, "Section 1").
///
/// **They are chrome, not content.** The section is a hundred loose cut-outs — temples, gateways,
/// offerings, a keris, a compass — with no names beyond their sheet numbers and nothing authored
/// about them. Eighteen of them ship: exactly what the two pages place, resampled to three times
/// the size they are drawn at. `Package.swift` copies `Resources/Images` wholesale, so a sticker in
/// that directory is a sticker in every user's bundle; adding a nineteenth means adding it to
/// `names` *and* accepting its bytes.
///
/// The stems keep the section's own numbering rather than being renamed to what they depict —
/// `sticker-2-11` is traceably `sheet-2-11`, and inventing "temple-gate" for a drawing nobody
/// captioned would be the app naming somebody else's artwork.
///
/// > **Sourcing, recorded rather than argued.** Four of these letter something into the picture —
/// > `sheet-3-32` reads "THE LAST TALES OF BADUNG", `sheet-2-26` is a building signed "MUSEUM
/// > BALI", `sheet-2-02` is a chart lettered "BALI" — and the History page additionally prints a
/// > likeness of a named historical figure (`history-king`). None of it carries a source or a
/// > consent record, and `sheet-3-32` names one quest inside a picture the app would show for any
/// > of them. The owner asked on 2026-08-20 for the frames reproduced exactly and that is what
/// > ships; `docs/hisplora-tokens.md` carries the decision and what has to be resolved before
/// > anything public.
public enum HisploraStickerArtwork {

    /// Every sticker this module packages. Held as a list so `HisploraStickerTests` fails when one
    /// stops shipping, rather than a screen quietly losing a layer nobody notices is gone.
    public static let names = [
        "sticker-1-04", "sticker-1-08", "sticker-1-21", "sticker-1-25",
        "sticker-2-02", "sticker-2-03", "sticker-2-09", "sticker-2-11", "sticker-2-16",
        "sticker-2-18", "sticker-2-26", "sticker-2-28", "sticker-2-30",
        "sticker-3-07", "sticker-3-09", "sticker-3-16", "sticker-3-18", "sticker-3-24",
        "sticker-3-27", "sticker-3-32"
    ]

    /// The drawing, or `nil` when it is not packaged — which every caller renders as nothing at
    /// all. A sticker is decoration, so its absence is a plainer page and never a placeholder.
    ///
    /// Cached on the same terms `HisploraStampArtwork` is: a collage lays out six of these at once
    /// and each is a quarter-megabyte PNG, so decoding them on every body evaluation is a scrolling
    /// stutter rather than a theoretical cost.
    public static func image(named name: String) -> Image? {
        cache.image(named: name, load: load)
    }

    public static var allAreAvailable: Bool {
        names.allSatisfy { url(named: $0) != nil }
    }

    /// PNG first, JPEG second.
    ///
    /// Every cut-out here is a PNG because every cut-out has an alpha channel — that is what makes
    /// it a cut-out. The two exceptions are the Discovery page's photographs (`949:2470`,
    /// `949:2471`), which are rectangular photographs with nothing to knock out: as PNGs they cost
    /// 2.8 MB between them and as JPEGs 0.6 MB, in a bundle this file's own doc comment already
    /// warns about. The extension is asked rather than assumed so a caller never has to know which
    /// of the two a drawing happens to be.
    static func url(named name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Images")
            ?? Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Images")
    }

    private static let cache = ArtworkCache()

    private static func load(_ name: String) -> Image? {
        #if canImport(UIKit)
        guard let url = url(named: name),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }
}

/// The eight drawings that are not cut-outs: the plates, the portrait, the open book, the two
/// pen ornaments, the summary's emblem and the two gilt medallion frames.
///
/// Separate from `HisploraStickerArtwork` only because they are not interchangeable — a sticker is
/// scattered wherever a collage wants one, and each of these has exactly one place in exactly one
/// frame. They share the loader and the cache.
public enum HisploraTripArtwork {

    /// `791:6547` / `791:6576` — the landscape plate the History page opens on and closes over.
    public static let plate = "history-plate"
    /// `791:6572` — the portrait beside `791:6575`.
    public static let king = "history-king"
    /// `791:6577` — the torn scrap the closing line of the sixth band is written on.
    ///
    /// The node's own export bakes the section's cream behind the scrap and prints as a hard
    /// rectangle over the painting; this is the layer's raw image, which has the alpha the tear
    /// needs. The frame turns it a quarter-turn, and so does the view.
    public static let torn = "history-torn"
    /// `791:6553` — the pen rule between the first two paragraphs.
    public static let ornament = "history-ornament"
    /// `791:6574` — the hand-drawn arrow pointing at the portrait.
    public static let arrow = "history-arrow"
    /// `791:6491` — the roundel under the Trip Summary's masthead.
    public static let emblem = "trip-emblem"
    /// `791:6482` — the portrait set into the Trip Collection's featured medallion.
    ///
    /// The frame's own layer rather than its node export: the export bakes the medallion's mount
    /// behind the sitter. Same likeness as `king`, painted at a different crop for the oval.
    public static let legend = "legend-portrait"
    /// `791:6463` — the 134 × 167.5 gilt frame the featured collectible sits in.
    public static let medallionTall = "medallion-tall"
    /// `791:6468` — the 147 × 147 gilt frame the grid's collectibles sit in.
    public static let medallionSquare = "medallion-square"

    /// `949:2470` — the split gate the Discovery page opens on, with the airport behind it.
    ///
    /// > **A photograph with no provenance recorded**, in the same class as `king` and `plate`.
    /// > It is a real place photographed by somebody, and nothing in this repository says who or
    /// > under what licence. `docs/hisplora-tokens.md` carries it beside the other two; it has to
    /// > be resolved before anything public.
    public static let discoveryGate = "discovery-gate"
    /// `949:2471` — the second photograph, the grove under a flat sky. Same provenance gap.
    public static let discoveryGrove = "discovery-grove"
    /// `949:2477` — the hand-drawn highlighter stroke under a picked-out phrase.
    ///
    /// A raster rather than a `Shape`, unlike `HisploraHighlightMark`: the exported vector is 146
    /// cubic segments of a double brush stroke, and transcribing that many control points into
    /// Swift produces a file nobody can check against the drawing.
    public static let marker = "history-marker"

    public static let names = [plate, king, torn, ornament, arrow,
                               emblem, legend, medallionTall, medallionSquare,
                               discoveryGate, discoveryGrove, marker]

    public static func image(named name: String) -> Image? {
        HisploraStickerArtwork.image(named: name)
    }

    public static var allAreAvailable: Bool {
        names.allSatisfy { HisploraStickerArtwork.url(named: $0) != nil }
    }
}

/// One of those drawings, by name. Nothing when the name is unknown.
public struct HisploraTripArtworkImage: View {
    private let name: String
    private let contentMode: ContentMode

    public init(_ name: String, contentMode: ContentMode = .fit) {
        self.name = name
        self.contentMode = contentMode
    }

    public var body: some View {
        if let image = HisploraTripArtwork.image(named: name) {
            image.resizable().aspectRatio(contentMode: contentMode)
        }
    }
}

/// Where one sticker sits inside a collage, in the frame's own coordinates.
///
/// **Centre and unrotated size, not the rotated bounding box Figma reports.** A rotated layer's
/// metadata gives the box the rotation swept out, which is larger than the drawing and offset from
/// it; laying out to that box shrinks and nudges every tilted sticker. The centre survives the
/// rotation, so the centre is what is written down.
public struct HisploraStickerPlacement: Sendable, Equatable {
    public let name: String
    /// Centre, in points of the collage's own coordinate space.
    public let center: CGPoint
    /// The drawing's size before it is turned.
    public let size: CGSize
    public let rotation: Angle
    /// Drawn behind the collage's content rather than over it. The frames put a few cut-outs under
    /// the words they surround.
    public let isBehind: Bool

    public init(
        _ name: String,
        center: CGPoint,
        size: CGSize,
        rotation: Angle = .zero,
        isBehind: Bool = false
    ) {
        self.name = name
        self.center = center
        self.size = size
        self.rotation = rotation
        self.isBehind = isBehind
    }
}

/// A scatter of stickers laid out in the frame's coordinates and scaled to whatever width it is
/// given.
///
/// **It scales rather than reflows, and that is deliberate.** A collage is one composition — the
/// cut-outs overlap each other and tuck behind the type at angles somebody chose — so the only
/// honest response to a wider or narrower screen is the same picture at a different size. Laying
/// them out with a stack would produce a different collage, not a responsive one.
///
/// It is decoration end to end: `accessibilityHidden`, and `allowsHitTesting(false)` so a cut-out
/// that overhangs the box cannot swallow a tap meant for the control underneath. That second one is
/// not theoretical — it is exactly the defect `HisploraJournalCard`'s torn sheet shipped with.
public struct HisploraStickerCollage: View {
    private let placements: [HisploraStickerPlacement]
    private let frameSize: CGSize

    /// - Parameter frameSize: the collage's box in the frame's own points. The view scales the
    ///   whole composition by `width / frameSize.width`, so its height follows from its width.
    public init(frameSize: CGSize, placements: [HisploraStickerPlacement]) {
        self.frameSize = frameSize
        self.placements = placements
    }

    public var body: some View {
        GeometryReader { proxy in
            let scale = frameSize.width > 0 ? proxy.size.width / frameSize.width : 1
            ZStack(alignment: .topLeading) {
                ForEach(Array(placements.enumerated()), id: \.offset) { _, placement in
                    HisploraStickerImage(name: placement.name)
                        .frame(width: placement.size.width * scale,
                               height: placement.size.height * scale)
                        .rotationEffect(placement.rotation)
                        .position(x: placement.center.x * scale,
                                  y: placement.center.y * scale)
                }
            }
            .frame(width: proxy.size.width, height: frameSize.height * scale)
        }
        .aspectRatio(frameSize.width / frameSize.height, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One sticker, by resource name. Nothing when the name is unknown.
public struct HisploraStickerImage: View {
    private let name: String

    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        if let image = HisploraStickerArtwork.image(named: name) {
            image
                .resizable()
                // Fit, unlike the stamp window's fill: a cut-out has an outline, and cropping it to
                // a box cuts the outline off. The placements carry each drawing's own proportion.
                .aspectRatio(contentMode: .fit)
        }
    }
}
