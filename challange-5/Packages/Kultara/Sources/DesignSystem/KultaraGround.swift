import SwiftUI

/// The printed sheet the museum-catalogue direction sits on — Figma `275:2179`, the Home frame's
/// ground, shipped from `docs/design-sources/home-ground.svg`.
///
/// **The SVG is the source and it is not the asset.** Its rectangle is `#FDF2DE`, which is
/// `palette.paper` and already a token; the speckle on top of it is an SVG filter — `feTurbulence`
/// fractal noise, `luminanceToAlpha`, a discrete transfer keeping ten of a hundred steps, and an
/// `rgba(147, 130, 97, 0.5)` flood composited back in. No iOS image loader runs SVG filters, and
/// Xcode's asset-catalogue SVG support does not either, so the file is rendered once through a real
/// SVG renderer and the result ships as `home-ground.png` — 1206 × 2622, the frame's 402 × 874 at
/// 3x. The render has exactly two colours, `#FDF2DE` and `#C8BAA0`, and covers 1.43% of the sheet
/// with the second.
///
/// The vector stays in `docs/design-sources/` and **not** in `Resources/Images`: `Package.swift`
/// copies that directory wholesale, so anything left there rides into every user's app bundle. It
/// is named `home-ground.svg` there because Figma exported it as `Rectangle 10.svg` and that name
/// is already taken beside it by `547:2953`, which is a different frame's ground.
///
/// **Drawn over the token, never instead of it.** `HisploraGround` makes the same argument:
/// `KultaraThemeTests` measures token pairs and cannot measure a picture, so the ground colour is
/// painted first and this goes on top. The render's own flat pixels are `#FDF2DE` exactly, which is
/// what makes that honest — the speckle moves `ink` on `paper` from 15.26:1 to **15.12:1**, and
/// leaves the hairline, the tightest pair on this surface, at 4.13:1 against a 3:1 requirement.
///
/// **Light appearance only.** There is no dark variant of the artwork, and tinting a cream sheet
/// dark produces mud rather than paper. `KultaraThemeProvider` therefore draws it only when the
/// resolved appearance is light; dark keeps the flat token. A deliberate gap, not an oversight —
/// see `sheet(for:)`.
///
/// It supersedes `paper-texture.png`, the museum direction's earlier hand-made grain: that was a
/// 445 KB speckle designed to be attenuated over an arbitrary cream, and this is the frame's own
/// sheet at 98 KB. Keeping both would have meant two grounds with no rule for which screen got
/// which.
public enum KultaraGround {
    /// Loaded once from the package bundle. `Image(_:bundle:)` would resolve lazily and silently
    /// draw nothing if the resource were ever dropped from `Package.swift`; this way the miss is a
    /// value the caller can branch on, and `isAvailable` makes it testable.
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
        Bundle.module.url(forResource: "home-ground", withExtension: "png", subdirectory: "Images")
    }

    /// Whether the artwork shipped. Asserted by `KultaraGroundTests` so dropping the resource from
    /// `Package.swift` fails the suite instead of quietly flattening every screen.
    public static var isAvailable: Bool { imageURL != nil }

    /// The sheet is opaque and carries the design's own alpha in its pixels, so it is drawn at full
    /// strength. The density that has to stay small lives in the artwork instead — see
    /// `speckleCoverage`.
    public static let opacity: Double = 1.0

    /// What fraction of the sheet is speckle rather than stock, measured off the render: 45,320 of
    /// 3,162,132 pixels.
    public static let speckleCoverage: Double = 0.0143

    /// The alpha those pixels were flooded at, from the SVG's `rgba(147, 130, 97, 0.5)`.
    public static let speckleAlpha: Double = 0.5

    /// How much of `palette.paper` the speckle actually replaces. This is the quantity that keeps
    /// the measured pairs describing what is on screen, and `KultaraGroundTests` holds it under 5%
    /// — roughly a 1% move on any ratio measured against the token.
    public static var speckleInkCoverage: Double { opacity * speckleCoverage * speckleAlpha }

    /// The sheet for a given appearance, or `nil` where the flat token should stand alone.
    ///
    /// Returns `nil` for `.dark` by design: the artwork is a cream sheet, and there is no dark
    /// counterpart. Adding one means adding a second asset here, not tinting this one.
    public static func sheet(for colorScheme: ColorScheme) -> Image? {
        colorScheme == .dark ? nil : image
    }
}

/// The printed sheet over whatever colour it is put on.
///
/// `scaledToFill` rather than tiled: it is one sheet the size of a phone, and the export's own
/// proportions are the frame's. Non-interactive and hidden from VoiceOver — it is paper, and there
/// is nothing in it to read.
public struct KultaraGroundSheet: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Whether the dark gap applies. The museum theme flips with the system and wants it; the
    /// Hisplora direction is a fixed editorial pairing that does not flip at all (`HisploraPalette`
    /// makes that argument), so its screens ask for the sheet unconditionally — otherwise a reader
    /// in dark mode gets the Journal's ground and nothing printed on it.
    private let respectsAppearance: Bool

    public init(respectsAppearance: Bool = true) {
        self.respectsAppearance = respectsAppearance
    }

    public var body: some View {
        if let image = respectsAppearance ? KultaraGround.sheet(for: colorScheme)
                                          : KultaraGround.image {
            image
                .resizable()
                .scaledToFill()
                .opacity(KultaraGround.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

public extension View {
    /// The museum direction's ground: the `paper` token with `275:2179`'s printed sheet over it.
    ///
    /// `KultaraThemeProvider` already draws this behind the whole app, so a screen that needs
    /// nothing of its own can leave it alone. Most cannot: a `sheet` or a `fullScreenCover` is
    /// presented outside the provider's view tree and would show the system's ground through it, so
    /// the screens that can be presented that way paint their own.
    ///
    /// **Use this rather than `.background(palette.paper.color)`.** Ten screens painted the flat
    /// token over the provider's sheet, which is why the catalogue read as flat cream while the
    /// Journal — which draws the sheet itself — read as printed paper. Same colour, one of them
    /// missing its speckle.
    func kultaraGround() -> some View {
        modifier(KultaraGroundBackground())
    }
}

/// The ground itself. A modifier rather than a plain `background` closure because the paper colour
/// comes from `\.kultaraPalette`, and reading the environment needs a view.
public struct KultaraGroundBackground: ViewModifier {
    @Environment(\.kultaraPalette) private var palette

    public init() {}

    public func body(content: Content) -> some View {
        content.background {
            ZStack {
                palette.paper.color
                KultaraGroundSheet()
            }
            // The same `ignoresSafeArea` `KultaraThemeProvider` puts on its own ground. Without it
            // the sheet stops at the safe-area inset and the status bar keeps the system's white,
            // which is what a screen presented as a `fullScreenCover` shows.
            .ignoresSafeArea()
        }
    }
}
