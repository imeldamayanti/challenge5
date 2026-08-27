import ContentKit
import CoreLocation
import Foundation
import RunEngine

/// Foreground arrival sampling, as the arrival screen needs it.
///
/// `AD-1` splits location by purpose, and this is the first half: sampling runs only while the
/// arrival screen is on screen, and stops when it goes away (`FR-ARR-02`, `NFR-BAT-04`). There is
/// no background mode here, no significant-change monitoring, and no way for a caller to leave it
/// running — `stop()` is not advisory.
@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorizationSnapshot { get }
    var onFix: ((LocationFix) -> Void)? { get set }
    var onAuthorizationChange: ((LocationAuthorizationSnapshot) -> Void)? { get set }

    /// `FR-ONB-04`, `FR-START-02` — asked in context at the first quest-start attempt, after the
    /// app has explained itself. Never from Settings, never during onboarding.
    func requestWhenInUseAuthorization()
    func start(target: Coordinate)
    func stop()
}

// MARK: - System

@MainActor
final class SystemLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private var target: Coordinate?

    var onFix: ((LocationFix) -> Void)?
    var onAuthorizationChange: ((LocationAuthorizationSnapshot) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var authorization: LocationAuthorizationSnapshot {
        Self.snapshot(manager.authorizationStatus)
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start(target: Coordinate) {
        self.target = target
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        target = nil
    }

    // MARK: CLLocationManagerDelegate
    //
    // `CLLocationManagerDelegate` is not main-actor-bound, so the callbacks are `nonisolated` and
    // hop deliberately. Only value types cross the hop: a `CLLocation` is not carried over, its
    // numbers are.

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let last = locations.last else { return }
        // CoreLocation reports an unusable fix as a negative accuracy. Passing that on would let
        // `-1 <= radius` read as a perfect fix and unlock a checkpoint from anywhere.
        guard last.horizontalAccuracy >= 0 else { return }
        let fix = LocationFix(
            coordinate: Coordinate(
                lat: last.coordinate.latitude, lon: last.coordinate.longitude),
            horizontalAccuracyM: last.horizontalAccuracy,
            timestamp: last.timestamp)

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.retune(for: fix)
            self.onFix?(fix)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let snapshot = Self.snapshot(manager.authorizationStatus)
        Task { @MainActor [weak self] in
            self?.onAuthorizationChange?(snapshot)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: any Error
    ) {
        // Nothing to report and nothing to retry: `FR-ERR-01` says the arrival screen shows live
        // status and offers the manual override after 60 s. A failed fix is simply no fix.
    }

    /// `NFR-BAT-03` — coarse accuracy while the checkpoint is far away, fine on approach. The
    /// threshold lives in `ArrivalEvaluator` so it is a tested number rather than a constant
    /// buried in a delegate callback.
    private func retune(for fix: LocationFix) {
        guard let target else { return }
        let distance = Geo.distanceM(fix.coordinate, target)
        let desired = ArrivalEvaluator.desiredAccuracyM(forDistanceM: distance)
        manager.desiredAccuracy = desired >= 100
            ? kCLLocationAccuracyHundredMeters
            : kCLLocationAccuracyNearestTenMeters
    }

    nonisolated static func snapshot(_ status: CLAuthorizationStatus) -> LocationAuthorizationSnapshot {
        switch status {
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        case .authorizedWhenInUse: .whenInUse
        case .authorizedAlways: .always
        @unknown default: .notRequested
        }
    }
}

// MARK: - Developer simulation

#if KULTARA_DEV_TOOLS
/// Places the walker exactly where the next checkpoint is, so the quest loop can be walked from a
/// desk. Debug and TestFlight builds only — the whole type is behind `#if KULTARA_DEV_TOOLS`, which
/// the app target sets on Debug and Release, and the switch that reaches it additionally asks
/// `DeveloperToolsAvailability.isEnabled`, which is `false` in an App Store install. So an App Store
/// build reaches none of this and `FR-START-08` cannot be walked around there.
///
/// It is a `LocationProviding` rather than a shortcut around the gate on purpose: the arrival rule
/// in `ArrivalEvaluator` still runs, still checks radius and accuracy, and still records
/// `arrivalMethod = .gps`. What is simulated is the position, not the decision — so what gets
/// tested here is the same code path a walker in Denpasar takes.
@MainActor
final class SimulatedLocationProvider: LocationProviding {

    var onFix: ((LocationFix) -> Void)?
    var onAuthorizationChange: ((LocationAuthorizationSnapshot) -> Void)?
    var authorization: LocationAuthorizationSnapshot { .whenInUse }

    /// Metres of jitter applied to the simulated position, so the arrival screen shows a distance
    /// counting down rather than a suspiciously perfect zero.
    private let accuracyM: Double
    private var task: Task<Void, Never>?

    init(accuracyM: Double = 8) {
        self.accuracyM = accuracyM
    }

    func requestWhenInUseAuthorization() {
        onAuthorizationChange?(.whenInUse)
    }

    func start(target: Coordinate) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            // A beat before the fix, so the arrival screen's "searching" state is actually seen
            // and can be looked at while testing.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self.onFix?(LocationFix(
                coordinate: target, horizontalAccuracyM: self.accuracyM, timestamp: Date()))
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

/// The developer switch that decides which provider the app uses.
///
/// Stored in `UserDefaults` rather than in `AppPreferencesStore`: this is not a user preference and
/// must not appear in the schema that ships or get synced in v2.
///
/// The getter answers `false` whatever is stored unless `DeveloperToolsAvailability.isEnabled`, so a
/// flag left set by a TestFlight build cannot carry into an App Store one on the same device.
@MainActor
enum DeveloperPreferences {

    /// `nonisolated` so `@AppStorage` can name it in a property initializer, which does not run on
    /// the main actor.
    nonisolated static let simulateArrivalKey = "kultara.debug.simulateArrivalAnywhere"

    static var simulatesArrivalAnywhere: Bool {
        get {
            DeveloperToolsAvailability.isEnabled
                && UserDefaults.standard.bool(forKey: simulateArrivalKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: simulateArrivalKey) }
    }
}

/// Chooses between the real radios and the simulator at the moment sampling starts, so flipping the
/// switch in Settings takes effect on the next checkpoint without relaunching.
@MainActor
final class DeveloperSwitchableLocationProvider: LocationProviding {

    private let system: any LocationProviding
    private let simulated: any LocationProviding
    private var active: (any LocationProviding)?

    var onFix: ((LocationFix) -> Void)? {
        didSet {
            system.onFix = onFix
            simulated.onFix = onFix
        }
    }

    var onAuthorizationChange: ((LocationAuthorizationSnapshot) -> Void)? {
        didSet {
            system.onAuthorizationChange = onAuthorizationChange
            simulated.onAuthorizationChange = onAuthorizationChange
        }
    }

    init(
        system: any LocationProviding,
        simulated: any LocationProviding = SimulatedLocationProvider()
    ) {
        self.system = system
        self.simulated = simulated
    }

    var authorization: LocationAuthorizationSnapshot {
        DeveloperPreferences.simulatesArrivalAnywhere ? .whenInUse : system.authorization
    }

    func requestWhenInUseAuthorization() {
        guard !DeveloperPreferences.simulatesArrivalAnywhere else {
            onAuthorizationChange?(.whenInUse)
            return
        }
        system.requestWhenInUseAuthorization()
    }

    func start(target: Coordinate) {
        let chosen: any LocationProviding =
            DeveloperPreferences.simulatesArrivalAnywhere ? simulated : system
        active = chosen
        chosen.start(target: target)
    }

    func stop() {
        active?.stop()
        active = nil
    }
}
#endif
