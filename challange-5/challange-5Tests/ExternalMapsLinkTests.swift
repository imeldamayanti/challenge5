import ContentKit
import Foundation
import Testing

@testable import challange_5

/// `FR-MAP-04` — the Apple Maps handoff behind "Navigate There" on `223:2004`.
///
/// The interesting failures here are silent ones: a decimal comma on an Indonesian device, or a
/// place name with a space in it, both produce a URL that opens Maps at the wrong place or not at
/// all. Neither shows up in a screenshot.
struct ExternalMapsLinkTests {

    private let pemecutan = Coordinate(lat: -8.6595, lon: 115.2077)

    @Test func theHandoffAsksAppleMapsForWalkingDirectionsToTheCheckpoint() throws {
        let url = try #require(
            ExternalMapsLink.appleMapsWalkingURL(to: pemecutan, name: "Puri Agung Pemecutan"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })

        #expect(components.host == "maps.apple.com")
        #expect(items["daddr"] == "-8.659500,115.207700")
        // FR-MAP-03: walking is asked of Maps, never drawn here.
        #expect(items["dirflg"] == "w")
        #expect(items["q"] == "Puri Agung Pemecutan")
    }

    @Test func theCoordinateUsesADecimalPointRegardlessOfTheDeviceLocale() throws {
        // `String(format:)` with no locale is POSIX. If that ever changes to a localised formatter,
        // an Indonesian device emits `-8,659500` and Maps opens somewhere else entirely.
        // The one comma in `daddr` is the lat/lon separator, so the check is that each half parses
        // as a `Double` under the C locale — a decimal comma would split into three parts, or into
        // two that do not parse.
        let url = try #require(
            ExternalMapsLink.appleMapsWalkingURL(to: pemecutan, name: "Pasar Kumbasari"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let daddr = try #require(components.queryItems?.first { $0.name == "daddr" }?.value)
        let halves = daddr.split(separator: ",")

        #expect(halves.count == 2)
        #expect(halves.compactMap { Double($0) } == [-8.6595, 115.2077])
    }

    @Test func aPlaceNameWithSpacesAndPunctuationStaysAValidURL() throws {
        let url = try #require(
            ExternalMapsLink.appleMapsWalkingURL(
                to: Coordinate(lat: 0, lon: 0), name: "Pura Maospahit (Wintang Rong)"))
        #expect(url.absoluteString.contains("%20") || url.absoluteString.contains("+"))
        #expect(URL(string: url.absoluteString) != nil)
    }
}
