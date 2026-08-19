import ContentKit
import Foundation

/// The one-tap handoff to Apple Maps walking directions — `FR-MAP-04`, and the "Navigate There"
/// pill on the Hisplora frame `223:2004`.
///
/// Three constraints shape this into a URL builder rather than the obvious `MKMapItem.openMaps`:
///
/// - **No MapKit in the app target.** `FR-MAP-01`/`FR-OFF-03` rule out live map tiles, and
///   `PermissionCallBoundaryTests.theAppDoesNotDrawMapsFromLiveTiles` holds that by banning
///   `import MapKit` outright. `MKMapItem` would need the import, so the handoff is a URL the
///   system opens instead.
/// - **`FR-MAP-03`.** Turn-by-turn is not something this app delivers; it is something Apple Maps
///   delivers after the walker has deliberately left. `dirflg=w` asks Maps for the walking mode,
///   which is a request to another app, not navigation drawn here.
/// - **`AD-3`.** Nothing on the arrival screen may depend on this. The button is an extra way out
///   for a walker who wants it; the clue, the route canvas, the distance and the manual override
///   are all still there and all still work with the radio off.
///
/// A pure function over a `Coordinate` and a name, so it is checkable without a simulator and
/// without opening anything.
enum ExternalMapsLink {

    /// A `maps.apple.com` walking-directions link to `coordinate`, labelled `name`.
    ///
    /// `daddr` carries the destination — coordinates rather than an address string, because the
    /// authored address is localised prose and the coordinate is what the arrival rule already
    /// trusts. `q` only names the pin. Returns `nil` if the components cannot form a URL, which
    /// keeps the caller honest about hiding the control rather than shipping a dead button.
    static func appleMapsWalkingURL(to coordinate: Coordinate, name: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        // Six decimals is ~0.1 m — well inside the tightest arrival radius, and short enough that
        // the URL stays readable in a share sheet. `String(format:)` with no locale is POSIX, so a
        // device set to Indonesian does not emit a decimal comma here.
        let destination = String(format: "%.6f,%.6f", coordinate.lat, coordinate.lon)
        components.queryItems = [
            URLQueryItem(name: "daddr", value: destination),
            // Walking. `FR-MAP-03` — asked of Maps, never drawn by us.
            URLQueryItem(name: "dirflg", value: "w"),
            URLQueryItem(name: "q", value: name),
        ]
        return components.url
    }
}
