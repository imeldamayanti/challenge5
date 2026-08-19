import SwiftUI

/// The illustrations franked into a stamp's window, and the rule that picks which of the three a
/// place is currently showing (Figma `456:6227` and the fourteen frames beside it).
///
/// **Three drawings per place, earned rather than chosen.** The design draws every place three
/// times — a pale pencil sketch, a fuller one, and a finished colour illustration — and the reader
/// moves up the set by walking: one finished quest through that place shows the sketch, two the
/// second drawing, three or more the colour plate. Nothing here decides *how many* walks a reader
/// has done; that is counted from their own records and arrives as a number.
///
/// **The pictures are packaged chrome, not content.** They depict real places, so the same rule
/// `PortraitFrame.swift` sets out applies: what is *written under* a picture is a claim and takes a
/// source, while the picture itself is a licence question. They live here rather than in
/// `ContentKit` because they are part of the visual direction and are replaced with it, and because
/// a place with no drawing has to keep working — a stamp with no artwork shows aged paper, which is
/// what shipped before these existed.
public enum HisploraStampArtwork {

    /// How many drawings each place has. Three, and a reader past three stays on the third.
    public static let highestTier = 3

    /// The five places the design drew. A list rather than a lookup: the names are asset stems, and
    /// what a *content* place is called is the app target's business (`Support/StampArtworkCatalog`).
    /// Held here so `HisploraStampArtworkTests` fails when a drawing stops shipping rather than the
    /// Journal quietly emptying every window.
    public static let slugs = ["badung", "balimuseum", "caturmuka", "maospahit", "pemecutan"]

    /// Which of the three drawings a reader who has finished `completedVisits` quests through this
    /// place is looking at.
    ///
    /// The floor is 1, not 0: a stamp is only ever drawn once it has been *earned*, and a walk in
    /// progress has earned its stamps without having finished the quest yet. Showing that reader an
    /// empty window would be the card taking back something they are holding.
    public static func tier(completedVisits: Int) -> Int {
        min(max(completedVisits, 1), highestTier)
    }

    /// `"pemecutan-stamp2"` — the resource stem, which is also what the presentation layer passes
    /// around so nothing above this file has to know the naming convention.
    public static func resourceName(slug: String, tier: Int) -> String {
        "\(slug)-stamp\(min(max(tier, 1), highestTier))"
    }

    /// Convenience for the two callers that have a slug and a count rather than a name.
    public static func resourceName(slug: String, completedVisits: Int) -> String {
        resourceName(slug: slug, tier: tier(completedVisits: completedVisits))
    }

    /// The drawing, or `nil` when it is not packaged — which the stamp card renders as aged paper.
    ///
    /// Cached, unlike the seals and the envelope papers: the Explorer's Card lays out a grid of
    /// these and each one is a half-megabyte PNG, so decoding on every body evaluation is a
    /// scrolling stutter rather than a theoretical cost.
    public static func image(named name: String) -> Image? {
        cache.image(named: name, load: load)
    }

    public static func image(slug: String, tier: Int) -> Image? {
        image(named: resourceName(slug: slug, tier: tier))
    }

    private static let cache = ArtworkCache()

    private static func load(_ name: String) -> Image? {
        #if canImport(UIKit)
        guard let url = url(named: name),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }

    static func url(named name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Images")
    }

    /// Every drawing this module ships — five places at three tiers.
    public static var allResourceNames: [String] {
        slugs.flatMap { slug in (1...highestTier).map { resourceName(slug: slug, tier: $0) } }
    }

    public static var allAreAvailable: Bool {
        allResourceNames.allSatisfy { url(named: $0) != nil }
    }
}

/// A lock around a dictionary, which is all the cache is. Internal rather than file-private
/// because `MapLandmarkArtwork` loads half-megabyte PNGs on the same terms — a map that redecodes
/// four illustrations on every pan frame is the same scrolling stutter this was written for.
///
/// `Mutex` would say this in one line and is not reachable here: it needs macOS 15 and this package
/// declares macOS 14 so the pure-logic suites run on this machine (`Package.swift`). `NSLock` costs
/// a type and is portable to both.
final class ArtworkCache: @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Image?] = [:]

    func image(named name: String, load: (String) -> Image?) -> Image? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = store[name] { return cached }
        let loaded = load(name)
        store[name] = loaded
        return loaded
    }
}

/// The picture inside a stamp's window, by resource name.
///
/// A named view rather than a closure at every call site, so `HisploraStampCard` can offer an
/// initializer that takes a name — the presentation models carry one, and threading a `ViewBuilder`
/// through them would be exactly the palette-shaped dependency `Model/` is not allowed to hold.
public struct HisploraStampArtworkImage: View {
    private let name: String?

    public init(name: String?) {
        self.name = name
    }

    public var body: some View {
        if let name, let image = HisploraStampArtwork.image(named: name) {
            image
                .resizable()
                // Fill: the drawings are 1.05:1 to 1.8:1 and the window is square-ish. Fitting them
                // would print bands of paper across a picture that is meant to be a window.
                .aspectRatio(contentMode: .fill)
        }
    }
}

public extension HisploraStampCard where Picture == HisploraStampArtworkImage {
    /// A stamp franked with one of the packaged drawings. `nil` — an unknown place, or content that
    /// has been withdrawn — falls back to the aged paper the window showed before the drawings
    /// existed, which is the honest empty state rather than a borrowed picture.
    init(title: String, subtitle: String, showsFranking: Bool = true, artworkName: String?) {
        self.init(title: title, subtitle: subtitle, showsFranking: showsFranking) {
            HisploraStampArtworkImage(name: artworkName)
        }
    }
}
