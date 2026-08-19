import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import DesignSystem

/// `plaque-plate.png` is the place notice's whole background, and every number in
/// `HisploraPlateArtMetrics` was measured off its pixels. Two things can go wrong quietly: the file
/// can be dropped (and the screen falls back to the drawn plate with nothing saying so), or it can
/// be replaced by a differently-cropped export (and the measured sheet, the caps and the print
/// area's cream all describe a picture that is no longer there). Both fail here.
@Suite struct PlateArtTests {

    /// The shipped file, read through the package bundle the same way the panel reads it. Nil on a
    /// platform without ImageIO, which is not one this suite runs on.
    private var plate: CGImage? {
        guard let url = HisploraPlaqueArtwork.plateURL,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    @Test func thePlateShipsWithThePackage() {
        #expect(HisploraPlaqueArtwork.plateIsAvailable,
                "plaque-plate.png is the place notice's background; without it the screen falls back to the drawn plate with nothing saying so")
    }

    /// The measurements are only true of a 395 × 631 file. A re-export at another size is the
    /// realistic way they go stale, and it would move the sheet under every column on the screen.
    @Test func theShippedFileIsTheOneTheMetricsWereMeasuredFrom() throws {
        let image = try #require(plate, "plaque-plate.png did not decode")
        #expect(CGFloat(image.width) == HisploraPlateArtMetrics.pixelSize.width)
        #expect(CGFloat(image.height) == HisploraPlateArtMetrics.pixelSize.height)
    }

    /// The sheet is a box inside the picture, not the picture — the artwork carries transparent
    /// margin on all four sides and is not centred in its own canvas.
    @Test func theSheetSitsInsideTheArtworkWithMarginOnEverySide() {
        let m = HisploraPlateArtMetrics.self
        #expect(m.sheet.minX > 0)
        #expect(m.sheet.minY > 0)
        #expect(m.sheet.maxX < m.pixelSize.width)
        #expect(m.sheet.maxY < m.pixelSize.height)
        // Not centred: the right margin is the wider one, which is why the picture is placed by its
        // sheet rather than by centring it on the panel.
        #expect(m.trailingOverhang > m.leadingOverhang)
    }

    /// The three-slice's whole point. Caps that met would leave no stretchy band and the plate could
    /// not grow with Dynamic Type; caps that overlapped would tear it.
    @Test func theCapsLeaveAStretchableBandBetweenThem() {
        let m = HisploraPlateArtMetrics.self
        #expect(m.capTop + m.capBottom < m.pixelSize.height)
        #expect(m.pixelSize.height - m.capTop - m.capBottom >= 40,
                "the flat band at y 430…490 is the only part of this artwork that may be stretched")
        // The band has to be *below* the sheet's top edge and above its bottom one, or the stretch
        // would fall on a lobe rather than on the sheet.
        #expect(m.capTop > m.sheet.minY)
        #expect(m.pixelSize.height - m.capBottom < m.sheet.maxY)
    }

    /// The band the caps leave carries no ornament — measured, not asserted from the frame. Anything
    /// drawn there smears down the page as the plate grows.
    @Test func theStretchedBandIsBlankInTheShippedFile() throws {
        let image = try #require(plate)
        let pixels = try #require(readPixels(image))
        let m = HisploraPlateArtMetrics.self
        let cream = m.printAreaCream

        for y in Int(m.capTop)..<Int(m.pixelSize.height - m.capBottom) {
            for x in 0..<image.width {
                let sample = pixels[y * image.width + x]
                guard sample.alpha > 0.9 else { continue }
                // The two edge rules are the exception and they are allowed: they run vertically
                // through this band, so replicating its rows extends them rather than smearing them.
                guard x > 40, x < 343 else { continue }
                let delta = max(abs(sample.color.red - cream.red),
                                max(abs(sample.color.green - cream.green),
                                    abs(sample.color.blue - cream.blue)))
                #expect(delta < 0.06,
                        "ornament at (\(x), \(y)) falls inside the stretched band")
            }
        }
    }

    /// The picture's sheet has to land exactly where the drawn plate's sheet would have, because the
    /// place notice's columns and indents are all measured against that box. This is the assertion
    /// the layout arithmetic was pulled out of the view for.
    @Test func thePictureIsPlacedSoItsSheetLandsOnTheDrawnPlatesSheet() {
        let panel = CGRect(x: 0, y: 0, width: 358, height: 700)
        let expected = HisploraPlaqueShape.body(in: panel)
        let box = HisploraPlateArtMetrics.frame(forPanel: panel)
        let m = HisploraPlateArtMetrics.self
        let scale = box.width / m.pixelSize.width

        let sheetX = box.minX + m.sheet.minX * scale
        let sheetWidth = m.sheet.width * scale
        #expect(abs(sheetX - expected.minX) < 0.5)
        #expect(abs(sheetWidth - expected.width) < 0.5)
        // Vertically the caps draw at their own size, so the sheet's edges are the overhangs away
        // from the picture's, unscaled.
        #expect(abs((box.minY + m.topOverhang) - expected.minY) < 0.5)
        #expect(abs((box.maxY - m.bottomOverhang) - expected.maxY) < 0.5)
    }

    /// A picture behind text is exactly what the contrast suite cannot see — `KultaraPaperTexture`
    /// says so about the museum direction's grain, and it is truer here, where the ground *is* the
    /// picture. So the darkest pixel anywhere text can land is measured against `inkBody` directly.
    @Test func bodyTextClearsAAOverTheDarkestPixelItCanBePrintedOn() {
        let ink = HisploraPalette.standard.inkBody
        let ratio = contrastRatio(ink, HisploraPlateArtMetrics.printAreaDarkestCream)
        #expect(ratio >= ContrastRequirement.bodyText.minimumRatio,
                "inkBody measures \(ratio):1 on the plate's darkest print-area pixel")
    }

    /// And the plate's own cream is close enough to `paperCream` that every ratio `HisploraThemeTests`
    /// measures still describes what is on screen. A picture in a different colour would invalidate
    /// the suite without failing it.
    @Test func thePlatesCreamIsTheTokenTheSuiteMeasuresAgainst() {
        let token = HisploraPalette.standard.paperCream
        let plate = HisploraPlateArtMetrics.printAreaCream
        #expect(abs(token.relativeLuminance - plate.relativeLuminance) < 0.02,
                "the shipped plate's cream (\(plate.hex)) has drifted from paperCream (\(token.hex))")
    }

    private struct Sample {
        let color: SRGBColor
        let alpha: Double
    }

    /// Straight RGBA, top row first — the same orientation the metrics were measured in.
    private func readPixels(_ image: CGImage) -> [Sample]? {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return stride(from: 0, to: bytes.count, by: 4).map { i in
            let alpha = Double(bytes[i + 3]) / 255
            guard alpha > 0 else { return Sample(color: SRGBColor(hex: "#FFFFFF"), alpha: 0) }
            // Premultiplied: undo it, or every faint pixel reads darker than it is.
            return Sample(
                color: SRGBColor(red: Double(bytes[i]) / 255 / alpha,
                                 green: Double(bytes[i + 1]) / 255 / alpha,
                                 blue: Double(bytes[i + 2]) / 255 / alpha),
                alpha: alpha)
        }
    }
}
