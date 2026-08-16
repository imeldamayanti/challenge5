import ContentKit
import DesignSystem
import SwiftUI

/// Vector canvas renderer that renders any standard `OpenMapTilesMapDocument`
/// using Hisplora's hand-drawn vintage Balinese parchment design system.
struct OpenMapTilesCanvasRenderer: View {

    let document: OpenMapTilesMapDocument
    let projection: HisploraBaliMapProjection

    var body: some View {
        Canvas { context, size in
            // 1. Base aged parchment ocean ground
            drawOceanParchment(context: context, size: size)

            // 2. OpenMapTiles `water_name` layer
            drawWaterNames(context: context)

            // 3. OpenMapTiles `landcover` layer (forests, green washes)
            drawLandcover(context: context)

            // 4. OpenMapTiles `park` layer (national parks, nature reserves, public squares)
            drawParks(context: context)

            // 5. OpenMapTiles `water` layer (ocean coastlines, lakes, reservoirs)
            drawWaterBodies(context: context)

            // 6. OpenMapTiles `building` layer (compounds, palaces, cadastral parcel sketches)
            drawBuildingsAndParcels(context: context)

            // 7. OpenMapTiles `waterway` layer (rivers, streams, canals)
            drawWaterways(context: context)

            // 8. OpenMapTiles `boundary` layer (regency & administrative borders)
            drawBoundaries(context: context)

            // 9. OpenMapTiles `transportation` layer (highways, roads, alleys, walking paths)
            drawTransportation(context: context)

            // 10. OpenMapTiles `mountain_peak` layer (peaks, elevations, hatch shading)
            drawMountainPeaks(context: context)

            // 11. OpenMapTiles `place` layer (cities, towns, villages)
            drawPlaces(context: context)
        }
    }

    // MARK: - 1. Ocean Parchment

    private func drawOceanParchment(context: GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(HisploraMapStyle.parchmentGround.color))
        let seaTint = Color(red: 0.89, green: 0.85, blue: 0.77).opacity(0.4)
        context.fill(Path(rect), with: .color(seaTint))
    }

    // MARK: - 2. Water Names

    private func drawWaterNames(context: GraphicsContext) {
        for wn in document.waterNameFeatures {
            let pt = projection.project(wn.coordinate)
            let text = Text(wn.name)
                .font(.system(size: 8.5, weight: .bold, design: .serif))
                .foregroundStyle(HisploraMapStyle.riverCasing.color.opacity(0.75))

            var textCtx = context
            textCtx.translateBy(x: pt.x, y: pt.y)
            textCtx.rotate(by: .degrees(wn.angleDegrees))
            textCtx.draw(textCtx.resolve(text), at: .zero, anchor: .center)
        }
    }

    // MARK: - 3. Landcover

    private func drawLandcover(context: GraphicsContext) {
        for lc in document.landcoverFeatures {
            let style = OpenMapTilesStyleEngine.style(for: lc.class)
            let pts = lc.coordinates.map { projection.project($0) }
            guard pts.count > 2 else { continue }

            var path = Path()
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i - 1])
            }
            path.closeSubpath()

            context.fill(path, with: .color(style.fillColor))
        }
    }

    // MARK: - 4. Parks

    private func drawParks(context: GraphicsContext) {
        for park in document.parkFeatures {
            let style = OpenMapTilesStyleEngine.style(for: park.class)
            let pts = park.coordinates.map { projection.project($0) }
            guard pts.count > 2 else { continue }

            var path = Path()
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i - 1])
            }
            path.closeSubpath()

            context.fill(path, with: .color(style.fillColor))
            if style.strokeWidth > 0 {
                context.stroke(path, with: .color(style.strokeColor), lineWidth: style.strokeWidth)
            }
        }
    }

    // MARK: - 5. Water Bodies (Ocean Landmasses & Lakes)

    private func drawWaterBodies(context: GraphicsContext) {
        for water in document.waterFeatures {
            let style = OpenMapTilesStyleEngine.style(for: water.class)

            switch water.geometry {
            case .polygon(let coords):
                guard coords.count > 2 else { continue }
                let pts = coords.map { projection.project($0) }

                var path = Path()
                path.move(to: pts[0])
                for i in 1..<pts.count {
                    let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                    path.addQuadCurve(to: mid, control: pts[i - 1])
                }
                path.closeSubpath()

                if water.class == .ocean || water.class == .sea {
                    // For ocean polygon, it represents the landmass contour on the parchment sea
                    context.fill(path, with: .color(HisploraMapStyle.parchmentWarm.color))
                    context.stroke(path, with: .color(style.strokeColor), lineWidth: style.strokeWidth)
                } else {
                    // For lakes and reservoirs
                    context.fill(path, with: .color(style.fillColor))
                    context.stroke(path, with: .color(style.strokeColor), lineWidth: style.strokeWidth)

                    if let name = water.name {
                        let label = Text(name)
                            .font(.system(size: 7.5, weight: .semibold, design: .serif))
                            .italic()
                            .foregroundStyle(HisploraMapStyle.riverCasing.color)
                        if let first = pts.first {
                            context.draw(context.resolve(label), at: CGPoint(x: first.x, y: first.y - 8), anchor: .center)
                        }
                    }
                }

            default:
                break
            }
        }
    }

    // MARK: - 6. Buildings & Compounds

    private func drawBuildingsAndParcels(context: GraphicsContext) {
        for bldg in document.buildingFeatures {
            let style = OpenMapTilesStyleEngine.style(for: bldg.class)
            let pts = bldg.coordinates.map { projection.project($0) }
            guard pts.count > 1 else { continue }

            var path = Path()
            path.move(to: pts[0])
            for i in 1..<pts.count {
                path.addLine(to: pts[i])
            }
            if pts.count > 2 && bldg.class != .parcel {
                path.closeSubpath()
            }

            if style.fillColor != .clear {
                context.fill(path, with: .color(style.fillColor))
            }

            if let strokeStyle = style.strokeStyle {
                context.stroke(path, with: .color(style.strokeColor), style: strokeStyle)
            } else {
                context.stroke(path, with: .color(style.strokeColor), lineWidth: style.strokeWidth)
            }
        }
    }

    // MARK: - 7. Waterways

    private func drawWaterways(context: GraphicsContext) {
        for ww in document.waterwayFeatures {
            let pts = ww.coordinates.map { projection.project($0) }
            guard pts.count > 1 else { continue }

            var path = Path()
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i - 1])
            }

            context.stroke(path, with: .color(HisploraMapStyle.riverFill.color), lineWidth: 4.5)
            context.stroke(path, with: .color(HisploraMapStyle.riverCasing.color), lineWidth: 1.0)
        }
    }

    // MARK: - 8. Boundaries

    private func drawBoundaries(context: GraphicsContext) {
        for b in document.boundaryFeatures {
            let centerPt = projection.project(b.centerCoordinate)

            let text = Text(b.name.uppercased())
                .font(.system(size: 7.5, weight: .bold, design: .serif))
                .tracking(1.5)
                .foregroundStyle(HisploraMapStyle.inkText.color.opacity(0.45))

            context.draw(context.resolve(text), at: centerPt, anchor: .center)
        }
    }

    // MARK: - 9. Transportation

    private func drawTransportation(context: GraphicsContext) {
        for tr in document.transportationFeatures {
            let style = OpenMapTilesStyleEngine.style(for: tr.class)
            let pts = tr.coordinates.map { projection.project($0) }
            guard pts.count > 1 else { continue }

            var path = Path()
            path.move(to: pts[0])
            for i in 1..<pts.count {
                let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                path.addQuadCurve(to: mid, control: pts[i - 1])
            }

            if let strokeStyle = style.strokeStyle {
                context.stroke(path, with: .color(style.casingColor), style: strokeStyle)
            } else {
                // Casing
                context.stroke(path, with: .color(style.casingColor), lineWidth: style.casingWidth)
                // Fill
                if style.fillWidth > 0 {
                    context.stroke(path, with: .color(style.fillColor), lineWidth: style.fillWidth)
                }
            }
        }
    }

    // MARK: - 10. Mountain Peaks

    private func drawMountainPeaks(context: GraphicsContext) {
        for peak in document.mountainPeakFeatures {
            let pt = projection.project(peak.coordinate)
            let isPrimary = peak.rank == 1
            let peakSize: CGFloat = isPrimary ? 22 : 16

            var mountainPath = Path()
            let top = CGPoint(x: pt.x, y: pt.y - peakSize)
            let left = CGPoint(x: pt.x - peakSize * 0.9, y: pt.y + 2)
            let right = CGPoint(x: pt.x + peakSize * 0.9, y: pt.y + 2)

            mountainPath.move(to: top)
            mountainPath.addLine(to: left)
            mountainPath.addLine(to: right)
            mountainPath.closeSubpath()

            context.fill(mountainPath, with: .color(HisploraMapStyle.parchmentGround.color))
            context.stroke(mountainPath, with: .color(HisploraMapStyle.roadCasing.color), lineWidth: 1.2)

            // Eastern Slope Hatch Shading
            var hatchPath = Path()
            for h in 1...4 {
                let fraction = CGFloat(h) / 5.0
                let startY = top.y + (right.y - top.y) * fraction
                let startX = top.x + (right.x - top.x) * fraction
                hatchPath.move(to: CGPoint(x: startX, y: startY))
                hatchPath.addLine(to: CGPoint(x: startX - 3.5, y: startY + 2.5))
            }
            context.stroke(hatchPath, with: .color(HisploraMapStyle.roadCasing.color.opacity(0.6)), lineWidth: 0.8)

            let peakLabel = Text("\(peak.name) (\(peak.elevationM)m)")
                .font(.system(size: isPrimary ? 8.5 : 7.5, weight: isPrimary ? .bold : .medium, design: .serif))
                .foregroundStyle(HisploraMapStyle.roadCasing.color)

            context.draw(context.resolve(peakLabel), at: CGPoint(x: pt.x, y: pt.y + 10), anchor: .top)
        }
    }

    // MARK: - 11. Places

    private func drawPlaces(context: GraphicsContext) {
        for place in document.placeFeatures {
            let pt = projection.project(place.coordinate)
            let text = Text(place.name.uppercased())
                .font(.system(size: 8, weight: .black, design: .serif))
                .tracking(1.0)
                .foregroundStyle(HisploraMapStyle.inkText.color)

            context.draw(context.resolve(text), at: pt, anchor: .center)
        }
    }
}
