import SwiftUI

/// The printed ground the Journal and the Explorer's Card sit on — Figma `547:2953`, shipped from
/// `Rectangle 10.svg`.
///
/// **The SVG is the source and it is not the asset.** Its rectangle is `#6E3B26`, which is
/// `brownMid` and already a token; everything else in the file is an SVG filter — `feTurbulence`
/// fractal noise, `luminanceToAlpha`, a discrete transfer keeping ten of a hundred steps, and a
/// white flood at `0.25` composited back in. No iOS image loader runs SVG filters, and Xcode's
/// asset-catalogue SVG support does not either, so the file is rendered once through the system's
/// own SVG renderer and the result ships as `hisplora-ground.png` — 804 × 1748, the frame's 402 ×
/// 874 at 2x. The SVG stays in `Resources/Images` as the record of where the pixels came from.
///
/// **Drawn over the token, never instead of it.** `KultaraPaperTexture` makes the same argument:
/// `HisploraThemeTests` measures token pairs and cannot measure a picture, so the ground colour is
/// painted first and this goes on top. The render's own flat pixels are `#6E3B26` exactly, which is
/// what makes that honest — the speckle moves the ground's average luminance from `0.0659` to
/// `0.0769`, taking `inkCream` from 7.94:1 to **7.25:1**. See `docs/hisplora-tokens.md`.
public enum HisploraGround {

    /// The printed sheet. `nil` off UIKit, where the pure-logic suites run and nothing is drawn.
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
        Bundle.module.url(forResource: "hisplora-ground", withExtension: "png", subdirectory: "Images")
    }

    /// Whether the sheet shipped, for the same reason `KultaraPaperTexture.grainIsAvailable` and
    /// `TransitionScrollMetrics.isAvailable` exist: a dropped resource should fail a test rather
    /// than flatten a screen with nothing to notice it by.
    public static var isAvailable: Bool { imageURL != nil }
}

/// The printed ground over whatever colour it is put on.
///
/// `scaledToFill` rather than tiled: it is one sheet the size of a phone, and the export's own
/// proportions are the frame's. Non-interactive and hidden from VoiceOver — it is paper, and there
/// is nothing in it to read.
public struct HisploraGroundSheet: View {
    public init() {}

    public var body: some View {
        if let image = HisploraGround.image {
            image
                .resizable()
                .scaledToFill()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
