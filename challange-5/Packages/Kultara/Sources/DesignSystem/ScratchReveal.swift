import SwiftUI

/// How much of a covered picture a rubbing gesture has uncovered — `98:1588`'s "swipe photo frame
/// to reveal the legends".
///
/// A value rather than view state, for the same reason `TypewriterProgress` is one: the rule that
/// decides when the reveal is finished — and therefore when the story flow moves on to `187:866` —
/// is a rule about coverage, and a rule that lives only inside a `@State` is a rule no test can
/// reach without a simulator. The view above owns the strokes it draws; this owns the one question
/// "is enough of it gone yet".
public struct ScratchRevealField: Sendable, Equatable {

    /// The picture is divided into `resolution × resolution` cells, and a cell counts as uncovered
    /// once the brush passes over its centre. 12 is fine enough that one diagonal swipe does not
    /// finish the reveal, coarse enough that a walker rubbing with a thumb is not asked to colour
    /// in the edges.
    public static let defaultResolution = 12

    /// The fraction of cells that has to go before the reveal counts as done.
    ///
    /// Not 1.0, and that number is load-bearing. Every cell means the four corners of a rectangle
    /// whose picture is clipped to an *ellipse* — cells that are not part of the portrait at all —
    /// so a walker who had rubbed the entire face away would still be stuck on the screen. An
    /// ellipse fills π/4 ≈ 0.785 of its box; 0.6 sits comfortably inside that with room for the
    /// gaps a real thumb leaves behind.
    public static let defaultCompletionThreshold: Double = 0.6

    public let resolution: Int
    public let completionThreshold: Double

    /// Cell indices, row-major. A `Set` because a rub crosses the same cell many times and the
    /// count has to be of distinct cells, not of touches.
    private var revealedCells: Set<Int> = []

    public init(
        resolution: Int = ScratchRevealField.defaultResolution,
        completionThreshold: Double = ScratchRevealField.defaultCompletionThreshold
    ) {
        self.resolution = max(1, resolution)
        self.completionThreshold = min(max(completionThreshold, 0), 1)
    }

    private var cellCount: Int { resolution * resolution }

    public var revealedFraction: Double {
        Double(revealedCells.count) / Double(cellCount)
    }

    public var isComplete: Bool { revealedFraction >= completionThreshold }

    /// Marks every cell whose centre falls inside the brush.
    ///
    /// Only the cells the brush's bounding box can touch are examined, so the cost is the brush's
    /// area rather than the grid's — a drag reports points continuously and this runs on every one
    /// of them.
    public mutating func reveal(at point: CGPoint, in size: CGSize, brushRadius: CGFloat) {
        guard size.width > 0, size.height > 0, brushRadius > 0 else { return }

        let cellWidth = size.width / CGFloat(resolution)
        let cellHeight = size.height / CGFloat(resolution)
        let minColumn = max(0, Int(((point.x - brushRadius) / cellWidth).rounded(.down)))
        let maxColumn = min(resolution - 1, Int(((point.x + brushRadius) / cellWidth).rounded(.down)))
        let minRow = max(0, Int(((point.y - brushRadius) / cellHeight).rounded(.down)))
        let maxRow = min(resolution - 1, Int(((point.y + brushRadius) / cellHeight).rounded(.down)))
        guard minColumn <= maxColumn, minRow <= maxRow else { return }

        for row in minRow...maxRow {
            for column in minColumn...maxColumn {
                let centreX = (CGFloat(column) + 0.5) * cellWidth
                let centreY = (CGFloat(row) + 0.5) * cellHeight
                let dx = centreX - point.x
                let dy = centreY - point.y
                if dx * dx + dy * dy <= brushRadius * brushRadius {
                    revealedCells.insert(row * resolution + column)
                }
            }
        }
    }

    /// Everything at once — what Reduce Motion, VoiceOver and the explicit control all end at.
    public mutating func revealEverything() {
        revealedCells = Set(0..<cellCount)
    }
}

/// The picture under a cover the walker rubs away — `98:1588` into `223:1987`.
///
/// Two copies of the same content are stacked: the clear one, and an obscured one over it whose
/// mask is a full-bleed rectangle minus every stroke drawn so far. Erasing the mask rather than
/// painting the clear copy is what makes the uncovered part *the picture itself* at full fidelity,
/// with no seam where a painted patch meets the original.
///
/// **The gesture is never the only way through.** A rub is undiscoverable to anyone who does not
/// try it and is not a control at all for VoiceOver, so under Reduce Motion or VoiceOver this
/// renders uncovered from the first frame and the screen above shows its own action instead
/// (`NFR-A11Y-04`, `NFR-A11Y-05`).
public struct HisploraScratchReveal<Content: View>: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private let brushRadius: CGFloat
    private let veil: KeyPath<HisploraPalette, SRGBColor>
    private let onProgress: (Double) -> Void
    private let onComplete: () -> Void
    private let content: Content

    @State private var field = ScratchRevealField()
    /// One array per continuous drag. Kept separate so lifting the finger and starting again
    /// somewhere else does not draw a line between the two places.
    @State private var strokes: [[CGPoint]] = []
    @State private var hasCompleted = false

    /// `brushRadius` is the rubbed radius in points. 34 is a little over a fingertip, which is what
    /// keeps the reveal feeling like wiping rather than colouring.
    public init(
        brushRadius: CGFloat = 34,
        veil: KeyPath<HisploraPalette, SRGBColor> = \.brownStone,
        onProgress: @escaping (Double) -> Void = { _ in },
        onComplete: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.brushRadius = brushRadius
        self.veil = veil
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.content = content()
    }

    /// Whether the cover is skipped outright. Not the same as "finished": the screen above reads
    /// the same two environment values to decide whether to offer its explicit action.
    private var rendersUncovered: Bool { reduceMotion || voiceOverEnabled }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                content
                cover
                    .mask(coverMask(size: size))
                    .opacity(rendersUncovered || hasCompleted ? 0 : 1)
                    .animation(.easeOut(duration: 0.35), value: hasCompleted)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            // High priority, because this sits inside the cutscene's `ScrollView` and a plain
            // `.gesture` loses the drag to the scroll the moment the finger moves — which is every
            // rub. The screen still scrolls; it scrolls from anywhere that is not the picture.
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in rub(at: value.location, in: size) }
                    .onEnded { _ in strokes.append([]) })
        }
    }

    /// The obscured copy: the same picture out of focus, under a wash of the ground colour. Blur
    /// alone still reads as a photograph of a face; the wash is what makes it a covered frame.
    private var cover: some View {
        ZStack {
            content
                .blur(radius: 18)
                .saturation(0.55)
            palette[keyPath: veil].color.opacity(0.55)
        }
    }

    /// White everywhere the cover still stands, transparent everywhere it has been rubbed. Drawn
    /// inside an explicit layer so `destinationOut` erases the rectangle filled just above it
    /// rather than compositing against whatever is behind the canvas.
    private func coverMask(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            context.drawLayer { layer in
                layer.fill(
                    Path(CGRect(origin: .zero, size: canvasSize)), with: .color(.white))
                layer.blendMode = .destinationOut
                for stroke in strokes {
                    guard let path = path(for: stroke) else { continue }
                    layer.stroke(
                        path,
                        with: .color(.white),
                        style: StrokeStyle(
                            lineWidth: brushRadius * 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// A stroke as a path. A single touch is given a hair of length, because a path that only
    /// moves strokes nothing and a tap that erased no pixels would look like a dead frame.
    private func path(for stroke: [CGPoint]) -> Path? {
        guard let first = stroke.first else { return nil }
        var path = Path()
        path.move(to: first)
        if stroke.count == 1 {
            path.addLine(to: CGPoint(x: first.x + 0.01, y: first.y))
        } else {
            for point in stroke.dropFirst() { path.addLine(to: point) }
        }
        return path
    }

    private func rub(at location: CGPoint, in size: CGSize) {
        guard !rendersUncovered, !hasCompleted else { return }

        field.reveal(at: location, in: size, brushRadius: brushRadius)
        if strokes.isEmpty { strokes.append([]) }
        strokes[strokes.count - 1].append(location)
        onProgress(field.revealedFraction)

        guard field.isComplete else { return }
        hasCompleted = true
        onComplete()
    }
}
