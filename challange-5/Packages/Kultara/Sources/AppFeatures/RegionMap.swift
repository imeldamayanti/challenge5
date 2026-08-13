import ContentKit
import DesignSystem
import SwiftUI

/// One quest marker on the illustrated map, at its start point.
///
/// A pin per quest rather than per Place: the map is a discovery surface, and a traveller choosing a
/// walk wants to see where walks *begin*. Marking all five stops of every quest would draw the
/// route's shape onto a map that is explicitly not a navigation aid (`FR-MAP-03`).
public struct RegionMapPin: Sendable, Identifiable, Equatable {
    public let questID: String
    public let title: String
    public let placeName: String
    public let point: MapPoint
    public let accessibilityLabel: String

    public var id: String { questID }
}

@MainActor
@Observable
public final class RegionMapViewModel {

    public let language: ContentLanguage
    public let pins: [RegionMapPin]
    public let mapImageURL: URL?
    public let aspectRatio: Double

    /// The centre of the pin cluster, so the map can open showing the pins rather than whichever
    /// corner of the illustration happens to sit at the scroll origin. Bali's south coast is two
    /// thirds of the way down a portrait drawing; without this the first thing a user sees is
    /// open sea.
    public var pinCentroid: MapPoint {
        guard !pins.isEmpty else { return MapPoint(x: 0.5, y: 0.5) }
        let x = pins.map(\.point.x).reduce(0, +) / Double(pins.count)
        let y = pins.map(\.point.y).reduce(0, +) / Double(pins.count)
        return MapPoint(x: x, y: y)
    }

    /// Pins ordered top to bottom, so the alternating label side is stable rather than following
    /// manifest order — otherwise reordering content silently reshuffles the layout.
    public var labelOrderedPins: [RegionMapPin] {
        pins.sorted { ($0.point.y, $0.point.x) < ($1.point.y, $1.point.x) }
    }

    /// The distance between the two closest pins, in points, once the illustration is drawn at
    /// `size`. Nil when there are fewer than two pins.
    public func closestPinSeparation(drawnAt size: CGSize) -> CGFloat? {
        guard pins.count > 1 else { return nil }
        var closest: CGFloat = .greatestFiniteMagnitude
        for (index, pin) in pins.enumerated() {
            for other in pins[(index + 1)...] {
                let dx = (pin.point.x - other.point.x) * size.width
                let dy = (pin.point.y - other.point.y) * size.height
                closest = min(closest, hypot(dx, dy))
            }
        }
        return closest
    }

    /// How far in the map has to open for the closest two markers to be `minimumSeparation` points
    /// apart.
    ///
    /// The design draws the island whole, and whole is how this opens whenever the content allows
    /// it. But quests in one town sit within a few hundred metres of each other, and at island
    /// scale their markers land on top of one another — the overlap `NFR-A11Y-01` forbids and the
    /// end of the 44-point target `NFR-A11Y-06` requires. So the opening zoom is derived from the
    /// content rather than fixed: spread pins open fitted, a cluster opens on the cluster.
    public func initialZoom(
        drawnAt size: CGSize,
        minimumSeparation: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        guard let separation = closestPinSeparation(drawnAt: size), separation > 0 else { return 1 }
        return min(max(minimumSeparation / separation, 1), maximum)
    }

    /// The pin closest to the cluster's centre. The map scrolls to *this marker* rather than to a
    /// zero-sized anchor at the centroid: `ScrollViewReader` positions real, laid-out views
    /// reliably, and a 1×1 `Color.clear` inside a `.position` modifier is neither.
    public var anchorPinID: String? {
        let centre = pinCentroid
        return pins.min {
            hypot($0.point.x - centre.x, $0.point.y - centre.y)
                < hypot($1.point.x - centre.x, $1.point.y - centre.y)
        }?.questID
    }

    /// Nil when content ships no region map. The screen then has nothing to draw, and saying so is
    /// better than presenting an empty frame that looks like a failed download — which, given
    /// `AD-3`, it could never be.
    public init?(
        repository: any ContentRepository,
        language: ContentLanguage,
        suppressedQuestIDs: Set<String> = [],
        suppressedPlaceIDs: Set<String> = []
    ) {
        guard let regionMap = (try? repository.manifest())?.regionMap else { return nil }

        self.language = language
        aspectRatio = regionMap.aspectRatio
        mapImageURL = (try? repository.assetURL(regionMap.asset)) ?? nil

        let quests = (try? repository.quests(
            suppressingQuestIDs: suppressedQuestIDs,
            suppressingPlaceIDs: suppressedPlaceIDs)) ?? []

        pins = quests.compactMap { quest -> RegionMapPin? in
            guard let start = quest.startCheckpoint,
                  let place = (try? repository.place(id: start.placeId)) ?? nil,
                  let point = place.mapPoint
            else { return nil }

            let title = quest.title.value(for: language)
            let placeName = place.nameOfficial.value(for: language)
            return RegionMapPin(
                questID: quest.id,
                title: title,
                placeName: placeName,
                point: point,
                // NFR-A11Y-02: a marker is a control, so it says what it is and where it starts.
                accessibilityLabel: "\(title) — \(placeName)")
        }
    }
}

// MARK: - View

public struct RegionMapView: View {
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

    /// The viewport and the drawn artwork, recorded so the gesture handlers can clamp the pan they
    /// store. A gesture callback has no `GeometryProxy`.
    @State private var viewport: CGSize = .zero
    @State private var content: CGSize = .zero

    private static let maximumZoom: CGFloat = 6

    public init(
        model: RegionMapViewModel,
        onSelect: @escaping (String) -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.model = model
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
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
    private func marker(_ pin: RegionMapPin, labelBelow: Bool) -> some View {
        Button { onSelect(pin.questID) } label: {
            VStack(spacing: KultaraMetrics.xs) {
                if !labelBelow { MapPlaceLabel(pin.title, width: Self.labelWidth) }
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(palette.sealFill.color)
                    .background(Circle().fill(palette.inkOnSeal.color).padding(3))
                    .shadow(color: palette.photoScrim.color.opacity(0.45), radius: 3, y: 1)
                if labelBelow { MapPlaceLabel(pin.title, width: Self.labelWidth) }
            }
            .frame(minWidth: KultaraMetrics.minimumTapTarget, minHeight: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pin.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
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

/// Loads a bundled image from disk. In one place because the card, the preview and the map all need
/// it, and because `Image(contentsOfFile:)` does not exist.
enum BundledImage {
    static func load(_ url: URL) -> Image? {
        #if canImport(UIKit)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }
}
