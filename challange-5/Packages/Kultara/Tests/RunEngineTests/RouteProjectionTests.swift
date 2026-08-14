import ContentKit
import Foundation
import Testing
@testable import RunEngine

/// `FR-MAP-02`. The map has to agree with the number printed beside it — a canvas that draws the
/// walker 200 m from a checkpoint while the status card says 40 m is worse than no canvas.
struct RouteProjectionTests {

    /// A short walk in Denpasar, which is where the sample content is.
    private let line = [
        Coordinate(lat: -8.6570, lon: 115.2085),
        Coordinate(lat: -8.6552, lon: 115.2101),
        Coordinate(lat: -8.6561, lon: 115.2138),
        Coordinate(lat: -8.6595, lon: 115.2129),
    ]

    private func projection(width: Double = 300, height: Double = 200, padding: Double = 20)
        -> RouteProjection {
        RouteProjection(coordinates: line, width: width, height: height, padding: padding)!
    }

    @Test func everyDrawnPointLandsInsideTheCanvas() {
        let p = projection()
        for coordinate in line {
            let point = p.project(coordinate)
            #expect(point.x >= 0 && point.x <= 300, "x \(point.x)")
            #expect(point.y >= 0 && point.y <= 200, "y \(point.y)")
        }
    }

    @Test func padddingIsHonouredOnEveryEdge() {
        let p = projection()
        let xs = line.map { p.project($0).x }
        let ys = line.map { p.project($0).y }
        #expect(xs.min()! >= 20 - 0.001)
        #expect(xs.max()! <= 280 + 0.001)
        #expect(ys.min()! >= 20 - 0.001)
        #expect(ys.max()! <= 180 + 0.001)
    }

    /// North is up. Drawn the other way the route is a mirror of the street the walker is standing
    /// in, which is worse than a schematic — it is a wrong instruction.
    @Test func northIsUp() {
        let p = projection()
        let north = p.project(Coordinate(lat: -8.6552, lon: 115.2110))
        let south = p.project(Coordinate(lat: -8.6595, lon: 115.2110))
        #expect(north.y < south.y)
    }

    @Test func eastIsRight() {
        let p = projection()
        let west = p.project(Coordinate(lat: -8.6570, lon: 115.2085))
        let east = p.project(Coordinate(lat: -8.6570, lon: 115.2138))
        #expect(east.x > west.x)
    }

    /// The load-bearing agreement: a length drawn on the canvas, converted back through
    /// `metresPerUnit`, is the same number `Geo.distanceM` gives for the same pair.
    @Test func drawnLengthConvertsBackToTheDistanceTheStatusCardPrints() {
        let p = projection()
        let a = line[0]
        let b = line[2]
        let pa = p.project(a)
        let pb = p.project(b)
        let drawn = (pa.x - pb.x) * (pa.x - pb.x) + (pa.y - pb.y) * (pa.y - pb.y)
        let drawnMetres = drawn.squareRoot() * p.metresPerUnit
        let real = Geo.distanceM(a, b)
        // Under 1 % over a few hundred metres: the equirectangular approximation's error at this
        // scale, not a fudge factor.
        #expect(abs(drawnMetres - real) / real < 0.01,
                "drew \(drawnMetres) m for a real \(real) m")
    }

    @Test func aRadiusInMetresConvertsToUnitsAndBack() {
        let p = projection()
        #expect(abs(p.metresPerUnit * p.units(forMetres: 75) - 75) < 0.0001)
    }

    /// A route that is a single point has no box to fit, and drawing it at an arbitrary zoom would
    /// state a scale nobody chose.
    @Test func aDegenerateRouteRefusesToProject() {
        let single = [Coordinate(lat: -8.65, lon: 115.21)]
        #expect(RouteProjection(coordinates: single, width: 300, height: 200) == nil)
        #expect(RouteProjection(coordinates: [], width: 300, height: 200) == nil)
        #expect(RouteProjection(coordinates: line, width: 0, height: 200) == nil)
    }

    /// A straight north–south route has no horizontal span; the fit must come from the other axis
    /// rather than dividing by zero.
    @Test func aStraightRouteStillFits() {
        let vertical = [
            Coordinate(lat: -8.6600, lon: 115.2100),
            Coordinate(lat: -8.6550, lon: 115.2100),
        ]
        let p = RouteProjection(coordinates: vertical, width: 300, height: 200, padding: 10)
        #expect(p != nil)
        let top = p!.project(vertical[1])
        let bottom = p!.project(vertical[0])
        #expect(top.y >= 10 - 0.001)
        #expect(bottom.y <= 190 + 0.001)
        // Centred horizontally, since there is no horizontal extent to spread.
        #expect(abs(top.x - 150) < 0.001)
    }
}
