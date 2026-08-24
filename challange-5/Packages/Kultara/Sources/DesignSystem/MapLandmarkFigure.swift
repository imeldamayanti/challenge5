import SwiftUI

/// The drawings the region map stands on its places, and the fog that lifts them off the paper
/// (Figma `275:2309`, the "Map — Fantasy" frame).
///
/// The frame does not mark a place with a pin. It stands a small ink-and-wash building on the
/// coastline, blows four overlapping puffs of white smoke behind it so the building reads against
/// the drawn terrain rather than disappearing into it, and writes the quest's name underneath in
/// the display serif. Three buildings ship, and which one a place gets is the caller's business —
/// `ContentKit` knows nothing about them, exactly as `HisploraStampArtwork` knows nothing about
/// which content place a stamp slug belongs to.
///
/// **These are chrome, not content.** They are generic Balinese architecture, not photographs of
/// the five real places the quest walks, so they make no claim that takes a citation. A place with
/// no drawing still works: `MapLandmarkFigure` renders the fog and nothing else rather than
/// borrowing a picture of somewhere it is not.
public enum MapLandmarkArtwork: String, CaseIterable, Sendable {
    /// The tiered meru — the Pura Besakih temple complex. The frame's default.
    case temple = "map-marker-temple"
    /// The candi bentar, the split gate. The drawing `1322:4256`'s popover stands on its quest.
    case naga = "map-marker-naga"
    /// A legong stage under its parasols.
    case dance = "map-marker-dance"

    /// The drawing's display box in the frame's own points — `82 × 55` off `298:1021`, `85 × 57.025`
    /// off `1026:3382`, `85 × 61` off `298:1013` — so a caller sizing by width gets the drawing's
    /// height for free rather than guessing at it. The dance box is *not* the shipped file's own
    /// proportions (344 × 287): the frame draws that source cropped to fill, and the figure
    /// reproduces the crop rather than the raw file.
    var buildingSize: CGSize {
        switch self {
        case .temple: CGSize(width: 82, height: 55)
        case .naga: CGSize(width: 85, height: 57.025)
        case .dance: CGSize(width: 85, height: 61)
        }
    }

    /// Top-left of the building within the 159-point fog cluster, read off the same frames. The
    /// building's feet sit inside the fog and its roof rises out of the top; each drawing stands
    /// at its own depth.
    var buildingOffset: CGPoint {
        switch self {
        case .temple: CGPoint(x: 36, y: 3)
        case .naga: CGPoint(x: 36, y: -6)
        case .dance: CGPoint(x: 37, y: -1)
        }
    }

    public var resourceName: String { rawValue }

    public var image: Image? { MapLandmarkImages.image(named: resourceName) }

    public static var allAreAvailable: Bool {
        allCases.allSatisfy { MapLandmarkImages.url(named: $0.resourceName) != nil }
            && MapLandmarkImages.url(named: MapLandmarkImages.fogResourceName) != nil
    }
}

/// Loading and caching for the map's packaged PNGs. Separate from `HisploraStampArtwork` because
/// these are a different set with a different rule for picking one, and shared with it only in the
/// cache — the map pans, and re-decoding four illustrations per frame is a stutter, not a cost.
public enum MapLandmarkImages {

    public static let fogResourceName = "map-marker-fog"

    public static func image(named name: String) -> Image? {
        cache.image(named: name, load: load)
    }

    public static var fog: Image? { image(named: fogResourceName) }

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

    static func url(named name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Images")
    }
}

/// One landmark as the map frame draws it: four puffs of fog with a building standing in them.
///
/// The layout is the frame's, read off `298:957`–`298:963` and expressed as fractions of the
/// figure's own width so the whole thing scales as one drawing. In the frame the fog cluster is
/// 159 × 87 points and each building stands at its own box and depth within it — `buildingSize`
/// and `buildingOffset` on `MapLandmarkArtwork` carry the per-drawing numbers, read off
/// `298:1021`, `1026:3382` and `298:1013`. The building's feet sit *inside* the fog and its roof
/// rises out of the top.
///
/// The figure carries no label. `MapPlaceLabel` is a separate view because the map alternates the
/// label above and below the marker to keep two adjacent names out of the same strip of paper, and
/// a figure that owned its own caption could not do that.
public struct MapLandmarkFigure: View {

    /// The frame's cluster, in points, at `referenceWidth`.
    private static let referenceWidth: CGFloat = 159
    private static let referenceHeight: CGFloat = 87
    private static let fogSize = CGSize(width: 111.159, height: 60.504)
    /// Top-left of each puff within the cluster.
    private static let fogOffsets: [CGPoint] = [
        CGPoint(x: 29.55, y: 0),
        CGPoint(x: 12.66, y: 26.73),
        CGPoint(x: 0, y: 5.63),
        CGPoint(x: 47.84, y: 19.70),
    ]

    private let artwork: MapLandmarkArtwork?
    private let width: CGFloat
    /// Overrides the drawing's own depth in the cluster. The marker frames stand the gate at
    /// (36, −6); the popover frame `1322:4256` stands the same drawing at (38, 0), so the card
    /// passes its own number rather than borrowing the marker's.
    private let buildingOffsetOverride: CGPoint?

    public init(artwork: MapLandmarkArtwork?, width: CGFloat = 110, buildingOffset: CGPoint? = nil) {
        self.artwork = artwork
        self.width = width
        self.buildingOffsetOverride = buildingOffset
    }

    /// The height the figure occupies when drawn `width` points across.
    public static func height(forWidth width: CGFloat) -> CGFloat {
        referenceHeight * (width / referenceWidth)
    }

    /// Where the building's own centre falls down the figure, as a fraction of its height. Each
    /// drawing stands at its own depth in the fog, so the answer is the drawing's. Published
    /// because a caller placing a tap target over the drawing needs it and cannot read it off the
    /// layout.
    public static func buildingCentreFraction(for artwork: MapLandmarkArtwork) -> CGFloat {
        (artwork.buildingOffset.y + artwork.buildingSize.height / 2) / referenceHeight
    }

    /// The scale everything below is drawn at.
    private var k: CGFloat { width / Self.referenceWidth }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            fogCluster
            building
        }
        .frame(width: width, height: Self.referenceHeight * k, alignment: .topLeading)
        // The drawing is decoration for a control that names itself. `RegionMapView` puts the
        // accessible label on the marker as a whole.
        .accessibilityHidden(true)
    }

    @ViewBuilder private var fogCluster: some View {
        if let fog = MapLandmarkImages.fog {
            ForEach(Array(Self.fogOffsets.enumerated()), id: \.offset) { _, origin in
                fog
                    .resizable()
                    .frame(width: Self.fogSize.width * k, height: Self.fogSize.height * k)
                    .offset(x: origin.x * k, y: origin.y * k)
            }
        }
    }

    @ViewBuilder private var building: some View {
        if let artwork, let image = artwork.image {
            let size = artwork.buildingSize
            let origin = buildingOffsetOverride ?? artwork.buildingOffset
            image
                .resizable()
                .scaledToFill()
                .frame(width: size.width * k, height: size.height * k)
                // The dance stage's box is not the file's own proportions — the frame draws that
                // source cropped to fill, so every drawing is cropped the same way here.
                .clipped()
                // The frame's `2px 2px 5px rgba(0,0,0,0.25)` — the drawing casts onto the map, or
                // it looks pasted on rather than standing on the island.
                .shadow(color: .black.opacity(0.25), radius: 2.5 * k, x: 2 * k, y: 2 * k)
                .offset(x: origin.x * k, y: origin.y * k)
        }
    }
}

/// Constants about the *shipped illustration itself* rather than about the theme.
///
/// Deliberately not a `KultaraPalette` token. A palette token is a colour something is measured
/// against — `KultaraThemeTests` enforces exactly that — and this is neither a surface nor an ink:
/// it is the colour the drawing's own sea fades to at its edge, used to letterbox the artwork when
/// the reader pinches out far enough to see the whole island. Behind an image, not behind text.
public enum RegionMapArtwork {
    /// Sampled from `Content/assets/maps/bali-illustrated.png` at its four corners and averaged:
    /// #99CCD9, #9ACED9, #A5D5DE, #A3D3DE. Re-sampled when the chart was replaced — the previous
    /// artwork's sea was a grey-green #8B9999 and letterboxing this one with it printed a band of
    /// the old map's colour beside the new one.
    public static let seaEdge = SRGBColor(hex: "#9FD0DC")
}
