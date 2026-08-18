import CoreGraphics
import Foundation
import Testing
@testable import DesignSystem

/// The stamp's perforated border (`452:3142`) is drawn from measurements rather than shipped as a
/// raster, so the measurements are what a test can hold — the same argument `PlaqueGeometryTests`
/// makes about the plate.
///
/// The numbers come from the exported vector's own path: notch centres at x = 4.6037, 11.4509,
/// 18.2980, 25.1452 on a 64 × 60.9099 box, each arc radius 2.2384.
@Suite("Quest stamp geometry")
struct QuestStampTests {

    @Test func theMetricsAreTheExportedVectorsOwn() {
        #expect(HisploraStampMetrics.designSize.width == 64)
        #expect(abs(HisploraStampMetrics.designSize.height - 60.9099) < 0.0001)
        #expect(abs(HisploraStampMetrics.notchRadius - 2.2384) < 0.0001)
        // The pitch is the difference between two consecutive drawn centres, to four places.
        #expect(abs(HisploraStampMetrics.notchPitch - (11.4509 - 4.6037)) < 0.0005)
        #expect(abs(HisploraStampMetrics.notchLeadIn - 4.6037) < 0.0001)
    }

    /// At the design's own size the first four notch centres land on the exported path's own x
    /// values. Getting the lead-in and the pitch confused puts the pattern half a notch off, which
    /// looks deliberate and is not.
    @Test func theTopEdgesNotchesLandWhereTheVectorDrawsThem() {
        let rect = CGRect(origin: .zero, size: HisploraStampMetrics.designSize)
        let centres = HisploraStampMetrics.notchCentres(
            in: rect, pitch: HisploraStampMetrics.notchPitch)
        let topXs = centres.filter { $0.y == rect.minY }.map(\.x).sorted()

        for (index, drawn) in [4.6037, 11.4509, 18.2980, 25.1452].enumerated() {
            #expect(abs(topXs[index] - drawn) < 0.002,
                    "notch \(index) at \(topXs[index]), drawn at \(drawn)")
        }
    }

    /// All four edges are perforated, and each edge's notches are mirrored on the opposite one — a
    /// stamp perforated on three sides reads as a torn coupon.
    @Test func everyEdgeIsPerforatedAndOppositeEdgesAgree() {
        let rect = CGRect(origin: .zero, size: HisploraStampMetrics.designSize)
        let centres = HisploraStampMetrics.notchCentres(
            in: rect, pitch: HisploraStampMetrics.notchPitch)

        let top = centres.filter { $0.y == rect.minY }.map(\.x).sorted()
        let bottom = centres.filter { $0.y == rect.maxY }.map(\.x).sorted()
        let left = centres.filter { $0.x == rect.minX }.map(\.y).sorted()
        let right = centres.filter { $0.x == rect.maxX }.map(\.y).sorted()

        #expect(!top.isEmpty)
        #expect(top == bottom)
        #expect(!left.isEmpty)
        #expect(left == right)
        // The box is wider than it is tall, so it takes more bites along the top than up the side.
        #expect(top.count > left.count)
    }

    /// The lead-in scales with the pitch. It is the bug a fixed lead-in would have: at half size the
    /// notches would still start 4.6 points in while sitting 3.4 apart, so the pattern walks off the
    /// corner and the far edge ends mid-bite.
    @Test func aHalfSizeStampKeepsThePatternSymmetricAboutItsCentre() {
        let half = CGRect(x: 0, y: 0,
                          width: HisploraStampMetrics.designSize.width / 2,
                          height: HisploraStampMetrics.designSize.height / 2)
        let centres = HisploraStampMetrics.notchCentres(
            in: half, pitch: HisploraStampMetrics.notchPitch / 2)
        let top = centres.filter { $0.y == half.minY }.map(\.x).sorted()

        let firstInset = top.first! - half.minX
        let lastInset = half.maxX - top.last!
        #expect(abs(firstInset - lastInset) < HisploraStampMetrics.notchPitch / 2,
                "pattern is \(firstInset) in on one side and \(lastInset) on the other")
    }

    @Test func aDegenerateRectangleProducesNoNotchesRatherThanLooping() {
        // A zero-width stamp is a layout accident, and a `while` loop over a zero pitch is a hang.
        let empty = HisploraStampMetrics.notchCentres(in: .zero, pitch: 0)
        #expect(empty.isEmpty)
    }

    /// Even-odd fill is not a style choice: with the default non-zero winding the added circles fill
    /// solid and the perforations vanish, which is a stamp that looks like a plain cream rectangle.
    @Test func theShapeIsFilledEvenOdd() {
        #expect(HisploraStampShape.fillStyle.isEOFilled)
    }

    @Test func theStampKeepsTheProportionsItIsDrawnAt() {
        #expect(abs(HisploraStampMetrics.aspectRatio - 64.0 / 60.9099) < 0.0001)
        // The tilt is the frame's, not a rounded 8°.
        #expect(HisploraStampMetrics.tiltDegrees == 7.88)
    }

    /// The picture's margin under it is deeper than the one over it, as `I452:3142;7:28` insets it.
    /// Symmetrical looks tidier and is a different object.
    @Test func thePicturesInsetIsTheFramesOwn() {
        let size = HisploraStampMetrics.designSize
        let inset = HisploraStampMetrics.pictureInset(in: size)
        #expect(abs(inset.horizontal - size.width * 0.0637) < 0.001)
        #expect(abs(inset.vertical - size.height * 0.0745) < 0.001)
    }
}

/// The segmented task bar (`452:3138`–`3141`).
@Suite("Segmented task progress")
struct SegmentedProgressTests {

    @Test func theWellAndItsSegmentsAreTheFramesOwnMeasurements() {
        #expect(HisploraSegmentedProgressMetrics.wellHeight == 40)
        #expect(HisploraSegmentedProgressMetrics.wellRadius == 12)
        #expect(HisploraSegmentedProgressMetrics.segmentRadius == 10)
        #expect(HisploraSegmentedProgressMetrics.wellBorder == 2)
        #expect(HisploraSegmentedProgressMetrics.segmentBorder == 2)
        // 22 in on a well starting at 20 — the segment strip is inset 2, which is the border width.
        #expect(HisploraSegmentedProgressMetrics.wellPadding == 2)
    }

    /// The frame's three segments abut: 22…133, 133…244, 244…355. A gap would make each segment
    /// narrower than 111 and the strip stop filling the well.
    @Test func theSegmentsAbutSoTheirOwnBordersDivideThem() {
        #expect(HisploraSegmentedProgressMetrics.segmentGap == 0)
    }

    /// The well's interior has to fit inside the well: padding on both sides plus a 36-point segment
    /// is the drawn 40.
    @Test func aSegmentFillsTheWellsHeightExactly() {
        let interior = HisploraSegmentedProgressMetrics.wellHeight
            - HisploraSegmentedProgressMetrics.wellPadding * 2
        #expect(interior == 36)
    }
}

/// The three images `452:3132` and `447:1880` are built from have to actually ship. `Image(_:bundle:)`
/// resolves lazily and draws nothing when a resource is dropped from `Package.swift`, so this is the
/// difference between a missing file failing here and a blank sheet reaching a walker.
@Suite("Quest scroll art")
struct QuestScrollArtTests {

    @Test func everyPackagedImageResolves() {
        for art in [HisploraScrollArt.sheet,
                    HisploraScrollArt.divider,
                    HisploraScrollArt.rolledScroll] {
            #expect(art.isAvailable, "\(art.name).png is not in the bundle")
            #expect(art.aspectRatio > 0)
        }
    }

    /// The parchment's interior margins have to leave the rolled bars alone: printing into them puts
    /// the first line across a curl.
    @Test func theSheetsInteriorClearsBothRolls() {
        // The head roll runs to y ≈ 78 of the drawn 478 and the foot roll starts at y ≈ 404.
        #expect(HisploraParchmentMetrics.interiorTop > 78)
        #expect(HisploraParchmentMetrics.interiorBottom > 478 - 404)
        // And the side margins are inside the sheet's own 368 width.
        #expect(HisploraParchmentMetrics.interiorSide * 2 < 368)
    }

    @Test func theMapHintKeepsTheFramesTilt() {
        #expect(HisploraScrollArt.mapHintTiltDegrees == 41.6)
    }
}
