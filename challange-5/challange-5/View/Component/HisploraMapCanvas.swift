import ContentKit
import DesignSystem
import SwiftUI

/// High-fidelity vector canvas renderer for the Hisplora vintage Balinese heritage map,
/// with GeoLibre-compatible customizable 2.5D building extrusions and deep zoom LOD.
struct HisploraMapCanvas: View {

    let projection: HisploraMapProjection
    let route: [Coordinate]?
    let activeQuestCoordinate: Coordinate?
    let userCoordinate: Coordinate?
    let buildingOptions: GeoLibreBuildingOptions
    let selectedBuildingID: String?

    init(
        projection: HisploraMapProjection,
        route: [Coordinate]? = nil,
        activeQuestCoordinate: Coordinate? = nil,
        userCoordinate: Coordinate? = nil,
        buildingOptions: GeoLibreBuildingOptions = GeoLibreBuildingOptions(),
        selectedBuildingID: String? = nil
    ) {
        self.projection = projection
        self.route = route
        self.activeQuestCoordinate = activeQuestCoordinate
        self.userCoordinate = userCoordinate
        self.buildingOptions = buildingOptions
        self.selectedBuildingID = selectedBuildingID
    }

    private var zoom: CGFloat {
        projection.zoom
    }

    var body: some View {
        Canvas { context, size in
            // 1. Base aged parchment background
            drawParchmentGround(context: context, size: size)

            // 2. Cadastral parcel sketch lines (Balinese pekarangan compounds)
            if buildingOptions.showParcels {
                drawParcelSketches(context: context)
            }

            // 3. Heritage polygon areas (Puputan park, royal palaces, courtyards)
            drawPolygonAreas(context: context)

            // 4. GeoLibre 2.5D Building Footprints & Isometric Roof Extrusions
            drawBuildingsAndExtrusions(context: context)

            // 5. Tukad Badung river watercolor wash & tributaries
            drawWaterways(context: context)

            // 6. Road network: Casing, Fill, and Junctions
            drawRoadCasings(context: context)
            drawRoadFills(context: context)

            // 7. Roundabouts & Transit / Heritage Badges
            drawRoundabouts(context: context)
            drawTransitBadges(context: context)

            // 8. Hand-drawn ink walking route
            drawWalkingRoute(context: context)

            // 9. Angled Street Labels along road vectors
            drawStreetLabels(context: context)

            // 10. Calligraphic Landmark Art & Green Sketch Rings
            drawCalligraphicLandmarks(context: context)

            // 11. Live Realtime GPS Explorer Position Marker
            drawLiveUserMarker(context: context)

            // 12. Vintage cartographic ornaments (compass rose & scale bar)
            drawCartographicDecorations(context: context, size: size)
        }
    }

    // MARK: - 1. Parchment Background

    private func drawParchmentGround(context: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(HisploraMapStyle.parchmentGround.color))

        // Subtle vintage aging wash
        let washGradient = Gradient(stops: [
            .init(color: HisploraMapStyle.parchmentWarm.color.opacity(0.45), location: 0.0),
            .init(color: Color.clear, location: 0.35),
            .init(color: Color.clear, location: 0.70),
            .init(color: HisploraMapStyle.parchmentSunken.color.opacity(0.40), location: 1.0)
        ])
        context.fill(
            Path(rect),
            with: .radialGradient(
                washGradient,
                center: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                startRadius: size.width * 0.15,
                endRadius: size.width * 0.85
            )
        )
    }

    // MARK: - 2. Cadastral Parcel Sketches (LOD Zoom Dependent)

    private func drawParcelSketches(context: GraphicsContext) {
        let parcelAlpha: Double = zoom > 1.8 ? 0.55 : (zoom > 1.2 ? 0.35 : 0.20)
        for parcel in HisploraDenpasarDistrict.parcelSketches {
            guard parcel.coordinates.count >= 2 else { continue }
            var path = Path()
            path.move(to: projection.project(parcel.coordinates[0]))
            for coord in parcel.coordinates.dropFirst() {
                path.addLine(to: projection.project(coord))
            }
            context.stroke(
                path,
                with: .color(HisploraMapStyle.parcelLine.color.opacity(parcelAlpha)),
                style: HisploraMapStyle.parcelStrokeStyle
            )
        }
    }

    // MARK: - 3. Heritage Polygon Areas

    private func drawPolygonAreas(context: GraphicsContext) {
        let isDeepZoom = zoom >= 1.2
        for area in HisploraDenpasarDistrict.areas {
            guard area.coordinates.count >= 3 else { continue }
            var path = Path()
            path.move(to: projection.project(area.coordinates[0]))
            for coord in area.coordinates.dropFirst() {
                path.addLine(to: projection.project(coord))
            }
            path.closeSubpath()

            switch area.kind {
            case .park:
                context.fill(path, with: .color(HisploraMapStyle.parkWash.color.opacity(0.40)))
                context.stroke(
                    path,
                    with: .color(HisploraMapStyle.parkBorder.color.opacity(0.6)),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 3])
                )
                if isDeepZoom {
                    // Tree pattern
                    for pt in area.coordinates {
                        let projected = projection.project(pt)
                        let text = Text("🌳").font(.system(size: 6))
                        context.draw(context.resolve(text), at: projected)
                    }
                }
            case .palaceCompound:
                context.fill(path, with: .color(HisploraMapStyle.compoundWash.color.opacity(0.40)))
                context.stroke(
                    path,
                    with: .color(HisploraMapStyle.compoundBorder.color.opacity(0.5)),
                    style: StrokeStyle(lineWidth: 1.0, dash: [6, 3])
                )
            case .templeCourtyard:
                context.fill(path, with: .color(HisploraMapStyle.parchmentWarm.color.opacity(0.45)))
                context.stroke(
                    path,
                    with: .color(HisploraMapStyle.roadCasing.color.opacity(0.35)),
                    style: StrokeStyle(lineWidth: 0.8, dash: [4, 3])
                )
                if isDeepZoom {
                    // Sand/Flagstone texture points
                    let bounds = path.boundingRect
                    var step: CGFloat = 20
                    for y in stride(from: bounds.minY, to: bounds.maxY, by: step) {
                        for x in stride(from: bounds.minX, to: bounds.maxX, by: step) {
                            let pt = CGPoint(x: x + CGFloat.random(in: -5...5), y: y + CGFloat.random(in: -5...5))
                            if path.contains(pt) {
                                let rect = CGRect(x: pt.x, y: pt.y, width: 2, height: 1)
                                context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(HisploraMapStyle.roadCasing.color.opacity(0.3)))
                            }
                        }
                    }
                }
            case .marketComplex:
                context.fill(path, with: .color(HisploraMapStyle.parchmentSunken.color.opacity(0.30)))
                context.stroke(
                    path,
                    with: .color(HisploraMapStyle.parcelLine.color.opacity(0.45)),
                    style: StrokeStyle(lineWidth: 0.8, dash: [5, 2])
                )
            }
        }
    }

    // MARK: - 4. GeoLibre 2.5D Building Footprints & Extrusion

    private func drawBuildingsAndExtrusions(context: GraphicsContext) {
        guard buildingOptions.isEnabled else { return }
        let isDeepZoom = zoom >= 1.4

        for building in HisploraDenpasarDistrict.buildings {
            guard buildingOptions.visibleClasses.contains(building.class) else { continue }
            guard building.coordinates.count >= 3 else { continue }

            let groundPts = building.coordinates.map { projection.project($0) }
            let isSelected = selectedBuildingID == building.id
            let heightPixels = projection.metersToPoints(building.heightM)

            var groundPath = Path()
            groundPath.move(to: groundPts[0])
            for pt in groundPts.dropFirst() {
                groundPath.addLine(to: pt)
            }
            groundPath.closeSubpath()

            if buildingOptions.renderMode == .isometric25D && isDeepZoom {
                let roofPts = GeoLibreBuildingMath.computeRoofPoints(groundPoints: groundPts, heightPixels: heightPixels)

                var roofPath = Path()
                roofPath.move(to: roofPts[0])
                for pt in roofPts.dropFirst() {
                    roofPath.addLine(to: pt)
                }
                roofPath.closeSubpath()

                // 1. Footprint ground ambient drop shadow
                var shadowPath = groundPath
                shadowPath = shadowPath.offsetBy(dx: heightPixels * 0.2, dy: heightPixels * 0.2)
                context.fill(shadowPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.25)))

                // 2. Isometric Side Wall Facets
                for i in 0..<groundPts.count {
                    let nextI = (i + 1) % groundPts.count
                    let g1 = groundPts[i]
                    let g2 = groundPts[nextI]
                    let r1 = roofPts[i]
                    let r2 = roofPts[nextI]

                    var wallPath = Path()
                    wallPath.move(to: g1)
                    wallPath.addLine(to: g2)
                    wallPath.addLine(to: r2)
                    wallPath.addLine(to: r1)
                    wallPath.closeSubpath()

                    // Dynamic shading based on surface normal relative to isometric sun
                    let shadeFactor = GeoLibreBuildingMath.wallShadeFactor(p1: g1, p2: g2)
                    let wallShade = HisploraMapStyle.compoundBorder.color.opacity(shadeFactor)

                    context.fill(wallPath, with: .color(wallShade))
                    context.stroke(wallPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.5)), lineWidth: 0.8)
                }

                // 3. Extruded Roof Top
                let roofFillColor: Color
                switch building.class {
                case .royalPalace:
                    roofFillColor = Color(red: 0.82, green: 0.72, blue: 0.62)
                case .templeShrine:
                    roofFillColor = Color(red: 0.88, green: 0.82, blue: 0.74)
                case .marketHall:
                    roofFillColor = Color(red: 0.78, green: 0.68, blue: 0.58)
                case .commercialShophouse:
                    roofFillColor = Color(red: 0.84, green: 0.77, blue: 0.70)
                case .civic:
                    roofFillColor = Color(red: 0.86, green: 0.80, blue: 0.73)
                case .residentialCompound:
                    roofFillColor = HisploraMapStyle.compoundWash.color
                }

                context.fill(roofPath, with: .color(roofFillColor))
                context.stroke(
                    roofPath,
                    with: .color(isSelected ? HisploraMapStyle.goldStamp.color : HisploraMapStyle.roadCasing.color),
                    lineWidth: isSelected ? 2.0 : 1.2
                )
                
                // Draw multi-tiers for Meru roofs
                if building.roofType == .balineseMeru && zoom >= 2.0 {
                    let numTiers = min(building.levels, 5)
                    for tier in 1..<numTiers {
                        let scale = 1.0 - (CGFloat(tier) * 0.15)
                        let tierHeight = heightPixels + (CGFloat(tier) * 8.0)
                        let tierPts = GeoLibreBuildingMath.computeRoofPoints(groundPoints: groundPts, heightPixels: tierHeight, scale: scale)
                        var tierPath = Path()
                        tierPath.move(to: tierPts[0])
                        for pt in tierPts.dropFirst() { tierPath.addLine(to: pt) }
                        tierPath.closeSubpath()
                        
                        // Shade for tier walls
                        for i in 0..<groundPts.count {
                            let nextI = (i + 1) % groundPts.count
                            let r1 = (tier == 1) ? roofPts[i] : GeoLibreBuildingMath.computeRoofPoints(groundPoints: groundPts, heightPixels: heightPixels + (CGFloat(tier-1) * 8.0), scale: 1.0 - (CGFloat(tier-1) * 0.15))[i]
                            let r2 = (tier == 1) ? roofPts[nextI] : GeoLibreBuildingMath.computeRoofPoints(groundPoints: groundPts, heightPixels: heightPixels + (CGFloat(tier-1) * 8.0), scale: 1.0 - (CGFloat(tier-1) * 0.15))[nextI]
                            let t1 = tierPts[i]
                            let t2 = tierPts[nextI]
                            
                            var wallPath = Path()
                            wallPath.move(to: r1)
                            wallPath.addLine(to: r2)
                            wallPath.addLine(to: t2)
                            wallPath.addLine(to: t1)
                            wallPath.closeSubpath()
                            
                            let shadeFactor = GeoLibreBuildingMath.wallShadeFactor(p1: groundPts[i], p2: groundPts[nextI])
                            context.fill(wallPath, with: .color(HisploraMapStyle.compoundBorder.color.opacity(shadeFactor)))
                            context.stroke(wallPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.5)), lineWidth: 0.6)
                        }
                        
                        context.fill(tierPath, with: .color(roofFillColor.opacity(0.9)))
                        context.stroke(tierPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.8)), lineWidth: 1.0)
                    }
                }

                // 4. Traditional Balinese Roof Ridge Lines (Meru & Limasan)
                if (building.roofType == .balineseMeru || building.roofType == .limasan) && roofPts.count >= 4 {
                    var ridge = Path()
                    ridge.move(to: roofPts[0])
                    ridge.addLine(to: roofPts[2])
                    context.stroke(ridge, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.4)), lineWidth: 0.8)
                }

                // 5. Building Name Tag if enabled and deep zoomed
                if buildingOptions.showBuildingLabels && zoom >= 2.6 {
                    let avgX = roofPts.map(\.x).reduce(0, +) / CGFloat(roofPts.count)
                    let avgY = roofPts.map(\.y).reduce(0, +) / CGFloat(roofPts.count)

                    let text = Text(building.name)
                        .font(.system(size: 7.5, weight: .bold, design: .serif))
                        .foregroundStyle(HisploraMapStyle.inkText.color)

                    context.draw(context.resolve(text), at: CGPoint(x: avgX, y: avgY), anchor: .center)
                }

            } else {
                // 2D Footprint Mode
                context.fill(groundPath, with: .color(HisploraMapStyle.compoundWash.color.opacity(0.6)))
                context.stroke(
                    groundPath,
                    with: .color(isSelected ? HisploraMapStyle.goldStamp.color : HisploraMapStyle.roadCasing.color.opacity(0.8)),
                    lineWidth: isSelected ? 2.0 : 1.0
                )
            }
        }
    }

    // MARK: - 5. Waterways (Tukad Badung Watercolor Wash)

    private func drawWaterways(context: GraphicsContext) {
        for waterway in HisploraDenpasarDistrict.waterways {
            guard waterway.coordinates.count >= 2 else { continue }
            let points = waterway.coordinates.map { projection.project($0) }

            var path = Path()
            path.move(to: points[0])
            for i in 1..<points.count {
                let mid = CGPoint(
                    x: (points[i - 1].x + points[i].x) / 2.0,
                    y: (points[i - 1].y + points[i].y) / 2.0
                )
                path.addQuadCurve(to: mid, control: points[i - 1])
            }
            if let last = points.last {
                path.addLine(to: last)
            }

            let riverPixelWidth = max(projection.metersToPoints(waterway.widthM), 5.0)

            // 1. Soft blue river wash
            context.stroke(
                path,
                with: .color(Color(red: 0.61, green: 0.77, blue: 0.84).opacity(0.85)),
                style: StrokeStyle(lineWidth: riverPixelWidth, lineCap: .round, lineJoin: .round)
            )

            // 2. Hand-drawn sepia river bank casing lines
            context.stroke(
                path,
                with: .color(HisploraMapStyle.riverCasing.color),
                style: StrokeStyle(lineWidth: riverPixelWidth + 1.6, lineCap: .round, lineJoin: .round)
            )
            // Re-apply fill over inner casing
            context.stroke(
                path,
                with: .color(Color(red: 0.61, green: 0.77, blue: 0.84)),
                style: StrokeStyle(lineWidth: riverPixelWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - 6. Road Network (Double Casing + Crisp White Fills)

    private func drawRoadCasings(context: GraphicsContext) {
        for road in HisploraDenpasarDistrict.roads {
            guard road.coordinates.count >= 2 else { continue }
            let points = road.coordinates.map { projection.project($0) }

            var path = Path()
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }

            let casingWidth: CGFloat
            let casingColor: Color

            switch road.type {
            case .major:
                casingWidth = HisploraMapStyle.roadMajorCasingWidth
                casingColor = HisploraMapStyle.roadCasing.color
            case .secondary:
                casingWidth = HisploraMapStyle.roadSecondaryCasingWidth
                casingColor = HisploraMapStyle.roadCasing.color
            case .alley:
                if zoom < 1.1 { continue }
                casingWidth = 1.4
                casingColor = HisploraMapStyle.roadCasingMinor.color.opacity(0.85)
            }

            context.stroke(
                path,
                with: .color(casingColor),
                style: StrokeStyle(lineWidth: casingWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawRoadFills(context: GraphicsContext) {
        for road in HisploraDenpasarDistrict.roads {
            guard road.coordinates.count >= 2 else { continue }
            if road.type == .alley && zoom < 1.1 { continue }

            let points = road.coordinates.map { projection.project($0) }

            var path = Path()
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }

            let fillWidth: CGFloat
            let fillColor: Color

            switch road.type {
            case .major:
                fillWidth = HisploraMapStyle.roadMajorFillWidth
                fillColor = Color.white
            case .secondary:
                fillWidth = HisploraMapStyle.roadSecondaryFillWidth
                fillColor = Color.white
            case .alley:
                fillWidth = 0.8
                fillColor = HisploraMapStyle.roadFillMinor.color
            }

            context.stroke(
                path,
                with: .color(fillColor),
                style: StrokeStyle(lineWidth: fillWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    // MARK: - 7. Roundabouts & Transit Badges

    private func drawRoundabouts(context: GraphicsContext) {
        for rb in HisploraDenpasarDistrict.roundabouts {
            let center = projection.project(rb.coordinate)
            let radius = max(projection.metersToPoints(rb.radiusM), 5.0)

            let outerCircle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            let innerRadius = radius * 0.45
            let innerCircle = Path(ellipseIn: CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2, height: innerRadius * 2))

            // White roadway ring
            context.fill(outerCircle, with: .color(.white))
            context.stroke(outerCircle, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 1.4)

            // Inner island circle
            context.fill(innerCircle, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.85)))
            context.stroke(innerCircle, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 1.0)
        }
    }

    private func drawTransitBadges(context: GraphicsContext) {
        if zoom < 1.25 { return }
        for badge in HisploraDenpasarDistrict.transitBadges {
            let pt = projection.project(badge.coordinate)
            let badgeRadius: CGFloat = 7.0

            let circlePath = Path(ellipseIn: CGRect(x: pt.x - badgeRadius, y: pt.y - badgeRadius, width: badgeRadius * 2, height: badgeRadius * 2))
            context.fill(circlePath, with: .color(.white))
            context.stroke(circlePath, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 1.2)

            let text = Text(badge.symbol)
                .font(.system(size: 6.5, weight: .bold, design: .serif))
                .foregroundStyle(HisploraMapStyle.roadCasing.color)

            context.draw(context.resolve(text), at: pt, anchor: .center)
        }
    }

    // MARK: - 8. Hand-Drawn Walking Route

    private func drawWalkingRoute(context: GraphicsContext) {
        guard let route, route.count >= 2 else { return }

        var routePath = Path()
        let startPoint = projection.project(route[0])
        routePath.move(to: startPoint)

        for coord in route.dropFirst() {
            routePath.addLine(to: projection.project(coord))
        }

        // Soft ink halo
        context.stroke(
            routePath,
            with: .color(HisploraMapStyle.parchmentGround.color.opacity(0.9)),
            style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round)
        )

        // Inked trail
        context.stroke(
            routePath,
            with: .color(HisploraMapStyle.routeInk.color),
            style: HisploraMapStyle.routeStrokeStyle
        )
        
        // Directional Arrows
        if zoom >= 1.5 {
            for i in 0..<(route.count - 1) {
                let p1 = projection.project(route[i])
                let p2 = projection.project(route[i+1])
                
                let dx = p2.x - p1.x
                let dy = p2.y - p1.y
                let dist = sqrt(dx*dx + dy*dy)
                
                if dist > 30 {
                    let angle = atan2(dy, dx)
                    let midX = p1.x + dx * 0.5
                    let midY = p1.y + dy * 0.5
                    
                    var arrowPath = Path()
                    let arrowLength: CGFloat = 8
                    let arrowWidth: CGFloat = 6
                    
                    arrowPath.move(to: CGPoint(x: midX + cos(angle) * arrowLength, y: midY + sin(angle) * arrowLength))
                    arrowPath.addLine(to: CGPoint(x: midX + cos(angle + .pi*0.75) * arrowWidth, y: midY + sin(angle + .pi*0.75) * arrowWidth))
                    arrowPath.addLine(to: CGPoint(x: midX + cos(angle - .pi*0.75) * arrowWidth, y: midY + sin(angle - .pi*0.75) * arrowWidth))
                    arrowPath.closeSubpath()
                    
                    context.fill(arrowPath, with: .color(HisploraMapStyle.goldStamp.color))
                    context.stroke(arrowPath, with: .color(HisploraMapStyle.routeInk.color), lineWidth: 1.5)
                }
            }
        }

        // Dashed bearing line from user to active quest
        if let user = userCoordinate, let target = activeQuestCoordinate {
            let uPt = projection.project(user)
            let tPt = projection.project(target)
            var bearingPath = Path()
            bearingPath.move(to: uPt)
            bearingPath.addLine(to: tPt)
            context.stroke(
                bearingPath,
                with: .color(HisploraMapStyle.goldStamp.color.opacity(0.8)),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
            )
        }
    }

    // MARK: - 9. Angled Street Labels (LOD Scaled)

    private func drawStreetLabels(context: GraphicsContext) {
        for road in HisploraDenpasarDistrict.roads {
            if road.type == .secondary && zoom < 1.2 { continue }
            if road.type == .alley && zoom < 2.0 { continue }

            guard let offset = road.labelOffset, road.coordinates.count >= 2 else { continue }
            let p0 = projection.project(road.coordinates[0])
            let p1 = projection.project(road.coordinates.last!)

            let labelPoint = CGPoint(
                x: p0.x + (p1.x - p0.x) * CGFloat(offset),
                y: p0.y + (p1.y - p0.y) * CGFloat(offset)
            )

            let deltaX = p1.x - p0.x
            let deltaY = p1.y - p0.y
            var angle = atan2(deltaY, deltaX)

            if angle > .pi / 2.0 {
                angle -= .pi
            } else if angle < -.pi / 2.0 {
                angle += .pi
            }

            let fontSize: CGFloat = road.type == .major ? 9.5 : (road.type == .secondary ? 8.2 : 7.0)

            var labelContext = context
            labelContext.translateBy(x: labelPoint.x, y: labelPoint.y)
            labelContext.rotate(by: Angle(radians: Double(angle)))

            let text = Text(road.name)
                .font(.system(size: fontSize, weight: road.type == .major ? .bold : .medium, design: .serif))
                .foregroundStyle(HisploraMapStyle.inkText.color.opacity(0.9))

            labelContext.draw(labelContext.resolve(text), at: .zero, anchor: .center)
        }
    }

    // MARK: - 10. Calligraphic Landmark Art & Green Sketch Rings

    private func drawCalligraphicLandmarks(context: GraphicsContext) {
        for landmark in HisploraDenpasarDistrict.calligraphicLandmarks {
            let pt = projection.project(landmark.coordinate)
            let radius = max(projection.metersToPoints(landmark.circleRadiusM), 14.0)

            // 1. Hand-Drawn Sage-Green Sketch Circle around the site
            let circleColor = SRGBColor(hex: landmark.circleColorHex).color
            let circleRect = CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2)

            let circle1 = Path(ellipseIn: circleRect)
            let circle2 = Path(ellipseIn: circleRect.insetBy(dx: 1.2, dy: -0.8))
            context.stroke(circle1, with: .color(circleColor.opacity(0.75)), lineWidth: 1.6)
            context.stroke(circle2, with: .color(circleColor.opacity(0.45)), lineWidth: 1.0)

            // 2. Hand-Lettered Bold Typography Title
            let textColor = SRGBColor(hex: landmark.textColorHex).color
            let textPt = CGPoint(x: pt.x + landmark.labelOffsetPoints.x, y: pt.y + landmark.labelOffsetPoints.y)

            let lines = landmark.title.components(separatedBy: "\n")
            let lineHeight: CGFloat = 13.0
            let totalHeight = CGFloat(lines.count - 1) * lineHeight

            for (index, line) in lines.enumerated() {
                let lineY = textPt.y - (totalHeight / 2.0) + (CGFloat(index) * lineHeight)
                let titleText = Text(line)
                    .font(.system(size: 13.0, weight: .black, design: .rounded))
                    .foregroundStyle(textColor)

                context.draw(context.resolve(titleText), at: CGPoint(x: textPt.x, y: lineY), anchor: .center)
            }

            // 3. Iconic Heritage Pin Marker on the gateway
            let pinColor = SRGBColor(hex: landmark.pinColorHex).color
            drawHeritagePin(context: context, at: pt, color: pinColor)
        }
    }

    private func drawHeritagePin(context: GraphicsContext, at point: CGPoint, color: Color) {
        let pinHeight: CGFloat = 16.0
        let pinWidth: CGFloat = 10.0

        var pinPath = Path()
        let topCenter = CGPoint(x: point.x, y: point.y - pinHeight + 5)

        pinPath.addArc(center: topCenter, radius: pinWidth / 2.0, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        pinPath.addLine(to: CGPoint(x: point.x, y: point.y))
        pinPath.closeSubpath()

        let shadowPath = Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 1.5, width: 8, height: 3))
        context.fill(shadowPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.35)))

        context.fill(pinPath, with: .color(color))
        context.stroke(pinPath, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 1.0)

        let dot = Path(ellipseIn: CGRect(x: topCenter.x - 2, y: topCenter.y - 2, width: 4, height: 4))
        context.fill(dot, with: .color(.white))
    }

    // MARK: - 11. Live Realtime GPS Explorer Position Marker

    private func drawLiveUserMarker(context: GraphicsContext) {
        guard let userCoordinate else { return }
        let pt = projection.project(userCoordinate)

        let aura = Path(ellipseIn: CGRect(x: pt.x - 18, y: pt.y - 18, width: 36, height: 36))
        context.fill(aura, with: .color(HisploraMapStyle.markerActive.color.opacity(0.12)))
        context.stroke(
            aura,
            with: .color(HisploraMapStyle.markerActive.color.opacity(0.35)),
            style: StrokeStyle(lineWidth: 1.0, dash: [3, 3])
        )

        let text = Text("✦ YOU ●")
            .font(.system(size: 8.5, weight: .black, design: .serif))
            .foregroundStyle(HisploraMapStyle.markerActive.color)

        context.draw(context.resolve(text), at: CGPoint(x: pt.x, y: pt.y - 14), anchor: .center)

        let centerDot = Path(ellipseIn: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8))
        context.fill(centerDot, with: .color(HisploraMapStyle.markerActive.color))
        context.stroke(centerDot, with: .color(.white), lineWidth: 1.5)
    }

    // MARK: - 12. Cartographic Decorations

    private func drawCartographicDecorations(context: GraphicsContext, size: CGSize) {
        let compassCenter = CGPoint(x: size.width - 34, y: 38)
        drawCompassRose(context: context, at: compassCenter)
        drawScaleBar(context: context, at: CGPoint(x: 20, y: size.height - 24))
    }

    private func drawCompassRose(context: GraphicsContext, at center: CGPoint) {
        let radius: CGFloat = 13.0
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(circle, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.5)), lineWidth: 0.9)

        var needle = Path()
        needle.move(to: CGPoint(x: center.x, y: center.y - radius - 2))
        needle.addLine(to: CGPoint(x: center.x + 3.5, y: center.y))
        needle.addLine(to: CGPoint(x: center.x + 3.5, y: center.y))
        needle.addLine(to: CGPoint(x: center.x - 3.5, y: center.y))
        needle.closeSubpath()
        context.fill(needle, with: .color(HisploraMapStyle.roadCasing.color))

        context.draw(
            Text("N")
                .font(.system(size: 7.5, weight: .bold, design: .serif))
                .foregroundStyle(HisploraMapStyle.roadCasing.color),
            at: CGPoint(x: center.x, y: center.y - radius - 8)
        )
    }

    private func drawScaleBar(context: GraphicsContext, at origin: CGPoint) {
        let barLengthPoints: CGFloat = 45.0
        let barMeters = Int(projection.pointsToMeters(barLengthPoints))

        var barPath = Path()
        barPath.move(to: origin)
        barPath.addLine(to: CGPoint(x: origin.x + barLengthPoints, y: origin.y))
        barPath.move(to: CGPoint(x: origin.x, y: origin.y - 3))
        barPath.addLine(to: CGPoint(x: origin.x, y: origin.y + 3))
        barPath.move(to: CGPoint(x: origin.x + barLengthPoints, y: origin.y - 3))
        barPath.addLine(to: CGPoint(x: origin.x + barLengthPoints, y: origin.y + 3))

        context.stroke(barPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.7)), lineWidth: 1.0)

        let label = Text("\(barMeters) m")
            .font(.system(size: 7, weight: .bold, design: .serif))
            .foregroundStyle(HisploraMapStyle.roadCasing.color.opacity(0.8))

        context.draw(context.resolve(label), at: CGPoint(x: origin.x + barLengthPoints / 2.0, y: origin.y - 6), anchor: .bottom)
    }
}
