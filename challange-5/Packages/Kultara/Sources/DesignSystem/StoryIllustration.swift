import SwiftUI

/// The story reveal's background art (Figma `46:120`, "Story - Puri Maospahit"), packaged the same
/// way the portrait frame's ornament and the typewriter's machine are: loaded once from the bundle,
/// with `isAvailable` exposed so a dropped resource fails a test rather than shipping a blank page.
///
/// One picture for every checkpoint's story reveal, not one per place — the content tree has no
/// per-place illustration field (`heroImageAsset` exists only on `Quest`), and this is chrome the
/// screen draws, the same way `KultaraTypewriter` always shows the same machine regardless of which
/// quest is running. `public`, unlike its siblings: `StoryRevealScreen` lives in the app target, not
/// in this module, so the loaded image has to cross that boundary.
public enum StoryIllustrationMetrics {

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
