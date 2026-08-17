import SwiftUI

/// The three pieces of packaged art `447:1880` ("Quest_Filled") and `452:3132` ("Quest 1/3") are
/// built from: the parchment sheet the task is printed on, the ornamental rule under the place name,
/// and the small rolled scroll that marks a task in a list.
///
/// **Provenance.** All three are generated images exported from the design file. They depict objects
/// — a blank sheet, a flourish, a rolled scroll — and assert nothing about any real place or person,
/// which puts them in the same class as `portrait-frame.png` and `typewriter.png`: a licence question
/// to answer, recorded here so it stays answerable, rather than an editorial one. The
/// **site plan** on `452:3028` is deliberately not in here for exactly that reason — it annotates a
/// real place with real distances, so it is content with a citation (`PlaceSiteMap`), not chrome.
public enum HisploraScrollArt {

    /// The parchment sheet, `447:1886` — 368 × 478 as drawn, with a rolled bar top and bottom and a
    /// smooth cream field between them.
    public static let sheet = PackagedImage(name: "quest-parchment", aspectRatio: 368.0 / 478.0)

    /// The flourish `447:1887` rules under the place name — 263 × 9.08, drawn at 4× so it stays crisp
    /// on a 3× screen.
    ///
    /// **Shipped as an alpha mask, not as the frame's own pixels.** Figma exports this node with the
    /// containing frame's `#808080` backdrop baked in, so the file as exported is a solid grey bar
    /// with a faint `#AA9B8E` flourish inside it — which is exactly how it rendered on device before
    /// this was caught. The coverage was lifted out of the red channel (170 against 128, the widest
    /// separation of the three) into alpha, leaving white ink the theme tints. That also means the
    /// ornament takes a palette token rather than the frame's raw value, which happens to be the
    /// pre-deviation `inkDusty` this palette already moved away from.
    public static let divider = PackagedImage(name: "story-divider", aspectRatio: 263.0 / 9.0796)

    /// The rolled scroll. Two frames use it at two very different sizes — `452:3147` puts it in a
    /// 48-point square as a list row's icon, `447:1909` tilts it 41.6° under the map hint — so the
    /// asset is one file and the geometry is the caller's.
    public static let rolledScroll = PackagedImage(name: "quest-scroll", aspectRatio: 511.0 / 488.0)

    /// The tilt `447:1909` gives the scroll above the map hint.
    public static let mapHintTiltDegrees: Double = 41.6
}

/// One image shipped with the design system, loaded once from the package bundle.
///
/// `Image(_:bundle:)` resolves lazily and draws nothing at all if the resource is ever dropped from
/// `Package.swift`, which is a silent failure. Loading eagerly makes the miss a value the caller can
/// branch on and `isAvailable` makes it a thing a test can hold — the same argument
/// `PortraitFrameMetrics` makes for the one image it owns.
public struct PackagedImage: Sendable {
    public let name: String
    /// Width ÷ height, so a layout can reserve space before the bytes are decoded.
    public let aspectRatio: CGFloat

    public init(name: String, aspectRatio: CGFloat) {
        self.name = name
        self.aspectRatio = aspectRatio
    }

    public var url: URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Images")
    }

    public var isAvailable: Bool { url != nil }

    public var image: Image? {
        #if canImport(UIKit)
        guard let url, let data = try? Data(contentsOf: url), let decoded = UIImage(data: data)
        else { return nil }
        return Image(uiImage: decoded)
        #else
        return nil
        #endif
    }
}

/// The parchment sheet with content printed on it — `447:1880`'s whole middle.
///
/// The sheet is the *background* of the printed matter rather than a fixed-size image with content
/// laid over it, which is the same decision `PhotoQuestCard` records: a background cannot make its
/// parent smaller, so at the largest accessibility sizes the sheet grows to fit the words instead of
/// the words spilling off the paper (`NFR-A11Y-01`). Reproduced the other way round — a 368 × 478
/// image with an overlay — the instruction runs off the lower roll at the second size above default.
///
/// When the packaged art is missing the sheet falls back to a plain cream panel. A missing decoration
/// must not take the task with it, which is the rule `KultaraPortraitFrame` and `RunRouteMapView`
/// already follow.
public struct HisploraParchmentSheet<Content: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity)
            // The rolled bars at the head and foot are art, not margin: printing into them puts the
            // first line across a curl. 78 and 74 of the drawn 478, plus the sheet's own 44-point
            // interior margin.
            .padding(.top, HisploraParchmentMetrics.interiorTop)
            .padding(.bottom, HisploraParchmentMetrics.interiorBottom)
            .padding(.horizontal, HisploraParchmentMetrics.interiorSide)
            .background(alignment: .center) { sheet }
    }

    @ViewBuilder private var sheet: some View {
        if let image = HisploraScrollArt.sheet.image {
            image
                .resizable()
                // The rolls have to stay the shape they are drawn; the field between them is a flat
                // gradient and stretching it is invisible.
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                .fill(palette.paperCream.color)
                .accessibilityHidden(true)
        }
    }
}

/// `447:1886`'s own proportions, in its own 368 × 478 terms.
public enum HisploraParchmentMetrics {
    /// The sheet's head roll runs to y ≈ 78 of 478, and `447:1906` prints the place name at 107 —
    /// which on a sheet starting at 190 is 29 points of clear paper under the roll.
    public static let interiorTop: CGFloat = 107
    /// The foot roll starts at y ≈ 404 of 478, and the drawn content ends well above it.
    public static let interiorBottom: CGFloat = 96
    /// `447:1895` runs x = 65…336 on a sheet spanning 17…385, so 48 in on each side.
    public static let interiorSide: CGFloat = 48
}

/// The flourish under the place name (`447:1887`), or nothing when the art is missing.
///
/// Decoration throughout: it is hidden from accessibility, and the hierarchy it marks is carried by
/// the type sizes above and below it rather than by the rule (`NFR-A11Y-05`).
public struct HisploraOrnamentDivider: View {
    @Environment(\.hisploraPalette) private var palette

    private let width: CGFloat

    /// `447:1887` draws it 263 wide inside a 271-point column.
    public init(width: CGFloat = 263) {
        self.width = width
    }

    public var body: some View {
        Group {
            if let image = HisploraScrollArt.divider.image {
                // The asset is a mask (see `HisploraScrollArt.divider`), so the ink comes from the
                // palette. `brownMid` is the same brown the place name above it is set in.
                image
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(palette.brownMid.color)
            } else {
                // Not a stroke across the full width: the flourish tapers, and a hard rule where an
                // ornament was reads as a missing asset. A short centred hairline reads as a rule.
                Rectangle().fill(palette.brownMid.color.opacity(0.4))
            }
        }
        .frame(width: width, height: width / HisploraScrollArt.divider.aspectRatio)
        .accessibilityHidden(true)
    }
}

/// The rolled scroll, at whatever size and tilt the caller needs.
public struct HisploraScrollGlyph: View {
    @Environment(\.hisploraPalette) private var palette

    private let size: CGFloat
    private let tiltDegrees: Double

    public init(size: CGFloat, tiltDegrees: Double = 0) {
        self.size = size
        self.tiltDegrees = tiltDegrees
    }

    public var body: some View {
        Group {
            if let image = HisploraScrollArt.rolledScroll.image {
                image.resizable().scaledToFit()
            } else {
                // `scroll` has shipped in SF Symbols since iOS 14, so the fallback is a scroll and
                // not a rectangle.
                Image(systemName: "scroll")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(palette.brownMid.color)
            }
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tiltDegrees))
        .accessibilityHidden(true)
    }
}
