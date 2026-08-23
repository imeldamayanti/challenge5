import ContentKit
import Foundation
import UIStringsKit

@MainActor
@Observable
final class SettingsViewModel {

    private(set) var language: ContentLanguage
    private(set) var isConfirmingDelete = false
    private(set) var lastDeletionSummary: ErasureSummary?
    private(set) var deletionFailed = false

    private let repository: any ContentRepository
    private let store: any AppPreferencesStore
    private let locationAuthorization: any LocationAuthorizationReporting
    private let eraser: any LocalDataEraser
    private let storage: any StorageUsageReporting
    private let proximityMonitor: any ProximityMonitoring
    /// Bumped after every toggle and every async permission check, so the `@Observable` machinery
    /// has a tracked property to notice — `proximityMonitor` itself is a plain reference, and
    /// reading through it does not register as a dependency on its own.
    private(set) var nearbyAlertsRevision = 0

    var onLanguageChange: ((ContentLanguage) -> Void)?

    init(
        repository: any ContentRepository,
        store: any AppPreferencesStore,
        language: ContentLanguage,
        locationAuthorization: any LocationAuthorizationReporting,
        eraser: any LocalDataEraser,
        storage: any StorageUsageReporting,
        proximityMonitor: any ProximityMonitoring
    ) {
        self.repository = repository
        self.store = store
        self.language = language
        self.locationAuthorization = locationAuthorization
        self.eraser = eraser
        self.storage = storage
        self.proximityMonitor = proximityMonitor
    }

    private var formatter: ContentFormatter { ContentFormatter(language: language) }

    private func string(_ key: UIStringKey) -> String { UIStrings.string(key, language) }

    // MARK: Language — FR-SET-01, FR-ONB-05

    func selectLanguage(_ newValue: ContentLanguage) {
        store.preferredLanguage = newValue
        language = newValue
        onLanguageChange?(newValue)
    }

    func title(for candidate: ContentLanguage) -> String {
        switch candidate {
        case .id: string(.settingsLanguageIndonesian)
        case .en: string(.settingsLanguageEnglish)
        }
    }

    // MARK: Location — read-only

    var locationStatusText: String {
        switch locationAuthorization.currentAuthorization() {
        case .notRequested: string(.settingsLocationStatusNotRequested)
        case .denied: string(.settingsLocationStatusDenied)
        case .whenInUse: string(.settingsLocationStatusWhenInUse)
        case .always: string(.settingsLocationStatusAlways)
        case .restricted: string(.settingsLocationStatusRestricted)
        }
    }

    /// `FR-DISC-01` is a promise to the user as well as to the code, so it is stated here.
    var locationExplanation: String { string(.settingsLocationExplanation) }

    var openSystemSettingsTitle: String { string(.settingsOpenSystemSettings) }

    /// `UIApplication.openSettingsURLString` without importing UIKit into a module that has no
    /// other reason to have it.
    var systemSettingsURL: URL? { URL(string: "app-settings:") }
    var systemSettingsURLIsMissing: Bool { systemSettingsURL == nil }

    // MARK: Nearby alerts — FR-PROX-03, s3

    var nearbyAlertsHeading: String { string(.settingsNearbyAlertsHeading) }
    var nearbyAlertsToggleTitle: String { string(.settingsNearbyAlertsToggle) }
    /// Shown unconditionally, before the toggle is ever touched — this text *is* `FR-PROX-03`'s
    /// in-app explanation; there is no separate screen.
    var nearbyAlertsExplanation: String { string(.settingsNearbyAlertsExplanation) }

    var nearbyAlertsEnabled: Bool {
        _ = nearbyAlertsRevision
        return proximityMonitor.isEnabled
    }

    /// Non-nil once the toggle is on and iOS has settled on something short of `Always` —
    /// `When In Use`, denied, or restricted (`s3` §3). `nil` while a fresh request is still in
    /// flight, so the warning does not flash the instant the toggle is tapped.
    var nearbyAlertsNeedsAlwaysText: String? {
        _ = nearbyAlertsRevision
        guard proximityMonitor.isEnabled else { return nil }
        switch proximityMonitor.authorization {
        case .whenInUse, .denied, .restricted: return string(.settingsNearbyAlertsNeedsAlways)
        case .always, .notRequested: return nil
        }
    }

    /// Non-nil once `Always` is granted but notifications are not — regions would register for
    /// nothing without them (`s3` §3).
    var nearbyAlertsNeedsNotificationsText: String? {
        _ = nearbyAlertsRevision
        guard proximityMonitor.isEnabled,
              proximityMonitor.authorization == .always,
              !proximityMonitor.notificationsAuthorized
        else { return nil }
        return string(.settingsNearbyAlertsNeedsNotifications)
    }

    func setNearbyAlertsEnabled(_ newValue: Bool) {
        if newValue {
            proximityMonitor.enable()
        } else {
            proximityMonitor.disable()
        }
        nearbyAlertsRevision += 1
    }

    /// Called from the screen's `onAppear` — permission state changes out from under the app
    /// (a trip to system Settings and back), and there is no push channel for it.
    func refreshNearbyAlertsStatus() {
        proximityMonitor.refreshNotificationStatus { [weak self] in self?.nearbyAlertsRevision += 1 }
    }

    #if DEBUG
    /// "Simulate passing a place" (`s3` §8) — every sidequest in the discovery set, oldest-content
    /// order, the same list the nearby browse path uses.
    var devSideQuestOptions: [(id: String, title: String)] {
        ((try? repository.sideQuests(suppressingSideQuestIDs: [], suppressingPlaceIDs: [])) ?? [])
            .map { (id: $0.id, title: $0.title.value(for: language)) }
    }

    func simulateSideQuestPassing(_ sideQuestID: String) {
        proximityMonitor.simulateEntry(sideQuestID: sideQuestID)
    }

    func simulateNearbyWhileOpen(_ sideQuestID: String) {
        proximityMonitor.simulateNearbyWhileOpen(sideQuestID: sideQuestID)
    }

    func fireHardcodedTestNotification() {
        proximityMonitor.fireHardcodedTestNotification()
    }
    #endif

    // MARK: Storage — FR-SET-01

    var storageUsedText: String {
        "\(string(.settingsStorageUsed)): \(formatter.bytes(storage.bytesUsedOnDevice()))"
    }

    // MARK: Deletion — FR-SET-02

    var deleteActionTitle: String { string(.settingsDeleteAction) }
    var deleteConfirmTitle: String { string(.settingsDeleteConfirmTitle) }
    var deleteConfirmBody: String { string(.settingsDeleteConfirmBody) }
    var deleteConfirmAction: String { string(.settingsDeleteConfirmAction) }
    var deleteCancelAction: String { string(.settingsDeleteCancel) }
    /// The honest scope for this build: preferences only. Runs, photos, reflections, awards and
    /// telemetry do not exist yet, and claiming to delete them would be a claim about nothing.
    var deleteScopeNote: String { string(.settingsDeleteScopeNote) }
    var deleteDoneText: String { string(.settingsDeleteDone) }

    func requestDelete() {
        deletionFailed = false
        isConfirmingDelete = true
    }

    func cancelDelete() {
        isConfirmingDelete = false
    }

    func confirmDelete() async {
        isConfirmingDelete = false
        do {
            lastDeletionSummary = try await eraser.eraseAllLocalData()
            // The eraser owns whatever store it was given; preferences are cleared here as well
            // because a language override that survives "delete all local data" is a surprise.
            store.removeAll()
        } catch {
            deletionFailed = true
            lastDeletionSummary = nil
        }
    }

    // MARK: Attribution — FR-SET-03, NFR-GOV-05

    /// Every citation the shipped content rests on, deduplicated and ordered. Consent records are
    /// not shipped (`schema.md` §A.1), so what is credited here is the sources, which is what
    /// `NFR-GOV-05` asks for: the organisations, juru kunci, pemangku and storytellers behind the
    /// claims.
    var attributionEntries: [String] {
        guard let places = try? repository.manifest().places else { return [] }
        var seen: Set<String> = []
        var entries: [String] = []
        for placeID in places {
            guard let place = (try? repository.place(id: placeID)) ?? nil else { continue }
            for source in place.sources where seen.insert(source.citation).inserted {
                entries.append(source.citation)
            }
        }
        return entries
    }

    var attributionBody: String { string(.settingsAttributionBody) }

    var contentVersionText: String {
        let version = (try? repository.contentBundleVersion()) ?? "—"
        return "\(string(.settingsContentVersion)): \(version)"
    }

    var placeholderContentNotice: String { string(.settingsPlaceholderContentNotice) }

    // MARK: Reporting — FR-SET-04, NFR-CONT-07

    var reportActionTitle: String { string(.settingsReportAction) }
    var reportBody: String { string(.settingsReportBody) }

    /// A mail composer, prefilled with the content version so a report can be tied to a build
    /// without a round trip. Opening it is the user's action; nothing is sent by the app.
    var reportDestination: URL? {
        let version = (try? repository.contentBundleVersion()) ?? "unknown"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "koreksi@kultara.example"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Kultara — content \(version)"),
        ]
        return components.url
    }
}
