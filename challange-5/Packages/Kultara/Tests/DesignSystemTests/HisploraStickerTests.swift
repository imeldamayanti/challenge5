import CoreGraphics
import Testing
@testable import DesignSystem

/// The paper cut-outs the Trip Summary and the History page scatter over their grounds
/// (Figma section `791:6917`).
///
/// Two things are guarded, and the second is the more important one.
struct HisploraStickerTests {

    /// Every name the catalog lists is actually in the bundle. A dropped export costs a screen a
    /// layer with no error anywhere — the collage simply draws one fewer thing.
    @Test func everyListedStickerIsPackaged() {
        for name in HisploraStickerArtwork.names {
            #expect(HisploraStickerArtwork.url(named: name) != nil,
                    "\(name) is listed but not packaged")
        }
        #expect(HisploraStickerArtwork.allAreAvailable)
    }

    /// The nine page illustrations the two frames place — the plate, the portrait, the torn scrap,
    /// the pen rule, the arrow, the summary's emblem, the Trip Collection's legend, and the two
    /// gilt medallion frames.
    @Test func everyPageIllustrationIsPackaged() {
        #expect(HisploraTripArtwork.allAreAvailable)
        #expect(HisploraTripArtwork.names.count == 9)
    }

    /// **The set is eighteen, and the number is the guard.** Four of these letter something into
    /// the picture and one page illustration is a likeness of a named historical figure; the owner
    /// asked on 2026-08-20 for the frames reproduced exactly, so all of it ships and the sourcing
    /// is carried as a recorded decision rather than as a refusal. This test exists so the set
    /// cannot drift silently in either direction — a sticker quietly added or quietly dropped is a
    /// change to what the app asserts, and it should have to be made here on purpose.
    @Test func theSetIsExactlyWhatTheTwoPagesPlace() {
        #expect(HisploraStickerArtwork.names.count == 18)
        for lettered in ["sticker-3-32", "sticker-2-26", "sticker-2-02"] {
            #expect(HisploraStickerArtwork.names.contains(lettered))
        }
        // `sheet-3-05`'s portrait is a page illustration, not a sticker, and is named there.
        #expect(!HisploraStickerArtwork.names.contains("sticker-3-05"))
        #expect(HisploraTripArtwork.names.contains(HisploraTripArtwork.king))
    }

    /// A collage is decoration laid out in the frame's own coordinates, so a placement's box is the
    /// drawing's own size before rotation — never the rotated bounding box Figma reports.
    @Test func aPlacementKeepsItsCentreAndItsUnrotatedSize() {
        let placement = HisploraStickerPlacement(
            "sticker-3-16",
            center: CGPoint(x: 369.3, y: 51.5),
            size: CGSize(width: 68.4, height: 94.4),
            rotation: .degrees(7.99))
        #expect(placement.center.x == 369.3)
        #expect(placement.size.width == 68.4)
        #expect(abs(placement.rotation.degrees - 7.99) < 0.0001)
        #expect(placement.isBehind == false)
    }
}
