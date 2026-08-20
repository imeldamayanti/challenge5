import ContentKit
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

    /// True once MapKit has reported a load that failed, false again once one succeeds.
    ///
    /// **Not a reachability flag** — nothing here asks whether the network is up, which is the check
    /// `AD-3` exists to prevent. This is the record of a request that was made and did not come
    /// back, and of a later one that did.
    private(set) var basemapFailed = false

    private(set) var authorization: LocationAuthorizationSnapshot = .notRequested

    private let locationProvider: (any LocationProviding)?

    init(mode: Mode = .illustrated, locationProvider: (any LocationProviding)? = nil) {
        self.mode = mode
        self.locationProvider = locationProvider
        authorization = locationProvider?.authorization ?? .notRequested
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

    // MARK: Location

    /// Asks for location the first time the map is opened, and only then.
    ///
    /// **This is a second in-context permission moment and `FR-ONB-04` names only one.** That
    /// requirement bans the prompt during onboarding and says it is asked at the first quest-start
    /// attempt; a map that draws a dot for where you are is the other honest place to ask, and a map
    /// that silently draws no dot is the bug this fixes. The deviation is recorded in
    /// `docs/prd-amendments/fr-map-01-discovery-basemap.md` and is **unsigned**.
    ///
    /// Only from `.notRequested`. A refusal is an answer, and asking again on every appearance is
    /// how an app teaches people to refuse it permanently in Settings.
    func prepareLocation() {
        guard let locationProvider else { return }

        locationProvider.onAuthorizationChange = { [weak self] snapshot in
            self?.authorization = snapshot
        }
        authorization = locationProvider.authorization

        if authorization == .notRequested {
            locationProvider.requestWhenInUseAuthorization()
        }
    }

    /// MapKit will not ask on the app's behalf, so promising a dot before there is permission for
    /// one draws nothing and explains nothing.
    var showsUserLocation: Bool {
        authorization == .whenInUse || authorization == .always
    }

    // MARK: What the screen draws

    /// The chart, whenever the mode asks for it **or** the basemap is not answering.
    ///
    /// The illustration needs no network — it is a shipped asset drawn into a rectangle, and the
    /// projection under it is arithmetic — so with no tiles it is the whole of what there is to see,
    /// and it covers the viewport by construction. `FR-OFF-03` is met by drawing it rather than by
    /// swapping the screen out.
    var showsIllustrationOverlay: Bool { mode == .illustrated || basemapFailed }

    /// Said only when the fallback actually took something away. Falling back while illustrated
    /// lands on exactly the picture the reader asked for, and announcing a loss nobody can see is
    /// worse than saying nothing.
    var showsOfflineNotice: Bool { basemapFailed && mode == .real }
}
