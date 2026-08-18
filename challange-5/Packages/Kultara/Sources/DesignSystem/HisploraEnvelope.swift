import SwiftUI

/// Where the Journal's envelope is in its opening (`332:1607` sealed, `332:1691` opened,
/// `332:1252` the page standing out of it and zooming in).
///
/// A value rather than a pile of `@State` booleans, so the order of the four beats — and the fact
/// that there is no way to reach `zooming` without passing through `dwelling` — is something a test
/// can assert without building a view. The designer's note on the frames is the specification:
/// *"delay 2 or 3 seconds then the detail page comes out of the envelope and zooming in slowly."*
public enum HisploraEnvelopeStage: String, Sendable, CaseIterable, Comparable {
    /// Closed, wax intact. The card wiggles on a slow cycle — the frame's other note, *"swipe
    /// animation wiggle"* — to say it can be swiped and opened.
    case sealed
    /// The flap is swinging up and the wax is falling away.
    case opening
    /// Open, and holding. This is the designer's two-to-three seconds.
    case dwelling
    /// The page rises out of the pocket.
    case rising
    /// And zooms slowly toward the reader, which is where the screen hands over.
    case zooming

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (allCases.firstIndex(of: lhs) ?? 0) < (allCases.firstIndex(of: rhs) ?? 0)
    }

    /// The beat after this one, and `nil` at the end of the sequence.
    public var next: Self? {
        guard let index = Self.allCases.firstIndex(of: self) else { return nil }
        let following = Self.allCases.index(after: index)
        return following < Self.allCases.endIndex ? Self.allCases[following] : nil
    }

    /// Whether the flap stands open at this beat.
    public var isOpen: Bool { self > .sealed }
}

/// How long each beat lasts, and what it lasts when the reader has asked for less movement.
///
/// Reduce Motion does not skip the sequence — the opening *is* the content here, the way the
/// typed sheet is on the story preview — it collapses it to a cut. `HisploraTypewriterText` makes
/// the same call for the same reason.
public struct HisploraEnvelopeSequence: Sendable, Equatable {

    /// How often the sealed card nudges itself.
    public static let wiggleInterval: Duration = .seconds(3.2)
    public static let wiggleDuration: Duration = .milliseconds(520)
    /// The angle the sealed card rocks through, in degrees.
    public static let wiggleAngle: Double = 1.6
    /// How far the flap swings. Past 90° it is behind the envelope, which is where an opened flap
    /// goes; the last few degrees are what make it read as paper rather than as a hinge.
    public static let flapAngle: Double = 168

    public let rendersImmediately: Bool

    public init(rendersImmediately: Bool) {
        self.rendersImmediately = rendersImmediately
    }

    public func duration(of stage: HisploraEnvelopeStage) -> Duration {
        guard !rendersImmediately else { return .zero }
        switch stage {
        case .sealed: return .zero
        case .opening: return .milliseconds(900)
        // The designer's "2 or 3 seconds", taken at the middle.
        case .dwelling: return .milliseconds(2500)
        case .rising: return .milliseconds(1400)
        case .zooming: return .milliseconds(1600)
        }
    }

    /// The whole opening, end to end. Zero under Reduce Motion, which is the point.
    public var total: Duration {
        HisploraEnvelopeStage.allCases.reduce(Duration.zero) { $0 + duration(of: $1) }
    }
}

/// The envelope itself: a photographed paper object with a pocket, a flap and a wax seal, that a
/// page can be drawn out of.
///
/// **Every layer is a packaged export, and the composition is the code's.** The design draws the
/// closed and the opened envelope as two separate frames; an app has to get from one to the other,
/// so the flap is a layer with a hinge at its top edge rather than a second picture. The pocket
/// front is the lower band of the same body export, drawn a second time over whatever is rising out
/// of it — which is what makes the page look like it is coming from inside the paper instead of
/// sliding in front of it.
public struct HisploraEnvelope<Franking: View, Contents: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let stage: HisploraEnvelopeStage
    private let wiggles: Bool
    private let sequence: HisploraEnvelopeSequence
    private let franking: Franking
    private let contents: Contents

    @State private var wiggleAngle: Double = 0

    /// - Parameters:
    ///   - franking: what is stuck to the pocket — the picture, the stamps, the title.
    ///   - contents: the page that rises out. Drawn behind the pocket at every beat before
    ///     `rising`, so it is never visible until the envelope is open.
    public init(
        stage: HisploraEnvelopeStage,
        wiggles: Bool = false,
        sequence: HisploraEnvelopeSequence = HisploraEnvelopeSequence(rendersImmediately: false),
        @ViewBuilder franking: () -> Franking,
        @ViewBuilder contents: () -> Contents
    ) {
        self.stage = stage
        self.wiggles = wiggles
        self.sequence = sequence
        self.franking = franking()
        self.contents = contents()
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // Behind everything once open, so the flap that has swung over the top of the card
                // lands *behind* the paper rather than on the reader's side of it.
                if stage.isOpen { flap(size: size) }

                layer(HisploraEnvelopeMetrics.innerImage, size: size)

                page(size: size)

                if stage.isOpen {
                    // Open, only the pocket is in front of the reader: the lower band of the body
                    // export, drawn over the page so the page reads as coming from inside the
                    // paper. Drawing the *whole* body here would put a second copy of the sheet
                    // over the first and print a visible seam along the mask's edge.
                    layer(HisploraEnvelopeMetrics.bodyImage, size: size)
                        .mask(alignment: .bottom) {
                            Rectangle()
                                .frame(height: size.height
                                       * (1 - HisploraEnvelopeMetrics.pocketTopRatio))
                        }
                } else {
                    // Closed, the body is whole and the flap is folded down over it.
                    layer(HisploraEnvelopeMetrics.bodyImage, size: size)
                    flap(size: size)
                }

                // Above the flap in both states, which is where the frame franks them: the stamps
                // are drawn over the fold (`511:1464`), and a picture half under a flap reads as a
                // clipping bug rather than as an envelope.
                franking
                seal(size: size)
            }
            .frame(width: size.width, height: size.height)
        }
        .aspectRatio(HisploraEnvelopeMetrics.aspectRatio, contentMode: .fit)
        .rotationEffect(.degrees(wiggleAngle))
        .task(id: wiggles) { await runWiggle() }
    }

    // MARK: - Layers

    @ViewBuilder private func layer(_ image: Image?, size: CGSize) -> some View {
        if let image {
            image
                .resizable()
                .frame(width: size.width, height: size.height)
                .accessibilityHidden(true)
        } else {
            // A ruled rectangle in the paper's own colour, so a dropped export costs the texture
            // and not the screen. `PortraitFrame`'s fallback makes the same trade.
            RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                .fill(palette.paperWarm.color)
                .overlay(RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                    .stroke(palette.inkMuted.color.opacity(0.3), lineWidth: KultaraMetrics.hairline))
                .frame(width: size.width, height: size.height)
                .accessibilityHidden(true)
        }
    }

    /// The flap, hinged along its own top edge.
    ///
    /// Drawn at its own height rather than cropped out of a card-sized copy: the export is the
    /// flap, 286 × 121 of the card's 290 × 174, and stretching it to the card before clipping
    /// flattens the fold into the paper behind it.
    private func flap(size: CGSize) -> some View {
        let flapSize = CGSize(width: size.width,
                              height: size.height * HisploraEnvelopeMetrics.flapHeightRatio)
        return layer(HisploraEnvelopeMetrics.flapImage, size: flapSize)
            .rotation3DEffect(
                .degrees(stage.isOpen ? HisploraEnvelopeSequence.flapAngle : 0),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.45)
            .frame(width: size.width, height: size.height, alignment: .top)
    }

    /// The wax, which breaks with the flap: it does not stay whole on an open envelope.
    private func seal(size: CGSize) -> some View {
        HisploraWaxSeal()
            .frame(width: size.width * HisploraEnvelopeMetrics.sealSizeRatio)
            .position(x: size.width * HisploraEnvelopeMetrics.sealCentre.x,
                      y: size.height * HisploraEnvelopeMetrics.sealCentre.y)
            .opacity(stage.isOpen ? 0 : 1)
            .scaleEffect(stage.isOpen ? 1.35 : 1)
            .rotationEffect(.degrees(stage.isOpen ? 22 : 0))
    }

    /// The page inside. It sits fully in the pocket until `rising`, then stands out of it, then
    /// grows toward the reader — the three beats of `332:1252`.
    private func page(size: CGSize) -> some View {
        contents
            .frame(width: size.width * HisploraEnvelopeMetrics.pageWidthRatio)
            .scaleEffect(stage >= .zooming ? HisploraEnvelopeMetrics.zoomScale : 1,
                         anchor: .center)
            .offset(y: pageOffset(height: size.height))
            .opacity(stage >= .rising ? 1 : 0)
    }

    private func pageOffset(height: CGFloat) -> CGFloat {
        switch stage {
        case .sealed, .opening, .dwelling: return height * 0.34
        case .rising, .zooming: return -height * HisploraEnvelopeMetrics.pageRiseRatio
        }
    }

    // MARK: - The wiggle

    /// The sealed card's slow nudge. It runs only while `wiggles` is true, which the screen turns
    /// off the moment the reader opens the envelope and whenever the motion would be unwelcome.
    private func runWiggle() async {
        guard wiggles else {
            wiggleAngle = 0
            return
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: HisploraEnvelopeSequence.wiggleInterval)
            guard !Task.isCancelled else { return }
            let step = HisploraEnvelopeSequence.wiggleDuration / 4
            for angle in [HisploraEnvelopeSequence.wiggleAngle,
                          -HisploraEnvelopeSequence.wiggleAngle,
                          HisploraEnvelopeSequence.wiggleAngle * 0.5,
                          0] {
                withAnimation(.easeInOut(duration: step.seconds)) { wiggleAngle = angle }
                try? await Task.sleep(for: step)
                guard !Task.isCancelled else { return }
            }
        }
    }
}

public extension HisploraEnvelope where Contents == EmptyView {
    /// An envelope with nothing to draw out of it — the carousel's neighbours, and the empty state.
    init(
        stage: HisploraEnvelopeStage = .sealed,
        wiggles: Bool = false,
        @ViewBuilder franking: () -> Franking
    ) {
        self.init(stage: stage, wiggles: wiggles, franking: franking) { EmptyView() }
    }
}

/// The envelope's measurements and its packaged papers, kept out of the view for the reason
/// `PortraitFrameMetrics` is: a generic type cannot hold stored statics, and proportions are worth
/// testing without building a view to read them.
public enum HisploraEnvelopeMetrics {

    /// 290 × 173.999 in `511:1421`.
    public static let aspectRatio: CGFloat = 290.0 / 173.999
    /// The flap is 120.652 of the card's 173.999.
    public static let flapHeightRatio: CGFloat = 120.652 / 173.999
    /// Where the pocket's lip falls. Below this line the body export is the front of the paper and
    /// is drawn over whatever is coming out; above it, the reader is looking inside.
    public static let pocketTopRatio: CGFloat = 0.56
    /// The wax, 54.269 wide, centred at (118.28 + 54.269/2, 92.64 + 54.507/2).
    public static let sealSizeRatio: CGFloat = 54.269 / 290.0
    public static let sealCentre = CGPoint(x: (118.28 + 54.269 / 2) / 290.0,
                                           y: (92.64 + 54.507 / 2) / 173.999)
    /// The page that comes out is narrower than the pocket that held it.
    public static let pageWidthRatio: CGFloat = 0.62
    /// How far it stands proud of the envelope once risen, as a fraction of the card's height.
    public static let pageRiseRatio: CGFloat = 0.62
    /// And how much it grows on the last beat. `332:1252` sets the page at roughly twice the
    /// envelope's own width by the end of the zoom.
    public static let zoomScale: CGFloat = 2.1

    public static let bodyImage: Image? = HisploraWaxSealMetrics.image(named: "envelope-body")
    public static let flapImage: Image? = HisploraWaxSealMetrics.image(named: "envelope-flap")
    public static let innerImage: Image? = HisploraWaxSealMetrics.image(named: "envelope-inner")
    public static let tapeImage: Image? = HisploraWaxSealMetrics.image(named: "envelope-tape")

    public static var allResourceNames: [String] {
        ["envelope-body", "envelope-flap", "envelope-inner", "envelope-tape"]
    }

    /// Whether every packaged paper resolved. Asserted by `HisploraEnvelopeTests` so dropping one
    /// fails the suite instead of quietly flattening the Journal.
    public static var allAreAvailable: Bool {
        allResourceNames.allSatisfy { HisploraWaxSealMetrics.url(named: $0) != nil }
    }
}

extension Duration {
    /// Seconds as a `Double`, for the SwiftUI animation APIs that take one.
    var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}
