import ContentKit
import DesignSystem
import MapKit
import SwiftUI

/// The popover a quest marker opens (`1322:4256`), where the tap used to navigate straight through.
///
/// One marker tap now *selects*; the walk starts from the card's own Start band. Everything the
/// card says comes off the pin (`RegionMapPin`), which resolved it from content — the frame's
/// invented figures ("9 quests") are the one thing not carried over.
struct QuestMapPopoverPresentation: Sendable, Equatable {
    let title: String
    let locationName: String
    let durationText: String
    let stopsText: String
    /// The band is the frame's own "Start"; what it is announced as says where it goes.
    let startSpokenLabel: String
}

/// The card itself, as `1322:4256` draws it: the quest's landmark standing in fog over the title,
/// two rows of meta in warm brown, and a full-width brown Start band closing the card. The ground
/// is the frame's own vertical wash — `paperSheet` to the frame's dusty-rose foot, which has no
/// token and is decoration rather than a measured surface, so it stays a literal here.
///
/// The frame's Start fill and its border are `brownMid` and `brownStone` exactly, so the measured
/// pairs hold rather than sampled near-misses; the meta brown `#5D4C44` has no token and is a
/// literal with the frame's number written on it.
struct QuestMapPopoverCard: View {

    /// Handed in rather than read from the environment — a hosted view sits outside the app's
    /// SwiftUI tree and inherits nothing from the theme provider (`QuestMapAnnotationView`).
    let palette: HisploraPalette
    let presentation: QuestMapPopoverPresentation
    /// The same drawing the marker on the map stands, so the card and its marker read as one
    /// object. Nil draws the fog alone, which is what a quest with no entry in the catalogue gets.
    let artwork: MapLandmarkArtwork?
    /// Which side the tail points. A marker near the screen's west edge gets a card on its right,
    /// and then the tail has to point back.
    var tailEdge: TailEdge = .right
    let onStart: () -> Void

    enum TailEdge { case right, left }

    /// `1322:4256`'s card body is 176 wide (the tail adds 6.5 outside it); the title wraps inside
    /// a 154-point column.
    static let width: CGFloat = 176
    static let tailLength: CGFloat = 6.5
    private static let tailHeight: CGFloat = 19
    private static let cornerRadius: CGFloat = 23.5
    /// The tail's point sits at y 155 of the frame's 235.5 — two thirds down, not mid-card — so
    /// the card hangs off its marker at that fraction rather than by its centre.
    nonisolated static let tailCentreFraction: CGFloat = 155.0 / 235.5
    /// The frame's meta brown, untokened: it is text on `paperSheet` at 7.3:1, measured once here
    /// rather than added to the palette for one surface.
    private static let metaInk = SRGBColor(hex: "#5D4C44")
    /// The frame's ground wash foot, untokened: decoration behind the Start band, not a surface
    /// anything is measured against.
    private static let groundFoot = SRGBColor(hex: "#E0BBAB")

    var body: some View {
        // The frame composites the card and its tail as one silhouette under one drop shadow, so
        // they are drawn into one composited group here rather than shadowed separately. The
        // shadow is the frame's `−4px 4px 12.5px rgba(0,0,0,0.25)`.
        HStack(alignment: .top, spacing: 0) {
            if tailEdge == .left { tail }
            card.alignmentGuide(.top) { $0.height * Self.tailCentreFraction }
            if tailEdge == .right { tail }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.25), radius: 6.25, x: -4, y: 4)
        .accessibilityElement(children: .contain)
        .environment(\.hisploraPalette, palette)
    }

    // The frame's vertical rhythm, read off `1322:4256`'s own coordinates: figure cluster at 9
    // (87 tall, so its box ends at 96), title top at 80 — the fog runs 16 points past the figure's
    // box and the title rises into it — meta 12 under a two-line title, the meta block 44 tall,
    // Start band 9 under that and 49 tall, closing the card at 235.5 for a two-line title.
    private var card: some View {
        VStack(spacing: 0) {
            MapLandmarkFigure(
                artwork: artwork,
                width: 159,
                // `1322:4256` stands the gate at (38, 0) in its cluster; the marker frames use
                // (36, −6). The card carries its own number.
                buildingOffset: CGPoint(x: 38, y: 0))
                .frame(maxWidth: .infinity)
                .padding(.top, 9)

            Text(presentation.title)
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.43)
                // The frame's leading of 1.2; the system default for 17pt is looser.
                .lineSpacing(-1.6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(palette.inkDark.color)
                .padding(.top, -16)
                .padding(.horizontal, 11)

            meta
                .padding(.top, 12)
                .padding(.horizontal, 11)

            startBand
                .padding(.top, 9)
        }
        .frame(width: Self.width)
        .background(
            LinearGradient(
                stops: [
                    .init(color: palette.paperSheet.color, location: 0.62),
                    .init(color: Self.groundFoot.color, location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom))
        .clipShape(.rect(cornerRadius: Self.cornerRadius))
    }

    /// The frame's two meta rows: the place alone, then minutes and stops side by side, in a block
    /// the frame fixes at 44 tall. The icons are the frame's own glyphs, exported and tinted
    /// `metaInk` in the file, so the row reads as one ink rather than SF Symbols in a second
    /// colour.
    private var meta: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                icon("quest-popover-pin", width: 11, height: 13)
                metaText(presentation.locationName)
            }
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    icon("quest-popover-clock", width: 11, height: 12.3)
                    metaText(presentation.durationText)
                }
                HStack(spacing: 5) {
                    icon("quest-popover-pencil", width: 11, height: 11.4)
                    metaText(presentation.stopsText)
                }
            }
        }
        .frame(height: 44, alignment: .topLeading)
    }

    private func metaText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            // The frame's leading of 16 on 12pt text.
            .lineSpacing(0.5)
            .foregroundStyle(Self.metaInk.color)
    }

    @ViewBuilder
    private func icon(_ resource: String, width: CGFloat, height: CGFloat) -> some View {
        if let image = MapLandmarkImages.image(named: resource) {
            image
                .resizable()
                .frame(width: width, height: height)
        } else {
            Color.clear.frame(width: width, height: height)
        }
    }

    /// The frame's Start band: full card width, `brownMid` under a `brownStone` hairline on three
    /// sides, the card's own bottom corners closing it.
    private var startBand: some View {
        Button(action: onStart) {
            Text("Start")
                .font(.system(size: 17, weight: .medium))
                .kerning(-0.34)
                .foregroundStyle(palette.inkOnButton.color)
                .frame(maxWidth: .infinity)
                .frame(height: 49)
                .background(palette.brownMid.color)
                .overlay {
                    // The frame rounds the band's own bottom corners at 22, one and a half inside
                    // the card's 23.5.
                    QuestMapPopoverBandBorder(cornerRadius: 22)
                        .stroke(palette.brownStone.color, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(presentation.startSpokenLabel))
    }

    private var tail: some View {
        QuestMapPopoverTail()
            .fill(palette.paperSheet.color)
            .frame(width: Self.tailLength, height: Self.tailHeight)
            .alignmentGuide(.top) { $0.height / 2 }
    }
}

/// `1322:4256`'s callout tail: two concave curves meeting in a point, the shape an iOS popover
/// arrow draws. It hangs off the card's two-thirds line, not its middle — the alignment guides in
/// `QuestMapPopoverCard.body` put it there.
struct QuestMapPopoverTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.maxX * 0.35, y: rect.height * 0.3))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY),
            control: CGPoint(x: rect.maxX * 0.35, y: rect.height * 0.7))
        path.closeSubpath()
        return path
    }
}

/// The Start band's hairline: left, right and bottom only, the bottom corners rounded to the
/// card's own radius. The frame borders three sides because the band's top edge abuts the content
/// rather than the world.
struct QuestMapPopoverBandBorder: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: cornerRadius, y: rect.maxY),
            control: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        return path
    }
}

/// What the card needs to stand next to its marker, gathered so the representable hands over one
/// value.
struct QuestMapPopoverControls {
    let presentation: QuestMapPopoverPresentation?
    let artwork: MapLandmarkArtwork?
    let palette: HisploraPalette
    let anchorCoordinate: CLLocationCoordinate2D?
    let onStart: () -> Void
}

/// The popover lives **in UIKit, beside the map** — not as a SwiftUI layer above the representable.
/// That lesson cost three attempts once already; see `QuestMapControlsHost`. A hosted SwiftUI card
/// over `MKMapView` would lose every tap to the map's gesture recognizers exactly the way the wand
/// did.
@MainActor
final class QuestMapPopoverHost {

    /// Same rule as `QuestMapControlsHost.PassthroughView`: everything that is not the card belongs
    /// to the map.
    final class PassthroughView: UIView {
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let hit = super.hitTest(point, with: event)
            return hit === self ? nil : hit
        }
    }

    let container = PassthroughView()
    private var hostingController: UIHostingController<QuestMapPopoverCard>?
    private var lastControls: QuestMapPopoverControls?
    private var tailEdge: QuestMapPopoverCard.TailEdge = .right
    private(set) var isVisible = false

    func update(
        _ controls: QuestMapPopoverControls,
        in mapView: MKMapView
    ) {
        lastControls = controls
        guard let presentation = controls.presentation,
              let coordinate = controls.anchorCoordinate else {
            dismiss()
            return
        }

        if hostingController == nil {
            let host = UIHostingController(rootView: QuestMapPopoverCard(
                palette: controls.palette,
                presentation: presentation,
                artwork: controls.artwork,
                onStart: controls.onStart))
            host.view.backgroundColor = .clear
            container.addSubview(host.view)
            hostingController = host
        }

        position(mapView: mapView, at: coordinate)
        hostingController?.rootView = QuestMapPopoverCard(
            palette: controls.palette,
            presentation: presentation,
            artwork: controls.artwork,
            tailEdge: tailEdge,
            onStart: controls.onStart)
    }

    /// Puts the card down-left of its marker, the way the frame hangs `1322:4256` off the cluster,
    /// and flips it around the marker when there is no room on that side. Vertically the card hangs
    /// off its **tail** — two thirds down the card — rather than by its centre.
    private func position(mapView: MKMapView, at coordinate: CLLocationCoordinate2D) {
        guard let host = hostingController else { return }
        let point = mapView.convert(coordinate, toPointTo: container)

        let size = host.sizeThatFits(in: CGSize(
            width: QuestMapPopoverCard.width + QuestMapPopoverCard.tailLength,
            height: .greatestFiniteMagnitude))

        let gap: CGFloat = 10 + QuestMapPopoverCard.tailLength
        let flipped = point.x - gap - size.width < 8
        tailEdge = flipped ? .left : .right

        var origin = CGPoint(
            x: flipped ? point.x + gap : point.x - gap - size.width,
            y: point.y + 24 - size.height * QuestMapPopoverCard.tailCentreFraction)

        // Keep the whole card on screen vertically even when the marker sits at an edge of the
        // viewport.
        let margin: CGFloat = 8
        origin.y = min(
            max(origin.y, margin),
            max(container.bounds.height - size.height - margin, margin))

        host.view.frame = CGRect(origin: origin, size: size)
    }

    /// Re-anchors the visible card after the camera moved. A no-op while nothing is shown.
    func refresh(in mapView: MKMapView) {
        guard isVisible, let coordinate = lastControls?.anchorCoordinate else { return }
        position(mapView: mapView, at: coordinate)
    }

    func dismiss() {
        hostingController?.view.removeFromSuperview()
        hostingController = nil
        isVisible = false
    }
}
