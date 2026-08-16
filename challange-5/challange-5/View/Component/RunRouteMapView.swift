import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// `FR-MAP-02` — the map during an active Run: the ordered checkpoint sequence, where the walker is
/// relative to the next stop, and the straight-line distance remaining.
///
/// Drawn, not tiled. `FR-MAP-01` and `FR-OFF-03` rule out live map tiles, so there is no
/// `MKMapView` here and there never will be — every core flow has to work in airplane mode. What
/// replaces it is the authored route geometry the content already ships, projected onto a canvas by
/// `RouteProjection`, which is arithmetic and therefore testable.
///
/// `Place.mapPoint` is not used and must not be: it is authored against the stylised island
/// illustration and means nothing at street scale.
struct RunRouteMapView: View {
    @Environment(\.kultaraPalette) private var palette

    private let route: RunRoutePresentation
    private let language: ContentLanguage
    private let totalCheckpoints: Int
    private let showsChrome: Bool

    /// Scales with the reader's text size, so the numbers inside the canvas do not outgrow it.
    @ScaledMetric private var canvasHeight: CGFloat = 200

    /// `showsChrome` is false on the Hisplora screens. The heading and the distance row are drawn in
    /// the museum theme's inks — seal red and body ink — which are measured against *paper*, not
    /// against the story flow's brown ground, where the heading falls to roughly 2:1. The caller on
    /// that ground supplies its own heading and its own numbers in inks the Hisplora palette
    /// measures. The canvas itself is unaffected: it draws on its own paper panel either way.
    init(
        route: RunRoutePresentation,
        language: ContentLanguage,
        totalCheckpoints: Int,
        showsChrome: Bool = true
    ) {
        self.route = route
        self.language = language
        self.totalCheckpoints = totalCheckpoints
        self.showsChrome = showsChrome
    }

    /// Everything drawn has to fit, so the projection is fitted to all of it at once — the line,
    /// the stops, and the walker if there is a fix.
    private var drawnCoordinates: [Coordinate] {
        route.line + route.stops.map(\.coordinate) + [route.userPosition].compactMap { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            if showsChrome {
                KultaraSectionHeading(UIStrings.string(.runMapHeading, language))
            }
            canvas
                .frame(height: canvasHeight)
                .background(palette.paperSunken.color)
                .overlay(
                    RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius)
                        .stroke(palette.rule.color, lineWidth: KultaraMetrics.hairline))
                .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius))
                // A drawing is not readable by VoiceOver, so the same three facts are stated.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityLabel)
            if showsChrome, let distance = route.distanceRemainingText {
                LabelledValue(label: UIStrings.string(.arrivalDistanceRemaining, language),
                              value: distance)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var canvas: some View {
        Canvas { context, size in
            guard let projection = RouteProjection(
                coordinates: drawnCoordinates,
                width: size.width,
                height: size.height,
                padding: 26) else { return }

            drawArrivalRadius(context: context, projection: projection)
            drawRoute(context: context, projection: projection)
            drawLineToTarget(context: context, projection: projection)
            drawStops(context: context, projection: projection)
            drawUser(context: context, projection: projection)
        }
    }

    private func point(_ coordinate: Coordinate, _ projection: RouteProjection) -> CGPoint {
        let projected = projection.project(coordinate)
        return CGPoint(x: projected.x, y: projected.y)
    }

    /// The gate itself, at true scale. Drawing it at a size that merely looks about right would
    /// misstate the one thing on this screen that decides whether the checkpoint unlocks.
    private func drawArrivalRadius(context: GraphicsContext, projection: RouteProjection) {
        guard let target = route.target, route.targetRadiusM > 0 else { return }
        let centre = point(target, projection)
        let radius = projection.units(forMetres: route.targetRadiusM)
        let rect = CGRect(x: centre.x - radius, y: centre.y - radius,
                          width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(palette.seal.color.opacity(0.12)))
        context.stroke(Path(ellipseIn: rect),
                       with: .color(palette.seal.color.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    }

    private func drawRoute(context: GraphicsContext, projection: RouteProjection) {
        guard route.line.count >= 2 else { return }
        var path = Path()
        path.move(to: point(route.line[0], projection))
        for coordinate in route.line.dropFirst() {
            path.addLine(to: point(coordinate, projection))
        }
        context.stroke(path, with: .color(palette.inkMuted.color),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        // Directional Arrows
        for i in 0..<(route.line.count - 1) {
            let p1 = point(route.line[i], projection)
            let p2 = point(route.line[i+1], projection)
            
            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let dist = sqrt(dx*dx + dy*dy)
            
            if dist > 30 {
                let angle = atan2(dy, dx)
                let midX = p1.x + dx * 0.5
                let midY = p1.y + dy * 0.5
                
                var arrowPath = Path()
                let arrowLength: CGFloat = 6
                let arrowWidth: CGFloat = 4
                
                arrowPath.move(to: CGPoint(x: midX + cos(angle) * arrowLength, y: midY + sin(angle) * arrowLength))
                arrowPath.addLine(to: CGPoint(x: midX + cos(angle + .pi*0.75) * arrowWidth, y: midY + sin(angle + .pi*0.75) * arrowWidth))
                arrowPath.addLine(to: CGPoint(x: midX + cos(angle - .pi*0.75) * arrowWidth, y: midY + sin(angle - .pi*0.75) * arrowWidth))
                arrowPath.closeSubpath()
                
                context.fill(arrowPath, with: .color(palette.paper.color))
                context.stroke(arrowPath, with: .color(palette.inkMuted.color), lineWidth: 1.5)
            }
        }
    }

    /// The straight line `FR-MAP-02` asks for, with the distance printed on it. Dashed, so it does
    /// not read as a path anybody should walk — it is a bearing, not a route.
    private func drawLineToTarget(context: GraphicsContext, projection: RouteProjection) {
        guard let user = route.userPosition, let target = route.target else { return }
        let from = point(user, projection)
        let to = point(target, projection)
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(palette.seal.color),
                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

        if let distance = route.distanceRemainingText {
            let midpoint = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
            context.draw(
                Text(distance)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.seal.color),
                at: CGPoint(x: midpoint.x, y: midpoint.y - 10))
        }
    }

    private func drawStops(context: GraphicsContext, projection: RouteProjection) {
        for stop in route.stops {
            let centre = point(stop.coordinate, projection)
            let radius: CGFloat = stop.isTarget ? 11 : 8
            let rect = CGRect(x: centre.x - radius, y: centre.y - radius,
                              width: radius * 2, height: radius * 2)
            // Three states told apart by fill and ring as well as by colour (`NFR-A11Y-05`):
            // reached is solid, the target carries a ring, the rest are outlines.
            let fill = stop.isReached ? palette.seal.color : palette.paper.color
            context.fill(Path(ellipseIn: rect), with: .color(fill))
            context.stroke(Path(ellipseIn: rect),
                           with: .color(palette.ink.color),
                           lineWidth: stop.isTarget ? 2 : 1)
            context.draw(
                Text("\(stop.orderIndex + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(stop.isReached ? palette.inkOnSeal.color : palette.ink.color),
                at: centre)
        }
    }

    private func drawUser(context: GraphicsContext, projection: RouteProjection) {
        guard let user = route.userPosition else { return }
        let centre = point(user, projection)
        let outer = CGRect(x: centre.x - 7, y: centre.y - 7, width: 14, height: 14)
        let inner = CGRect(x: centre.x - 4, y: centre.y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: outer), with: .color(palette.paper.color))
        context.fill(Path(ellipseIn: inner), with: .color(palette.warning.color))
        context.stroke(Path(ellipseIn: inner), with: .color(palette.ink.color), lineWidth: 1)
    }
}
