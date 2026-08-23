import ContentKit
import MapKit
import SwiftUI

/// The arrival screen's map slot — frame `223:2046` on the Hisplora board — drawn by MapKit rather
/// than projected onto a canvas.
///
/// **This narrows `FR-MAP-01`'s ban a second time, and it is narrower than the first.** The
/// discovery basemap (`QuestBaseMapView`) is a whole screen *before* any walk starts; this is one
/// transient state inside one, shown while the walker is being placed at the first checkpoint or
/// handed to external directions for the next one. The owner directed it on 2026-08-23: the frame
/// pastes a street map of the checkpoint's neighbourhood into this slot, and the slot now draws a
/// real one. What still holds, and why the cost stays bounded:
///
/// - **The camera is set once from content and never follows anyone.** No user tracking mode, no
///   recentering on each fix (`FR-MAP-03`): this is a picture of where to go, not a navigation aid.
/// - **Nothing here decides arrival.** The gate is `ArrivalEvaluator`, measuring the Place
///   coordinate against the fix's radius and accuracy (`FR-ARR-01`); this map only illustrates it,
///   which is the same division `RunRouteMapView` had.
/// - **The line the guard actually holds is untouched**: `RunRouteMapView` still projects the
///   authored `route.geojson` onto a `Canvas`, and `PermissionCallBoundaryTests` names this file in
///   its MapKit allowlist so a fifth caller turns red rather than shipping quietly.
/// - **Offline the tiles drop out and the pins stay.** There is no reachability check here and no
///   fallback swap (`AD-3`) — an `MKMapView` with no network draws its annotations over blank
///   ground, which is honest about having no imagery without pretending the walk depends on it.
struct ArrivalLiveMapView: UIViewRepresentable {
    /// The checkpoint being walked to. Nil only when content ships no readable geometry at all, in
    /// which case the caller shows nothing — the same gate `RunRouteMapView` sat behind.
    let target: Coordinate?
    /// The last fix, when there is one. Used only to fit the camera; the blue dot itself is
    /// MapKit's own `showsUserLocation`, driven by the real provider, so what it draws can never
    /// disagree with what arrival measured.
    let userPosition: Coordinate?
    let targetName: String
    let accessibilityLabel: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        // `FR-MAP-03`: a map, not a navigation aid. Same config as the discovery basemap.
        map.userTrackingMode = .none
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        map.showsUserLocation = true
        // The frame's screenshot carries Apple's own points of interest; nothing filters them out.
        map.insetsLayoutMarginsFromSafeArea = false
        map.accessibilityLabel = accessibilityLabel

        if let target {
            let pin = TargetAnnotation()
            pin.coordinate = CLLocationCoordinate2D(latitude: target.lat, longitude: target.lon)
            pin.title = targetName
            context.coordinator.pin = pin
            map.addAnnotation(pin)
        }
        map.visibleMapRect = Self.fittedRect(
            target: target.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) },
            user: userPosition.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) })
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.accessibilityLabel = accessibilityLabel
        // The walker moves; the camera does not chase them (see the type doc). But a fix arriving
        // after the first layout is worth fitting to once, so both ends of the walk are on screen.
        if !context.coordinator.didRefitWithFix, let userPosition {
            context.coordinator.didRefitWithFix = true
            if let target {
                map.visibleMapRect = Self.fittedRect(
                    target: CLLocationCoordinate2D(latitude: target.lat, longitude: target.lon),
                    user: CLLocationCoordinate2D(latitude: userPosition.lat, longitude: userPosition.lon))
            }
        }
    }

    /// Fits the checkpoint and the walker when they are close together — never closer than ~900 m
    /// across, so two nearby points still read as a neighbourhood, which is roughly the scale the
    /// frame's screenshot sits at. When there is no fix, or the walker is far away, the camera
    /// centres on the checkpoint alone.
    ///
    /// The distance gate is load-bearing, not cosmetic. Fitting both ends unconditionally drew a
    /// hemisphere: a fix in California and a checkpoint in Denpasar sit on opposite sides of the
    /// antimeridian in Web Mercator's x, so their union is most of the world's width and the map
    /// opens on the Atlantic with neither end visible. The screen's job is to show where to walk,
    /// and a walker an ocean away is told that by the pin alone.
    static func fittedRect(
        target: CLLocationCoordinate2D?, user: CLLocationCoordinate2D?
    ) -> MKMapRect {
        guard let target else { return .world }
        let targetPoint = MKMapPoint(target)
        let side = 900 * MKMapPointsPerMeterAtLatitude(target.latitude)
        let fitsBoth = user.map { Self.straightLineM($0, target) <= Self.fitBothMaximumMetres } ?? false

        var rect = MKMapRect(origin: targetPoint, size: MKMapSize(width: 0, height: 0))
        if fitsBoth, let user {
            rect = rect.union(MKMapRect(origin: MKMapPoint(user), size: MKMapSize(width: 0, height: 0)))
        }
        if rect.width < side || rect.height < side {
            rect = MKMapRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        }
        return rect
    }

    /// Past this gap the walker and the checkpoint no longer share one neighbourhood, and fitting
    /// both would only shrink the checkpoint into a dot beside the walker's continent.
    static let fitBothMaximumMetres: CLLocationDistance = 5_000

    private static func straightLineM(
        _ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// The red pin at the checkpoint — the frame's own marker, Apple's default shape rather than
    /// shipped art. The walker's dot is `showsUserLocation`, not an annotation, so the delegate
    /// returns nil for it and MapKit keeps drawing it itself.
    final class TargetAnnotation: NSObject, MKAnnotation {
        dynamic var coordinate = CLLocationCoordinate2D()
        var title: String?
    }

    private static let pinReuseID = "ArrivalLiveMapView.targetPin"

    final class Coordinator: NSObject, MKMapViewDelegate {
        var pin: TargetAnnotation?
        var didRefitWithFix = false

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is TargetAnnotation else { return nil } // the user dot is not ours
            let view = (mapView.dequeueReusableAnnotationView(
                withIdentifier: ArrivalLiveMapView.pinReuseID) as? MKPinAnnotationView)
                ?? MKPinAnnotationView(annotation: annotation,
                                       reuseIdentifier: ArrivalLiveMapView.pinReuseID)
            view.annotation = annotation
            view.pinTintColor = UIColor.systemRed
            view.canShowCallout = false
            view.animatesDrop = true
            return view
        }
    }
}
