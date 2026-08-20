import ContentKit
import DesignSystem
import MapKit
import SwiftUI

/// A quest's start point on the live basemap.
final class QuestMapAnnotation: NSObject, MKAnnotation {

    let questID: String
    let questTitle: String
    let spokenLabel: String
    let artwork: MapLandmarkArtwork
    let coordinate: CLLocationCoordinate2D

    init(pin: RegionMapPin) {
        questID = pin.questID
        questTitle = pin.title
        spokenLabel = pin.accessibilityLabel
        artwork = MapLandmarkCatalog.artwork(forQuestID: pin.questID)
        coordinate = CLLocationCoordinate2D(latitude: pin.coordinate.lat,
                                            longitude: pin.coordinate.lon)
    }
}

/// The marker `276:2520` draws: `275:2309`'s own fog-and-building figure with the quest's name
/// under it, standing on a real map.
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

    private static let figureWidth: CGFloat = 120
    private static let labelWidth: CGFloat = 150
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
            title: annotation.questTitle,
            artwork: annotation.artwork,
            figureWidth: Self.figureWidth,
            labelWidth: Self.labelWidth,
            palette: palette)
        let controller = UIHostingController(rootView: marker)
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false

        let size = controller.sizeThatFits(in: CGSize(width: Self.labelWidth,
                                                      height: .greatestFiniteMagnitude))
        // The building sits 27.5 points down an 87-point cluster, so the figure is pushed down
        // until *the building's* centre — not the drawing's — lands on the annotation's coordinate.
        let figureHeight = MapLandmarkFigure.height(forWidth: Self.figureWidth)
        let buildingOffset = figureHeight / 2 - MapLandmarkFigure.buildingCentreFraction * figureHeight

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

/// The marker's contents, as `275:2309` composes them: the fog-and-building figure with the quest's
/// name tucked under it.
struct QuestMapMarker: View {

    let title: String
    let artwork: MapLandmarkArtwork
    let figureWidth: CGFloat
    let labelWidth: CGFloat
    let palette: KultaraPalette

    var body: some View {
        VStack(spacing: 0) {
            MapLandmarkFigure(artwork: artwork, width: figureWidth)
            MapPlaceLabel(title, width: labelWidth)
                // The frame tucks the name against the fog rather than spacing it off the marker —
                // the name reads as written on the map, not as a caption under a pin.
                .padding(.top, -KultaraMetrics.xs)
        }
        .environment(\.kultaraPalette, palette)
        .accessibilityHidden(true)
    }
}
