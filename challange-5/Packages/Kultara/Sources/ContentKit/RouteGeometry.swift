import Foundation

/// The authored walking route for a quest, decoded from its `route.geojson`.
///
/// `FR-MAP-02` asks the run screen to show the ordered checkpoint sequence, the walker's position
/// relative to the next checkpoint, and the straight-line distance remaining. The first of those is
/// this — the geometry the content already ships at `RouteInfo.geometryAsset`, which until now
/// nothing read.
///
/// Decoded here rather than in the view for the same reason every other content shape is: the
/// parsing is testable where the rest of the parsing is tested, and `RunEngine` and the views stay
/// Foundation-only.
public struct RouteGeometry: Sendable, Equatable {

    /// A checkpoint as the geometry file records it. `checkpointID` is what links it back to the
    /// quest — content never links by position in an array.
    public struct CheckpointPoint: Sendable, Equatable {
        public let checkpointID: String?
        public let orderIndex: Int?
        public let coordinate: Coordinate

        public init(checkpointID: String?, orderIndex: Int?, coordinate: Coordinate) {
            self.checkpointID = checkpointID
            self.orderIndex = orderIndex
            self.coordinate = coordinate
        }
    }

    /// The walked line, in authored order.
    public let line: [Coordinate]
    /// The stop markers the file carries, sorted by `orderIndex` where it is given.
    public let checkpoints: [CheckpointPoint]

    public init(line: [Coordinate], checkpoints: [CheckpointPoint]) {
        self.line = line
        self.checkpoints = checkpoints
    }
}

public enum RouteGeometryError: Error, Equatable, CustomStringConvertible {
    case notJSON
    case notAFeatureCollection
    case noLineString
    /// A line of one point is a dot, and a route drawn from it is a blank canvas.
    case tooFewPoints(Int)
    case malformedCoordinate(String)

    public var description: String {
        switch self {
        case .notJSON: "The geometry is not JSON."
        case .notAFeatureCollection: "The geometry is not a GeoJSON FeatureCollection."
        case .noLineString: "The geometry carries no LineString feature for the route."
        case .tooFewPoints(let count): "The route line has \(count) point(s); at least 2 are needed."
        case .malformedCoordinate(let detail): "Malformed coordinate: \(detail)."
        }
    }
}

public enum RouteGeometryDecoder {

    /// GeoJSON positions are `[longitude, latitude]`, in that order. Getting this backwards
    /// produces a route that is plausible-looking and in the wrong hemisphere, so it is asserted in
    /// the tests rather than trusted to the reader of this line.
    public static func decode(_ data: Data) throws -> RouteGeometry {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RouteGeometryError.notJSON
        }
        guard root["type"] as? String == "FeatureCollection",
              let features = root["features"] as? [[String: Any]] else {
            throw RouteGeometryError.notAFeatureCollection
        }

        var line: [Coordinate] = []
        var points: [RouteGeometry.CheckpointPoint] = []

        for feature in features {
            guard let geometry = feature["geometry"] as? [String: Any],
                  let type = geometry["type"] as? String else { continue }
            let properties = feature["properties"] as? [String: Any] ?? [:]

            switch type {
            case "LineString":
                guard let raw = geometry["coordinates"] as? [[Any]] else {
                    throw RouteGeometryError.malformedCoordinate("LineString coordinates")
                }
                line = try raw.map(coordinate(from:))
            case "Point":
                guard let raw = geometry["coordinates"] as? [Any] else {
                    throw RouteGeometryError.malformedCoordinate("Point coordinates")
                }
                points.append(RouteGeometry.CheckpointPoint(
                    checkpointID: properties["checkpointId"] as? String,
                    orderIndex: properties["orderIndex"] as? Int,
                    coordinate: try coordinate(from: raw)))
            default:
                continue
            }
        }

        guard !line.isEmpty else { throw RouteGeometryError.noLineString }
        guard line.count >= 2 else { throw RouteGeometryError.tooFewPoints(line.count) }

        // Sorted by the authored order, with unnumbered points left at the end rather than dropped:
        // a marker the file carries is a marker the writer meant.
        let sorted = points.sorted { a, b in
            (a.orderIndex ?? Int.max) < (b.orderIndex ?? Int.max)
        }
        return RouteGeometry(line: line, checkpoints: sorted)
    }

    private static func coordinate(from raw: [Any]) throws -> Coordinate {
        guard raw.count >= 2,
              let lon = (raw[0] as? NSNumber)?.doubleValue,
              let lat = (raw[1] as? NSNumber)?.doubleValue else {
            throw RouteGeometryError.malformedCoordinate("\(raw)")
        }
        return Coordinate(lat: lat, lon: lon)
    }
}
