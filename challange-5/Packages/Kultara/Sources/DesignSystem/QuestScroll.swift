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

    /// The parchment sheet, `447:1886` — 368 × 482, with a rolled bar top and bottom and a plain
    /// tan field between them.
    public static let sheet = PackagedImage(name: "quest-parchment", aspectRatio: 368.0 / 482.0)

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

    /// The ribboned scroll `921:3851` ("Quest - Card") draws on the quest-availability sheet — a
    /// tied roll rather than `rolledScroll`'s plain one, at its own aspect ratio. The width/height
    /// here is provisional pending the real export; `HisploraAvailabilityGlyph` sizes it by
    /// `.scaledToFit()` regardless, so a corrected ratio is a one-line fix once the file lands.
    public static let availabilityScroll = PackagedImage(
        name: "quest-availability-scroll", aspectRatio: 474.0 / 274.0)

    /// The tilt `447:1909` gives the scroll above the map hint.
    public static let mapHintTiltDegrees: Double = 41.6

    /// The open horizontal scroll the Location Verified map is drawn on — `1:4467` ("image 26") on
    /// `1:4458`. Gold-capped rods left and right, the sheet bowing between them.
    ///
    /// **It is the frame's own source image rotated, not the frame's export.** Figma exports this
    /// node with the frame's `#82736B` backdrop baked into every transparent pixel and clipped to
    /// the 402-point frame width, losing the 19 points it bleeds past each edge — the same defect
    /// `HisploraScrollArt.divider` records. The upload behind it is a 326 x 350 *vertical* scroll
    /// with real alpha, and the node is that image turned a quarter turn clockwise, which is what
    /// ships.
    ///
    /// **It is a 1x asset and wants replacing.** 350 x 326 drawn 439 points wide is under a third of
    /// what a 3x screen asks for, so the rods are soft. A hand export of the *unrotated* source at
    /// 4x, turned the same quarter turn, is a drop-in at this path.
    public static let mapScroll = PackagedImage(name: "map-scroll", aspectRatio: 439.0 / 409.0)
}

/// `1:4458`'s open scroll with a drawing laid in its paper field.
///
/// **An overlay rather than a background, unlike `HisploraParchmentSheet`**, and the difference is
/// deliberate. The parchment holds a task's words, so it has to grow when the words do
/// (`NFR-A11Y-01`); this holds one image at a fixed aspect ratio, which never reflows. Sizing the
/// scroll and insetting the drawing by fractions of it is what keeps the rods the shape they are
/// drawn — a background stretched to fit a taller caller would smear them.
///
/// The fractions are the frame's own arithmetic. The scroll spans x −19…420 and y 205…614 of a
/// 402 x 874 frame; `1:4468` sits at x 30…368, y 310…523. The interior that leaves is 338 x 213 —
/// exactly the map asset's own size, so the drawing fills the field rather than floating in it.
///
/// When the art is missing the drawing still draws, on a plain cream panel. A missing decoration
/// must not take the thing it decorates with it, which is the rule `HisploraParchmentSheet` and
/// `RunRouteMapView` already follow.
///
/// **It can open.** `openFraction` runs 0 (the two rods stood together, no paper between them) to 1
/// (`1:4467` as drawn), and everything between is the same object part-unrolled. It defaults to 1,
/// so a caller that never asks for the animation gets exactly the picture it got before — and at 1
/// the drawing is the untouched asset, not a re-composition of it, because three slices butted
/// together can show a hairline seam that a single image cannot.
///
/// **`Animatable`, and it has to be.** `openFraction` is read inside the body to build the slices,
/// so without this the whole subtree would be swapped at the end of the animation instead of the
/// widths being interpolated — the scroll would sit shut for the duration and then appear open. The
/// conformance is what makes SwiftUI re-evaluate the body at each step of the caller's animation.
public struct HisploraMapScroll<Content: View>: View, Animatable {
    @Environment(\.hisploraPalette) private var palette

    private var openFraction: CGFloat
    private let content: Content

    public init(openFraction: CGFloat = 1, @ViewBuilder content: () -> Content) {
        self.openFraction = openFraction
        self.content = content()
    }

    /// `nonisolated` because the animation machinery reads and writes this off the main actor while
    /// the view type itself is main-actor isolated. It touches one `CGFloat` and nothing else, so
    /// there is no state to race over.
    public nonisolated var animatableData: CGFloat {
        get { openFraction }
        set { openFraction = newValue }
    }

    /// Interpolation overshoots on a spring, and a scroll wider than its own picture tears. The
    /// clamp is here rather than in the initialiser because `animatableData` writes past it.
    private var open: CGFloat { min(1, max(0, openFraction)) }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                scroll(in: proxy.size)
                interior(in: proxy.size)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(HisploraScrollArt.mapScroll.aspectRatio, contentMode: .fit)
    }

    /// The drawing in the paper field, revealed by the opening rather than squashed with it.
    ///
    /// The paper itself is stretched — it is a texture, and a texture that grows reads as paper
    /// coming off a rod. A map is not: a map squeezed to a tenth of its width and let go reads as a
    /// rendering fault. So the drawing is laid at its final size and *masked* to whatever the scroll
    /// has opened, which is what unrolling a real one shows.
    private func interior(in size: CGSize) -> some View {
        content
            .frame(width: size.width * HisploraMapScrollMetrics.interiorWidth,
                   height: size.height * HisploraMapScrollMetrics.interiorHeight)
            .position(x: size.width * HisploraMapScrollMetrics.interiorCentreX,
                      y: size.height * HisploraMapScrollMetrics.interiorCentreY)
            .mask(alignment: .center) {
                Rectangle()
                    .frame(width: size.width * HisploraMapScrollMetrics.paperWidth * open)
            }
            // A sliver of map inside a nearly shut scroll is a smudge, not a reveal.
            .opacity(HisploraMapScrollMetrics.interiorOpacity(atOpenFraction: open))
    }

    @ViewBuilder private func scroll(in size: CGSize) -> some View {
        if let image = HisploraScrollArt.mapScroll.image {
            if open >= 1 {
                image
                    .resizable()
                    .accessibilityHidden(true)
            } else {
                unrolling(image, in: size)
            }
        } else {
            RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                .fill(palette.paperCream.color)
                .accessibilityHidden(true)
        }
    }

    /// The scroll part-open: both rods at the size they are drawn, the paper between them narrowed
    /// to what has come off them.
    ///
    /// The rods are *sliced* out of the asset rather than scaled with it — a rod that thins as the
    /// scroll opens is the one thing that would give the trick away, and it is what a plain
    /// horizontal squash of the whole picture does.
    private func unrolling(_ image: Image, in size: CGSize) -> some View {
        let left = size.width * HisploraMapScrollMetrics.leftRodWidth
        let right = size.width * HisploraMapScrollMetrics.rightRodWidth
        let paper = size.width * HisploraMapScrollMetrics.paperWidth
        return HStack(spacing: 0) {
            slice(image, in: size, from: 0, width: left)
            slice(image, in: size, from: left, width: paper)
                // Layout stays `paper` wide and the drawing shrinks inside it, so the band's centre
                // never moves: the rods travel out from the middle, exactly as the reference does.
                .scaleEffect(x: open, anchor: .center)
                .frame(width: paper * open)
            slice(image, in: size, from: left + paper, width: right)
        }
        .frame(width: size.width, height: size.height)
        .accessibilityHidden(true)
    }

    /// One vertical band of the asset, drawn at the size the whole asset would be drawn at.
    private func slice(_ image: Image, in size: CGSize, from x: CGFloat, width: CGFloat) -> some View {
        image
            .resizable()
            .frame(width: size.width, height: size.height)
            .offset(x: -x)
            .frame(width: width, height: size.height, alignment: .leading)
            .clipped()
    }
}

/// Where the paper field sits inside `1:4467`, in fractions of the scroll's own 439 x 409.
///
/// Fractions and not points: the scroll is drawn at whatever width the screen gives it, and a fixed
/// inset would put the drawing over a rod on a narrow device.
public enum HisploraMapScrollMetrics {
    /// The rods eat 49 points off the left of 439 and 52 off the right.
    public static let interiorWidth: CGFloat = 338.0 / 439.0
    /// The curled top and bottom edges eat 105 and 91 of 409.
    public static let interiorHeight: CGFloat = 213.0 / 409.0
    /// x = 30…368 of −19…420, so the field's centre is a shade right of the scroll's.
    public static let interiorCentreX: CGFloat = (30 + 338 / 2.0 - (-19)) / 439.0
    /// y = 310…523 of 205…614, a shade above centre — the top curl is deeper than the bottom one.
    public static let interiorCentreY: CGFloat = (310 + 213 / 2.0 - 205) / 409.0

    /// How far the scroll runs past each edge of a 402-point screen: x −19…420.
    ///
    /// The screen lays its content out in the frame's 362-point column, so reaching the scroll's
    /// full width means escaping that column by this much plus the column's own 20-point margin.
    public static let screenBleed: CGFloat = 19

    /// Where the two rods end, measured off `map-scroll.png`'s own alpha rather than read off the
    /// frame: a column-by-column scan of the 350 x 326 file puts the left rod at x 0…44 and the
    /// right at 304…350 — the columns whose vertical coverage is the rod's full 260-odd pixels
    /// before the paper's bow starts eating into it. The two differ by two pixels because the
    /// picture is a photograph of an object, not a symmetrical drawing.
    ///
    /// These are what the unrolling slices on, so they are fractions: the asset is drawn at whatever
    /// width the screen gives it and a rod measured in points would be the wrong rod on any other
    /// device.
    public static let leftRodWidth: CGFloat = 44.0 / 350.0
    public static let rightRodWidth: CGFloat = 46.0 / 350.0
    /// What is left between the rods, and therefore the only part the opening stretches.
    public static let paperWidth: CGFloat = 1 - leftRodWidth - rightRodWidth

    /// How wide the scroll stands with no paper off the rods at all — the closed state, both rods
    /// touching.
    public static let closedWidth: CGFloat = leftRodWidth + rightRodWidth

    /// How long the scroll takes to open. The reference render runs a shade over four seconds; this
    /// is the same movement at a pace that does not hold up a walker standing at a gate.
    public static let openDuration: Double = 1.8

    /// How visible the drawing is at a given point in the opening. It holds back until the scroll is
    /// a third open and is fully there well before the rods stop, so the map arrives *during* the
    /// movement rather than being switched on at the end of it.
    public static func interiorOpacity(atOpenFraction fraction: CGFloat) -> Double {
        let start: CGFloat = 0.35
        let end: CGFloat = 0.75
        guard fraction > start else { return 0 }
        guard fraction < end else { return 1 }
        return Double((fraction - start) / (end - start))
    }
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
/// the words spilling off the paper (`NFR-A11Y-01`). Reproduced the other way round — a 368 × 482
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
            // first line across a curl. 64 and 64 of the drawn 482, plus the sheet's own clear
            // interior margin.
            .padding(.top, HisploraParchmentMetrics.interiorTop)
            .padding(.bottom, HisploraParchmentMetrics.interiorBottom)
            .padding(.horizontal, HisploraParchmentMetrics.interiorSide)
            .background(alignment: .center) { sheet }
    }

    @ViewBuilder private var sheet: some View {
        if let image = HisploraScrollArt.sheet.image {
            image
                // **Nine-slice, not a plain stretch, and this was a visible bug.** A plain
                // `.resizable()` scales the whole picture to the content's height — so a task with a
                // text field, which is a good deal taller than the art's own 482, drew the head roll
                // at two and a half times the size it is painted and pushed the foot roll off the
                // screen with the skip printed across it. The caps hold both rolls at the height they
                // are drawn whatever the sheet grows to; the field between them is a flat grain and
                // stretching *that* is invisible.
                .resizable(capInsets: HisploraParchmentMetrics.rollCaps, resizingMode: .stretch)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                .fill(palette.paperCream.color)
                .accessibilityHidden(true)
        }
    }
}

/// `447:1886`'s own proportions, in its own 368 × 482 terms.
///
/// **These are measured off `quest-parchment.png`'s own alpha, not read off the frame**, the same way
/// `HisploraMapScrollMetrics` measures the map scroll's rods. A row-by-row scan of the 368 × 482 file
/// puts the head roll at y 0…63 and the foot roll at 418…482 — the rows whose coverage is the rolls'
/// full width before the paper's narrower field starts — and the field between them narrows to
/// x 39…329 at its waist, because the rolls are painted wider than the sheet they hold and the
/// sheet's sides bow inward.
///
/// Replacing the art means re-running that scan. The rolls are held at these heights by
/// `rollCaps` regardless of how tall the sheet grows, so a cap that does not match the picture cuts
/// a roll in half rather than merely mis-margining the text.
public enum HisploraParchmentMetrics {
    /// The two rolls, at the height they are painted. Leading and trailing are zero: the sheet is
    /// drawn within a few points of the art's own 368 wide, so the horizontal stretch is invisible,
    /// and a horizontal cap would pin the rolls' rounded ends against a field that no longer met
    /// them.
    public static let rollCaps = EdgeInsets(top: rollHeadHeight,
                                            leading: 0,
                                            bottom: rollFootHeight,
                                            trailing: 0)

    /// The head roll runs y 0…63 of the art's own 482.
    public static let rollHeadHeight: CGFloat = 64
    /// The foot roll starts at y 418, so it is the same 64 deep.
    public static let rollFootHeight: CGFloat = 64

    /// Clear paper under the head roll before the place name starts — `447:1906`'s 29, rounded to
    /// the 30 the new art's softer roll edge wants.
    public static let interiorTop: CGFloat = rollHeadHeight + 24
    /// The same, above the foot roll. Slightly tighter than the head because the foot carries a
    /// control rather than a masthead.
    public static let interiorBottom: CGFloat = rollFootHeight + 20
    /// The paper narrows to x 39…329 of 368 at its waist, so the ink has to clear 39 before it
    /// clears anything else — measured at the *narrowest* row rather than at the rolls, or a line
    /// set against the sheet's widest point runs off its bowed side halfway down. 56 leaves 17
    /// points of paper inside each edge there.
    public static let interiorSide: CGFloat = 56
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

/// The ribboned scroll `921:3851` draws — decoration for the quest-availability sheet, sized by
/// width with the height following its own ratio rather than a caller-supplied square.
public struct HisploraAvailabilityGlyph: View {
    @Environment(\.hisploraPalette) private var palette

    private let width: CGFloat

    public init(width: CGFloat) {
        self.width = width
    }

    public var body: some View {
        Group {
            if let image = HisploraScrollArt.availabilityScroll.image {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "scroll")
                    .font(.system(size: width * 0.5))
                    .foregroundStyle(palette.brownMid.color)
            }
        }
        .frame(width: width, height: width / HisploraScrollArt.availabilityScroll.aspectRatio)
        .accessibilityHidden(true)
    }
}
