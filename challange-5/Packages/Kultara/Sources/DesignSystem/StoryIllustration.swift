import SwiftUI

/// The story reveal's background art (Figma `293:1643`, "Story - Puri Agung Pemecutan"), packaged
/// the same way the portrait frame's ornament and the typewriter's machine are: loaded once from
/// the bundle, with `isAvailable` exposed so a dropped resource fails a test rather than shipping a
/// blank page.
///
/// One picture for every surface that ships no drawing of its own — the sidequest story letters,
/// and any Place whose content carries no `storyArtwork`. It used to be every checkpoint's story
/// reveal; since `964:3212` and its three siblings shipped as `Place.storyArtwork`, the four
/// places they belong to draw their own art full bleed instead, and this stays what those without
/// one get. Chrome either way, the same way `KultaraTypewriter` always shows the same machine
/// regardless of which quest is running. `public`, unlike its siblings: `StoryRevealScreen` lives
/// in the app target, not in this module, so the loaded image has to cross that boundary.
///
/// **The geometry below is why this is not simply a `.fill` in a fixed-height box.** `293:1643`
/// draws the picture full-bleed at the screen's own width, so its height follows from its aspect
/// rather than being chosen; the drawing sits in the lower half of a tall sheet of blank paper, and
/// the frame lifts it 21 points off the top and lets the words start at 557. Everything under that
/// is the same cream the screen's ground already is, so the strip is cut there rather than drawn —
/// which is what leaves the passage room to grow at accessibility text sizes instead of being
/// pushed off a picture that never moves.
public enum StoryIllustrationMetrics {

    /// The artwork's own proportions, 941 × 1672.
    public static let aspectRatio: CGFloat = 941.0 / 1672.0

    /// How far the picture is lifted above the screen's top edge, as a fraction of the screen's
    /// width: 21 of 402 in the frame.
    public static let topOffsetFraction: CGFloat = -21.0 / 402.0

    /// How tall the picture's strip is, measured from the screen's own top edge — status bar
    /// included, because the frame runs the paper up under it — as a fraction of the screen's
    /// width. The words begin at 557 on a 402-point frame.
    public static let visibleHeightFraction: CGFloat = 557.0 / 402.0

    public static let image: Image? = {
        #if canImport(UIKit)
        guard let url = imageURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }()

    static var imageURL: URL? {
        Bundle.module.url(
            forResource: "story-reveal-illustration", withExtension: "png", subdirectory: "Images")
    }

    /// Whether the packaged illustration resolved. Exposed for the same reason
    /// `PortraitFrameMetrics.ornamentIsAvailable` and `TypewriterMetrics.machineIsAvailable` are.
    public static var isAvailable: Bool { imageURL != nil }
}
