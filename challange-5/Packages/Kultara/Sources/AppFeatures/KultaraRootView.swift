import ContentKit
import CoreLocation
import DesignSystem
import SwiftUI

/// Reads the current authorisation without ever asking for it. Constructing a `CLLocationManager`
/// and reading `authorizationStatus` presents no prompt; `FR-ONB-04` reserves the prompt for the
/// first quest-start attempt, which M5 does not build.
public struct SystemLocationAuthorizationReporter: LocationAuthorizationReporting {
    public init() {}

    public func currentAuthorization() -> LocationAuthorizationSnapshot {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        case .authorizedWhenInUse: .whenInUse
        case .authorizedAlways: .always
        @unknown default: .notRequested
        }
    }
}

/// Everything the app needs, assembled once. Content is read-only and bundled; preferences are the
/// only writable store in M5.
@MainActor
public struct KultaraEnvironment {
    public let repository: any ContentRepository
    public let preferences: any AppPreferencesStore
    public let locationAuthorization: any LocationAuthorizationReporting
    public let storage: any StorageUsageReporting

    public init(
        repository: any ContentRepository,
        preferences: any AppPreferencesStore,
        locationAuthorization: any LocationAuthorizationReporting = SystemLocationAuthorizationReporter(),
        storage: any StorageUsageReporting = ContainerStorageReporter()
    ) {
        self.repository = repository
        self.preferences = preferences
        self.locationAuthorization = locationAuthorization
        self.storage = storage
    }

    /// The shipped configuration. Fails only if the content resources are missing from the bundle,
    /// which is a build problem rather than a runtime one.
    public static func bundled(defaults: UserDefaults = .standard) throws -> KultaraEnvironment {
        KultaraEnvironment(
            repository: try BundledContentRepository(),
            preferences: UserDefaultsAppPreferencesStore(defaults: defaults))
    }
}

public struct KultaraRootView: View {

    private let environment: KultaraEnvironment

    @State private var language: ContentLanguage
    @State private var showsOnboarding: Bool
    @State private var selectedQuestID: String?
    @State private var showsSettings = false

    public init(environment: KultaraEnvironment) {
        self.environment = environment
        _language = State(initialValue: LanguageResolver.resolve(
            override: environment.preferences.preferredLanguage))
        _showsOnboarding = State(initialValue: OnboardingGate.shouldPresentOnboarding(
            store: environment.preferences))
    }

    public var body: some View {
        KultaraThemeProvider {
            if showsOnboarding {
                OnboardingView(
                    store: environment.preferences,
                    language: language,
                    onFinish: { showsOnboarding = false })
            } else {
                browser
            }
        }
    }

    private var browser: some View {
        NavigationStack {
            QuestListView(
                // Rebuilt when the language changes: every string in the list is resolved at
                // construction, so the identity of the view model *is* the language.
                model: QuestListViewModel(repository: environment.repository, language: language),
                onSelect: { selectedQuestID = $0 },
                onOpenSettings: { showsSettings = true })
                .navigationDestination(isPresented: Binding(
                    get: { selectedQuestID != nil },
                    set: { if !$0 { selectedQuestID = nil } })
                ) {
                    previewDestination
                }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack { settingsDestination }
        }
    }

    @ViewBuilder private var previewDestination: some View {
        if let questID = selectedQuestID,
           let model = QuestPreviewViewModel(
            repository: environment.repository, questID: questID, language: language) {
            KultaraThemeProvider { QuestPreviewView(model: model) }
        } else {
            // A quest that cannot be built is not a blank screen; the list stays reachable.
            EmptyView()
        }
    }

    private var settingsDestination: some View {
        let model = SettingsViewModel(
            repository: environment.repository,
            store: environment.preferences,
            language: language,
            locationAuthorization: environment.locationAuthorization,
            eraser: PreferencesOnlyDataEraser(store: environment.preferences),
            storage: environment.storage)
        model.onLanguageChange = { language = $0 }
        return KultaraThemeProvider { SettingsView(model: model) }
    }
}

/// Shown when the content resources are missing — a build error surfaced as a screen rather than a
/// crash, since a crash on launch tells whoever finds it nothing (`NFR-REL-04`).
public struct ContentUnavailableScreen: View {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        KultaraThemeProvider {
            VStack(spacing: KultaraMetrics.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                Text(message)
                    .kultaraFont(.body)
                    .multilineTextAlignment(.center)
            }
            .padding(KultaraMetrics.xl)
        }
    }
}
