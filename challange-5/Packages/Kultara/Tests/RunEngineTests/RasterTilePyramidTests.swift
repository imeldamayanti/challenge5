import Foundation
import Testing

@testable import RunEngine

/// The shipped pyramid, as `scripts/build-map-tiles.sh` wrote it.
///
/// 6144 × 4096 is the authored 1536 × 1024 chart through a 4× super-resolution pass, so these
/// numbers are the artwork's *current* ceiling rather than a property of the drawing — which is
/// exactly why they are pinned here: re-tiling from a different source has to come through this
/// file and say so.
private let shipped = RasterTilePyramid(
    tileSize: 256, tileFormat: "webp",
    sourceWidthPx: 6144, sourceHeightPx: 4096, minZoom: 0, maxZoom: 5)

@Suite("Raster tile pyramid")
struct RasterTilePyramidTests {

    @Test("The deepest level is the source at 1:1 and each level below halves it")
    func levelsHalve() {
        #expect(shipped.scale(atZoom: 5) == 1)
        #expect(shipped.scale(atZoom: 4) == 0.5)
        #expect(shipped.scale(atZoom: 0) == 0.03125)

        let native = shipped.levelSize(atZoom: 5)
        #expect(native.width == 6144)
        #expect(native.height == 4096)

        // Level 3 is the authored drawing at its own size — the whole pyramid before the
        // super-resolution pass, still sitting in the middle of this one.
        let authored = shipped.levelSize(atZoom: 3)
        #expect(authored.width == 1536)
        #expect(authored.height == 1024)
    }

    /// The counts `gdal2tiles` actually wrote. If the geometry here drifts from the generator's,
    /// the map asks for files that are not there and draws holes.
    @Test("The grid at each level is the one gdal2tiles wrote")
    func gridMatchesTheGenerator() {
        #expect(shipped.columnCount(atZoom: 5) == 24)
        #expect(shipped.rowCount(atZoom: 5) == 16)
        #expect(shipped.columnCount(atZoom: 4) == 12)
        #expect(shipped.rowCount(atZoom: 4) == 8)
        #expect(shipped.columnCount(atZoom: 3) == 6)
        #expect(shipped.rowCount(atZoom: 3) == 4)
        #expect(shipped.allTiles(atZoom: 0).count == 1)

        // 513 files on disk, which is what the generator reported.
        let total = (shipped.minZoom...shipped.maxZoom)
            .map { shipped.allTiles(atZoom: $0).count }
            .reduce(0, +)
        #expect(total == 513)
    }

    /// The rule that makes the pyramid worth having: never hand the screen fewer pixels than it is
    /// about to paint, because magnifying is the defect and downsampling only costs memory.
    @Test("A level is picked with at least as many pixels as the screen will paint")
    func picksALevelThatIsNotMagnified() {
        // 402 points at 3x, the resting size on an iPhone 17 — level 2 is 768 px, level 3 is 1536.
        #expect(shipped.zoom(forDrawnWidthPx: 1206) == 3)
        #expect(shipped.zoom(forDrawnWidthPx: 700) == 2)
        #expect(shipped.zoom(forDrawnWidthPx: 180) == 0)
        #expect(shipped.zoom(forDrawnWidthPx: 200) == 1)
        // The zooms the super-resolution pass bought: 4× and 16× the resting width still descend
        // rather than magnify.
        #expect(shipped.zoom(forDrawnWidthPx: 2400) == 4)
        #expect(shipped.zoom(forDrawnWidthPx: 4800) == 5)
    }

    /// The artwork's own resolution is the ceiling. Saying so in a test rather than in a comment,
    /// because the obvious reading of "tiles fix pixelation" is that they fix it at every zoom, and
    /// they do not: past `maxZoom` there is nothing left to descend into.
    @Test("Past the deepest level the deepest level is what there is")
    func stopsAtNativeResolution() {
        #expect(shipped.zoom(forDrawnWidthPx: 9000) == shipped.maxZoom)
        #expect(shipped.zoom(forDrawnWidthPx: .greatestFiniteMagnitude) == shipped.maxZoom)
    }

    @Test("Tiles are addressed the way gdal2tiles --xyz names its files")
    func addressesFilesTheWayTheyAreWritten() {
        let corner = shipped.tiles(
            covering: .init(minX: 0, minY: 0, maxX: 0.001, maxY: 0.001), atZoom: 5)
        #expect(corner.map(\.relativePath) == ["5/0/0.webp"])

        // Bottom-right of the drawing, which is the padded corner of the grid.
        let far = shipped.tiles(
            covering: .init(minX: 0.999, minY: 0.999, maxX: 1, maxY: 1), atZoom: 5)
        #expect(far.map(\.relativePath) == ["5/23/15.webp"])

        // A pyramid written before `tileFormat` existed still addresses PNGs.
        let legacy = RasterTilePyramid(
            tileSize: 256, sourceWidthPx: 1469, sourceHeightPx: 1071, minZoom: 0, maxZoom: 3)
        #expect(legacy.allTiles(atZoom: 0).map(\.relativePath) == ["0/0/0.png"])
    }

    /// A tile's footprint is stated in the *source's* fractions, so an edge tile overhangs 1. The
    /// alternative — clipping the footprint at the image's edge while still drawing a whole 256
    /// pixel tile — squeezes the visible half of every edge tile and shears the coastline.
    ///
    /// The shipped pyramid happens not to exercise it: 6144 and 4096 are exact multiples of 256, so
    /// its grid closes on the image with nothing left over. Both are asserted, because the one that
    /// is true today stops being true the moment the artwork is re-cut to another size.
    @Test("Edge tiles report the overhang rather than a clipped footprint")
    func edgeTilesOverhang() {
        let shippedLast = try! #require(
            shipped.allTiles(atZoom: 5).first { $0.x == 23 && $0.y == 15 })
        #expect(abs(shippedLast.originX + shippedLast.width - 1) < 1e-9)
        #expect(abs(shippedLast.originY + shippedLast.height - 1) < 1e-9)

        let ragged = RasterTilePyramid(
            tileSize: 256, sourceWidthPx: 1469, sourceHeightPx: 1071, minZoom: 0, maxZoom: 3)
        let last = try! #require(ragged.allTiles(atZoom: 3).first { $0.x == 5 && $0.y == 4 })

        #expect(last.originX + last.width > 1)
        #expect(last.originY + last.height > 1)
        // 6 columns of 256 over a 1469-pixel source.
        #expect(abs(last.originX + last.width - 6 * 256 / 1469.0) < 1e-9)
    }

    @Test("Neighbouring tiles share an edge exactly, so nothing seams")
    func neighboursShareTheirEdge() {
        let tiles = shipped.allTiles(atZoom: 5)
        let a = try! #require(tiles.first { $0.x == 2 && $0.y == 1 })
        let b = try! #require(tiles.first { $0.x == 3 && $0.y == 1 })
        let below = try! #require(tiles.first { $0.x == 2 && $0.y == 2 })

        #expect(a.originX + a.width == b.originX)
        #expect(a.originY + a.height == below.originY)
    }

    @Test("Only the tiles meeting the viewport are returned")
    func coversOnlyWhatIsAsked() {
        let region = RasterTilePyramid.NormalizedRect(
            minX: 0.4, minY: 0.4, maxX: 0.5, maxY: 0.5)
        let covering = shipped.tiles(covering: region, atZoom: 5)

        #expect(!covering.isEmpty)
        #expect(covering.count < shipped.allTiles(atZoom: 5).count)
        for tile in covering {
            #expect(tile.originX < region.maxX)
            #expect(tile.originX + tile.width > region.minX)
            #expect(tile.originY < region.maxY)
            #expect(tile.originY + tile.height > region.minY)
        }
    }

    @Test("A zoom outside the pyramid is clamped rather than addressing a level that is not there")
    func clampsTheLevel() {
        #expect(shipped.allTiles(atZoom: 99).allSatisfy { $0.z == 5 })
        #expect(shipped.allTiles(atZoom: -4).allSatisfy { $0.z == 0 })
    }

    @Test("The manifest gdal2tiles writes decodes as it stands")
    func decodesTheGeneratedManifest() throws {
        let json = Data("""
        {
          "tileSize": 256,
          "tileFormat": "webp",
          "sourceWidthPx": 6144,
          "sourceHeightPx": 4096,
          "minZoom": 0,
          "maxZoom": 5
        }
        """.utf8)

        #expect(try JSONDecoder().decode(RasterTilePyramid.self, from: json) == shipped)
    }
}
