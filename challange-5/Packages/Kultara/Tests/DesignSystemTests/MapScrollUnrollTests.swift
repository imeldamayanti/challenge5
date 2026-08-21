import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import DesignSystem

/// The Location Verified scroll opens itself, and the opening is a three-slice of `map-scroll.png`:
/// left rod, paper, right rod, with only the middle one stretching. That works exactly as long as
/// `HisploraMapScrollMetrics`'s two rod fractions still describe where the rods are in the shipped
/// file — and `HisploraScrollArt.mapScroll` says out loud that the file wants replacing with a 4×
/// export. A replacement cropped even slightly differently would put the slice through a rod and
/// stretch half of it, which on screen is a rod that fattens as the scroll opens.
///
/// So the fractions are measured against the file here rather than trusted.
@Suite struct MapScrollUnrollTests {

    private var scroll: CGImage? {
        guard let url = HisploraScrollArt.mapScroll.url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// How much of a column is opaque, 0…1. A rod runs the picture's full drawn height; the paper
    /// bows in from both edges, so its columns cover visibly less.
    private func coverage(ofColumn x: Int, in image: CGImage) -> Double {
        let width = image.width, height = image.height
        guard x >= 0, x < width,
              let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else { return 0 }
        let rowBytes = image.bytesPerRow
        let pixelBytes = image.bitsPerPixel / 8
        var first = -1, last = -1
        for y in 0..<height {
            let alpha = bytes[y * rowBytes + x * pixelBytes + (pixelBytes - 1)]
            if alpha > 127 {
                if first < 0 { first = y }
                last = y
            }
        }
        guard first >= 0 else { return 0 }
        return Double(last - first) / Double(height)
    }

    @Test func theScrollShipsWithThePackage() {
        #expect(HisploraScrollArt.mapScroll.isAvailable,
                "map-scroll.png is the Location Verified scroll; without it the screen falls back to a plain cream panel")
    }

    /// Inside each rod fraction the column is the rod's full height; just outside it the paper's bow
    /// has already started eating into it. That pair is what makes the fractions a measurement of
    /// this file rather than two numbers somebody typed.
    @Test func theRodFractionsFallOnTheRodsOfTheShippedFile() throws {
        let image = try #require(scroll)
        let width = image.width
        // The rod's own columns cover about 0.80 of the height and the paper's first columns about
        // 0.73, so anything between the two separates them.
        let rodCoverage = 0.75

        let leftEdge = Int(HisploraMapScrollMetrics.leftRodWidth * CGFloat(width))
        #expect(coverage(ofColumn: leftEdge - 4, in: image) > rodCoverage,
                "the left slice should end on the rod, not before it")
        #expect(coverage(ofColumn: leftEdge + 4, in: image) < rodCoverage,
                "the left slice should end at the rod, not past it into the paper")

        let rightEdge = width - Int(HisploraMapScrollMetrics.rightRodWidth * CGFloat(width))
        #expect(coverage(ofColumn: rightEdge + 4, in: image) > rodCoverage,
                "the right slice should start on the rod, not after it")
        #expect(coverage(ofColumn: rightEdge - 4, in: image) < rodCoverage,
                "the right slice should start at the rod, not before it inside the paper")
    }

    /// The three slices are the whole picture. A gap would show the ground through the scroll; an
    /// overlap would draw a band of paper twice and shorten the rest.
    @Test func theThreeSlicesAccountForTheWholePicture() {
        let total = HisploraMapScrollMetrics.leftRodWidth
            + HisploraMapScrollMetrics.paperWidth
            + HisploraMapScrollMetrics.rightRodWidth
        #expect(abs(total - 1) < 0.0001)
    }

    /// Shut, the scroll is exactly its two rods — the state the reference render opens from.
    @Test func theClosedScrollIsTheTwoRodsAndNothingElse() {
        #expect(HisploraMapScrollMetrics.closedWidth
            == HisploraMapScrollMetrics.leftRodWidth + HisploraMapScrollMetrics.rightRodWidth)
        #expect(HisploraMapScrollMetrics.closedWidth < 0.3,
                "a closed scroll that is a third of the open one is not closed")
    }

    /// The drawing arrives during the movement: nothing while the scroll is barely open, whole
    /// before the rods stop.
    @Test func theDrawingFadesInWhileTheScrollIsStillOpening() {
        #expect(HisploraMapScrollMetrics.interiorOpacity(atOpenFraction: 0) == 0)
        #expect(HisploraMapScrollMetrics.interiorOpacity(atOpenFraction: 0.3) == 0)
        #expect(HisploraMapScrollMetrics.interiorOpacity(atOpenFraction: 0.55) > 0)
        #expect(HisploraMapScrollMetrics.interiorOpacity(atOpenFraction: 0.55) < 1)
        #expect(HisploraMapScrollMetrics.interiorOpacity(atOpenFraction: 0.8) == 1)
        #expect(HisploraMapScrollMetrics.interiorOpacity(atOpenFraction: 1) == 1)
    }

    /// A walker standing at a gate is waiting on this. The reference render is a shade over four
    /// seconds; the screen is not.
    @Test func theOpeningIsShorterThanTheReferenceRender() {
        #expect(HisploraMapScrollMetrics.openDuration > 0.8)
        #expect(HisploraMapScrollMetrics.openDuration <= 2.5)
    }
}
