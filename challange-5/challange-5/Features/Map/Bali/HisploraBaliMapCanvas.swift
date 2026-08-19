import ContentKit
import DesignSystem
import SwiftUI

/// Vector canvas renderer for the Whole Bali vintage cultural heritage map.
///
/// Draws aged ocean waters, coastline wave ripples, island landmasses (mainland, Nusa Penida,
/// Lembongan, Menjangan), mountain peaks with hatch shading, crater lakes, trade highways,
/// Balinese 8-direction compass rose, sea annotations, and decorative cartography.
struct HisploraBaliMapCanvas: View {

    let projection: HisploraBaliMapProjection
    let selectedLandmarkCoordinate: Coordinate?
    let userCoordinate: Coordinate?

    var body: some View {
        Canvas { context, size in
            // 1. Aged Ocean Water Background
            drawOceanParchment(context: context, size: size)

            // 2. Surrounding Ocean & Strait Labels
            drawSeaAnnotations(context: context, size: size)

            // 3. Decorative Cartographic Elements (Sailing boat, sea creature sketch)
            drawOceanDecorations(context: context)

            // 4. Coastline Wave Echoes (Ripple lines off the shore)
            drawCoastalWaveRipples(context: context)

            // 5. Landmass Polygons (Mainland Bali & Outlying Islands)
            drawLandmasses(context: context)

            // 6. Highland Ridge Forest Washes
            drawHighlandForestWashes(context: context)

            // 7. Sacred Crater Lakes (Batur, Beratan, Buyan, Tamblingan)
            drawCraterLakes(context: context)

            // 8. Island Highway Network (Main Trade Routes)
            drawHighways(context: context)

            // 9. Regency Regional Boundary Lines & Calligraphy
            drawRegencyBoundaries(context: context)

            // 10. Sacred Mountain Peaks with Vintage Hatch Shading
            drawMountainPeaks(context: context)

            // 11. Balinese 8-Direction Compass Rose (Pengider Nawasanga)
            drawBalineseCompassRose(context: context, size: size)

            // 12. Vintage Title Cartouche Banner & Scale Bar
            drawTitleBannerAndScale(context: context, size: size)
        }
    }

    // MARK: - 1. Ocean Background

    private func drawOceanParchment(context: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        // Muted parchment water tint
        context.fill(Path(rect), with: .color(HisploraMapStyle.parchmentGround.color))

        // Subtle vintage sea wash
        let seaWash = Color(red: 0.89, green: 0.85, blue: 0.77).opacity(0.45)
        context.fill(Path(rect), with: .color(seaWash))
    }

    // MARK: - 2. Sea Annotations

    private func drawSeaAnnotations(context: GraphicsContext, size: CGSize) {
        let labels: [(text: String, coord: Coordinate, angle: Double)] = [
            ("L A U T   B A L I", Coordinate(lat: -8.08, lon: 115.15), 0),
            ("S A M U D E R A   H I N D I A", Coordinate(lat: -8.88, lon: 115.18), 0),
            ("S E L A T   B A L I", Coordinate(lat: -8.28, lon: 114.41), -75),
            ("S E L A T   L O M B O K", Coordinate(lat: -8.45, lon: 115.73), 80),
            ("SELAT BADUNG", Coordinate(lat: -8.67, lon: 115.36), -35)
        ]

        for item in labels {
            let pt = projection.project(item.coord)
            let text = Text(item.text)
                .font(.system(size: 8.5, weight: .bold, design: .serif))
                .foregroundStyle(HisploraMapStyle.riverCasing.color.opacity(0.70))

            var textContext = context
            textContext.translateBy(x: pt.x, y: pt.y)
            textContext.rotate(by: .degrees(item.angle))
            textContext.draw(textContext.resolve(text), at: .zero, anchor: .center)
        }
    }

    // MARK: - 3. Ocean Decorations (Traditional Prahu / Outrigger Boat)

    private func drawOceanDecorations(context: GraphicsContext) {
        // Traditional Balinese Prahu in Selat Lombok
        let prahuCoord = Coordinate(lat: -8.58, lon: 115.65)
        let pt = projection.project(prahuCoord)

        var boatPath = Path()
        // Hull
        boatPath.move(to: CGPoint(x: pt.x - 14, y: pt.y + 2))
        boatPath.addQuadCurve(to: CGPoint(x: pt.x + 14, y: pt.y + 2), control: CGPoint(x: pt.x, y: pt.y + 6))
        boatPath.addLine(to: CGPoint(x: pt.x + 11, y: pt.y))
        boatPath.addLine(to: CGPoint(x: pt.x - 11, y: pt.y))
        boatPath.closeSubpath()

        // Triangular lateen sail
        boatPath.move(to: CGPoint(x: pt.x - 2, y: pt.y - 14))
        boatPath.addLine(to: CGPoint(x: pt.x + 10, y: pt.y - 1))
        boatPath.addLine(to: CGPoint(x: pt.x - 6, y: pt.y - 1))
        boatPath.closeSubpath()

        // Outrigger spar
        boatPath.move(to: CGPoint(x: pt.x - 8, y: pt.y + 4))
        boatPath.addLine(to: CGPoint(x: pt.x + 8, y: pt.y + 4))

        context.stroke(boatPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.35)), lineWidth: 0.9)
    }

    // MARK: - 4. Coastal Wave Ripples

    private func drawCoastalWaveRipples(context: GraphicsContext) {
        let rippleDistances: [Double] = [3000, 6500] // 3km and 6.5km offshore echoes

        for dist in rippleDistances {
            let strokePoints = HisploraBaliGeoData.mainlandCoastline.map { coord -> CGPoint in
                let pt = projection.project(coord)
                let centerPt = projection.project(HisploraBaliGeoData.islandCenter)
                let dx = pt.x - centerPt.x
                let dy = pt.y - centerPt.y
                let len = max(sqrt(dx * dx + dy * dy), 1.0)
                let offset = projection.metersToPoints(dist)
                return CGPoint(x: pt.x + (dx / len) * offset, y: pt.y + (dy / len) * offset)
            }

            guard strokePoints.count > 2 else { continue }
            var ripplePath = Path()
            ripplePath.move(to: strokePoints[0])
            for i in 1..<strokePoints.count {
                let mid = CGPoint(
                    x: (strokePoints[i - 1].x + strokePoints[i].x) / 2.0,
                    y: (strokePoints[i - 1].y + strokePoints[i].y) / 2.0
                )
                ripplePath.addQuadCurve(to: mid, control: strokePoints[i - 1])
            }
            ripplePath.closeSubpath()

            context.stroke(
                ripplePath,
                with: .color(HisploraMapStyle.riverCasing.color.opacity(0.30)),
                style: StrokeStyle(lineWidth: 0.8, dash: [4, 4])
            )
        }
    }

    // MARK: - 5. Landmasses (Mainland Bali & Islands)

    private func drawLandmasses(context: GraphicsContext) {
        let islandPolygons: [[Coordinate]] = [
            HisploraBaliGeoData.mainlandCoastline,
            HisploraBaliGeoData.nusaPenidaCoastline,
            HisploraBaliGeoData.nusaLembonganCoastline,
            HisploraBaliGeoData.nusaCeninganCoastline,
            HisploraBaliGeoData.pulauMenjanganCoastline
        ]

        for poly in islandPolygons {
            guard poly.count > 2 else { continue }
            var path = Path()
            let pts = poly.map { projection.project($0) }
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(
                    x: (pts[i - 1].x + pts[i].x) / 2.0,
                    y: (pts[i - 1].y + pts[i].y) / 2.0
                )
                path.addQuadCurve(to: mid, control: pts[i - 1])
            }
            path.closeSubpath()

            // 1. Warm cream land fill
            context.fill(path, with: .color(HisploraMapStyle.parchmentWarm.color))

            // 2. Deep sepia hand-drawn coastline rim
            context.stroke(path, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 1.6)

            // 3. Inner coastal vignette stroke
            context.stroke(path, with: .color(HisploraMapStyle.parcelLine.color.opacity(0.4)), lineWidth: 0.8)
        }
    }

    // MARK: - 6. Highland Forest Washes

    private func drawHighlandForestWashes(context: GraphicsContext) {
        // Central volcanic ridge highland wash (Bedugul – Batukaru – Kintamani)
        let highlandCoords: [Coordinate] = [
            Coordinate(lat: -8.22, lon: 115.12),
            Coordinate(lat: -8.20, lon: 115.42),
            Coordinate(lat: -8.36, lon: 115.54),
            Coordinate(lat: -8.40, lon: 115.35),
            Coordinate(lat: -8.38, lon: 115.05),
            Coordinate(lat: -8.28, lon: 115.06)
        ]

        var path = Path()
        let pts = highlandCoords.map { projection.project($0) }
        guard pts.count > 2 else { return }
        path.move(to: pts[0])
        for i in 1..<pts.count {
            let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
            path.addQuadCurve(to: mid, control: pts[i - 1])
        }
        path.closeSubpath()

        context.fill(path, with: .color(HisploraMapStyle.parkWash.color.opacity(0.35)))
    }

    // MARK: - 7. Sacred Crater Lakes

    private func drawCraterLakes(context: GraphicsContext) {
        for lake in HisploraBaliGeoData.lakes {
            guard lake.coordinates.count > 2 else { continue }
            var path = Path()
            let pts = lake.coordinates.map { projection.project($0) }
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i - 1])
            }
            path.closeSubpath()

            // Lake fill (mineral water)
            context.fill(path, with: .color(HisploraMapStyle.riverFill.color))
            // Lake shoreline
            context.stroke(path, with: .color(HisploraMapStyle.riverCasing.color), lineWidth: 1.1)

            // Lake label
            if let first = pts.first {
                let label = Text(lake.name)
                    .font(.system(size: 7.5, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(HisploraMapStyle.riverCasing.color)
                context.draw(context.resolve(label), at: CGPoint(x: first.x, y: first.y - 8), anchor: .center)
            }
        }
    }

    // MARK: - 8. Island Highway Network

    private func drawHighways(context: GraphicsContext) {
        for highway in HisploraBaliGeoData.highways {
            guard highway.coordinates.count > 1 else { continue }
            var path = Path()
            let pts = highway.coordinates.map { projection.project($0) }
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i - 1])
            }

            // Outer road casing
            context.stroke(path, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.7)), lineWidth: 2.2)
            // Inner cream fill
            context.stroke(path, with: .color(HisploraMapStyle.roadFill.color), lineWidth: 1.0)
        }
    }

    // MARK: - 9. Regency Boundaries & Typography

    private func drawRegencyBoundaries(context: GraphicsContext) {
        for regency in HisploraBaliGeoData.regencies {
            let centerPt = projection.project(regency.centerCoordinate)

            // Regency title in spaced serif typography
            let regencyText = Text(regency.name.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .serif))
                .tracking(1.5)
                .foregroundStyle(HisploraMapStyle.inkText.color.opacity(0.45))

            context.draw(context.resolve(regencyText), at: centerPt, anchor: .center)
        }
    }

    // MARK: - 10. Sacred Mountain Peaks with Vintage Hatch Shading

    private func drawMountainPeaks(context: GraphicsContext) {
        for peak in HisploraBaliGeoData.mountainPeaks {
            let pt = projection.project(peak.coordinate)
            let isAgung = peak.id == "gunung-agung"
            let peakSize: CGFloat = isAgung ? 22 : 16

            var mountainPath = Path()
            // Ridge Triangle
            let top = CGPoint(x: pt.x, y: pt.y - peakSize)
            let left = CGPoint(x: pt.x - peakSize * 0.9, y: pt.y + 2)
            let right = CGPoint(x: pt.x + peakSize * 0.9, y: pt.y + 2)

            mountainPath.move(to: top)
            mountainPath.addLine(to: left)
            mountainPath.addLine(to: right)
            mountainPath.closeSubpath()

            // Mountain fill
            context.fill(mountainPath, with: .color(HisploraMapStyle.parchmentGround.color))
            // Mountain outline
            context.stroke(mountainPath, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 1.2)

            // Eastern Slope Hatch Shading (Classic vintage cartography technique)
            var hatchPath = Path()
            for h in 1...4 {
                let fraction = CGFloat(h) / 5.0
                let startY = top.y + (right.y - top.y) * fraction
                let startX = top.x + (right.x - top.x) * fraction
                hatchPath.move(to: CGPoint(x: startX, y: startY))
                hatchPath.addLine(to: CGPoint(x: startX - 3.5, y: startY + 2.5))
            }
            context.stroke(hatchPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.6)), lineWidth: 0.8)

            // Central Peak Ridge line
            var spinePath = Path()
            spinePath.move(to: top)
            spinePath.addLine(to: CGPoint(x: pt.x, y: pt.y + 2))
            context.stroke(spinePath, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 0.9)

            // Mountain Peak Name & Elevation
            let peakLabel = Text("\(peak.name) (\(peak.elevationM)m)")
                .font(.system(size: isAgung ? 8.5 : 7.5, weight: isAgung ? .bold : .medium, design: .serif))
                .foregroundStyle(HisploraMapStyle.roadCasing.color)

            context.draw(context.resolve(peakLabel), at: CGPoint(x: pt.x, y: pt.y + 10), anchor: .top)
        }
    }

    // MARK: - 11. Balinese 8-Direction Compass Rose (Pengider Nawasanga)

    private func drawBalineseCompassRose(context: GraphicsContext, size: CGSize) {
        // Placed in Northwest Sea (Laut Bali / West)
        let compassCenter = CGPoint(x: 54, y: 78)
        let radius: CGFloat = 26

        var rosePath = Path()
        // Outer concentric ring
        rosePath.addEllipse(in: CGRect(x: compassCenter.x - radius, y: compassCenter.y - radius, width: radius * 2, height: radius * 2))
        rosePath.addEllipse(in: CGRect(x: compassCenter.x - radius * 0.75, y: compassCenter.y - radius * 0.75, width: radius * 1.5, height: radius * 1.5))
        context.stroke(rosePath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.6)), lineWidth: 0.9)

        // Cardinal star points (Kaja = North, Kelod = South, Kangin = East, Kauh = West)
        var starPath = Path()
        // North (Kaja) Point
        starPath.move(to: CGPoint(x: compassCenter.x, y: compassCenter.y - radius - 5))
        starPath.addLine(to: CGPoint(x: compassCenter.x + 3.5, y: compassCenter.y - 4))
        starPath.addLine(to: CGPoint(x: compassCenter.x, y: compassCenter.y))
        starPath.addLine(to: CGPoint(x: compassCenter.x - 3.5, y: compassCenter.y - 4))
        starPath.closeSubpath()
        context.fill(starPath, with: .color(HisploraMapStyle.markerActive.color))
        context.stroke(starPath, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 0.8)

        // South (Kelod) Point
        var southStar = Path()
        southStar.move(to: CGPoint(x: compassCenter.x, y: compassCenter.y + radius))
        southStar.addLine(to: CGPoint(x: compassCenter.x + 3, y: compassCenter.y + 4))
        southStar.addLine(to: CGPoint(x: compassCenter.x, y: compassCenter.y))
        southStar.addLine(to: CGPoint(x: compassCenter.x - 3, y: compassCenter.y + 4))
        southStar.closeSubpath()
        context.fill(southStar, with: .color(HisploraMapStyle.parchmentWarm.color))
        context.stroke(southStar, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 0.8)

        // East (Kangin) Point
        var eastStar = Path()
        eastStar.move(to: CGPoint(x: compassCenter.x + radius, y: compassCenter.y))
        eastStar.addLine(to: CGPoint(x: compassCenter.x + 4, y: compassCenter.y + 3))
        eastStar.addLine(to: CGPoint(x: compassCenter.x, y: compassCenter.y))
        eastStar.addLine(to: CGPoint(x: compassCenter.x + 4, y: compassCenter.y - 3))
        eastStar.closeSubpath()
        context.stroke(eastStar, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 0.8)

        // West (Kauh) Point
        var westStar = Path()
        westStar.move(to: CGPoint(x: compassCenter.x - radius, y: compassCenter.y))
        westStar.addLine(to: CGPoint(x: compassCenter.x - 4, y: compassCenter.y + 3))
        westStar.addLine(to: CGPoint(x: compassCenter.x, y: compassCenter.y))
        westStar.addLine(to: CGPoint(x: compassCenter.x - 4, y: compassCenter.y - 3))
        westStar.closeSubpath()
        context.stroke(westStar, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 0.8)

        // Balinese Cardinal Labels
        let kajaText = Text("KAJA")
            .font(.system(size: 6.5, weight: .black, design: .serif))
            .foregroundStyle(HisploraMapStyle.roadCasing.color)
        context.draw(context.resolve(kajaText), at: CGPoint(x: compassCenter.x, y: compassCenter.y - radius - 11), anchor: .center)

        let kelodText = Text("KELOD")
            .font(.system(size: 6.0, weight: .bold, design: .serif))
            .foregroundStyle(HisploraMapStyle.roadCasing.color.opacity(0.7))
        context.draw(context.resolve(kelodText), at: CGPoint(x: compassCenter.x, y: compassCenter.y + radius + 7), anchor: .center)
    }

    // MARK: - 12. Vintage Title Cartouche Banner & Scale Bar

    private func drawTitleBannerAndScale(context: GraphicsContext, size: CGSize) {
        // Distance Scale Bar in bottom left
        let scaleOrigin = CGPoint(x: 24, y: size.height - 40)
        let scale20kmPoints = projection.metersToPoints(20000) // 20 km in points

        var scalePath = Path()
        scalePath.move(to: scaleOrigin)
        scalePath.addLine(to: CGPoint(x: scaleOrigin.x + scale20kmPoints, y: scaleOrigin.y))
        // Ticks
        scalePath.move(to: CGPoint(x: scaleOrigin.x, y: scaleOrigin.y - 3))
        scalePath.addLine(to: CGPoint(x: scaleOrigin.x, y: scaleOrigin.y + 3))
        scalePath.move(to: CGPoint(x: scaleOrigin.x + scale20kmPoints / 2, y: scaleOrigin.y - 2))
        scalePath.addLine(to: CGPoint(x: scaleOrigin.x + scale20kmPoints / 2, y: scaleOrigin.y + 2))
        scalePath.move(to: CGPoint(x: scaleOrigin.x + scale20kmPoints, y: scaleOrigin.y - 3))
        scalePath.addLine(to: CGPoint(x: scaleOrigin.x + scale20kmPoints, y: scaleOrigin.y + 3))

        context.stroke(scalePath, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 1.2)

        let scaleText = Text("0          10          20 km")
            .font(.system(size: 7, weight: .bold, design: .serif))
            .foregroundStyle(HisploraMapStyle.roadCasing.color)
        context.draw(context.resolve(scaleText), at: CGPoint(x: scaleOrigin.x + scale20kmPoints / 2, y: scaleOrigin.y - 7), anchor: .center)
    }
}
