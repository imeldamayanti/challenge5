import SwiftUI

/// The speckled paper grain the museum-catalogue direction sits on.
///
/// The texture is drawn *over* `palette.paper`, never instead of it. That is what keeps
/// `NFR-A11Y-03` intact: `KultaraThemeTests` measures token pairs, and a picture behind text is
/// something it cannot measure. Because the grain is a near-transparent speckle in the same hue as
/// the token beneath it, every measured ratio still describes what is actually on screen. Replacing
/// the ground with a picture of a different colour would silently invalidate the whole suite.
///
/// **Light appearance only.** There is no dark variant of the artwork, and tinting a cream sheet
/// dark produces mud rather than paper. `KultaraThemeProvider` therefore draws the grain only when
/// the resolved appearance is light; dark keeps the flat token. This is a deliberate gap, not an
/// oversight — see `paperGrain(for:)`.
public enum KultaraPaperTexture {
    /// Loaded once from the package bundle. `Image(_:bundle:)` would resolve lazily and silently
    /// draw nothing if the resource were ever dropped from `Package.swift`; this way the miss is a
    /// value the caller can branch on, and `grainIsAvailable` makes it testable.
    public static let grain: Image? = {
        #if canImport(UIKit)
        guard let url = grainURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }()

    static var grainURL: URL? {
        Bundle.module.url(forResource: "paper-texture", withExtension: "png", subdirectory: "Images")
    }

    /// Whether the artwork shipped. Asserted by `PaperTextureTests` so dropping the resource from
    /// `Package.swift` fails the suite instead of quietly flattening every screen.
    public static var grainIsAvailable: Bool { grainURL != nil }

    /// How strongly the grain reads over the token beneath it. Low enough that the speckle is
    /// texture rather than pattern, and low enough that it cannot move a measured contrast ratio.
    public static let grainOpacity: Double = 0.55

    /// The grain for a given appearance, or `nil` where the flat token should stand alone.
    ///
    /// Returns `nil` for `.dark` by design: the artwork is a cream sheet, and there is no dark
    /// counterpart. Adding one means adding a second asset here, not tinting this one.
    public static func paperGrain(for colorScheme: ColorScheme) -> Image? {
        colorScheme == .dark ? nil : grain
    }
}
