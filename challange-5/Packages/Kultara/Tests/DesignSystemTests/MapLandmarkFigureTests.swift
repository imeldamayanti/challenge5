import Foundation
import ImageIO
import Testing
@testable import DesignSystem

/// Three landmark drawings, one fog, and the geometry a caller needs to put a tap target on the
/// building. All four fail silently: a dropped PNG leaves a marker that still lays out and marks
/// nothing, and a wrong `buildingCentreFraction` puts the 44-point target on the fog beside the
/// drawing rather than on it.
struct MapLandmarkFigureTests {

    @Test func everyDrawingShips() {
        let missing = MapLandmarkArtwork.allCases
            .map(\.resourceName)
            .filter { MapLandmarkImages.url(named: $0) == nil }
        #expect(missing.isEmpty, "missing landmark drawings: \(missing)")
        #expect(MapLandmarkImages.url(named: MapLandmarkImages.fogResourceName) != nil,
                "the fog the drawings stand in is not packaged")
        #expect(MapLandmarkArtwork.allAreAvailable)
    }

    @Test func theThreeDrawingsAreThreeDifferentFiles() {
        let names = MapLandmarkArtwork.allCases.map(\.resourceName)
        #expect(names.count == 3)
        #expect(Set(names).count == 3)
    }

    /// The published proportions have to stay sane, and the dance stage must keep its own box —
    /// the one drawing the frame crops away from its file's proportions. Collapsing all three to a
    /// single box is the mistake this guards.
    @Test func eachDrawingDeclaresItsOwnProportions() {
        for artwork in MapLandmarkArtwork.allCases {
            let ratio = artwork.buildingSize.width / artwork.buildingSize.height
            #expect(ratio > 1, "\(artwork.resourceName) is drawn landscape")
            #expect(ratio < 2, "\(artwork.resourceName)")
        }
        // Temple and gate are near-twins in the frame (82×55 and 85×57.025); the dance stage's
        // box is a different shape from both, and collapsing it to theirs is the mistake to catch.
        let temple = MapLandmarkArtwork.temple.buildingSize.width / MapLandmarkArtwork.temple.buildingSize.height
        let naga = MapLandmarkArtwork.naga.buildingSize.width / MapLandmarkArtwork.naga.buildingSize.height
        let dance = MapLandmarkArtwork.dance.buildingSize.width / MapLandmarkArtwork.dance.buildingSize.height
        #expect(abs(temple - naga) < 0.001)
        #expect(abs(dance - temple) > 0.05)
        #expect(MapLandmarkArtwork.dance.buildingSize.height == 61)
    }

    /// The building boxes are the frames' own display sizes, so they are recorded constants rather
    /// than derived from the files — but a file whose proportions drift far from its box means the
    /// wrong PNG shipped or the frame was re-measured without this table following.
    @Test func eachBoxIsInTheVicinityOfItsFile() throws {
        for artwork in MapLandmarkArtwork.allCases {
            let url = try #require(MapLandmarkImages.url(named: artwork.resourceName))
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
            let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source!, 0, nil) as? [CFString: Any])
            let pixelWidth = try #require(properties[kCGImagePropertyPixelWidth] as? CGFloat)
            let pixelHeight = try #require(properties[kCGImagePropertyPixelHeight] as? CGFloat)
            let pixelRatio = pixelWidth / pixelHeight
            let boxRatio = artwork.buildingSize.width / artwork.buildingSize.height
            // The dance stage's box deliberately crops its file, so the tolerance is loose —
            // tight enough to catch the wrong drawing, loose enough to hold the crop.
            #expect(abs(pixelRatio - boxRatio) < 0.25, "\(artwork.resourceName)")
        }
    }

    /// The frame's cluster is 159 × 87, so a figure drawn 120 across is 65.7 tall. A caller placing
    /// the tap target does this arithmetic and cannot read the answer off the layout.
    @Test func heightFollowsWidthAtTheFramesRatio() {
        #expect(abs(MapLandmarkFigure.height(forWidth: 159) - 87) < 0.001)
        #expect(abs(MapLandmarkFigure.height(forWidth: 120) - 65.66) < 0.01)
        #expect(abs(MapLandmarkFigure.height(forWidth: 318) - 174) < 0.001)
    }

    /// The building stands in the upper third of the cluster — its feet inside the fog, its roof
    /// out of the top — so the centre a target is hung on is above the figure's own middle. A
    /// value at or below 0.5 would put the 44-point square on fog.
    @Test func theBuildingSitsAboveTheFiguresMiddle() {
        for artwork in MapLandmarkArtwork.allCases {
            let fraction = MapLandmarkFigure.buildingCentreFraction(for: artwork)
            #expect(fraction < 0.5, "\(artwork.resourceName)")
            #expect(fraction > 0.25, "\(artwork.resourceName)")
        }
    }
}
