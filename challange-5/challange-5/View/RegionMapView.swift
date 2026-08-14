import ContentKit
import DesignSystem
import SwiftUI

struct RegionMapView: View {
    @Environment(\.kultaraPalette) private var palette

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
            let scale = clampedZoom
            // `.fill`, not `.fit`: the design's map runs to every edge, and the shipped
            // illustration is within a percent of the screen's own aspect ratio, so filling
            // crops almost nothing.
            let size = filledSize(in: proxy.size)

            let offset = clampedPan(in: proxy.size, content: size, scale: scale)

            ZStack(alignment: .topLeading) {
                mapImage(size: size)
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale)
                    .offset(offset)
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
        .background(palette.photoScrim.color)
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) { closeButton }
        // Deliberately no `accessibilityLabel` on this container: naming it turns the whole map
        // into a single accessibility element and swallows every marker inside it, which is both a
        // `NFR-A11Y-02` failure and how the marker assertions in the XCUITest started finding
        // nothing. The markers name themselves.
    }

    private var clampedZoom: CGFloat {
        min(max(zoom * pinch, 1), Self.maximumZoom)
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

    /// Narrower than the design's, because the design's map has two labels on it and this one has
    /// as many as the content ships.
    private static let labelWidth: CGFloat = 130

    /// Opens fitted when the pins are spread and on the cluster when they are not, then centres
    /// what it zoomed into. Runs once — a reader who has panned away is not dragged back.
    private func openOnThePins(drawnAt size: CGSize, viewport: CGSize) {
        guard !hasOpened else { return }
        hasOpened = true

        let scale = model.initialZoom(
            drawnAt: size,
            minimumSeparation: Self.minimumMarkerSeparation,
            maximum: Self.maximumZoom)
        guard scale > 1 else { return }

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
                let target = min(max(zoom * value.magnification, 1), Self.maximumZoom)
                let ratio = target / max(zoom, 0.0001)
                zoom = target
                if target == 1 {
                    pan = .zero
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
        VStack(spacing: KultaraMetrics.xs) {
            if !labelBelow { MapPlaceLabel(pin.title, width: Self.labelWidth) }
            pinSymbol(pin)
            if labelBelow { MapPlaceLabel(pin.title, width: Self.labelWidth) }
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
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 28))
            .foregroundStyle(palette.sealFill.color)
            .background(Circle().fill(palette.inkOnSeal.color).padding(3))
            .shadow(color: palette.photoScrim.color.opacity(0.45), radius: 3, y: 1)
            .frame(width: KultaraMetrics.minimumTapTarget,
                   height: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
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
