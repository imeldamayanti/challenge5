import ContentKit
import DesignSystem
import MapKit
import RunEngine
import SwiftUI

/// The live basemap the discovery map now stands on, with `275:2309`'s chart drawn over it.
///
/// **`FR-MAP-01` bans a live MapKit view for in-quest use, and this is not that.** This is the
/// discovery surface — choosing a walk, before one starts. The run's own map (`RunRouteMapView`) is
/// untouched, still projects the authored `route.geojson` onto a `Canvas`, and still must never
/// become one of these. `ImportBoundaryTests` holds that line by reading the source rather than by
/// trusting this comment. The PRD amendment scoping `FR-MAP-01` to in-quest use is drafted at
/// `docs/prd-amendments/fr-map-01-discovery-basemap.md` and is unsigned.
///
/// There is **no reachability check here and there must not be one** (`AD-3`). Nothing asks whether
/// the network is up. `mapViewDidFailLoadingMap` reports a load that actually failed, and the screen
/// reacts to that fact — which is a different thing from predicting it.
struct QuestBaseMapView: UIViewRepresentable {

    let pins: [RegionMapPin]
    let georeference: IllustratedMapGeoreference?
    let illustration: UIImage?
    let showsIllustration: Bool
    let showsUserLocation: Bool
    let palette: KultaraPalette
    let hisploraPalette: HisploraPalette
    let userLocationLabel: String
    let showsWandControl: Bool
    let wandLabel: String
    let closeLabel: String
    let onToggleMode: () -> Void
    let onClose: (() -> Void)?
    let onSelect: (String) -> Void
    let onBasemapFailure: () -> Void
    let onBasemapRecovery: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = showsUserLocation
        // `FR-MAP-03`: this is a map, not a navigation aid. No user-tracking mode that turns the
        // screen into a heading-up follow view, and no compass calling for one.
        map.userTrackingMode = .none
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.register(QuestMapAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: QuestMapAnnotationView.reuseIdentifier)
        map.register(UserLocationAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: UserLocationAnnotationView.reuseIdentifier)
        // The screen is full-bleed and MapKit is not told so by `ignoresSafeArea` alone: left to
        // its own layout margins it fits a region into the *unobscured* area and lets the rest of
        // the viewport run past it, which drew a band of bare basemap under the chart's south
        // coast exactly the height of the home indicator's inset.
        map.insetsLayoutMarginsFromSafeArea = false
        map.preservesSuperviewLayoutMargins = false

        map.setRegion(Self.openingRegion(for: pins), animated: false)
        context.coordinator.apply(to: map, from: self, isInitial: true)

        // The controls are a sibling of the map inside one container, not a SwiftUI layer over the
        // representable. See `QuestMapControlsHost` — this is what makes a tap on the wand a tap on
        // the wand rather than a race against the map's gesture recognizers.
        let container = UIView()
        container.addSubview(map)
        map.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            map.topAnchor.constraint(equalTo: container.topAnchor),
            map.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            map.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        let host = QuestMapControlsHost(controls: controls)
        context.coordinator.map = map
        context.coordinator.controlsHost = host

        container.addSubview(host.container)
        host.container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            host.container.topAnchor.constraint(equalTo: container.topAnchor),
            host.container.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            host.container.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.container.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.controlsHost?.update(controls)
        guard let map = context.coordinator.map else { return }
        context.coordinator.apply(to: map, from: self, isInitial: false)
    }

    private var controls: QuestMapControls {
        QuestMapControls(
            showsWand: showsWandControl,
            palette: palette,
            wandLabel: wandLabel,
            closeLabel: closeLabel,
            onToggle: onToggleMode,
            onClose: onClose)
    }

    /// Opens on the quests rather than on the island. A discovery map whose first frame is open sea
    /// makes the reader pan before it tells them anything — the same reason `RegionMapViewModel`
    /// carries a pin centroid.
    static let minimumOpeningSpan: Double = 0.32

    /// How far out the camera may go while the chart is the ground: the distance at which the paper
    /// still fills a screen. Past it the reader is looking at Java, Lombok and a rectangle of Bali
    /// floating between them, which is not a map of anywhere.
    ///
    /// Derived from the chart's own width in metres rather than typed as a constant, so re-cutting
    /// the artwork to a different span moves the limit with it.
    static func zoomedOutLimit(for chart: IllustratedMapOverlay) -> CLLocationDistance {
        let rect = chart.boundingMapRect
        let west = MKMapPoint(x: rect.minX, y: rect.midY)
        let east = MKMapPoint(x: rect.maxX, y: rect.midY)
        return west.distance(to: east)
    }

    static func openingRegion(for pins: [RegionMapPin]) -> MKCoordinateRegion {
        guard let first = pins.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -8.65, longitude: 115.21),
                span: MKCoordinateSpan(latitudeDelta: minimumOpeningSpan,
                                       longitudeDelta: minimumOpeningSpan))
        }

        var minLat = first.coordinate.lat, maxLat = first.coordinate.lat
        var minLon = first.coordinate.lon, maxLon = first.coordinate.lon
        for pin in pins.dropFirst() {
            minLat = min(minLat, pin.coordinate.lat); maxLat = max(maxLat, pin.coordinate.lat)
            minLon = min(minLon, pin.coordinate.lon); maxLon = max(maxLon, pin.coordinate.lon)
        }

        // The floor is set by the artwork, not by the markers. The chart is 1469 points across a
        // span of 1.53° of longitude, so a viewport showing 0.045° magnifies it about thirty times
        // and the island dissolves into blur — which is what the first run on device looked like.
        // At a third of a degree it is drawn at roughly its own resolution, which is also the scale
        // both frames draw: a region with quests on it, not a street.
        //
        // It costs something and the cost is deliberate. A single quest — which is what ships —
        // opens as one marker on a wide view rather than filling the screen.
        let padding = 2.6
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * padding, minimumOpeningSpan),
                longitudeDelta: max((maxLon - minLon) * padding, minimumOpeningSpan)))
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {

        var parent: QuestBaseMapView
        weak var map: MKMapView?
        var controlsHost: QuestMapControlsHost?
        private var overlay: IllustratedMapOverlay?
        private weak var renderer: IllustratedMapOverlayRenderer?
        private var installedQuestIDs: Set<String> = []
        private var isShowingIllustration = false
        /// The opening clamp runs once from `makeUIView`, before the map has been laid out, so the
        /// region it reads is a guess at the viewport's aspect and the chart's south edge lands a
        /// dozen points short. This re-runs it on the first region change after layout, once.
        private var hasSettledOpeningRegion = false
        private var isCorrectingRegion = false

        init(_ parent: QuestBaseMapView) {
            self.parent = parent
        }

        func apply(to map: MKMapView, from view: QuestBaseMapView, isInitial: Bool) {
            if map.showsUserLocation != view.showsUserLocation {
                map.showsUserLocation = view.showsUserLocation
            }

            let wanted = Set(view.pins.map(\.questID))
            if installedQuestIDs != wanted {
                map.removeAnnotations(map.annotations.compactMap { $0 as? QuestMapAnnotation })
                map.addAnnotations(view.pins.map(QuestMapAnnotation.init(pin:)))
                installedQuestIDs = wanted
            }

            if overlay == nil,
               let georeference = view.georeference,
               let illustration = view.illustration {
                overlay = IllustratedMapOverlay(image: illustration, georeference: georeference)
            }

            guard let overlay else { return }

            // **The overlay is added once and never removed.** Adding and removing it was what made
            // the wand feel like it was refusing taps: each toggle threw away every rendered tile of
            // a 1469 × 1071 drawing and rebuilt them, and a second tap arriving during that work had
            // to wait for it. The layer stays; only its opacity changes, and `canDraw` returns false
            // at zero so the real mode costs nothing to keep it around.
            if !map.overlays.contains(where: { $0 === overlay }) {
                map.addOverlay(overlay, level: .aboveLabels)

                // **Bali and nothing else, in both modes, set once and never touched again.**
                //
                // These used to be applied and lifted on every toggle, and that is what made the
                // wand look like it was zooming the map instead of switching it. Three things moved
                // the camera on the way back to the chart — the boundary pulling the centre in, the
                // zoom range pulling the scale in, and the correction — so a reader who had panned
                // or zoomed while on the real map tapped the wand and watched an animation instead
                // of a toggle. The ground did change; the eye followed the zoom.
                //
                // Confining both grounds is what makes the toggle *nothing but* a change of opacity,
                // which is the property being asked for. It costs the real map its freedom to show
                // Java and Lombok — deliberate, and a one-line revert if that is wanted: this app is
                // a walk around Bali, and the basemap is here to say where in Bali a quest is.
                map.cameraBoundary = MKMapView.CameraBoundary(mapRect: overlay.boundingMapRect)
                map.cameraZoomRange = MKMapView.CameraZoomRange(
                    maxCenterCoordinateDistance: QuestBaseMapView.zoomedOutLimit(for: overlay))
                correct(map, to: overlay, animated: false)
            }

            guard view.showsIllustration != isShowingIllustration || isInitial else { return }
            isShowingIllustration = view.showsIllustration

            // The whole of what a toggle does. No camera work, so it cannot be mistaken for one.
            renderer?.alpha = view.showsIllustration ? 1 : 0
            renderer?.setNeedsDisplay()
        }

        /// Slides the viewport until the drawing covers it, where the drawing is big enough to.
        ///
        /// **In map-point space, not in latitude.** Mercator's y is not linear in latitude, so a
        /// clamp written against `MKCoordinateRegion` is off by however much the projection bends
        /// over the span — which showed as a strip of bare basemap under the chart's south coast
        /// that the clamp swore was not there. `MKMapRect` is the space MapKit actually draws in
        /// and the space the overlay's own rectangle is already in.
        ///
        /// The opening viewport is centred on the quests, and the one that ships sits near Bali's
        /// south coast — well below the chart's own middle — so a screen two and a bit times taller
        /// than it is wide hangs off the bottom of the paper. Moving the camera is the right
        /// correction rather than zooming out: the reader still opens on the quests, just not on
        /// the edge of the sheet.
        static func keepingTheChartUnderTheViewport(
            _ visible: MKMapRect,
            chart: MKMapRect
        ) -> MKMapRect {
            var rect = visible

            // First, cover. A viewport larger than the paper in either axis cannot be fixed by
            // sliding it — the gap only moves from one edge to the other — so it is pulled in
            // until the drawing covers it, about its own centre and without changing its aspect.
            // This is the same rule `RegionMapView` states one layer down: **fill is the zoom-out
            // limit.** MapKit fits a region rather than adopting it exactly, so the opening
            // viewport comes back a little taller than the span asked for, and on this chart that
            // was a strip of bare basemap under the south coast.
            let excess = max(rect.width / chart.width, rect.height / chart.height)
            if excess > 1 {
                let centreX = rect.midX
                let centreY = rect.midY
                rect.size.width /= excess
                rect.size.height /= excess
                rect.origin.x = centreX - rect.width / 2
                rect.origin.y = centreY - rect.height / 2
            }

            // Then, slide it back onto the paper.
            if rect.minX < chart.minX { rect.origin.x = chart.minX }
            if rect.maxX > chart.maxX { rect.origin.x = chart.maxX - rect.width }
            if rect.minY < chart.minY { rect.origin.y = chart.minY }
            if rect.maxY > chart.maxY { rect.origin.y = chart.maxY - rect.height }

            return rect
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            guard let illustrated = overlay as? IllustratedMapOverlay else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let made = IllustratedMapOverlayRenderer(overlay: illustrated)
            made.alpha = isShowingIllustration ? 1 : 0
            renderer = made
            return made
        }

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: UserLocationAnnotationView.reuseIdentifier,
                    for: annotation) as? UserLocationAnnotationView
                view?.install(palette: parent.hisploraPalette,
                              spokenLabel: parent.userLocationLabel)
                return view
            }

            guard let quest = annotation as? QuestMapAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: QuestMapAnnotationView.reuseIdentifier,
                for: quest) as? QuestMapAnnotationView
            view?.annotation = quest
            view?.install(annotation: quest, palette: parent.palette)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let quest = view.annotation as? QuestMapAnnotation else { return }
            // Deselected immediately: selection here is a navigation, and a marker left in the
            // selected state is a marker that cannot be tapped again on the way back.
            mapView.deselectAnnotation(quest, animated: false)
            parent.onSelect(quest.questID)
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            guard !hasSettledOpeningRegion, let overlay else { return }
            hasSettledOpeningRegion = true
            correct(mapView, to: overlay, animated: false)
        }

        /// Slides a finished pan or pinch back onto the paper.
        ///
        /// At the *end* of the gesture rather than during it. Correcting continuously fights the
        /// finger — the map stops where the touch does not — and the boundary and zoom range have
        /// already kept the gesture close, so what is left to correct is a few points of edge.
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // The change this is hearing about is the correction's own. Clearing the flag here
            // rather than beside the call is what makes one gesture produce one correction:
            // released synchronously, the animation's own region changes come back through this
            // method and start another.
            if isCorrectingRegion {
                isCorrectingRegion = false
                return
            }
            guard let overlay else { return }
            correct(mapView, to: overlay, animated: true)
        }

        /// `setVisibleMapRect` reports a region change of its own, so this has two ways of not
        /// calling itself forever, and both are needed.
        ///
        /// The flag covers the synchronous re-entry. The overflow test covers the asynchronous one:
        /// MapKit fits the rectangle it is given rather than adopting it exactly, so comparing the
        /// corrected rect against the one that comes back never converges and the map twitches
        /// against itself. What is measured instead is the thing the correction exists to remove —
        /// **how much basemap is showing past the edge of the paper** — and once that is under a
        /// couple of screen points there is nothing left to do.
        private func correct(_ map: MKMapView, to chart: IllustratedMapOverlay, animated: Bool) {
            guard !isCorrectingRegion, map.bounds.width > 0 else { return }
            // An un-laid-out map reports a rect that means nothing, and a correction computed from
            // it snaps the camera somewhere the reader did not ask for.

            let visible = map.visibleMapRect
            let paper = chart.boundingMapRect

            let overflow = max(
                paper.minX - visible.minX, visible.maxX - paper.maxX,
                paper.minY - visible.minY, visible.maxY - paper.maxY)
            let tolerance = (visible.width / Double(map.bounds.width)) * 2
            guard overflow > tolerance else { return }

            isCorrectingRegion = true
            map.setVisibleMapRect(
                Self.keepingTheChartUnderTheViewport(visible, chart: paper),
                edgePadding: .zero,
                animated: animated)
        }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) {
            parent.onBasemapFailure()
        }

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            parent.onBasemapRecovery()
        }
    }
}
