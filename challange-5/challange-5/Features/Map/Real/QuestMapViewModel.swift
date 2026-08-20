import Foundation
import Observation

/// Which ground the discovery map is standing on, and whether the live one is answering.
///
/// The two modes are one map with two skins, not two screens: the camera, the markers and the
/// user's own position are shared, so the wand swaps what is underneath and moves nothing else.
@MainActor
@Observable
final class QuestMapViewModel {

    enum Mode: String, Sendable, CaseIterable {
        /// `275:2309` — the chart drawn over the live basemap.
        case illustrated
        /// `276:2520` — the basemap alone, with the same markers on it.
        case real
    }

    /// The map opens illustrated. That is the app's own map, and the real one is the alternative it
    /// offers — not the other way round.
    private(set) var mode: Mode = .illustrated

    /// True once MapKit has reported a load that failed. **Not a reachability flag** — nothing here
    /// asks whether the network is up, which is the check `AD-3` exists to prevent. This is the
    /// record of a request that was made and did not come back.
    private(set) var basemapFailed = false

    init(mode: Mode = .illustrated) {
        self.mode = mode
    }

    func toggleMode() {
        mode = mode == .illustrated ? .real : .illustrated
    }

    func basemapDidFail() {
        basemapFailed = true
    }

    func basemapDidLoad() {
        basemapFailed = false
    }

    /// What the screen draws. With no basemap there is nothing for the chart to stand on, so the
    /// screen falls back to the illustrated surface that never needed one — `RegionMapView`, which
    /// reads the authored `mapPoint`s and has always worked in airplane mode (`FR-OFF-03`).
    var usesOfflineSurface: Bool { basemapFailed }

    var showsIllustrationOverlay: Bool { mode == .illustrated }

    /// Said only when the fallback actually took something away. Falling back while illustrated
    /// lands on very nearly the same picture, and announcing a loss the reader cannot see is worse
    /// than saying nothing.
    var showsOfflineNotice: Bool { basemapFailed && mode == .real }
}
