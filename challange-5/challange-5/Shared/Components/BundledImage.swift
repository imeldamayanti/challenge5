import SwiftUI

/// Loads a bundled image from disk. In one place because the card, the preview and the map all need
/// it, and because `Image(contentsOfFile:)` does not exist.
enum BundledImage {
    static func load(_ url: URL) -> Image? {
        #if canImport(UIKit)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }

    /// The same picture with its resolution destroyed — `98:1588`'s covered frame.
    ///
    /// The cover has to still be *the photograph*: a wash heavy enough to hide the subject reads as
    /// a grey plate, and rubbing a grey plate away says nothing about what is underneath. Dropping
    /// the picture to `blocks` pixels across and drawing it back at full size with nearest-neighbour
    /// sampling leaves the composition, the colours and the light exactly where they are, and takes
    /// away only the detail — which is the state the walker is uncovering out of.
    ///
    /// Done at load rather than with `.blur`: blur at a radius strong enough to hide a face turns
    /// every picture into the same smear, and the cheap SwiftUI route to real pixels — a small frame
    /// upscaled — needs an `Image` in hand, which is here and not inside `DesignSystem`.
    ///
    /// The caller must draw the result with `.interpolation(.none)`, or the upscale smooths the
    /// blocks straight back into a blur.
    static func pixelated(_ url: URL, blocks: Int = 26) -> Image? {
        #if canImport(UIKit)
        guard blocks > 0,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data),
              image.size.width > 0, image.size.height > 0
        else { return nil }

        // `blocks` counts across the shorter edge, so a landscape and a portrait source are
        // destroyed by the same amount rather than by the same pixel count.
        let scale = CGFloat(blocks) / min(image.size.width, image.size.height)
        let target = CGSize(width: max(1, (image.size.width * scale).rounded()),
                            height: max(1, (image.size.height * scale).rounded()))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let small = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return Image(uiImage: small)
        #else
        return nil
        #endif
    }
}
