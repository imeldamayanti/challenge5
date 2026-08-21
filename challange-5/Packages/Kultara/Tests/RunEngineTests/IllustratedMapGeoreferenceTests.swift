import ContentKit
import Testing
@testable import RunEngine

/// The five Places `badung-empat-wajah` walks, as they are authored today: the real coordinate and
/// the `mapPoint` that was eyeballed onto the shipped chart. These are the anchors the discovery
/// map fits its overlay from, so this suite is what stands between an author nudging a pin and the
/// illustration silently sliding off Bali.
private let badungAnchors: [IllustratedMapGeoreference.Anchor] = [
    .init(point: MapPoint(x: 0.6050, y: 0.6313), coordinate: Coordinate(lat: -8.6595, lon: 115.2077)),
    .init(point: MapPoint(x: 0.6056, y: 0.6289), coordinate: Coordinate(lat: -8.6570, lon: 115.2085)),
    .init(point: MapPoint(x: 0.6078, y: 0.6260), coordinate: Coordinate(lat: -8.6540, lon: 115.2115)),
    .init(point: MapPoint(x: 0.6111, y: 0.6255), coordinate: Coordinate(lat: -8.6535, lon: 115.2160)),
    .init(point: MapPoint(x: 0.6120, y: 0.6279), coordinate: Coordinate(lat: -8.6560, lon: 115.2172)),
]

@Suite struct IllustratedMapGeoreferenceTests {

    @Test func theAuthoredPointsAgreeOnOneOriginToWithinTwentyMetres() {
        let fit = IllustratedMapGeoreference.fittedToBaliIllustration(anchors: badungAnchors)
        let georeference = try! #require(fit)

        for anchor in badungAnchors {
            let residual = georeference.residualMetres(for: anchor)
            #expect(residual < 20,
                    "anchor at \(anchor.point) is \(residual) m from where the fit puts it")
        }
    }

    /// The load-bearing consequence of the fit: the drawing, placed so its features land at their
    /// real coordinates, covers Bali. A fit that has slipped puts the island off the paper, and
    /// this is the assertion that notices before a user does.
    @Test func theFittedImageCoversTheIsland() {
        let georeference = try! #require(
            IllustratedMapGeoreference.fittedToBaliIllustration(anchors: badungAnchors))

        // Bali proper plus Nusa Penida. **Not** as far as Lombok: the chart is framed on Bali and
        // its east edge sits a little past Tanjung Bungsil (115.7133), where the older drawing ran
        // on to Lombok's coast. Widening this back would be asserting coverage the artwork does not
        // have.
        #expect(georeference.northWest.lon < 114.40)
        #expect(georeference.southEast.lon > 115.72)
        #expect(georeference.northWest.lat > -8.05)
        #expect(georeference.southEast.lat < -8.90)
    }

    /// 1536 ÷ 1126.82 and 1024 ÷ 983.33. The spans are what the overlay's rectangle is built from,
    /// so they are pinned rather than left to arithmetic nobody re-checks.
    @Test func theSpansComeFromTheMeasuredRates() {
        let georeference = try! #require(
            IllustratedMapGeoreference.fittedToBaliIllustration(anchors: badungAnchors))

        #expect(abs(georeference.lonSpanDegrees - 1.36311) < 0.0001)
        #expect(abs(georeference.latSpanDegrees - 1.04136) < 0.0001)
    }

    /// The drawing is compressed vertically against true scale, and this is the number that says by
    /// how much. Placed so geography is right, the picture is drawn about 1.15× taller than its own
    /// proportions — the deviation `docs/hisplora-tokens.md` records, asserted rather than trusted.
    ///
    /// It reversed when the chart was replaced. The older drawing ran 1.256 the other way, and the
    /// note that used to sit here said the art was squashed; this one is close enough to true scale
    /// that the remaining error is the Bukit's exaggerated length, absorbed at the south edge.
    @Test func theArtIsStretchedAboutOneAndAQuarterAgainstTrueScale() {
        let georeference = try! #require(
            IllustratedMapGeoreference.fittedToBaliIllustration(anchors: badungAnchors))

        let stretch = georeference.pixelsPerDegreeLat / georeference.pixelsPerDegreeLon
        #expect(abs(stretch - 0.87266) < 0.0001)
    }

    @Test func aPointAndACoordinateRoundTrip() {
        let georeference = try! #require(
            IllustratedMapGeoreference.fittedToBaliIllustration(anchors: badungAnchors))

        let point = MapPoint(x: 0.31, y: 0.62)
        let back = georeference.point(for: georeference.coordinate(at: point))

        #expect(abs(back.x - point.x) < 1e-9)
        #expect(abs(back.y - point.y) < 1e-9)
    }

    /// No anchors means no honest placement, and the caller draws no overlay at all. An
    /// illustration placed at an invented latitude is a map that lies.
    /// **Every authored `mapPoint` in the shipped bundle, against the drawing it is authored on.**
    ///
    /// This reads live content on purpose, and it is not the mistake CLAUDE.md warns about. That
    /// warning is about *requirement* guards — a rule about `FR-*` that reads the bundle changes
    /// meaning every time an author edits JSON. This is a *content* guard, the same family as
    /// `BundledContentRepositoryTests`, and reading the bundle is the only way it can do its job.
    ///
    /// It exists because five Places shipped with `mapPoint`s that were **34 to 40 km out** —
    /// placeholder values authored against the older portrait drawing. They were invisible for as
    /// long as they were: the region map draws one pin per quest start checkpoint, only one quest
    /// ships, and none of the five ever rendered. They stopped being invisible when
    /// `IllustratedMapGeoreference` started fitting the overlay's place in the world from authored
    /// points, and the fix for them was arithmetic. The fix for *the next one* is this.
    ///
    /// The tolerance is 1.5 km, which is about 15 pixels of longitude on a 1536-pixel drawing. A
    /// point is still authored, not derived — a pin may be nudged off the exact projection to clear
    /// a label or a coastline, and that headroom is what the tolerance is for. What it will not
    /// tolerate is a point that was never placed against this artwork at all: the five were out by
    /// more than twenty times this.
    @Test func everyAuthoredMapPointSitsWhereThePlaceIs() throws {
        let repository = try BundledContentRepository()
        let places = try repository.bundle().places
        let anchors = places.compactMap { place in
            place.mapPoint.map {
                IllustratedMapGeoreference.Anchor(point: $0, coordinate: place.coordinate)
            }
        }

        #expect(anchors.count >= 6, "The scan would be near-vacuous with fewer anchors than this.")

        let georeference = try #require(
            IllustratedMapGeoreference.fittedToBaliIllustration(anchors: badungAnchors))

        for place in places {
            guard let point = place.mapPoint else { continue }
            let residual = georeference.residualMetres(
                for: .init(point: point, coordinate: place.coordinate))
            #expect(residual < 1_500,
                    "\(place.id) is \(Int(residual)) m from where its mapPoint puts it")
        }
    }

    @Test func noAnchorsYieldsNoGeoreferenceRatherThanAGuess() {
        #expect(IllustratedMapGeoreference.fittedToBaliIllustration(anchors: []) == nil)
    }

    @Test func aDegenerateImageYieldsNoGeoreference() {
        #expect(IllustratedMapGeoreference.fitted(
            imageWidthPx: 0, imageHeightPx: 1024,
            pixelsPerDegreeLon: 1126.82, pixelsPerDegreeLat: 983.33,
            anchors: badungAnchors) == nil)
    }
}
