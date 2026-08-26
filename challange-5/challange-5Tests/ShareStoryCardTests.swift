// `FR-DONE-06`. The share-story card (`921:2654`, `921:2960`) and the variant picker's list.
//
// These run against `ImageRenderer`, which is why they need `@MainActor` and a simulator
// destination — the same terms `ShareCardTests.theCardRendersToPNGBytes` already accepts for the
// recap artwork. What they pin down is not the design (the frames are the design) but the three
// things a silent failure would hide: that a render really happens at story width, that the
// walker's photograph actually lands inside the perforated die, and that the die's empty state is
// the dark pane rather than a blank.
import ContentKit
import DesignSystem
import SwiftUI
import Testing
import UIKit
@testable import challange_5

@MainActor
struct ShareStoryCardTests {

    private static let journallessInput = ShareStoryCard.Input(
        regionTitle: "Badung",
        journalText: nil,
        placesCount: 5,
        durationMinutes: 47,
        stamp: nil,
        postmarkArtworkName: HisploraTripArtwork.emblem,
        language: .en,
        ground: .brown)

    /// The picker builds both variants from one input by swapping the ground; this pins that the
    /// swap carries every snapshot field across (`AD-4`, `FR-RUN-06`) — a future edit that drops
    /// one of them makes two cards disagree about the same walk.
    @Test func derivingTheOtherGroundKeepsEverySnapshotField() {
        let input = ShareStoryCard.Input(
            regionTitle: "Badung", journalText: "Teks jurnal", placesCount: 5,
            durationMinutes: 47,
            stamp: .init(placeName: "Puri Agung Pemecutan", region: "Badung", artworkName: nil),
            postmarkArtworkName: HisploraTripArtwork.emblem,
            language: .id, ground: .brown)
        let photograph = Self.solidColor(UIColor.red)
        let derived = input.withGround(.photo(photograph))

        #expect(derived.regionTitle == input.regionTitle)
        #expect(derived.journalText == input.journalText)
        #expect(derived.placesCount == input.placesCount)
        #expect(derived.durationMinutes == input.durationMinutes)
        #expect(derived.stamp == input.stamp)
        #expect(derived.language == .id)
        guard case .photo(let carried) = derived.ground else {
            #expect(Bool(false), "the ground was not swapped")
            return
        }
        #expect(carried === photograph)
    }

    /// The output is an Instagram-story image: ~1080 px wide off a 246-point canvas at the pinned
    /// scale. A wrong scale would ship a blurry or enormous card and nothing else would notice.
    @Test func theBrownCardRendersNonNilAtStoryWidth() throws {
        let image = try #require(ShareStoryCard(input: Self.journallessInput).render())
        let width = try #require(image.cgImage?.width)
        #expect(abs(width - 1080) <= 2)
    }

    /// The photograph variant renders end to end from a stand-in picture, and the picture itself
    /// shows up in the perforated die — sampled at the die's centre, where the rotation leaves it.
    @Test func thePhotoCardRendersAndCarriesThePhotographInTheDie() throws {
        let red = Self.solidColor(UIColor.red)
        let input = ShareStoryCard.Input(
            regionTitle: "Badung", journalText: "Hari ini", placesCount: 3, durationMinutes: 30,
            stamp: nil, postmarkArtworkName: HisploraTripArtwork.emblem,
            language: .en, ground: .photo(red))
        let image = try #require(ShareStoryCard(input: input).render())
        let sample = try #require(Self.pixel(
            atCanvasPoint: CGPoint(x: 123, y: 249), in: image))
        #expect(abs(Int(sample.red) - 255) < 16)
        #expect(sample.green < 32 && sample.blue < 32)
    }

    /// No photograph anywhere in the walk: the brown card still renders, and the die prints its
    /// documented dark pane (`#221D1D`) instead of a gap — the honest-empty rule, asserted as
    /// colour rather than taken on trust.
    @Test func aWalkWithNoPhotographRendersTheDarkPane() throws {
        let image = try #require(ShareStoryCard(input: Self.journallessInput).render())
        let sample = try #require(Self.pixel(
            atCanvasPoint: CGPoint(x: 123, y: 249), in: image))
        #expect(abs(Int(sample.red) - 0x22) < 14)
        #expect(abs(Int(sample.green) - 0x1D) < 14)
        #expect(abs(Int(sample.blue) - 0x1D) < 14)
    }

    /// **The die is a stamp, which means paper between the picture and the teeth.** The card drew
    /// the photograph clipped straight to the perforation once, so the bites were cut out of the
    /// picture itself — and on the photo ground that is dark-on-dark: the die lost its edge and
    /// came out a scalloped smudge rather than a franked object.
    ///
    /// Sampled in the margin below the picture, on the die's lower edge where it hangs clear of the
    /// postcard, midway between two bites (die space (-9.1, 57), rotated 5.41° about (123, 249)).
    /// White there means paper; anything dark means the picture has bled to the teeth again. A
    /// re-cut die moves this point — recompute it from the die's own geometry rather than widening
    /// the tolerance.
    @Test func theDieKeepsPrintedPaperBetweenThePictureAndTheTeeth() throws {
        let image = try #require(ShareStoryCard(input: Self.journallessInput).render())
        let sample = try #require(Self.pixel(
            atCanvasPoint: CGPoint(x: 108.6, y: 304.9), in: image))
        #expect(sample.red > 210 && sample.green > 210 && sample.blue > 210,
                """
                the die's paper margin sampled \(sample) rather than white — \
                the picture is bleeding to the perforation
                """)
    }

    /// A walk that earned no stamps omits the corner stamp and postmark whole — absent means
    /// absent — and rendering neither crashes nor blanks.
    @Test func aWalkWithNoStampsRendersWithoutCrashing() throws {
        let image = try #require(ShareStoryCard(input: Self.journallessInput).render())
        #expect((image.cgImage?.width ?? 0) > 0)
    }

    /// A walk whose first stamp exists renders too — the stamp's own artwork resolves inside the
    /// card, so this exercises the `artworkName` path rather than the omission.
    @Test func aWalkWithAFirstStampRendersWithIt() throws {
        let stamped = ShareStoryCard.Input(
            regionTitle: "Badung", journalText: nil, placesCount: 5, durationMinutes: 47,
            stamp: .init(placeName: "Puri Agung Pemecutan", region: "Badung",
                         artworkName: nil),
            postmarkArtworkName: HisploraTripArtwork.emblem,
            language: .en, ground: .brown)
        #expect(ShareStoryCard(input: stamped).render() != nil)
    }

    // MARK: - Helpers

    /// A flat colour at 1×, standing in for a photograph so a sample can assert exactly what
    /// landed under the die.
    private static func solidColor(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }

    /// One RGB triple out of the rendered card, at a *canvas* point (the view's own 246 × 437
    /// space), rescaled into the bitmap the renderer produced.
    private static func pixel(
        atCanvasPoint point: CGPoint, in image: UIImage
    ) -> (red: UInt8, green: UInt8, blue: UInt8)? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width, height = cgImage.height
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let x = min(width - 1, max(0, Int(point.x * ShareStoryCard.rendererScale)))
        let y = min(height - 1, max(0, Int(point.y * ShareStoryCard.rendererScale)))
        let row = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let offset = (y * width + x) * 4
        return (row[offset], row[offset + 1], row[offset + 2])
    }
}

/// The picker's offer rule — the one piece of the sheet that is decision logic rather than paint.
struct ShareStoryVariantListTests {

    @Test func aWalkWithAPhotographIsOfferedBothVariants() {
        #expect(ShareStoryVariantKind.availableVariants(hasPhoto: true) == [.photo, .brown])
    }

    @Test func aWalkWithoutOneIsOfferedOnlyTheBrownCard() {
        #expect(ShareStoryVariantKind.availableVariants(hasPhoto: false) == [.brown])
    }
}
