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
    /// The tiered meru — a mountain temple. The frame's default.
    case temple = "map-marker-temple"
    /// The naga gate, a candi bentar guarded by two serpents.
    case naga = "map-marker-naga"
    /// A legong stage under its parasols.
    case dance = "map-marker-dance"

    /// The design's own proportions, so a caller sizing by width gets the drawing's height for
    /// free rather than guessing at it.
    var aspectRatio: CGFloat {
        switch self {
        case .temple: 640.0 / 427.0
        case .naga: 640.0 / 458.0
        case .dance: 640.0 / 534.0
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
/// 159 × 87 points and the building 85 × 61, standing at (37, −3) from the cluster's top-left —
/// i.e. the building's feet sit *inside* the fog and its roof rises out of the top.
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
    private static let buildingOrigin = CGPoint(x: 37, y: -3)
    private static let buildingWidth: CGFloat = 85

    private let artwork: MapLandmarkArtwork?
    private let width: CGFloat

    public init(artwork: MapLandmarkArtwork?, width: CGFloat = 110) {
        self.artwork = artwork
        self.width = width
    }

    /// The height the figure occupies when drawn `width` points across.
    public static func height(forWidth width: CGFloat) -> CGFloat {
        referenceHeight * (width / referenceWidth)
    }

    /// Where the building's own centre falls down the figure, as a fraction of its height. The
    /// building spans −3…58 of the 87-point cluster, so its middle is at 27.5. Published because a
    /// caller placing a tap target over the drawing needs it and cannot read it off the layout.
    public static let buildingCentreFraction: CGFloat = 27.5 / 87

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
            let w = Self.buildingWidth * k
            image
                .resizable()
                .frame(width: w, height: w / artwork.aspectRatio)
                // The frame's `2px 2px 5px rgba(0,0,0,0.25)` — the drawing casts onto the map, or
                // it looks pasted on rather than standing on the island.
                .shadow(color: .black.opacity(0.25), radius: 2.5 * k, x: 2 * k, y: 2 * k)
                .offset(x: Self.buildingOrigin.x * k, y: Self.buildingOrigin.y * k)
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
    /// Sampled from `Content/assets/maps/bali-illustrated.png` at its four corners, which agree to
    /// within two levels: #879598–#8F9F9E.
    public static let seaEdge = SRGBColor(hex: "#8B9999")
}
