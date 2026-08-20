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

/// Which way round the sealed envelope is standing, and how far through turning (`791:5637`).
///
/// **The idle animation is a turn now, not only a nudge.** A sealed card wiggles to say it can be
/// swiped; it turns to say there is something written on the other side — the stamps and the hand
/// that addressed it. Four beats rather than two booleans, because the reader may tap "Unseal"
/// mid-turn and the card has to finish getting back to its front before the flap can open: an
/// envelope that opened while showing its back would be opening the wrong side of itself.
///
/// The angle is the card's own rotation about its vertical axis. `turningToFront` is 90 again
/// rather than 270 on purpose — the card comes back the way it went, which is what "flip it back"
/// means.
public enum HisploraEnvelopeFlip: String, Sendable, CaseIterable, Equatable {
    case front
    case turningToBack
    case back
    case turningToFront

    /// How far round the card is at this beat, in degrees.
    public var angle: Double {
        switch self {
        case .front: 0
        case .turningToBack, .turningToFront: 90
        case .back: 180
        }
    }

    /// Whether the reader is looking at the addressed side.
    ///
    /// The swap happens at the quarter turn, where the card is edge-on and neither face has any
    /// width — which is what makes one picture become the other rather than cross-fade into it.
    public var showsBack: Bool {
        switch self {
        case .front, .turningToBack: false
        case .back, .turningToFront: true
        }
    }

    public var isFront: Bool { self == .front }

    /// The next beat of the idle turn.
    public var next: HisploraEnvelopeFlip {
        switch self {
        case .front: .turningToBack
        case .turningToBack: .back
        case .back: .turningToFront
        case .turningToFront: .front
        }
    }

    /// The beats that bring the card back to its front from here — the shortest way, which from a
    /// half-turn is back the way it came rather than on round.
    public var returningToFront: [HisploraEnvelopeFlip] {
        switch self {
        case .front: []
        case .turningToBack, .turningToFront: [.front]
        case .back: [.turningToFront, .front]
        }
    }
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

    /// **Halved against the designer's note, deliberately.** The frames ask for a two-to-three
    /// second dwell and a slow zoom, which read correctly once and then read as a wait: this is the
    /// gate in front of every letter a reader opens, not a title sequence they see at launch. The
    /// beats keep their proportions to each other — the flap is still the quickest, the dwell is
    /// still the longest, the zoom still outlasts the rise — so the opening is the same shape at
    /// 2.9s that it was at 6.4s. `total` is what any test should assert against, never a literal.
    public func duration(of stage: HisploraEnvelopeStage) -> Duration {
        guard !rendersImmediately else { return .zero }
        switch stage {
        case .sealed: return .zero
        case .opening: return .milliseconds(520)
        // The designer's "2 or 3 seconds", taken at a beat the reader will sit through repeatedly.
        case .dwelling: return .milliseconds(900)
        case .rising: return .milliseconds(700)
        case .zooming: return .milliseconds(780)
        }
    }

    /// The curve each beat moves on.
    ///
    /// **One animation per beat, not one for the whole opening.** This used to be a single
    /// `.easeInOut(duration: 0.9)` hung on the carousel, which meant every beat moved for 900ms
    /// whatever its own length was: the flap swung correctly, the page finished rising half a
    /// second before the beat ended, and the zoom — the one the designer's note asks for *slowly* —
    /// ran at nearly twice its intended speed and then sat still. Each beat now moves for exactly
    /// as long as it lasts.
    ///
    /// `nil` at `sealed` and `dwelling` because nothing moves on them, and `nil` throughout under
    /// Reduce Motion, where the sequence is a cut.
    public func animation(of stage: HisploraEnvelopeStage) -> Animation? {
        guard !rendersImmediately else { return nil }
        let seconds = duration(of: stage).seconds
        switch stage {
        case .sealed, .dwelling: return nil
        // Paper swinging on a fold: it leaves fast and settles.
        case .opening: return .easeOut(duration: seconds)
        // Drawn out of the pocket by hand — it starts and stops.
        case .rising: return .easeInOut(duration: seconds)
        // Toward the reader, and never snapping at either end.
        case .zooming: return .easeInOut(duration: seconds)
        }
    }

    /// How fast the page becomes visible as it leaves the pocket.
    ///
    /// Deliberately much shorter than `rising` itself: paper does not fade in. Long enough not to
    /// pop, short enough that what the reader watches is a page *moving* rather than one
    /// materialising in front of the envelope.
    public static let pageRevealDuration: Duration = .milliseconds(200)


    // MARK: - The idle turn (`791:5637`)

    /// How long the card stands still before it turns itself over.
    ///
    /// Longer than the wiggle's interval: a nudge is a twitch and a turn is a whole movement, and
    /// two of them on the same card at the same cadence would be a screen that never settles.
    public static let flipInterval: Duration = .seconds(5.5)
    /// A quarter turn — half the flip. Two of these make the turn, and the face swaps between them.
    public static let flipHalfDuration: Duration = .milliseconds(320)
    /// How long the addressed side is held before the card turns back.
    public static let flipBackDwell: Duration = .milliseconds(1400)
    /// How much depth the turn is drawn with. Enough for the card to read as a physical object
    /// passing edge-on, not so much that its far edge stretches.
    public static let flipPerspective: CGFloat = 0.4

    /// How long a beat of the turn lasts. Zero throughout under Reduce Motion, where the card
    /// simply does not turn — an idle animation is the one kind that has nothing to say if it is
    /// collapsed to a cut, so `SealedLettersViewModel` skips the cycle entirely instead.
    public func duration(ofFlip flip: HisploraEnvelopeFlip) -> Duration {
        guard !rendersImmediately else { return .zero }
        switch flip {
        case .front: return Self.flipHalfDuration
        case .turningToBack, .turningToFront: return Self.flipHalfDuration
        case .back: return Self.flipBackDwell
        }
    }

    /// The curve a beat of the turn moves on. Linear through the two quarter turns so the card
    /// passes edge-on at a constant rate — easing each half separately makes the swap visible as a
    /// hitch in the middle of one turn.
    public func animation(ofFlip flip: HisploraEnvelopeFlip) -> Animation? {
        guard !rendersImmediately else { return nil }
        switch flip {
        case .back: return .easeOut(duration: Self.flipHalfDuration.seconds)
        default: return .linear(duration: Self.flipHalfDuration.seconds)
        }
    }

    /// The whole opening, end to end. Zero under Reduce Motion, which is the point.
    public var total: Duration {
        HisploraEnvelopeStage.allCases.reduce(Duration.zero) { $0 + duration(of: $1) }
    }
}

/// The envelope itself: a photographed paper object with a pocket, a flap, a wax seal and an
/// addressed back, that two papers can be drawn out of.
///
/// **Every layer is a packaged export, and the composition is the code's.** The design draws the
/// closed envelope, its back, and the opened one as separate frames; an app has to get from one to
/// the next, so the flap is a layer with a hinge at its top edge rather than a second picture, the
/// back is the same papers turned about their own centre, and the pocket front is the lower band of
/// the body export drawn a second time over whatever is rising out of it — which is what makes the
/// papers look like they are coming from inside the envelope instead of sliding in front of it.
///
/// **Two papers, not one** (`791:5585`). The frames put a trip summary and a history in the same
/// pocket, each with its own tilt and its own travel: the summary comes almost all the way out and
/// drifts left, the history rises about a quarter of the card and stays where it is. That is why
/// this takes two content slots rather than one — a single slot with two things stacked in it could
/// not give them different journeys.
public struct HisploraEnvelope<Franking: View, Back: View, Paper: View, Companion: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let stage: HisploraEnvelopeStage
    private let flip: HisploraEnvelopeFlip
    private let wiggles: Bool
    private let sequence: HisploraEnvelopeSequence
    private let franking: Franking
    private let back: Back
    private let paper: Paper
    private let companion: Companion

    @State private var wiggleAngle: Double = 0

    /// - Parameters:
    ///   - flip: which way round the card is standing. Only meaningful while it is sealed — an
    ///     envelope being opened is never turned, which `SealedLettersViewModel` guarantees by
    ///     returning it to its front before the first beat of the opening.
    ///   - franking: what is stuck to the pocket — the picture, the stamps, the title.
    ///   - back: what is written on the other side: the stamps and the address (`791:5644`).
    ///   - paper: the first sheet, which comes furthest out.
    ///   - companion: the second, which rises behind it.
    public init(
        stage: HisploraEnvelopeStage,
        flip: HisploraEnvelopeFlip = .front,
        wiggles: Bool = false,
        sequence: HisploraEnvelopeSequence = HisploraEnvelopeSequence(rendersImmediately: false),
        @ViewBuilder franking: () -> Franking,
        @ViewBuilder back: () -> Back,
        @ViewBuilder paper: () -> Paper,
        @ViewBuilder companion: () -> Companion
    ) {
        self.stage = stage
        self.flip = flip
        self.wiggles = wiggles
        self.sequence = sequence
        self.franking = franking()
        self.back = back()
        self.paper = paper()
        self.companion = companion()
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                // **Both faces are always built, and one of them is hidden.** Swapping between two
                // branches gives the card a new identity at the quarter turn, and the ambient beat
                // animation cross-fades the two — which drew the front's wax seal ghosted over the
                // addressed side for the length of the turn. Hiding one instead makes the swap the
                // hard cut it has to be, and `.animation(nil, value: flip)` is what keeps the
                // ambient animation from softening it back into a fade. Scoped to `flip` alone, so
                // the flap, the papers and the zoom — all driven by `stage` — still animate.
                frontFace(size: size)
                    .opacity(flip.showsBack ? 0 : 1)
                    .animation(nil, value: flip)
                backFace(size: size)
                    .opacity(flip.showsBack ? 1 : 0)
                    .animation(nil, value: flip)
            }
            .frame(width: size.width, height: size.height)
            // The card's own turn. The face swaps at the quarter turn, where this has squeezed both
            // of them to no width at all.
            .rotation3DEffect(
                .degrees(flip.angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: HisploraEnvelopeSequence.flipPerspective)
        }
        .aspectRatio(HisploraEnvelopeMetrics.aspectRatio, contentMode: .fit)
        .rotationEffect(.degrees(wiggleAngle))
        .task(id: wiggles) { await runWiggle() }
    }

    // MARK: - The two faces

    private func frontFace(size: CGSize) -> some View {
        ZStack {
            // Behind everything once open, so the flap that has swung over the top of the card
            // lands *behind* the paper rather than on the reader's side of it.
            Group {
                if stage.isOpen { flap(size: size) }
                layer(HisploraEnvelopeMetrics.innerImage, size: size)
            }
            .opacity(envelopeOpacity)
            .zIndex(0)

            papers(size: size)
                // **The papers are in front of the envelope once they are out of it.** Every beat
                // up to the rise, the pocket is drawn over them — that is what makes them read as
                // coming from inside. On the zoom they are larger than the envelope, and the pocket
                // band went on drawing a strip of paper straight across the middle of them.
                .zIndex(stage >= .zooming ? 2 : 1)

            Group {
                // **The front is the whole body export in both states, open included.** It is cut
                // with the pocket's own V — two wings rising to the top corners and a notch between
                // them — which is exactly what an envelope shows once its flap is off the front.
                // Masking it to a straight band across the middle, which is what this did, printed
                // a horizontal seam no envelope has and hid the wings that make the object read as
                // one; the papers are behind it either way, so they still come from inside.
                layer(HisploraEnvelopeMetrics.bodyImage, size: size)
                // Closed, the flap is folded down over the notch. Open, it has swung behind the
                // card and is drawn there instead — see `frontFace`'s first group.
                if !stage.isOpen { flap(size: size) }

                // Above the flap in both states, which is where the frame franks them: the stamps
                // are drawn over the fold (`511:1464`), and a picture half under a flap reads as a
                // clipping bug rather than as an envelope.
                franking
                seal(size: size)
            }
            .opacity(envelopeOpacity)
            .zIndex(stage >= .zooming ? 1 : 2)
        }
    }

    /// The addressed side (`791:5641`).
    ///
    /// **The envelope's own paper, turned about its centre.** `791:5642` and `791:5643` are both
    /// plain crumpled sheets at 179.8° — the back of this envelope is unbroken paper, which is why
    /// only the inner sheet is drawn here and the body is not: the body export carries the pocket's
    /// flap cutout, and rotated it printed a bright trapezoid and two notched corners across the
    /// address. No third export, and there should never be one.
    private func backFace(size: CGSize) -> some View {
        layer(HisploraEnvelopeMetrics.innerImage, size: size)
            .rotationEffect(.degrees(180))
        .overlay { back }
        .frame(width: size.width, height: size.height)
        // Undoes the card's own half turn, so the address reads the right way round rather than
        // mirrored.
        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }

    // MARK: - Layers

    /// The envelope's own papers fall away across the zoom.
    ///
    /// Not decoration: it is what makes the z-order swap above invisible. At the instant the papers
    /// go in front of the pocket they are still barely larger than the envelope, and a bottom edge
    /// appearing over the pocket in one frame reads as a glitch. Fading the paper out over the same
    /// beat the sheets grow through covers the swap, and matches what the beat is: the envelope is
    /// finished with, and the papers are on their way to the reader.
    private var envelopeOpacity: Double { stage >= .zooming ? 0 : 1 }

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
            // Past the fold the reader is looking at the *back* of the flap, standing away from
            // the light the rest of the object is photographed in. Drawn at the export's own
            // brightness it reads as a second, brighter envelope pitched behind the first — the
            // "tent" over the top of the card. The shade is what puts it behind.
            .brightness(stage.isOpen ? -0.14 : 0)
            .saturation(stage.isOpen ? 0.8 : 1)
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

    /// The two sheets: tucked in the pocket, standing out of it, then growing toward the reader —
    /// the three beats of `791:5585` → `791:5533`.
    ///
    /// They are invisible until the envelope is open, and that is a correctness point rather than a
    /// nicety: tucked, each sheet's head stands above the notch's vertex, so on a sealed envelope
    /// it would show through the V the closed flap is covering.
    private func papers(size: CGSize) -> some View {
        ZStack {
            slot(paper, at: .summary, size: size)
            slot(companion, at: .history, size: size)
        }
        .opacity(stage >= .dwelling ? 1 : 0)
        // Scoped to the opacity alone — everything else moves on the ambient beat animation. Run on
        // the beat's own long curve, the papers cross-fade through the whole of their travel and
        // read as appearing in front of the envelope rather than coming out of it.
        .animation(sequence.rendersImmediately
                   ? nil
                   : .linear(duration: HisploraEnvelopeSequence.pageRevealDuration.seconds),
                   value: stage >= .dwelling)
        .scaleEffect(stage >= .zooming ? HisploraEnvelopeMetrics.zoomScale : 1, anchor: .center)
        // They drift back toward the middle as they grow, so a sheet at `zoomScale` stays on the
        // screen it is growing into.
        .offset(y: stage >= .zooming ? -size.height * HisploraEnvelopeMetrics.pageZoomRiseRatio : 0)
    }

    private func slot<Content: View>(
        _ content: Content,
        at slot: HisploraEnvelopeMetrics.PaperSlot,
        size: CGSize
    ) -> some View {
        let width = size.width * HisploraEnvelopeMetrics.paperWidthRatio
        let offset = stage >= .rising ? slot.risenOffset : slot.tuckedOffset
        return content
            .frame(width: width, height: width / HisploraEnvelopeMetrics.paperAspectRatio)
            .rotationEffect(.degrees(slot.rotation))
            .offset(x: offset.x * size.width, y: offset.y * size.height)
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

public extension HisploraEnvelope where Back == EmptyView, Paper == EmptyView, Companion == EmptyView {
    /// An envelope with nothing to draw out of it and nothing on its back — the carousel's
    /// neighbours, and the empty state.
    init(
        stage: HisploraEnvelopeStage = .sealed,
        wiggles: Bool = false,
        @ViewBuilder franking: () -> Franking
    ) {
        self.init(stage: stage, wiggles: wiggles, franking: franking) {
            EmptyView()
        } paper: {
            EmptyView()
        } companion: {
            EmptyView()
        }
    }
}

/// The envelope's measurements and its packaged papers, kept out of the view for the reason
/// `PortraitFrameMetrics` is: a generic type cannot hold stored statics, and proportions are worth
/// testing without building a view to read them.
public enum HisploraEnvelopeMetrics {

    /// 290 × 173.999 in `511:1421`. `791:5549` redraws the same pocket at 339.814 × 202.714, which
    /// is the same shape to within a percent — so the card keeps its ratio and the new frame's
    /// numbers are converted against it below rather than the card being re-cut.
    public static let aspectRatio: CGFloat = 290.0 / 173.999
    /// The flap is 120.652 of the card's 173.999.
    public static let flapHeightRatio: CGFloat = 120.652 / 173.999
    /// Where the pocket's notch bottoms out, as a fraction of the card's height — the vertex of
    /// the V the body export is cut with (220 of its 522 pixels).
    ///
    /// **Nothing masks anything by it any more.** It used to be the lip of a straight band cut out
    /// of the body, which is what printed a horizontal seam across an open envelope; the export's
    /// own alpha is the occlusion now. It is kept because it is where a tucked sheet stops being
    /// visible, which is what the slot offsets below are set against.
    public static let pocketNotchVertexRatio: CGFloat = 220.0 / 522.0
    /// The wax, 58 wide, struck at (117, 90) and 53.399 tall (`719:3292`). It ships on a square
    /// 58-point board with the wax centred on it, because `HisploraWaxSeal` fits a square — so the
    /// board's top edge is 2.3 above the wax's, and that is in the centre below.
    public static let sealSizeRatio: CGFloat = 58.0 / 290.0
    public static let sealCentre = CGPoint(x: (117 + 58.0 / 2) / 290.0,
                                           y: (90 + 53.399 / 2) / 173.999)

    /// A sheet is 172.5 wide against the pocket's 339.814 (`791:5595`).
    public static let paperWidthRatio: CGFloat = 172.5 / 339.814
    /// **The card's own shape, not the frame's crop of it.** `791:5595` cuts the sheet at
    /// 172.5 × 113.5, which is the *head* of a 344 × 321 card — the export stops where the pocket
    /// hides the rest. Drawn that way in the app the paper is a card with its picture and its
    /// control sliced off, which is what a reader sees as "the asset is cut". The whole card is
    /// drawn instead, at the card's own ratio, and the envelope hides whatever is still inside it —
    /// the same object the modal opens, at a different size.
    public static let paperAspectRatio: CGFloat =
        HisploraJournalPaperMetrics.width / HisploraJournalPaperMetrics.height

    /// Where each sheet sits, tucked and risen, as offsets from the card's own centre.
    ///
    /// Read off `791:5585` and `791:5533` and converted from the `open_letter` box — whose top is
    /// the flap's tip — to the pocket, whose top-left is (0, 166.26) of that box and which is what
    /// this view actually draws. The two sheets travel differently on purpose: the summary comes
    /// nearly clear of the envelope and drifts left, the history rises about a quarter of the card
    /// and stays put, which is what stops them reading as one object splitting in two.
    public enum PaperSlot: String, Sendable, CaseIterable {
        case summary
        case history

        /// The frame's own tilt, which each sheet keeps through its whole travel.
        public var rotation: Double {
            switch self {
            case .summary: -5.64
            case .history: 9.33
            }
        }

        /// In the pocket, and peeking through the notch.
        ///
        /// **Re-authored against the V.** The old numbers put each sheet's head above a straight
        /// band that no longer exists: the front is the whole cut envelope now, so what shows of a
        /// tucked card is the strip standing above the wing it sits behind. Each sheet is a whole
        /// card and the card is nearly square, so these are set from the card's own top edge rather
        /// than converted out of the frame's crop.
        public var tuckedOffset: CGPoint {
            switch self {
            case .summary: CGPoint(x: -0.17509, y: -0.02)
            case .history: CGPoint(x: 0.21602, y: -0.04)
            }
        }

        public var risenOffset: CGPoint {
            switch self {
            case .summary: CGPoint(x: -0.25454, y: -0.50)
            case .history: CGPoint(x: 0.21602, y: -0.34)
            }
        }
    }

    /// And where the pair settles while it zooms — nearer the middle, so a sheet at `zoomScale`
    /// stays on the screen it is growing into.
    public static let pageZoomRiseRatio: CGFloat = 0.06
    /// And how much they grow on the last beat, before the modal takes over (`791:5551`).
    ///
    /// Lower than the 2.1 a single page used to grow to, and lower again since each sheet became a
    /// whole card rather than its head: two nearly-square cards spread across more than the
    /// envelope's width, and anything larger walked them off the top and the sides of the screen
    /// before the modal arrived.
    public static let zoomScale: CGFloat = 1.3

    public static let bodyImage: Image? = HisploraWaxSealMetrics.image(named: "envelope-body")
    public static let flapImage: Image? = HisploraWaxSealMetrics.image(named: "envelope-flap")
    public static let innerImage: Image? = HisploraWaxSealMetrics.image(named: "envelope-inner")
    /// The tape survived the `719:3285` redraw. That frame draws the bare envelope and has no tape
    /// in it, but the tape is not part of the envelope — it holds the quest's photograph onto the
    /// pocket in `511:1464`, which `SealedLetterEnvelope` still draws.
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
