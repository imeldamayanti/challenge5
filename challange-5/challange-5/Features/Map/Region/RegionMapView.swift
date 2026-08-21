import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

struct RegionMapView: View {
    @Environment(\.kultaraPalette) private var palette
    /// Pixels to the point, so the pyramid is asked for the level that matches what the device
    /// will actually paint rather than the level that matches the point count.
    @Environment(\.displayScale) private var displayScale

    private let model: RegionMapViewModel
    private let onSelect: (String) -> Void
    private let onClose: (() -> Void)?

    /// Zoom is the answer to the one thing fit-to-screen costs. Quests in a single town sit within
    /// a few hundred metres of one another, so at island scale their markers land on top of each
    /// other and stop being 44-point targets (`NFR-A11Y-06`). The map opens fitted, as the design
    /// draws it, and pinch or a double tap pulls a cluster apart.
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var drag: CGSize = .zero
    @State private var hasOpened = false

    /// Set while a pan or a pinch is settling. A pinch's two fingers do not lift together, and the
    /// second lift lands as a tap on whatever marker it happens to be over — which is the reported
    /// "kepencet pas zoom" case. `MapMarkerGesture.settleDelay` is how long markers stay deaf.
    @State private var isSettling = false
    /// Identifies the settle in flight, so a second gesture ending mid-window does not have its
    /// window cut short by the first one's timer firing.
    @State private var settleToken = UUID()

    /// The viewport and the drawn artwork, recorded so the gesture handlers can clamp the pan they
    /// store. A gesture callback has no `GeometryProxy`.
    @State private var viewport: CGSize = .zero
    @State private var content: CGSize = .zero

    private static let maximumZoom: CGFloat = 6

    /// How far out a pinch may go. **1 — the artwork filling the viewport is as far out as the map
    /// goes.**
    ///
    /// The shipped illustration is a landscape drawing of the whole island shown on a portrait
    /// screen, so filling crops roughly two thirds of its width; a floor below 1 would show the
    /// whole island but would letterbox it, and the author's decision on 2026-08-19 was that the
    /// current height is the limit. Pinching out therefore stops where the drawing still covers
    /// the screen, and seeing the rest of the island is a pan rather than a zoom.
    private static let minimumZoom: CGFloat = 1

    init(
        model: RegionMapViewModel,
        onSelect: @escaping (String) -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.model = model
        self.onSelect = onSelect
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(max(zoom * pinch, Self.minimumZoom), Self.maximumZoom)
            // `.fill`, not `.fit`: the design's map runs to every edge, and the shipped
            // illustration is within a percent of the screen's own aspect ratio, so filling
            // crops almost nothing.
            let size = filledSize(in: proxy.size)

            let offset = clampedPan(in: proxy.size, content: size, scale: scale)

            ZStack(alignment: .topLeading) {
                mapSurface(size: size, viewport: proxy.size, scale: scale, offset: offset)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                // Markers are drawn in screen space, not in map space: inside the `scaleEffect`
                // they would grow with the artwork, so zooming would separate two labels and
                // enlarge them by exactly the same factor and never pull them apart. Outside it,
                // the marker keeps its 44-point target and its type stays readable at every zoom.
                ForEach(Array(model.labelOrderedPins.enumerated()), id: \.element.id) { index, pin in
                    let point = position(of: pin, drawnAt: size, viewport: proxy.size,
                                         scale: scale, offset: offset)
                    marker(pin, labelBelow: index.isMultiple(of: 2))
                        .position(x: point.x, y: point.y)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .contentShape(Rectangle())
            // One combined gesture, not `.gesture` plus `.simultaneousGesture`. Attached
            // separately, the drag claims the touch sequence the moment a finger moves and the
            // magnify gesture never receives the second one — pinch-to-zoom silently does
            // nothing. `SimultaneousGesture` hands both the same events.
            .gesture(SimultaneousGesture(panGesture, zoomGesture))
            .onTapGesture(count: 2) { toggleZoom() }
            .onAppear {
                viewport = proxy.size
                content = size
                openOnThePins(drawnAt: size, viewport: proxy.size)
            }
            .onChange(of: proxy.size) { _, newViewport in
                viewport = newViewport
                content = filledSize(in: newViewport)
            }
        }
        .kultaraSpeckledGround(palette.photoScrim)
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) { closeButton }
        // Deliberately no `accessibilityLabel` on this container: naming it turns the whole map
        // into a single accessibility element and swallows every marker inside it, which is both a
        // `NFR-A11Y-02` failure and how the marker assertions in the XCUITest started finding
        // nothing. The markers name themselves.
    }

    /// True while the map is being moved, and for a moment afterwards. Markers do not hit-test in
    /// this state, so a touch that is part of a pan or a pinch cannot become a navigation.
    ///
    /// A finger that has landed but not yet moved leaves both gesture states at rest, so a plain
    /// tap on a pin still reaches it.
    private var isManipulating: Bool {
        isSettling || drag != .zero || pinch != 1
    }

    /// Holds markers deaf for `MapMarkerGesture.settleDelay` after a gesture ends.
    private func settleAfterGesture() {
        let token = UUID()
        settleToken = token
        isSettling = true
        Task { @MainActor in
            try? await Task.sleep(for: MapMarkerGesture.settleDelay)
            // A later gesture has taken over; its own timer owns the flag now.
            guard settleToken == token else { return }
            isSettling = false
        }
    }

    /// The minimum gap between two markers the screen will open with — wider than a marker,
    /// which is as wide as its label, so two of them cannot land on top of each other.
    private static let minimumMarkerSeparation: CGFloat = 200

    /// Narrower than the design's 202, because the design's map has four labels on it and this one
    /// has as many as the content ships.
    private static let labelWidth: CGFloat = 150

    /// The frame draws its landmark clusters at 159 points across. Held here rather than taken as
    /// the component's default so the two numbers that have to agree — the figure's width and the
    /// label's — sit next to each other.
    private static let figureWidth: CGFloat = 120

    /// Opens fitted when the pins are spread and on the cluster when they are not, then centres
    /// what it zoomed into. Runs once — a reader who has panned away is not dragged back.
    ///
    /// The centring is not conditional on having zoomed in. The shipped illustration is a
    /// landscape drawing of the whole island shown on a portrait screen, so filling the viewport
    /// already crops two thirds of its width away — and the middle of Bali is not where the quest
    /// is. Opening centred on the artwork put the one marker half off the right edge.
    private func openOnThePins(drawnAt size: CGSize, viewport: CGSize) {
        guard !hasOpened else { return }
        hasOpened = true

        let scale = model.initialZoom(
            drawnAt: size,
            minimumSeparation: Self.minimumMarkerSeparation,
            maximum: Self.maximumZoom)
        guard !model.pins.isEmpty else { return }

        // Positive offset moves the content right and down, so the centroid's displacement from
        // the middle of the map is negated.
        let centroid = model.pinCentroid
        let target = CGSize(
            width: (0.5 - centroid.x) * size.width * scale,
            height: (0.5 - centroid.y) * size.height * scale)

        zoom = scale
        let scaled = CGSize(width: size.width * scale, height: size.height * scale)
        let limitX = max((scaled.width - viewport.width) / 2, 0)
        let limitY = max((scaled.height - viewport.height) / 2, 0)
        pan = CGSize(width: min(max(target.width, -limitX), limitX),
                     height: min(max(target.height, -limitY), limitY))
    }

    /// Where a pin lands on screen: its normalised point through the same centre-scale-then-offset
    /// the artwork gets, so a marker drawn outside the `scaleEffect` still sits exactly on the
    /// place it marks.
    private func position(
        of pin: RegionMapPin,
        drawnAt size: CGSize,
        viewport: CGSize,
        scale: CGFloat,
        offset: CGSize
    ) -> CGPoint {
        CGPoint(
            x: viewport.width / 2 + (size.width * pin.point.x - size.width / 2) * scale + offset.width,
            y: viewport.height / 2 + (size.height * pin.point.y - size.height / 2) * scale + offset.height)
    }

    /// The size the illustration is drawn at before zoom: filled into the viewport, so neither
    /// letterboxing nor a cropped coastline depends on the device.
    private func filledSize(in viewport: CGSize) -> CGSize {
        let ratio = max(model.aspectRatio, 0.05)
        let byWidth = CGSize(width: viewport.width, height: viewport.width / ratio)
        let byHeight = CGSize(width: viewport.height * ratio, height: viewport.height)
        return byWidth.height >= viewport.height ? byWidth : byHeight
    }

    /// Keeps the artwork covering the viewport at every zoom level. Without it a pan can drag the
    /// island off the screen entirely and leave the reader looking at the backing colour with no
    /// way of knowing which direction to drag back.
    private func clampedPan(in viewport: CGSize, content: CGSize, scale: CGFloat) -> CGSize {
        let scaled = CGSize(width: content.width * scale, height: content.height * scale)
        let limitX = max((scaled.width - viewport.width) / 2, 0)
        let limitY = max((scaled.height - viewport.height) / 2, 0)
        // The stored pan was measured at the stored zoom, so it grows with the live pinch. Without
        // this the artwork slides under the fingers during a pinch and snaps back the moment the
        // gesture ends.
        let ratio = scale / max(zoom, 0.0001)
        return CGSize(
            width: min(max(pan.width * ratio + drag.width, -limitX), limitX),
            height: min(max(pan.height * ratio + drag.height, -limitY), limitY))
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in state = value.translation }
            .onEnded { value in
                commitPan(CGSize(width: pan.width + value.translation.width,
                                 height: pan.height + value.translation.height),
                          at: zoom)
                settleAfterGesture()
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                let target = min(max(zoom * value.magnification, Self.minimumZoom),
                                 Self.maximumZoom)
                let ratio = target / max(zoom, 0.0001)
                zoom = target
                if target == Self.minimumZoom {
                    // Back at fill. The pan is *not* reset: on this artwork fill still leaves two
                    // thirds of the island off either side, so zeroing it would throw the reader
                    // back to the middle of the drawing rather than leaving them where they were.
                    commitPan(pan, at: target)
                } else {
                    commitPan(CGSize(width: pan.width * ratio, height: pan.height * ratio), at: target)
                }
                settleAfterGesture()
            }
    }

    /// Stores a pan already clamped to the artwork's edges. `clampedPan` clamps what is *drawn*, but
    /// the stored value has to be clamped too — otherwise repeated drags accumulate an offset far
    /// outside the map and the next drag back spends its whole distance unwinding a number nothing
    /// on screen ever reflected.
    private func commitPan(_ proposed: CGSize, at scale: CGFloat) {
        let scaled = CGSize(width: content.width * scale, height: content.height * scale)
        let limitX = max((scaled.width - viewport.width) / 2, 0)
        let limitY = max((scaled.height - viewport.height) / 2, 0)
        pan = CGSize(width: min(max(proposed.width, -limitX), limitX),
                     height: min(max(proposed.height, -limitY), limitY))
    }

    /// Double tap cycles between the design's fitted view and a reading zoom. It does not visit
    /// the pinched-out whole-island view: that is somewhere the reader asked to go, not somewhere
    /// a stray double tap should land them.
    private func toggleZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if zoom > 1 {
                zoom = 1
                pan = .zero
            } else {
                zoom = 2.5
            }
        }
    }

    /// The artwork, drawn where the pan and the zoom put it.
    ///
    /// **The tiled branch is not an optimisation, it is the fix.** The old drawing was one
    /// `Image` framed at the resting size and then `scaleEffect`-ed: SwiftUI rasterises the image
    /// once at that frame — 402 points, about 1200 pixels on this screen — and magnifies the
    /// *layer*, so a reader pinching to 6× is stretching a 1200-pixel bitmap to 7200 and most of
    /// the 1469-pixel source is never consulted. That is the break-up this replaces. A `Canvas`
    /// re-renders on every frame at the size actually on screen, and the pyramid hands it a level
    /// whose pixels match, so zooming reads *into* the drawing rather than across a fixed raster.
    ///
    /// Falls back to the single image when content ships no pyramid — same picture, same
    /// behaviour as before, including the `scaleEffect` and its ceiling.
    @ViewBuilder private func mapSurface(
        size: CGSize, viewport: CGSize, scale: CGFloat, offset: CGSize
    ) -> some View {
        if let tiles = model.tiles {
            Canvas(opaque: false) { context, _ in
                draw(tiles, in: &context,
                     artwork: artworkRect(size: size, viewport: viewport, scale: scale, offset: offset),
                     viewport: viewport)
            }
            .frame(width: viewport.width, height: viewport.height)
            .accessibilityHidden(true)
        } else {
            mapImage(size: size)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .offset(offset)
        }
    }

    /// Where the artwork lands in the viewport, in the viewport's own coordinates.
    ///
    /// This is the same centre-scale-then-offset `position(of:)` puts the markers through, written
    /// out once instead of relying on `scaleEffect` and `offset` to perform it. The two must agree
    /// exactly or every marker drifts off the place it marks.
    private func artworkRect(
        size: CGSize, viewport: CGSize, scale: CGFloat, offset: CGSize
    ) -> CGRect {
        let drawn = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: (viewport.width - drawn.width) / 2 + offset.width,
            y: (viewport.height - drawn.height) / 2 + offset.height,
            width: drawn.width,
            height: drawn.height)
    }

    /// Paints the tiles that fall inside the viewport, at the level sized for what is on screen.
    private func draw(
        _ tiles: RasterTileImageStore,
        in context: inout GraphicsContext,
        artwork: CGRect,
        viewport: CGSize
    ) {
        guard artwork.width > 0, artwork.height > 0 else { return }

        let visible = CGRect(origin: .zero, size: viewport).intersection(artwork)
        guard !visible.isNull, !visible.isEmpty else { return }

        let zoom = tiles.zoom(forDrawnWidth: artwork.width, displayScale: displayScale)
        let region = RasterTilePyramid.NormalizedRect(
            minX: Double((visible.minX - artwork.minX) / artwork.width),
            minY: Double((visible.minY - artwork.minY) / artwork.height),
            maxX: Double((visible.maxX - artwork.minX) / artwork.width),
            maxY: Double((visible.maxY - artwork.minY) / artwork.height))

        for tile in tiles.pyramid.tiles(covering: region, atZoom: zoom) {
            guard let image = tiles.image(for: tile) else { continue }
            // `.high` on the `Image`, because a `GraphicsContext` has no interpolation setting of
            // its own. It matters between levels: the chosen level is at least as many pixels as
            // the rectangle, so every tile is being *down*-sampled, and the default quality prints
            // the chart's ink lines as stipple.
            context.draw(
                Image(uiImage: image).interpolation(.high),
                in: snapped(tile.rect(in: artwork), to: displayScale))
        }
    }

    /// Tile edges pulled onto the device's pixel grid.
    ///
    /// Two neighbours share an edge as an exact `Double`, but drawn at a fractional pixel each is
    /// antialiased against nothing and the seam prints as a bright hairline across the map. Both
    /// tiles round that shared edge the same way, so rounding closes the seam rather than trading
    /// it for an overlap.
    private func snapped(_ rect: CGRect, to displayScale: CGFloat) -> CGRect {
        let s = max(displayScale, 1)
        let minX = (rect.minX * s).rounded() / s
        let minY = (rect.minY * s).rounded() / s
        let maxX = (rect.maxX * s).rounded() / s
        let maxY = (rect.maxY * s).rounded() / s
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    @ViewBuilder private func mapImage(size: CGSize) -> some View {
        if let url = model.mapImageURL, let image = BundledImage.load(url) {
            image
                .resizable()
                .frame(width: size.width, height: size.height)
                .accessibilityHidden(true)
        } else {
            Rectangle()
                .fill(palette.paperSunken.color)
                .frame(width: size.width, height: size.height)
                .overlay(
                    Text(UIStrings.string(.mapUnavailable, model.language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .padding(KultaraMetrics.lg))
        }
    }

    /// A marker as the design draws one: the place itself, and its name written on the map in the
    /// display serif with a hard outline. `labelBelow` alternates down the cluster, so two adjacent
    /// markers put their names on opposite sides of the pin instead of into the same strip of map.
    ///
    /// Only the pin is pressable. The label is up to `labelWidth` points wide and several lines
    /// tall, so a `Button` wrapped around the whole stack made a target mostly of transparent map —
    /// wide enough that two adjacent markers' rectangles overlapped and a touch on empty coastline
    /// navigated. `NFR-A11Y-06` is satisfied by the pin's own 44-point square, and the label is
    /// already `accessibilityHidden` inside `MapPlaceLabel`, so VoiceOver loses nothing.
    private func marker(_ pin: RegionMapPin, labelBelow: Bool) -> some View {
        VStack(spacing: 0) {
            if !labelBelow {
                MapPlaceLabel(pin.title, width: Self.labelWidth)
                    .padding(.bottom, KultaraMetrics.xs)
            }
            pinSymbol(pin)
            if labelBelow {
                MapPlaceLabel(pin.title, width: Self.labelWidth)
                    // The frame tucks the name up against the fog rather than spacing it off the
                    // marker — the label reads as written on the map, not as a caption under a pin.
                    .padding(.top, -KultaraMetrics.xs)
            }
        }
        // One element for VoiceOver, named and activatable. The rotor cannot activate a bare
        // `DragGesture`, so the action is declared explicitly rather than inherited from a button.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pin.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onSelect(pin.questID) }
    }

    /// The pressable part. A `DragGesture(minimumDistance: 0)` rather than a `Button`, because a
    /// button fires on release regardless of how far the finger travelled first — so a drag that
    /// began on a pin navigated on lift. Selection needs the touch to have stayed put
    /// (`MapMarkerGesture.isTap`).
    private func pinSymbol(_ pin: RegionMapPin) -> some View {
        MapLandmarkFigure(artwork: MapLandmarkCatalog.artwork(forQuestID: pin.questID),
                          width: Self.figureWidth)
            // The pressable area is a 44-point square over the building, not the figure's own
            // bounds. The figure is 120 points wide and most of that width is fog at low alpha, so
            // a target the size of the drawing would be mostly transparent map — wide enough that
            // two adjacent markers' rectangles overlap and a touch on open sea navigates. That is
            // the same failure the old label-sized target had, and `NFR-A11Y-06` is satisfied by
            // the square regardless.
            .overlay { touchTarget(pin) }
    }

    /// The building sits in the upper third of the figure — 27.5 points down an 87-point cluster —
    /// so the square is raised off centre to land on the drawing rather than on the fog beneath it.
    private func touchTarget(_ pin: RegionMapPin) -> some View {
        let height = MapLandmarkFigure.height(forWidth: Self.figureWidth)
        return Color.clear
            .frame(width: KultaraMetrics.minimumTapTarget,
                   height: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
            .offset(y: MapLandmarkFigure.buildingCentreFraction * height - height / 2)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard MapMarkerGesture.isTap(translation: value.translation) else { return }
                        onSelect(pin.questID)
                    }
            )
            .allowsHitTesting(!isManipulating)
    }

    /// The way back to the list. The map is full-bleed, so there is no navigation bar to hold it —
    /// and a full-screen surface with no visible exit is the version of this design that traps
    /// someone who opened it by accident.
    @ViewBuilder private var closeButton: some View {
        if let onClose {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.inkOnSeal.color)
                    .frame(width: KultaraMetrics.minimumTapTarget,
                           height: KultaraMetrics.minimumTapTarget)
                    .background(palette.sealFill.color, in: Circle())
            }
            .accessibilityLabel(UIStrings.string(.questListListTab, model.language))
            .padding(.leading, KultaraMetrics.lg)
            .padding(.top, KultaraMetrics.xxl)
        }
    }
}
