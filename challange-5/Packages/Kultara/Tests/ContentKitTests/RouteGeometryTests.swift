import Foundation
import Testing
@testable import ContentKit

/// `FR-MAP-02` reads the route the content already ships. Every test here that could pass on a
/// lenient parser is written so it fails on one.
struct RouteGeometryTests {

    private func data(_ json: String) -> Data { Data(json.utf8) }

    private let valid = """
    {
      "type": "FeatureCollection",
      "features": [
        { "type": "Feature", "properties": { "role": "route" },
          "geometry": { "type": "LineString",
            "coordinates": [[115.2085, -8.6570], [115.2101, -8.6552], [115.2138, -8.6561]] } },
        { "type": "Feature", "properties": { "checkpointId": "cp2", "orderIndex": 1 },
          "geometry": { "type": "Point", "coordinates": [115.2101, -8.6552] } },
        { "type": "Feature", "properties": { "checkpointId": "cp1", "orderIndex": 0 },
          "geometry": { "type": "Point", "coordinates": [115.2085, -8.6570] } }
      ]
    }
    """

    /// GeoJSON is `[longitude, latitude]`. Read the other way round the whole route lands off the
    /// coast of Somalia while looking perfectly well-formed, which is why this is asserted rather
    /// than commented.
    @Test func longitudeComesFirstInTheFile() throws {
        let geometry = try RouteGeometryDecoder.decode(data(valid))
        #expect(geometry.line.first?.lat == -8.6570)
        #expect(geometry.line.first?.lon == 115.2085)
    }

    @Test func theLineKeepsItsAuthoredOrder() throws {
        let geometry = try RouteGeometryDecoder.decode(data(valid))
        #expect(geometry.line.count == 3)
        #expect(geometry.line[1].lon == 115.2101)
    }

    /// The file may list its points in any order; the walk has exactly one.
    @Test func checkpointsComeBackInOrderIndexOrder() throws {
        let geometry = try RouteGeometryDecoder.decode(data(valid))
        #expect(geometry.checkpoints.map(\.checkpointID) == ["cp1", "cp2"])
        #expect(geometry.checkpoints.map(\.orderIndex) == [0, 1])
    }

    @Test func nonJSONIsRejected() {
        #expect(throws: RouteGeometryError.notJSON) {
            try RouteGeometryDecoder.decode(data("not json at all"))
        }
    }

    @Test func aBareGeometryIsNotAFeatureCollection() {
        #expect(throws: RouteGeometryError.notAFeatureCollection) {
            try RouteGeometryDecoder.decode(data(#"{"type":"LineString","coordinates":[]}"#))
        }
    }

    /// A collection of points and no line is a set of pins with nothing joining them — which is
    /// exactly the map `FR-MAP-02` says is not enough.
    @Test func aCollectionWithNoLineStringIsRejected() {
        let pointsOnly = """
        { "type": "FeatureCollection", "features": [
          { "type": "Feature", "properties": {},
            "geometry": { "type": "Point", "coordinates": [115.2, -8.6] } } ] }
        """
        #expect(throws: RouteGeometryError.noLineString) {
            try RouteGeometryDecoder.decode(data(pointsOnly))
        }
    }

    @Test func aSinglePointLineIsRejected() {
        let oneVertex = """
        { "type": "FeatureCollection", "features": [
          { "type": "Feature", "properties": {},
            "geometry": { "type": "LineString", "coordinates": [[115.2, -8.6]] } } ] }
        """
        #expect(throws: RouteGeometryError.tooFewPoints(1)) {
            try RouteGeometryDecoder.decode(data(oneVertex))
        }
    }

    @Test func aCoordinateThatIsNotAPairIsRejected() {
        let short = """
        { "type": "FeatureCollection", "features": [
          { "type": "Feature", "properties": {},
            "geometry": { "type": "LineString", "coordinates": [[115.2], [115.3, -8.6]] } } ] }
        """
        #expect(throws: (any Error).self) {
            try RouteGeometryDecoder.decode(data(short))
        }
    }

    /// The shipped content is the thing the app actually draws, so it is parsed here rather than
    /// only in a fixture.
    @Test func everyShippedQuestCarriesAReadableRoute() throws {
        let repository = try BundledContentRepository()
        for quest in try repository.quests() {
            let geometry = try repository.routeGeometry(questID: quest.id)
            #expect(geometry != nil, "\(quest.id) has no readable route geometry")
            #expect((geometry?.line.count ?? 0) >= 2, "\(quest.id)")
        }
    }
}
