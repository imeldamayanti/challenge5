import ContentKit
import DesignSystem
import MapKit
import SwiftUI

/// A quest's start point on the live basemap.
final class QuestMapAnnotation: NSObject, MKAnnotation {

    let questID: String
    let questTitle: String
    let spokenLabel: String
    /// What `1026:3514`'s card prints beside the pin, the minutes and the stop count.
    let regionName: String
    let durationMin: Int
    let stopCount: Int
    let artwork: MapLandmarkArtwork
    let coordinate: CLLocationCoordinate2D

    init(pin: RegionMapPin) {
        questID = pin.questID
        questTitle = pin.title
        spokenLabel = pin.accessibilityLabel
        regionName = pin.regionName
        durationMin = pin.durationMin
        stopCount = pin.stopCount
        artwork = MapLandmarkCatalog.artwork(forQuestID: pin.questID)
        coordinate = CLLocationCoordinate2D(latitude: pin.coordinate.lat,
                                            longitude: pin.coordinate.lon)
    }
}

/// The marker the map frames draw: the fog-and-building figure standing on a real map, no caption.
///
/// The view's **bounds are the 44-point square over the building, not the figure**, and the drawing
/// is allowed to spill outside them. That is the same rule `RegionMapView` follows and for the same
/// reason: the figure is 120 points across and most of that width is fog at low alpha, so a target
/// the size of the drawing would be mostly transparent map — wide enough that two adjacent markers
/// overlap and a touch on open sea navigates (`NFR-A11Y-06`). Hit testing stops at the bounds, so
/// the spill is visible and not pressable, which leaves the label unpressable exactly as it is on
/// the illustrated surface.
final class QuestMapAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "QuestMapAnnotationView"

    private static let figureWidth: CGFloat = 159
    private static let target: CGFloat = 44

    private var host: UIHostingController<QuestMapMarker>?

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: Self.target, height: Self.target)
        clipsToBounds = false
        backgroundColor = .clear
        // The drawing names nothing; the annotation does. Without this the whole marker is
        // announced as the raw figure, or not at all.
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func prepareForReuse() {
        super.prepareForReuse()
        host?.view.removeFromSuperview()
        host = nil
    }

    /// Builds the drawing. The palette has to be handed in: a hosted view is outside the app's
    /// SwiftUI tree and inherits nothing from the theme provider.
    func install(annotation: QuestMapAnnotation, palette: KultaraPalette) {
        host?.view.removeFromSuperview()

        let marker = QuestMapMarker(
            artwork: annotation.artwork,
            figureWidth: Self.figureWidth,
            palette: palette)
        let controller = UIHostingController(rootView: marker)
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false

        let size = controller.sizeThatFits(in: CGSize(width: Self.figureWidth,
                                                      height: .greatestFiniteMagnitude))
        // The building sits a per-drawing depth down an 87-point cluster, so the figure is pushed
        // down until *the building's* centre — not the drawing's — lands on the annotation's
        // coordinate.
        let figureHeight = MapLandmarkFigure.height(forWidth: Self.figureWidth)
        let buildingOffset = figureHeight / 2
            - MapLandmarkFigure.buildingCentreFraction(for: annotation.artwork) * figureHeight

        controller.view.frame = CGRect(
            x: (Self.target - size.width) / 2,
            y: (Self.target - size.height) / 2 + buildingOffset,
            width: size.width,
            height: size.height)

        addSubview(controller.view)
        host = controller

        accessibilityLabel = annotation.spokenLabel
    }
}

/// The marker's contents, as the map frames draw them: the fog-and-building figure alone. The
/// quest's name lives in the marker's accessibility label and in the popover, not under the
/// drawing — the frames put no caption on a marker.
struct QuestMapMarker: View {

    let artwork: MapLandmarkArtwork
    let figureWidth: CGFloat
    let palette: KultaraPalette

    var body: some View {
        MapLandmarkFigure(artwork: artwork, width: figureWidth)
            .environment(\.kultaraPalette, palette)
            .accessibilityHidden(true)
    }
}

/// Where the reader is, drawn in this app's own hand rather than in MapKit's.
///
/// Apple's blue disc is legible, but on the illustrated chart it is the one object on the paper
/// that belongs to a different picture — and at the scale this map opens, it is also small enough
/// to lose against a coastline. This is `HisploraPulsingMapMarker`, the same dot the approach
/// screen beats, at a size that reads on a map of a whole regency: the seal-red dot inside a cream
/// ring, with a halo that breathes out and fades.
///
/// The halo is decoration and the ring is the legibility (`NFR-A11Y-05`) — the dot keeps a hard
/// cream boundary against both grounds whether or not the animation is running, and
/// `HisploraPulsingMapMarker` already stops the ring rather than the dot under Reduce Motion.
final class UserLocationAnnotationView: MKAnnotationView {

    static let reuseIdentifier = "UserLocationAnnotationView"

    /// The still dot is this across; the halo reaches 2.6× it. Apple's own is about 22 points
    /// including its ring, and this reads a little larger deliberately — the chart is busy.
    private static let dotDiameter: CGFloat = 18

    private var host: UIHostingController<UserLocationMarker>?

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        let extent = Self.dotDiameter * 2.6
        frame = CGRect(x: 0, y: 0, width: extent, height: extent)
        backgroundColor = .clear
        // The dot marks a point, so it stays centred on it — no `centerOffset`, unlike the quest
        // markers, whose drawing hangs off a building.
        canShowCallout = false
        isEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = .updatesFrequently
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func install(palette: HisploraPalette, spokenLabel: String) {
        guard host == nil else {
            accessibilityLabel = spokenLabel
            return
        }

        let controller = UIHostingController(
            rootView: UserLocationMarker(diameter: Self.dotDiameter, palette: palette))
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        controller.view.frame = bounds

        addSubview(controller.view)
        host = controller

        accessibilityLabel = spokenLabel
    }
}

struct UserLocationMarker: View {

    let diameter: CGFloat
    let palette: HisploraPalette

    var body: some View {
        HisploraPulsingMapMarker(diameter: diameter)
            .environment(\.hisploraPalette, palette)
    }
}
