import Foundation

/// The `gdal2tiles --profile=raster --xyz` pyramid built from the region illustration, described
/// well enough that a caller can pick a level and address a tile without touching the filesystem.
///
/// **Why a pyramid exists at all.** Both map surfaces magnify the chart: `RegionMapView` up to 6×,
/// and the discovery basemap further still. Handed a single PNG, SwiftUI rasterises it once at its
/// resting size and then scales the *layer* — so a reader pinching in is magnifying a 402-point
/// raster, not the artwork's own pixels, and the drawing breaks up long before its resolution is
/// spent. Drawing the level whose pixels match the pixels about to be filled is what fixes that;
/// drawing only the tiles on screen is what keeps it cheap.
///
/// **The geometry, which is the whole contract.** In the raster profile the source sits at the
/// *top-left* of each level's tile grid, and `--xyz` numbers rows downward from that corner — the
/// same direction the image's own pixels run, which is why nothing here flips anything. Level
/// `maxZoom` is the source at 1:1; each level below halves it. So a level's own pixel size is
/// `source × 2^(z − maxZoom)`, tile `(x, y)` covers `[x·tileSize, (x+1)·tileSize)` of it, and the
/// tiles on the right and bottom edges are padded with transparency rather than cropped.
///
/// Pure arithmetic over what `tiles.json` states, so the rules a map draws by are
/// testable under `swift test` without a simulator — the reason `ManualOverrideSchedule` and
/// `RouteProjection` live here too.
public struct RasterTilePyramid: Codable, Sendable, Equatable, Hashable {

    /// Edge of a square tile in pixels. 256 for everything gdal2tiles writes by default; read from
    /// the manifest rather than assumed, because a re-tiling at 512 would otherwise be a silent
    /// halving of every rectangle computed here.
    public let tileSize: Int
    /// The tile files' extension, without the dot — `"webp"` for what ships.
    ///
    /// Read from the manifest rather than hardcoded, because the choice of format is the
    /// generator's and it is a large one: the shipped 4× pyramid is 43 MB as PNG and 6.2 MB as
    /// WebP at quality 90, for a difference invisible on this artwork. Defaults to `"png"` so a
    /// pyramid written before this field existed still resolves.
    public let tileFormat: String
    public let sourceWidthPx: Int
    public let sourceHeightPx: Int
    public let minZoom: Int
    public let maxZoom: Int

    public init(
        tileSize: Int,
        tileFormat: String = "png",
        sourceWidthPx: Int,
        sourceHeightPx: Int,
        minZoom: Int,
        maxZoom: Int
    ) {
        self.tileSize = tileSize
        self.tileFormat = tileFormat
        self.sourceWidthPx = sourceWidthPx
        self.sourceHeightPx = sourceHeightPx
        self.minZoom = minZoom
        self.maxZoom = maxZoom
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tileSize = try c.decode(Int.self, forKey: .tileSize)
        tileFormat = try c.decodeIfPresent(String.self, forKey: .tileFormat) ?? "png"
        sourceWidthPx = try c.decode(Int.self, forKey: .sourceWidthPx)
        sourceHeightPx = try c.decode(Int.self, forKey: .sourceHeightPx)
        minZoom = try c.decode(Int.self, forKey: .minZoom)
        maxZoom = try c.decode(Int.self, forKey: .maxZoom)
    }

    /// One addressable tile. Carries its own footprint in the source's normalised space, because
    /// that is the space every caller draws in: `RegionMapView` multiplies it by the artwork's
    /// drawn size, and the basemap overlay multiplies it by the overlay's `MKMapRect`. Neither has
    /// to know that a pyramid was involved.
    public struct Tile: Sendable, Equatable, Hashable {
        public let z: Int
        public let x: Int
        public let y: Int
        /// The file extension, carried on the tile so `relativePath` stays a property rather than
        /// something every caller has to ask the pyramid to compute for it.
        public let format: String

        /// `origin` and `size` as fractions of the *source image*, not of the level's padded grid.
        /// The edge tiles therefore report a footprint that runs past 1 — deliberately, because the
        /// transparent padding is part of the picture the tile carries and cropping the rectangle
        /// while drawing the whole tile would squeeze the visible half of it.
        public let originX: Double
        public let originY: Double
        public let width: Double
        public let height: Double

        public init(z: Int, x: Int, y: Int, format: String = "png",
                    originX: Double, originY: Double, width: Double, height: Double) {
            self.z = z
            self.x = x
            self.y = y
            self.format = format
            self.originX = originX
            self.originY = originY
            self.width = width
            self.height = height
        }

        /// Where the file sits under the pyramid's directory. `gdal2tiles --xyz` writes exactly
        /// this shape.
        public var relativePath: String { "\(z)/\(x)/\(y).\(format)" }
    }

    /// How much of the source one level holds, as a fraction. 1 at `maxZoom`.
    public func scale(atZoom z: Int) -> Double {
        pow(2, Double(z - maxZoom))
    }

    /// The level's own pixel width and height — the source scaled, not the padded grid.
    public func levelSize(atZoom z: Int) -> (width: Double, height: Double) {
        let s = scale(atZoom: z)
        return (Double(sourceWidthPx) * s, Double(sourceHeightPx) * s)
    }

    public func columnCount(atZoom z: Int) -> Int {
        max(1, Int(ceil(levelSize(atZoom: z).width / Double(tileSize))))
    }

    public func rowCount(atZoom z: Int) -> Int {
        max(1, Int(ceil(levelSize(atZoom: z).height / Double(tileSize))))
    }

    /// The shallowest level with at least as many pixels as the caller is about to paint.
    ///
    /// "At least" rather than "closest": a level with fewer pixels than the target is magnified,
    /// which is the defect this type exists to remove, while one with more is downsampled and only
    /// costs memory. Past `maxZoom` there is nothing left to pick and the deepest level is returned
    /// — the artwork's own resolution is the ceiling, and no tiling scheme invents pixels.
    public func zoom(forDrawnWidthPx drawnWidthPx: Double) -> Int {
        guard drawnWidthPx > 0, sourceWidthPx > 0 else { return minZoom }
        for z in minZoom...maxZoom where levelSize(atZoom: z).width >= drawnWidthPx {
            return z
        }
        return maxZoom
    }

    /// Every tile of `z` whose footprint meets `rect`, which is given in the source's normalised
    /// space — the same space `MapPoint` is authored in.
    ///
    /// An empty result means the rectangle misses the drawing entirely, and the caller is expected
    /// to draw nothing rather than fall back to a level that would cover it: a map that quietly
    /// swaps resolution when panned off its own edge is harder to read than one that ends.
    public func tiles(covering rect: NormalizedRect, atZoom z: Int) -> [Tile] {
        let level = max(minZoom, min(maxZoom, z))
        let size = levelSize(atZoom: level)
        guard size.width > 0, size.height > 0 else { return [] }

        // Tile edges in normalised source units. The last column and row extend past 1; clamping
        // the *search* to the grid rather than to the image is what keeps the padded edge tiles
        // reachable.
        let stepX = Double(tileSize) / size.width
        let stepY = Double(tileSize) / size.height
        let columns = columnCount(atZoom: level)
        let rows = rowCount(atZoom: level)

        // `ceil − 1` rather than `floor(maxX.nextDown)`. A tile whose left edge is exactly the
        // viewport's right edge contributes nothing, and both forms mean to exclude it — but
        // `stepX` is a rounded quotient, so nudging the numerator down can divide out *above* the
        // boundary and pull that tile back in. `ceil` reads the boundary the same way from either
        // side.
        let firstColumn = max(0, Int(floor(rect.minX / stepX)))
        let lastColumn = min(columns - 1, Int(ceil(rect.maxX / stepX)) - 1)
        let firstRow = max(0, Int(floor(rect.minY / stepY)))
        let lastRow = min(rows - 1, Int(ceil(rect.maxY / stepY)) - 1)

        guard firstColumn <= lastColumn, firstRow <= lastRow else { return [] }

        var found: [Tile] = []
        found.reserveCapacity((lastColumn - firstColumn + 1) * (lastRow - firstRow + 1))
        for y in firstRow...lastRow {
            for x in firstColumn...lastColumn {
                found.append(Tile(
                    z: level, x: x, y: y, format: tileFormat,
                    originX: Double(x) * stepX,
                    originY: Double(y) * stepY,
                    width: stepX,
                    height: stepY))
            }
        }
        return found
    }

    /// The whole drawing at one level, for a caller with no viewport to intersect against.
    public func allTiles(atZoom z: Int) -> [Tile] {
        tiles(covering: .unit, atZoom: z)
    }

    /// A rectangle in the source's normalised space. Deliberately not `CGRect`: `RunEngine` is
    /// Foundation-only by the layering rule, and a rectangle that cannot be handed a `CGAffineTransform`
    /// is a rectangle nobody can accidentally put a view coordinate into.
    public struct NormalizedRect: Sendable, Equatable, Hashable {
        public let minX: Double
        public let minY: Double
        public let maxX: Double
        public let maxY: Double

        public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
            self.minX = min(minX, maxX)
            self.minY = min(minY, maxY)
            self.maxX = max(minX, maxX)
            self.maxY = max(minY, maxY)
        }

        public static let unit = NormalizedRect(minX: 0, minY: 0, maxX: 1, maxY: 1)
    }
}
