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
}
