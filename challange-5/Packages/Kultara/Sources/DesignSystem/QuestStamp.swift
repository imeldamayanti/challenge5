import SwiftUI

/// The postage stamp `452:3132` tilts over the right end of its progress bar (`452:3142`), and the
/// segmented bar itself (`452:3138`–`3141`).
///
/// **The stamp's perforated border is drawn, not shipped.** In Figma it is one 64 × 60.91 `evenodd`
/// vector, and the shape it describes is entirely regular: half-circle bites of radius 2.2384 taken
/// out of every edge at a 6.847-point pitch. A path that regular is measurements, and this repo
/// already keeps ornament measurements in code where a test can read them
/// (`HisploraPlaqueMetrics`, `PlaqueGeometryTests`). Exporting it as a raster would also lose the
/// only thing that matters about it — that the notches stay circular at every size the stamp is
/// drawn at.
///
/// **What goes inside it stays a parameter.** `452:3142` fills the stamp with a generated sketch of
/// a temple gate. This view takes the picture from its caller for the same reason
/// `KultaraPortraitFrame` does: an image presented as a particular place is a claim, and `FR-CP-05`
/// wants a source behind it. The caller passes the quest's own hero image, which has provenance
/// behind it in the content tree.
public struct HisploraStamp<Picture: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let accessibilityLabel: String
    private let picture: Picture

    public init(accessibilityLabel: String, @ViewBuilder picture: () -> Picture) {
        self.accessibilityLabel = accessibilityLabel
        self.picture = picture()
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let inset = HisploraStampMetrics.pictureInset(in: size)
            ZStack {
                HisploraStampShape()
                    // Even-odd, which is what turns the added circles into bites rather than bumps.
                    .fill(palette.paperCream.color, style: HisploraStampShape.fillStyle)
                picture
                    .frame(width: size.width - inset.horizontal * 2,
                           height: size.height - inset.vertical * 2)
                    .clipped()
            }
            .frame(width: size.width, height: size.height)
        }
        .aspectRatio(HisploraStampMetrics.aspectRatio, contentMode: .fit)
        // The tilt the frame draws. Decoration, so it is applied outside the accessibility element
        // and never rotates the label with it.
        .rotationEffect(.degrees(HisploraStampMetrics.tiltDegrees))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The stamp's numbers, read off `452:3142`'s exported vector, and the layout of the bar it sits on.
///
/// Kept out of the views because a generic type cannot hold stored statics, and because these are
/// values worth asserting without building a view to read them (`StampGeometryTests`).
public enum HisploraStampMetrics {

    /// The vector's own box.
    public static let designSize = CGSize(width: 64, height: 60.9099)

    public static var aspectRatio: CGFloat { designSize.width / designSize.height }

    /// The bite taken out of each edge, and the distance between two bites. Both read off the
    /// exported path: its first four notch centres stand at x = 4.6037, 11.4509, 18.2980 and
    /// 25.1452, which is a pitch of 6.8471 to four places, and each arc has radius 2.2384.
    public static let notchRadius: CGFloat = 2.2384
    public static let notchPitch: CGFloat = 6.8471
    /// Where the first notch centre sits, measured in from the edge.
    public static let notchLeadIn: CGFloat = 4.6037

    /// The tilt `452:3142` gives it. A stamp stuck on by hand is never square.
    public static let tiltDegrees: Double = 7.88

    /// The picture inside the stamp, as `I452:3142;7:28` insets it: 6.37% each side, 7.39% from the
    /// top and 7.51% from the bottom. Asymmetric vertically, and reproduced that way — the drawn
    /// margin under the picture is a shade deeper than the one above it, the way a real stamp's
    /// denomination strip is.
    public static func pictureInset(in size: CGSize) -> (horizontal: CGFloat, vertical: CGFloat) {
        (horizontal: size.width * 0.0637, vertical: size.height * 0.0745)
    }

    /// Every notch centre on all four edges, for a given drawn rectangle.
    ///
    /// The lead-in is scaled from the design rather than fixed, so a stamp drawn at half size has
    /// its notches half as far apart *and* half as far in from the corner — a fixed lead-in with a
    /// scaled pitch walks the pattern off the corner as the stamp shrinks.
    public static func notchCentres(in rect: CGRect, pitch: CGFloat) -> [CGPoint] {
        // The guard belongs here rather than only at the call site, because this is the function that
        // loops: a zero or negative pitch never advances `x`, so the `while` below runs forever and
        // appends until the process dies. A stamp given no room is a layout accident, not a hang.
        guard pitch > 0, rect.width > 0, rect.height > 0 else { return [] }
        let scale = pitch / notchPitch
        let leadIn = notchLeadIn * scale
        var centres: [CGPoint] = []

        var x = rect.minX + leadIn
        while x <= rect.maxX - leadIn + 0.001 {
            centres.append(CGPoint(x: x, y: rect.minY))
            centres.append(CGPoint(x: x, y: rect.maxY))
            x += pitch
        }
        var y = rect.minY + leadIn
        while y <= rect.maxY - leadIn + 0.001 {
            centres.append(CGPoint(x: rect.minX, y: y))
            centres.append(CGPoint(x: rect.maxX, y: y))
            y += pitch
        }
        return centres
    }
}

/// The task progress bar on `452:3132` — one segment per task at this checkpoint, filled as each is
/// resolved.
///
/// **Two things the frame draws are not reproduced, and both are `NFR-A11Y-03`.** Its unfilled
/// segments are washed with 29% cream, which measures 2.25:1 against a filled one — so the bar's
/// own state would be the thing that fails contrast. Unwashed, the pair is 3.36:1. And its `#9F8E88`
/// outline measures 2.87:1 on `brownStone`, so the bar's boundary is drawn in the already measured
/// `buttonRing` instead. Both are recorded in `docs/hisplora-tokens.md`.
///
/// The count comes from the run, never from the frame: `452:3132` is titled "Quest 1/3" and draws
/// three segments because the mock-up invents three tasks. The shipped content carries one task per
/// checkpoint, so this draws one (`AD-4`).
public struct HisploraSegmentedProgress: View {
    @Environment(\.hisploraPalette) private var palette

    private let total: Int
    private let completed: Int
    private let accessibilityLabel: String

    public init(completed: Int, total: Int, accessibilityLabel: String) {
        self.completed = completed
        self.total = total
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: HisploraSegmentedProgressMetrics.segmentGap) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                RoundedRectangle(cornerRadius: HisploraSegmentedProgressMetrics.segmentRadius)
                    .fill(index < completed ? palette.paperCream.color : palette.trackWell.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: HisploraSegmentedProgressMetrics.segmentRadius)
                            .stroke(palette.trackWell.color,
                                    lineWidth: HisploraSegmentedProgressMetrics.segmentBorder))
            }
        }
        .padding(HisploraSegmentedProgressMetrics.wellPadding)
        .frame(height: HisploraSegmentedProgressMetrics.wellHeight)
        .background(palette.trackWell.color,
                    in: RoundedRectangle(cornerRadius: HisploraSegmentedProgressMetrics.wellRadius))
        .overlay(
            RoundedRectangle(cornerRadius: HisploraSegmentedProgressMetrics.wellRadius)
                .stroke(palette.buttonRing.color,
                        lineWidth: HisploraSegmentedProgressMetrics.wellBorder))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// `452:3138`–`3141`'s own measurements: a 356 × 40 well at radius 12 with a 2-point border, holding
/// 111 × 36 segments at radius 10, each with its own 2-point border, inset 2 from the well.
public enum HisploraSegmentedProgressMetrics {
    public static let wellHeight: CGFloat = 40
    public static let wellRadius: CGFloat = 12
    public static let wellBorder: CGFloat = 2
    public static let wellPadding: CGFloat = 2
    public static let segmentRadius: CGFloat = 10
    public static let segmentBorder: CGFloat = 2
    /// The frame's three segments abut with no gap — 22…133, 133…244, 244…355 — so the gap is zero
    /// and each segment's own border is what divides them.
    public static let segmentGap: CGFloat = 0
}
