import ContentKit
import Foundation

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

    var onLanguageChange: ((ContentLanguage) -> Void)?

    init(
        repository: any ContentRepository,
        store: any AppPreferencesStore,
        language: ContentLanguage,
        locationAuthorization: any LocationAuthorizationReporting,
        eraser: any LocalDataEraser,
        storage: any StorageUsageReporting
    ) {
        self.repository = repository
        self.store = store
        self.language = language
        self.locationAuthorization = locationAuthorization
        self.eraser = eraser
        self.storage = storage
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

    func confirmDelete() {
        isConfirmingDelete = false
        do {
            lastDeletionSummary = try eraser.eraseAllLocalData()
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
