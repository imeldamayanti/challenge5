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
    let palette: KultaraPalette
    let onSelect: (String) -> Void
    let onBasemapFailure: () -> Void
    let onBasemapRecovery: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        // `FR-MAP-03`: this is a map, not a navigation aid. No user-tracking mode that turns the
        // screen into a heading-up follow view, and no compass calling for one.
        map.userTrackingMode = .none
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.register(QuestMapAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: QuestMapAnnotationView.reuseIdentifier)
        // The screen is full-bleed and MapKit is not told so by `ignoresSafeArea` alone: left to
        // its own layout margins it fits a region into the *unobscured* area and lets the rest of
        // the viewport run past it, which drew a band of bare basemap under the chart's south
        // coast exactly the height of the home indicator's inset.
        map.insetsLayoutMarginsFromSafeArea = false
        map.preservesSuperviewLayoutMargins = false

        map.setRegion(Self.openingRegion(for: pins), animated: false)
        context.coordinator.apply(to: map, from: self, isInitial: true)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(to: map, from: self, isInitial: false)
    }

    /// Opens on the quests rather than on the island. A discovery map whose first frame is open sea
    /// makes the reader pan before it tells them anything — the same reason `RegionMapViewModel`
    /// carries a pin centroid.
    static let minimumOpeningSpan: Double = 0.32

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
        private var overlay: IllustratedMapOverlay?
        private var installedQuestIDs: Set<String> = []
        private var isShowingIllustration = false
        /// The opening clamp runs once from `makeUIView`, before the map has been laid out, so the
        /// region it reads is a guess at the viewport's aspect and the chart's south edge lands a
        /// dozen points short. This re-runs it on the first region change after layout, once.
        private var hasSettledOpeningRegion = false

        init(_ parent: QuestBaseMapView) {
            self.parent = parent
        }

        func apply(to map: MKMapView, from view: QuestBaseMapView, isInitial: Bool) {
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
            if view.showsIllustration != isShowingIllustration || isInitial {
                isShowingIllustration = view.showsIllustration

                // The chart is a sheet of paper, not a world. Left unbounded, a pan south runs off
                // its edge and the screen fills with bare basemap below the coastline — which is
                // the same failure `RegionMapView` clamps its own pan against, one layer down. The
                // boundary holds the *centre* inside the paper; `keepingTheChartUnderTheViewport`
                // is what keeps its edges off screen at the opening zoom.
                //
                // Lifted in the real mode: the basemap is a world, and clamping it to the drawing's
                // rectangle would be inventing an edge that is not there.
                map.cameraBoundary = view.showsIllustration
                    ? MKMapView.CameraBoundary(mapRect: overlay.boundingMapRect)
                    : nil
                // The layer is added and removed rather than faded. `MKOverlayRenderer.alpha` is
                // not animatable — driving it would mean redrawing the whole chart a dozen times a
                // toggle — and a layer switch that cuts is what a layer switch looks like.
                if view.showsIllustration {
                    if !map.overlays.contains(where: { $0 === overlay }) {
                        // `.aboveLabels`, not `.aboveRoads`. Below the labels, Apple's own place
                        // names print across the chart — "Denpasar" and a department store were
                        // set over the illustration on the first run of this — and a fantasy map
                        // with the real map's typography on it is neither of the two things it is
                        // trying to be. In the real mode the overlay is removed and the labels
                        // come back.
                        map.addOverlay(overlay, level: .aboveLabels)
                    }
                } else {
                    map.removeOverlay(overlay)
                }

                if view.showsIllustration {
                    map.setVisibleMapRect(
                        Self.keepingTheChartUnderTheViewport(map.visibleMapRect,
                                                             chart: overlay.boundingMapRect),
                        edgePadding: .zero,
                        animated: !isInitial)
                }
            }
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
            return IllustratedMapOverlayRenderer(overlay: illustrated)
        }

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
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
            guard !hasSettledOpeningRegion, isShowingIllustration, let overlay else { return }
            hasSettledOpeningRegion = true
            mapView.setVisibleMapRect(
                Self.keepingTheChartUnderTheViewport(mapView.visibleMapRect,
                                                     chart: overlay.boundingMapRect),
                edgePadding: .zero,
                animated: false)
        }

        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) {
            parent.onBasemapFailure()
        }

        func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
            parent.onBasemapRecovery()
        }
    }
}
