import ContentKit
import DesignSystem
import MapKit
import SwiftUI

/// The popover a quest marker opens (`1026:3514`), where the tap used to navigate straight through.
///
/// One marker tap now *selects*; the walk starts from the card's own Start pill. Everything the
/// card says comes off the pin (`RegionMapPin`), which resolved it from content — the frame's
/// invented figures ("9 quests") are the one thing not carried over.
struct QuestMapPopoverPresentation: Sendable, Equatable {
    let title: String
    let locationName: String
    let durationText: String
    let stopsText: String
    /// The pill is the frame's own "Start"; what it is announced as says where it goes.
    let startSpokenLabel: String
}

/// The card itself. Drawn in the Hisplora direction against `paperSheet` — `1026:3514`'s own
/// ground is that token's exact hex — so the measured pairs hold rather than sampled near-misses:
/// the frame's meta grey `#727272` prints as `inkMuted`, and its `#1A1A1A` Start fill as
/// `buttonFill`, both already measured on this cream.
struct QuestMapPopoverCard: View {

    /// Handed in rather than read from the environment — a hosted view sits outside the app's
    /// SwiftUI tree and inherits nothing from the theme provider (`QuestMapAnnotationView`).
    let palette: HisploraPalette
    let presentation: QuestMapPopoverPresentation
    /// Which side the tail points. A marker near the screen's west edge gets a card on its right,
    /// and then the tail has to point back.
    var tailEdge: TailEdge = .right
    let onStart: () -> Void

    enum TailEdge { case right, left }

    /// `1026:3514` is 156 wide; the title wraps inside it.
    static let width: CGFloat = 156
    private static let cornerRadius: CGFloat = 21
    static let tailLength: CGFloat = 9
    private static let tailHeight: CGFloat = 26

    var body: some View {
        // The frame composites the card and its tail as one silhouette under one drop shadow, so
        // they are drawn into one composited group here rather than shadowed separately.
        HStack(spacing: 0) {
            if tailEdge == .left { tail }
            card
            if tailEdge == .right { tail }
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 5.55)
        .accessibilityElement(children: .contain)
        .environment(\.hisploraPalette, palette)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            Text(presentation.title)
                .font(.system(size: 17, weight: .semibold))
                .kerning(-0.43)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .foregroundStyle(palette.inkDark.color)

            VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                row(symbol: "mappin", text: presentation.locationName)
                row(symbol: "clock", text: presentation.durationText)
                row(symbol: "pencil", text: presentation.stopsText)
            }
            .frame(maxWidth: .infinity)

            Button(action: onStart) {
                Text("Start")
                    .font(.system(size: 17, weight: .medium))
                    .kerning(-0.34)
                    .foregroundStyle(palette.inkOnButton.color)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 7)
                    .background(palette.buttonFill.color, in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(presentation.startSpokenLabel))
        }
        .padding(.top, KultaraMetrics.md)
        .padding(.bottom, KultaraMetrics.lg)
        .padding(.horizontal, KultaraMetrics.xs)
        .frame(width: Self.width)
        .background(palette.paperSheet.color, in: .rect(cornerRadius: Self.cornerRadius))
    }

    private func row(symbol: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.inkMuted.color)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.inkMuted.color)
        }
    }

    private var tail: some View {
        QuestMapPopoverTail()
            .fill(palette.paperSheet.color)
            .frame(width: Self.tailLength, height: Self.tailHeight)
    }
}

/// `1026:3514`'s callout tail: concave sides meeting in a point, the shape an iOS popover arrow
/// draws.
struct QuestMapPopoverTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: 0),
            control: CGPoint(x: rect.maxX * 0.45, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.midY),
            control: CGPoint(x: rect.maxX * 0.45, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// What the card needs to stand next to its marker, gathered so the representable hands over one
/// value.
struct QuestMapPopoverControls {
    let presentation: QuestMapPopoverPresentation?
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
                onStart: controls.onStart))
            host.view.backgroundColor = .clear
            container.addSubview(host.view)
            hostingController = host
        }

        position(mapView: mapView, at: coordinate)
        hostingController?.rootView = QuestMapPopoverCard(
            palette: controls.palette,
            presentation: presentation,
            tailEdge: tailEdge,
            onStart: controls.onStart)
    }

    /// Puts the card down-left of its marker, the way the frame hangs `1026:3514` off the cluster,
    /// and flips it around the marker when there is no room on that side.
    private func position(mapView: MKMapView, at coordinate: CLLocationCoordinate2D) {
        guard let host = hostingController else { return }
        let point = mapView.convert(coordinate, toPointTo: container)

        let size = host.sizeThatFits(in: CGSize(
            width: QuestMapPopoverCard.width, height: .greatestFiniteMagnitude))

        let gap: CGFloat = 10 + QuestMapPopoverCard.tailLength
        let flipped = point.x - gap - size.width < 8
        tailEdge = flipped ? .left : .right

        var origin = CGPoint(x: flipped ? point.x + gap : point.x - gap - size.width,
                             y: point.y + 24 - size.height / 2)

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
