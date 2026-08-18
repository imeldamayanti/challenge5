import ContentKit
import CoreLocation
import Foundation
import RunEngine
import UIKit
import UserNotifications

/// The background half of `AD-1`'s location split — region monitoring plus the notification it
/// produces, for the sidequests a walker has not yet completed (`s3`).
///
/// Reuses `ProximityGate` and `RegionBudget` unmodified: both were built pure and tested in `s2`
/// for exactly this reason (`s0` D10). This type is the adapter — hardware on one side, a decided
/// fact on the other, the same shape that keeps `ArrivalEvaluator` testable.
///
/// **Scope.** `system-design.md` §6.2's `registerRegions()` candidates are quest starts *and*
/// sidequests. Quest-start monitoring (`FR-PROX-01…15`) is a separate, already-accepted v1
/// requirement that nothing in this codebase implements yet, and building it is outside a plan
/// folder titled "sidequest". This service therefore monitors sidequests only, drawn from
/// `SideQuestEngine.monitoringCandidates()`; wiring quest starts into the same budget is later
/// work, not a silent omission.
@MainActor
protocol ProximityMonitoring: AnyObject {
    /// The user's own switch (`FR-PROX-03`), independent of whether iOS has actually granted
    /// `Always`.
    var isEnabled: Bool { get }
    var authorization: LocationAuthorizationSnapshot { get }
    /// Best-effort cache of the system notification permission, refreshed by
    /// `refreshNotificationStatus(completion:)`. Reading it does not itself ask iOS anything —
    /// `Settings` must never request a permission a walker did not just ask for.
    var notificationsAuthorized: Bool { get }

    /// `FR-PROX-03` — the plain-language explanation is shown by the caller *before* this runs.
    func requestAlwaysAuthorization()
    /// Turns the feature on, requests `Always` then notification permission in that order, and
    /// registers regions once both land.
    func enable()
    /// `FR-PROX-13` — deregisters every region immediately.
    func disable()
    /// Recomputed on launch, on toggle, on completion, and after a suppression update
    /// (`system-design.md` §6.2). Safe to call repeatedly: it always clears every monitored region
    /// first, so re-registering the same set costs a little battery and drops nothing.
    func refreshRegions()
    /// Re-reads notification authorization from the system; `completion` runs once the async check
    /// lands, on the main actor, so a caller can force its own UI to redraw.
    func refreshNotificationStatus(completion: @escaping @MainActor () -> Void)
    /// `FR-SET-02` — the erasure half. Returns how many rows went.
    @discardableResult func deleteAllAlerts() throws -> Int

    /// The region fired while the app was already open, so a sheet is the right shape rather than
    /// a system notification (`s3` §5). Also the target of the debug "simulate passing a place"
    /// tool and of a real notification tap, both of which resolve to the same call.
    var onSideQuestNearby: ((String) -> Void)? { get set }

    #if DEBUG
    /// "Simulate passing a place" (`s3` §8). The input — being in the region — is simulated; the
    /// decision is not: `ProximityGate` still runs, quiet hours still block, the daily cap still
    /// counts. Debug builds only, and the whole conformance is one `#if DEBUG` case among several
    /// that a Release build simply does not compile.
    func simulateEntry(sideQuestID: String)
    /// A pure OS-pipeline check: fixed title/body, no content lookup, no `ProximityGate`, no
    /// location authorization at all. If this doesn't appear, nothing in this file can be the
    /// cause — the answer is in iOS Settings → Notifications for this app.
    func fireHardcodedTestNotification()
    #endif
}

// MARK: - System

@MainActor
final class SystemProximityMonitor: NSObject, ProximityMonitoring, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    private let repository: any ContentRepository
    private let sideQuestEngine: SideQuestEngine
    private let runStore: any RunStore
    private let preferences: any AppPreferencesStore
    private let alertStore: any ProximityAlertStore
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    private(set) var notificationsAuthorized = false
    var onSideQuestNearby: ((String) -> Void)?

    init(
        repository: any ContentRepository,
        sideQuestEngine: SideQuestEngine,
        runStore: any RunStore,
        preferences: any AppPreferencesStore,
        alertStore: any ProximityAlertStore,
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.repository = repository
        self.sideQuestEngine = sideQuestEngine
        self.runStore = runStore
        self.preferences = preferences
        self.alertStore = alertStore
        self.now = now
        self.calendar = calendar
        super.init()
        manager.delegate = self
    }

    var isEnabled: Bool { preferences.nearbyAlertsEnabled }

    var authorization: LocationAuthorizationSnapshot {
        SystemLocationProvider.snapshot(manager.authorizationStatus)
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func enable() {
        preferences.nearbyAlertsEnabled = true
        switch manager.authorizationStatus {
        case .authorizedAlways:
            ensureNotificationsThenRefresh()
        case .notDetermined, .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            // Denied or restricted: `FR-PROX-05` — the toggle stays on but nothing registers, and
            // `Settings` reads `authorization` to say so and offer the system Settings path.
            break
        }
    }

    func disable() {
        preferences.nearbyAlertsEnabled = false
        refreshRegions()
    }

    func refreshRegions() {
        for region in manager.monitoredRegions { manager.stopMonitoring(for: region) }
        guard isEnabled, authorization == .always else { return }

        let candidates = (try? sideQuestEngine.monitoringCandidates(
            suppressingSideQuestIDs: [], suppressingPlaceIDs: [])) ?? []
        let coordinate = manager.location.map {
            Coordinate(lat: $0.coordinate.latitude, lon: $0.coordinate.longitude)
        }
        let selected = RegionBudget.select(candidates: candidates, near: coordinate)

        for candidate in selected {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(
                    latitude: candidate.coordinate.lat, longitude: candidate.coordinate.lon),
                radius: Double(candidate.radiusM),
                identifier: candidate.id)
            // `NFR-PRIV-09` — an exit tells the server nothing useful and would only grow the
            // alert log for no reason the requirement asks for.
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
    }

    func refreshNotificationStatus(completion: @escaping @MainActor () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let authorized = Self.isAuthorized(settings.authorizationStatus)
            Task { @MainActor in
                self?.notificationsAuthorized = authorized
                completion()
            }
        }
    }

    @discardableResult func deleteAllAlerts() throws -> Int {
        try alertStore.deleteAll()
    }

    #if DEBUG
    func simulateEntry(sideQuestID: String) {
        // Tapping this button *is* asking to see the actual notification — the foreground/sheet
        // path is already exercised for real whenever a region fires while the app is open, so
        // forcing the notification here is what makes the button useful standing still.
        handleRegionEntered(identifier: sideQuestID, forceNotification: true)
    }

    func fireHardcodedTestNotification() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            let content = UNMutableNotificationContent()
            content.title = "Test notification"
            content.body = "Kalau ini muncul, jalur notifikasi OS-nya beres — masalahnya bukan di kode."
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "dev-hardcoded-test", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { addError in
                if let error { print("[dev] notification auth error: \(error)") }
                if let addError { print("[dev] notification add error: \(addError)") }
                print("[dev] notification authorized: \(granted), request added")
            }
        }
    }
    #endif

    // MARK: CLLocationManagerDelegate
    //
    // Not main-actor-bound, so callbacks hop deliberately — the same shape `SystemLocationProvider`
    // already uses. Only the region identifier and the authorization enum cross the hop.

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor [weak self] in
            self?.handleRegionEntered(identifier: identifier)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self, self.isEnabled else { return }
            if status == .authorizedAlways {
                self.ensureNotificationsThenRefresh()
            } else {
                // Fell back to `When In Use`, or was denied: nothing may stay registered.
                self.refreshRegions()
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        monitoringDidFailFor region: CLRegion?,
        withError error: any Error
    ) {
        // Nothing to report and nothing to retry: the next `refreshRegions()` call — launch,
        // toggle, or completion — tries again.
    }

    // MARK: - The decision

    /// `didEnterRegion`'s body, and the debug simulator's. The trigger differs; the rule does not.
    ///
    /// `forceNotification` also skips the `isEnabled`/`Always` gate: a real region event can only
    /// fire once both are true, so the gate is meaningful there. The debug button is an explicit
    /// "show me the notification" request — making it depend on the same slow, often-never-granted
    /// `Always` upgrade iOS does in its own time would defeat the point of having it.
    private func handleRegionEntered(identifier: String, forceNotification: Bool = false) {
        guard forceNotification || (isEnabled && authorization == .always) else { return }

        // `forceNotification` also skips the whole `ProximityGate` decision — active Run, already
        // completed, quiet hours, cooldown, daily cap. Those are meaningful for a real region event;
        // for "prove a notification can appear right now" they are just more ways to get nothing
        // and no explanation why.
        if !forceNotification {
            let hasActiveRun = ((try? runStore.mostRecentActiveRun()) ?? nil) != nil
            let isCompleted = ((try? sideQuestEngine.record(sideQuestID: identifier)) ?? nil)?
                .isCompleted ?? false
            let alerts = (try? alertStore.alerts()) ?? []
            let decision = ProximityGate.decide(
                targetID: identifier, now: now(), calendar: calendar, alerts: alerts,
                hasActiveRun: hasActiveRun, isTargetCompleted: isCompleted,
                limits: Self.limits(for: identifier))
            guard decision.isAllowed else { return }
        }

        guard let sideQuest = ((try? repository.sideQuest(id: identifier)) ?? nil),
              let place = ((try? repository.place(id: sideQuest.placeId)) ?? nil)
        else { return }

        // `NFR-PRIV-09` — recorded whether or not the walker ever sees it, because the row exists
        // to hold the rate limit, not to log an interaction.
        try? alertStore.append(ProximityAlert(targetID: identifier, shownAt: now()))

        // `FR-ONB-05` — the app's language, not the device's; it may differ.
        let language = LanguageResolver.resolve(override: preferences.preferredLanguage)

        if UIApplication.shared.applicationState == .active && !forceNotification {
            onSideQuestNearby?(identifier)
        } else {
            postNotification(
                sideQuestID: identifier,
                title: place.nameOfficial.value(for: language),
                body: sideQuest.synopsis.value(for: language))
        }
    }

    #if DEBUG
    /// A minute-scale cooldown for the local `park23` dev test target only, so "Simulate passing a
    /// place" — or repeatedly leaving and re-entering the real 50 m radius — can be tapped over and
    /// over while iterating on the flow. Every other target, real or test, keeps `Limits()`'s normal
    /// 24 h cooldown and 3-per-day cap (`FR-PROX-09`) — this never loosens rate limiting for content
    /// that ships.
    private static func limits(for targetID: String) -> ProximityGate.Limits {
        guard targetID == "sq-park23" else { return ProximityGate.Limits() }
        return ProximityGate.Limits(
            quietFrom: TimeOfDay(hour: 0, minute: 0), quietUntil: TimeOfDay(hour: 0, minute: 0),
            perTargetCooldown: 60, maxPerDay: .max)
    }
    #else
    private static func limits(for targetID: String) -> ProximityGate.Limits { ProximityGate.Limits() }
    #endif

    private func postNotification(sideQuestID: String, title: String, body: String) {
        // `requestAuthorization` only shows a dialog the first time a decision hasn't been made;
        // once granted or denied it just reports that back. Asking here — rather than trusting
        // `enable()` already ran it — means the debug "simulate passing a place" button (which
        // skips the location-authorization gate entirely, `forceNotification`) still gets a real
        // chance at notification permission even when `Always` location was never granted.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            // `userInfo` carries the id and nothing else — no coordinates in a payload (`FR-PROX-15`).
            content.userInfo = ["sideQuestID": sideQuestID]
            content.sound = .default
            // `trigger: nil` — delivered immediately, this is a live region-entry event, not a
            // scheduled reminder.
            let request = UNNotificationRequest(identifier: sideQuestID, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func ensureNotificationsThenRefresh() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Task { @MainActor [weak self] in
                    self?.notificationsAuthorized = true
                    self?.refreshRegions()
                }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound]
                ) { granted, _ in
                    Task { @MainActor [weak self] in
                        self?.notificationsAuthorized = granted
                        if granted { self?.refreshRegions() }
                    }
                }
            default:
                // Denied: `Settings` reports it and offers the system Settings path.
                Task { @MainActor [weak self] in self?.notificationsAuthorized = false }
            }
        }
    }

    private static func isAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied: false
        @unknown default: false
        }
    }
}

// MARK: - ProximityAlertStore

/// The write side of `ProximityAlert` rows — a protocol for the same reason every other store in
/// this codebase is one.
@MainActor
protocol ProximityAlertStore: AnyObject {
    func alerts() throws -> [ProximityAlert]
    func append(_ alert: ProximityAlert) throws
    @discardableResult func deleteAll() throws -> Int
}

@MainActor
final class InMemoryProximityAlertStore: ProximityAlertStore {
    private var storage: [ProximityAlert] = []

    init(_ seed: [ProximityAlert] = []) { storage = seed }

    func alerts() throws -> [ProximityAlert] { storage }
    func append(_ alert: ProximityAlert) throws { storage.append(alert) }

    @discardableResult func deleteAll() throws -> Int {
        let count = storage.count
        storage.removeAll()
        return count
    }
}

/// One JSON document under `Application Support/Kultara/proximity-alerts.json` — not one file per
/// row, because these rows are pruned at 7 days and never number more than a handful (`s3` §2).
///
/// Non-throwing, deliberately unlike `FileRunStore`: the alerts this holds exist only to enforce a
/// rate limit on an opt-in feature. A directory that cannot be created here costs that rate limit,
/// not the app's launch (`NFR-REL-04`).
@MainActor
final class FileProximityAlertStore: ProximityAlertStore {

    private let url: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cache: [ProximityAlert]

    static func defaultURL() -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("Kultara/proximity-alerts.json")
    }

    /// Loading happens in a `static` function, not inline, so the closure that decodes the file
    /// never closes over `self` before every stored property is set.
    private static func load(from url: URL, decoder: JSONDecoder) -> [ProximityAlert] {
        guard let data = FileManager.default.contents(atPath: url.path) else { return [] }
        return (try? decoder.decode([ProximityAlert].self, from: data)) ?? []
    }

    init(url: URL = FileProximityAlertStore.defaultURL(), now: @escaping () -> Date = { Date() }) {
        self.url = url
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.encoder = encoder
        self.decoder = decoder

        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let loaded = Self.load(from: url, decoder: decoder)
        // Pruned on load, per `s3` §2 — nobody needs an alert row older than the cooldown it
        // exists to enforce.
        let cutoff = now().addingTimeInterval(-7 * 24 * 3600)
        cache = loaded.filter { $0.shownAt >= cutoff }
        if cache.count != loaded.count { try? write() }
    }

    func alerts() throws -> [ProximityAlert] { cache }

    func append(_ alert: ProximityAlert) throws {
        cache.append(alert)
        try write()
    }

    @discardableResult func deleteAll() throws -> Int {
        let count = cache.count
        cache = []
        try write()
        return count
    }

    private func write() throws {
        let data = try encoder.encode(cache)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - Notification tap

/// Routes a tapped notification's `sideQuestID` back into the app. Held by `challange_5App`, which
/// is the only owner `UNUserNotificationCenter.current().delegate` needs — a delegate not retained
/// by something is a delegate iOS silently drops.
final class SideQuestNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    var onTap: (@MainActor (String) -> Void)?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let sideQuestID = response.notification.request.content.userInfo["sideQuestID"] as? String {
            Task { @MainActor [onTap] in onTap?(sideQuestID) }
        }
        completionHandler()
    }

    /// `FR-PROX-06`'s local notification still needs to show while the app is foregrounded — the
    /// service only skips *scheduling* one in that case (`s3` §5); this covers the rare case
    /// where a region fires the instant the app resumes and the `applicationState` check in
    /// `SystemProximityMonitor` already read `.active`.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
