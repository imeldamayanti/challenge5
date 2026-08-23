import ContentKit
import DesignSystem
import MapKit
import RunEngine
import SwiftUI
import UIStringsKit

/// The live basemap inside `223:2004`'s "Maps" rectangle — the frame pastes a real street map into
/// that slot, and this is it.
///
/// **This is a deviation from `FR-MAP-01`, taken on instruction on 2026-08-21, and it is
/// deliberately narrow.** The requirement bans live map tiles *during a walk* on the stated ground
/// that MapKit exposes no public offline tile cache, so a walk must not depend on one. Two things
/// keep that guarantee intact here rather than trading it away:
///
/// - **The drawn canvas is still what the walk falls back to.** `mapViewDidFailLoadingMap` is a
///   report of a load that actually failed, not a prediction about the network (`AD-3` — there is
///   still no reachability check anywhere), and on that report `ArrivalRouteMap` swaps in
///   `RunRouteMapView`, which projects the authored `route.geojson` with the radio off. A walker
///   inside a covered market still sees where the next checkpoint is (`FR-OFF-03`).
/// - **Nothing on this screen is gated on the map.** The distance, the arrival rule and the Apple
///   Maps handoff are unchanged; this slot is a picture of where the walker is standing.
///
/// The amendment scoping `FR-MAP-01` this far is `docs/prd-amendments/fr-map-01-arrival-basemap.md`
/// and is **unsigned**, exactly like the discovery map's. `PermissionCallBoundaryTests` names this
/// file and only this file, which is the record of how far the exception reaches.
///
/// The dot is drawn from the arrival sampler's own last fix rather than from
/// `MKMapView.showsUserLocation`, so this view opens no second location moment of its own —
/// `FR-ONB-04` still names one prompt, and arrival already owns it.
struct ArrivalRouteMap: View {

    let route: RunRoutePresentation
    let language: ContentLanguage
    let totalCheckpoints: Int

    /// Set only by a load that failed. Never by a guess about connectivity.
    @State private var basemapFailed = false

    var body: some View {
        Group {
            if basemapFailed {
                RunRouteMapView(route: route,
                                language: language,
                                totalCheckpoints: totalCheckpoints,
                                showsChrome: false)
            } else {
                ArrivalBaseMapView(route: route,
                                   palette: .standard,
                                   onFailure: { basemapFailed = true })
                    .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius,
                                                style: .continuous))
                    // Tiles are not readable by VoiceOver any more than a drawing is, so the same
                    // three facts `RunRouteMapView` states are stated here.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel)
            }
        }
    }

    private var accessibilityLabel: String {
        let step = (route.stops.first { $0.isTarget }?.orderIndex ?? 0) + 1
        if let distance = route.distanceRemainingText {
            return String(format: UIStrings.string(.runMapAccessibility, language),
                          step, totalCheckpoints, distance, route.targetName)
        }
        return String(format: UIStrings.string(.runMapNoPosition, language),
                      step, totalCheckpoints, route.targetName)
    }
}

/// The `MKMapView` itself, carrying the same four marks the drawn canvas carries: the arrival
/// radius at true scale, the authored route line, the numbered stops, and the walker.
struct ArrivalBaseMapView: UIViewRepresentable {

    let route: RunRoutePresentation
    let palette: HisploraPalette
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        // The walker's dot is the sampler's fix, drawn by this app — see the type comment. MapKit's
        // own would ask for location a second time and draw a disc from a different picture.
        map.showsUserLocation = false
        map.userTrackingMode = .none
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        // **Deliberately not pannable.** This sits inside the arrival screen's `ScrollView`, and a
        // map that takes the drag takes it from the screen; `FR-MAP-03` also says this is a map and
        // not a navigation aid. Real navigation is the "Navigate There" pill below it
        // (`FR-MAP-04`), which hands off to Apple Maps.
        map.isScrollEnabled = false
        map.isZoomEnabled = false
        map.isUserInteractionEnabled = false
        map.insetsLayoutMarginsFromSafeArea = false
        map.preservesSuperviewLayoutMargins = false
        map.register(ArrivalStopAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: ArrivalStopAnnotationView.reuseIdentifier)
        map.register(ArrivalUserAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: ArrivalUserAnnotationView.reuseIdentifier)
        context.coordinator.apply(to: map, from: self)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(to: map, from: self)
    }

    // MARK: Framing

    /// How far away a fix may be and still be worth framing beside the checkpoint.
    ///
    /// A desk build reports a position in California, and fitting that beside a Denpasar checkpoint
    /// draws the Pacific Ocean with two invisible dots on it — which is what the "13,422.6 km"
    /// screenshot was a picture of. Past this the map frames the route, and the distance text below
    /// carries the rest of the truth.
    static let maximumFramedUserDistanceM: CLLocationDistance = 50_000

    static func framedCoordinates(_ route: RunRoutePresentation) -> [Coordinate] {
        var framed = route.line + route.stops.map(\.coordinate)
        if let user = route.userPosition {
            let anchor = route.target ?? route.stops.first(where: \.isTarget)?.coordinate
            if let anchor, Geo.distanceM(user, anchor) <= maximumFramedUserDistanceM {
                framed.append(user)
            } else if anchor == nil {
                framed.append(user)
            }
        }
        return framed
    }

    /// The rectangle the map opens on. A single point has no extent, so it is given one — an
    /// `MKMapRect` of zero size zooms MapKit to its maximum and draws one building.
    static func region(for route: RunRoutePresentation) -> MKCoordinateRegion? {
        let coordinates = framedCoordinates(route)
        guard let first = coordinates.first else { return nil }

        var minLat = first.lat, maxLat = first.lat
        var minLon = first.lon, maxLon = first.lon
        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.lat); maxLat = max(maxLat, coordinate.lat)
            minLon = min(minLon, coordinate.lon); maxLon = max(maxLon, coordinate.lon)
        }

        // The arrival radius has to fit as well, or the gate the screen is about is cropped.
        // 75 m is roughly 0.00067° of latitude; the floor below is comfortably wider than that at
        // the scale a checkpoint is walked to.
        let minimumSpan = 0.004
        let padding = 1.45
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2,
                                           longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * padding, minimumSpan),
                longitudeDelta: max((maxLon - minLon) * padding, minimumSpan)))
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {

        var parent: ArrivalBaseMapView
        /// The framing is applied once per distinct route state. Re-setting the region on every
        /// `updateUIView` re-animates the camera every time the sampler ticks, which reads as a map
        /// that will not settle.
        private var appliedSignature: String?

        init(_ parent: ArrivalBaseMapView) {
            self.parent = parent
        }

        func apply(to map: MKMapView, from view: ArrivalBaseMapView) {
            let route = view.route
            let signature = Self.signature(of: route)
            guard signature != appliedSignature else { return }
            appliedSignature = signature

            map.removeAnnotations(map.annotations)
            map.removeOverlays(map.overlays)

            if let target = route.target, route.targetRadiusM > 0 {
                map.addOverlay(
                    MKCircle(center: CLLocationCoordinate2D(latitude: target.lat,
                                                            longitude: target.lon),
                             radius: route.targetRadiusM),
                    level: .aboveRoads)
            }

            if route.line.count >= 2 {
                let points = route.line.map {
                    CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)
                }
                map.addOverlay(MKPolyline(coordinates: points, count: points.count),
                               level: .aboveRoads)
            }

            // The bearing to the target — dashed, because it is a direction and not a path anybody
            // should walk. Only drawn when the fix is close enough to be on the same map.
            if let user = route.userPosition,
               let target = route.target,
               Geo.distanceM(user, target) <= ArrivalBaseMapView.maximumFramedUserDistanceM {
                let points = [CLLocationCoordinate2D(latitude: user.lat, longitude: user.lon),
                              CLLocationCoordinate2D(latitude: target.lat, longitude: target.lon)]
                map.addOverlay(ArrivalBearingLine(coordinates: points, count: points.count),
                               level: .aboveRoads)
            }

            map.addAnnotations(route.stops.map {
                ArrivalStopAnnotation(orderIndex: $0.orderIndex,
                                      isReached: $0.isReached,
                                      isTarget: $0.isTarget,
                                      lat: $0.coordinate.lat,
                                      lon: $0.coordinate.lon)
            })
            if let user = route.userPosition,
               ArrivalBaseMapView.framedCoordinates(route).contains(user) {
                map.addAnnotation(ArrivalUserAnnotation(lat: user.lat, lon: user.lon))
            }

            if let region = ArrivalBaseMapView.region(for: route) {
                map.setRegion(map.regionThatFits(region), animated: false)
            }
        }

        /// Everything drawn, and nothing else. The sampler republishes the presentation on every
        /// tick with an unchanged route and an unchanged fix; a signature over what is drawn is
        /// what stops that from re-laying the map out sixty times a walk.
        static func signature(of route: RunRoutePresentation) -> String {
            let stops = route.stops
                .map { "\($0.orderIndex)\($0.isReached ? "r" : "-")\($0.isTarget ? "t" : "-")" }
                .joined(separator: ",")
            let user = route.userPosition.map { "\($0.lat),\($0.lon)" } ?? "none"
            let target = route.target.map { "\($0.lat),\($0.lon)" } ?? "none"
            return "\(route.line.count)|\(stops)|\(user)|\(target)|\(route.targetRadiusM)"
        }

        // MARK: Delegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            let palette = parent.palette
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor(palette.mapMarker.color).withAlphaComponent(0.14)
                renderer.strokeColor = UIColor(palette.mapMarker.color).withAlphaComponent(0.7)
                renderer.lineWidth = 1
                renderer.lineDashPattern = [3, 3]
                return renderer
            }
            if let bearing = overlay as? ArrivalBearingLine {
                let renderer = MKPolylineRenderer(polyline: bearing)
                renderer.strokeColor = UIColor(palette.mapMarker.color)
                renderer.lineWidth = 2
                renderer.lineDashPattern = [5, 4]
                return renderer
            }
            if let line = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = UIColor(palette.brownMid.color).withAlphaComponent(0.85)
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if let stop = annotation as? ArrivalStopAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: ArrivalStopAnnotationView.reuseIdentifier,
                    for: annotation) as? ArrivalStopAnnotationView
                view?.install(stop: stop, palette: parent.palette)
                return view
            }
            if annotation is ArrivalUserAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: ArrivalUserAnnotationView.reuseIdentifier,
                    for: annotation) as? ArrivalUserAnnotationView
                view?.install(palette: parent.palette)
                return view
            }
            return nil
        }

        /// A load that failed, reported by MapKit. Not a prediction — `AD-3`.
        func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: any Error) {
            parent.onFailure()
        }
    }
}

/// Distinguished from the authored route line so the renderer can tell a bearing from a path
/// without inspecting coordinates.
// `nonisolated` because MapKit reads an overlay from its own tile queue, the same
// reason `IllustratedMapOverlay` is.
nonisolated final class ArrivalBearingLine: MKPolyline {}

// MARK: - Annotations

nonisolated final class ArrivalStopAnnotation: NSObject, MKAnnotation {

    let orderIndex: Int
    let isReached: Bool
    let isTarget: Bool
    let coordinate: CLLocationCoordinate2D

    /// Primitives rather than a `RunRouteStop`: the annotation is nonisolated and the presentation
    /// model is not `Sendable`, so the value would be crossing an isolation boundary to get here.
    init(orderIndex: Int, isReached: Bool, isTarget: Bool, lat: Double, lon: Double) {
        self.orderIndex = orderIndex
        self.isReached = isReached
        self.isTarget = isTarget
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

nonisolated final class ArrivalUserAnnotation: NSObject, MKAnnotation {

    let coordinate: CLLocationCoordinate2D

    init(lat: Double, lon: Double) {
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// The numbered stop, in the same three states the drawn canvas gives it: reached is solid, the
/// target carries a heavier ring, the rest are outlines (`NFR-A11Y-05` — fill and ring tell them
/// apart as well as colour does).
final class ArrivalStopAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "ArrivalStopAnnotationView"

    private var host: UIHostingController<ArrivalStopPin>?

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 28, height: 28)
        backgroundColor = .clear
        canShowCallout = false
        isEnabled = false
        // The map carries one spoken label for the whole picture; a pin that announced itself
        // separately would read the route out twice.
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func prepareForReuse() {
        super.prepareForReuse()
        host?.view.removeFromSuperview()
        host = nil
    }

    func install(stop: ArrivalStopAnnotation, palette: HisploraPalette) {
        host?.view.removeFromSuperview()
        let controller = UIHostingController(
            rootView: ArrivalStopPin(number: stop.orderIndex + 1,
                                     isReached: stop.isReached,
                                     isTarget: stop.isTarget,
                                     palette: palette))
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.view.frame = bounds
        addSubview(controller.view)
        host = controller
    }
}

struct ArrivalStopPin: View {

    let number: Int
    let isReached: Bool
    let isTarget: Bool
    let palette: HisploraPalette

    private var diameter: CGFloat { isTarget ? 26 : 20 }

    var body: some View {
        ZStack {
            Circle()
                .fill(isReached ? palette.mapMarker.color : palette.paperCream.color)
            Circle()
                .stroke(palette.brownDeep.color, lineWidth: isTarget ? 2 : 1)
            Text("\(number)")
                .font(.system(size: isTarget ? 13 : 11, weight: .semibold))
                .foregroundStyle(isReached ? palette.paperCream.color : palette.brownDeep.color)
        }
        .frame(width: diameter, height: diameter)
        // The pin is drawn on live tiles, which are busy; a hard boundary is what keeps it a pin
        // rather than a smudge on a roof.
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

/// Where the walker is — the same beating dot the approach screen and the discovery map draw, so
/// the reader learns one object rather than three.
final class ArrivalUserAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "ArrivalUserAnnotationView"

    private static let dotDiameter: CGFloat = 16

    private var host: UIHostingController<ArrivalUserDot>?

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        let extent = Self.dotDiameter * 2.6
        frame = CGRect(x: 0, y: 0, width: extent, height: extent)
        backgroundColor = .clear
        canShowCallout = false
        isEnabled = false
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func install(palette: HisploraPalette) {
        guard host == nil else { return }
        let controller = UIHostingController(
            rootView: ArrivalUserDot(diameter: Self.dotDiameter, palette: palette))
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.view.frame = bounds
        addSubview(controller.view)
        host = controller
    }
}

struct ArrivalUserDot: View {

    let diameter: CGFloat
    let palette: HisploraPalette

    var body: some View {
        HisploraPulsingMapMarker(diameter: diameter)
            .environment(\.hisploraPalette, palette)
    }
}
