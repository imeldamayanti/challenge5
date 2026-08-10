import ContentKit
import DesignSystem
import SwiftUI

/// What Settings may know about location: the current authorisation, and nothing else.
///
/// `FR-ONB-04` requires the permission prompt to appear in context at the first quest-start
/// attempt, with its own explanation screen — never from a Settings row. The protocol therefore has
/// no request method, so Settings cannot ask even by accident.
public enum LocationAuthorizationSnapshot: String, Sendable, CaseIterable {
    case notRequested
    case denied
    case whenInUse
    case always
    case restricted
}

public protocol LocationAuthorizationReporting: Sendable {
    func currentAuthorization() -> LocationAuthorizationSnapshot
}

public protocol StorageUsageReporting: Sendable {
    func bytesUsedOnDevice() -> Int
}

public struct ErasureSummary: Sendable, Equatable {
    public let deletedRuns: Int
    public let deletedPhotos: Int
    public let deletedTelemetryEvents: Int
    public let clearedPreferences: Bool

    public init(deletedRuns: Int, deletedPhotos: Int, deletedTelemetryEvents: Int, clearedPreferences: Bool) {
        self.deletedRuns = deletedRuns
        self.deletedPhotos = deletedPhotos
        self.deletedTelemetryEvents = deletedTelemetryEvents
        self.clearedPreferences = clearedPreferences
    }
}

/// `FR-SET-02`. The protocol is the whole point: M5 has no Runs, photos, reflections, awards or
/// queued telemetry to delete, so the implementation here clears preferences and reports zero for
/// the rest. M6 and M7 supply the real one behind the same call, and the UI copy already tells the
/// user what this build actually holds rather than implying it holds everything.
@MainActor
public protocol LocalDataEraser {
    func eraseAllLocalData() throws -> ErasureSummary
}

@MainActor
public final class PreferencesOnlyDataEraser: LocalDataEraser {
    private let store: any AppPreferencesStore

    public init(store: any AppPreferencesStore) {
        self.store = store
    }

    public func eraseAllLocalData() throws -> ErasureSummary {
        store.removeAll()
        return ErasureSummary(
            deletedRuns: 0, deletedPhotos: 0, deletedTelemetryEvents: 0, clearedPreferences: true)
    }
}

/// The app's own container size. `FR-SET-01` asks for storage used, and the honest number is what
/// the app occupies on this device, not the content payload the validator measures.
public struct ContainerStorageReporter: StorageUsageReporting {
    public init() {}

    public func bytesUsedOnDevice() -> Int {
        let candidates = [
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
        ].compactMap { $0 }

        var total = 0
        for root in candidates {
            guard let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { continue }
            for case let url as URL in walker {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                total += values?.fileSize ?? 0
            }
        }
        return total
    }
}

// MARK: - View model

@MainActor
@Observable
public final class SettingsViewModel {

    public private(set) var language: ContentLanguage
    public private(set) var isConfirmingDelete = false
    public private(set) var lastDeletionSummary: ErasureSummary?
    public private(set) var deletionFailed = false

    private let repository: any ContentRepository
    private let store: any AppPreferencesStore
    private let locationAuthorization: any LocationAuthorizationReporting
    private let eraser: any LocalDataEraser
    private let storage: any StorageUsageReporting

    public var onLanguageChange: ((ContentLanguage) -> Void)?

    public init(
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

    public func selectLanguage(_ newValue: ContentLanguage) {
        store.preferredLanguage = newValue
        language = newValue
        onLanguageChange?(newValue)
    }

    public func title(for candidate: ContentLanguage) -> String {
        switch candidate {
        case .id: string(.settingsLanguageIndonesian)
        case .en: string(.settingsLanguageEnglish)
        }
    }

    // MARK: Location — read-only

    public var locationStatusText: String {
        switch locationAuthorization.currentAuthorization() {
        case .notRequested: string(.settingsLocationStatusNotRequested)
        case .denied: string(.settingsLocationStatusDenied)
        case .whenInUse: string(.settingsLocationStatusWhenInUse)
        case .always: string(.settingsLocationStatusAlways)
        case .restricted: string(.settingsLocationStatusRestricted)
        }
    }

    /// `FR-DISC-01` is a promise to the user as well as to the code, so it is stated here.
    public var locationExplanation: String { string(.settingsLocationExplanation) }

    public var openSystemSettingsTitle: String { string(.settingsOpenSystemSettings) }

    /// `UIApplication.openSettingsURLString` without importing UIKit into a module that has no
    /// other reason to have it.
    public var systemSettingsURL: URL? { URL(string: "app-settings:") }
    public var systemSettingsURLIsMissing: Bool { systemSettingsURL == nil }

    // MARK: Storage — FR-SET-01

    public var storageUsedText: String {
        "\(string(.settingsStorageUsed)): \(formatter.bytes(storage.bytesUsedOnDevice()))"
    }

    // MARK: Deletion — FR-SET-02

    public var deleteActionTitle: String { string(.settingsDeleteAction) }
    public var deleteConfirmTitle: String { string(.settingsDeleteConfirmTitle) }
    public var deleteConfirmBody: String { string(.settingsDeleteConfirmBody) }
    public var deleteConfirmAction: String { string(.settingsDeleteConfirmAction) }
    public var deleteCancelAction: String { string(.settingsDeleteCancel) }
    /// The honest scope for this build: preferences only. Runs, photos, reflections, awards and
    /// telemetry do not exist yet, and claiming to delete them would be a claim about nothing.
    public var deleteScopeNote: String { string(.settingsDeleteScopeNote) }
    public var deleteDoneText: String { string(.settingsDeleteDone) }

    public func requestDelete() {
        deletionFailed = false
        isConfirmingDelete = true
    }

    public func cancelDelete() {
        isConfirmingDelete = false
    }

    public func confirmDelete() {
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
    public var attributionEntries: [String] {
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

    public var attributionBody: String { string(.settingsAttributionBody) }

    public var contentVersionText: String {
        let version = (try? repository.contentBundleVersion()) ?? "—"
        return "\(string(.settingsContentVersion)): \(version)"
    }

    public var placeholderContentNotice: String { string(.settingsPlaceholderContentNotice) }

    // MARK: Reporting — FR-SET-04, NFR-CONT-07

    public var reportActionTitle: String { string(.settingsReportAction) }
    public var reportBody: String { string(.settingsReportBody) }

    /// A mail composer, prefilled with the content version so a report can be tied to a build
    /// without a round trip. Opening it is the user's action; nothing is sent by the app.
    public var reportDestination: URL? {
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

// MARK: - View

public struct SettingsView: View {
    @Environment(\.kultaraPalette) private var palette
    @Environment(\.openURL) private var openURL

    private let model: SettingsViewModel

    public init(model: SettingsViewModel) {
        self.model = model
    }

    private var language: ContentLanguage { model.language }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                languageSection
                locationSection
                storageSection
                deletionSection
                attributionSection
                reportSection
            }
            .padding(KultaraMetrics.lg)
        }
        .background(palette.paper.color)
        .navigationTitle(UIStrings.string(.settingsTitle, language))
        .confirmationDialog(
            model.deleteConfirmTitle,
            isPresented: Binding(get: { model.isConfirmingDelete },
                                 set: { if !$0 { model.cancelDelete() } }),
            titleVisibility: .visible
        ) {
            Button(model.deleteConfirmAction, role: .destructive) { model.confirmDelete() }
            Button(model.deleteCancelAction, role: .cancel) { model.cancelDelete() }
        } message: {
            Text(model.deleteConfirmBody)
        }
    }

    private var languageSection: some View {
        SettingsSection(heading: .settingsLanguageHeading, language: language) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ContentLanguage.allCases, id: \.self) { candidate in
                    Button { model.selectLanguage(candidate) } label: {
                        HStack {
                            Text(model.title(for: candidate))
                                .kultaraFont(.body)
                                .foregroundStyle(palette.ink.color)
                            Spacer()
                            // A tick *and* a label change, so selection is not colour-only
                            // (`NFR-A11Y-05`).
                            if candidate == language {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(palette.seal.color)
                            }
                        }
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(candidate == language ? [.isSelected] : [])
                    if candidate != ContentLanguage.allCases.last { KultaraRule() }
                }
            }
        }
    }

    private var locationSection: some View {
        SettingsSection(heading: .settingsLocationHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                LabelledValue(label: UIStrings.string(.settingsLocationHeading, language),
                              value: model.locationStatusText)
                Text(model.locationExplanation)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = model.systemSettingsURL {
                    Button { openURL(url) } label: {
                        Text(model.openSystemSettingsTitle)
                            .kultaraFont(.buttonLabel)
                            .foregroundStyle(palette.seal.color)
                            .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    }
                }
            }
        }
    }

    private var storageSection: some View {
        SettingsSection(heading: .settingsStorageHeading, language: language) {
            Text(model.storageUsedText)
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
        }
    }

    private var deletionSection: some View {
        SettingsSection(heading: .settingsDeleteHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                Text(model.deleteScopeNote)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
                Button { model.requestDelete() } label: {
                    Text(model.deleteActionTitle)
                        .kultaraFont(.buttonLabel)
                        .foregroundStyle(palette.seal.color)
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                }
                if model.lastDeletionSummary != nil {
                    Text(model.deleteDoneText)
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.ink.color)
                }
            }
        }
    }

    private var attributionSection: some View {
        SettingsSection(heading: .settingsAttributionHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                Text(model.attributionBody)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                KultaraRule()
                ForEach(model.attributionEntries, id: \.self) { entry in
                    Text("· \(entry)")
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.inkMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(model.contentVersionText)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                Text(model.placeholderContentNotice)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.warning.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reportSection: some View {
        SettingsSection(heading: .settingsReportHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                Text(model.reportBody)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = model.reportDestination {
                    Button { openURL(url) } label: {
                        Text(model.reportActionTitle)
                            .kultaraFont(.buttonLabel)
                            .foregroundStyle(palette.seal.color)
                            .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    }
                }
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    @Environment(\.kultaraPalette) private var palette
    let heading: UIStringKey
    let language: ContentLanguage
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            Text(UIStrings.string(heading, language))
                .kultaraFont(.sectionHeading)
                .foregroundStyle(palette.seal.color)
            KultaraCard { content }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
