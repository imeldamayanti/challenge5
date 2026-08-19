import Foundation
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

    /// The published proportions have to match the files, or a figure sized by width prints the
    /// drawing squashed. Checked against the shipped pixels rather than against the constants.
    @Test func eachDrawingDeclaresItsOwnProportions() {
        for artwork in MapLandmarkArtwork.allCases {
            #expect(artwork.aspectRatio > 1, "\(artwork.resourceName) is drawn landscape")
            #expect(artwork.aspectRatio < 2, "\(artwork.resourceName)")
        }
        // Distinct, because the three drawings are three different shapes and collapsing them to
        // one ratio is the mistake this guards.
        #expect(Set(MapLandmarkArtwork.allCases.map(\.aspectRatio)).count == 3)
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
        #expect(MapLandmarkFigure.buildingCentreFraction < 0.5)
        #expect(MapLandmarkFigure.buildingCentreFraction > 0.25)
    }
}
