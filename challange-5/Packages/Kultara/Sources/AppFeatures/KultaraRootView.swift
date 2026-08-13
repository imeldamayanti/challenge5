import ContentKit
import CoreLocation
import DesignSystem
import RunEngine
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

/// Everything the app needs, assembled once. Content is read-only and bundled; the Run store and
/// preferences are the writable side.
@MainActor
public struct KultaraEnvironment {
    public let repository: any ContentRepository
    public let preferences: any AppPreferencesStore
    public let runStore: any RunStore
    public let locationAuthorization: any LocationAuthorizationReporting
    public let storage: any StorageUsageReporting
    /// A factory rather than a single instance: each arrival screen owns its own sampling and its
    /// own callbacks, and two screens sharing one provider would have the second silently steal the
    /// first's fixes.
    public let makeLocationProvider: @MainActor () -> any LocationProviding

    public init(
        repository: any ContentRepository,
        preferences: any AppPreferencesStore,
        runStore: any RunStore,
        locationAuthorization: any LocationAuthorizationReporting = SystemLocationAuthorizationReporter(),
        storage: any StorageUsageReporting = ContainerStorageReporter(),
        makeLocationProvider: (@MainActor () -> any LocationProviding)? = nil
    ) {
        self.repository = repository
        self.preferences = preferences
        self.runStore = runStore
        self.locationAuthorization = locationAuthorization
        self.storage = storage
        self.makeLocationProvider = makeLocationProvider ?? Self.defaultLocationProvider
    }

    public var runEngine: RunEngine {
        RunEngine(repository: repository, store: runStore)
    }

    /// In a debug build the provider can be switched to a simulator from Settings, so the loop can
    /// be walked from a desk. In a release build that type does not exist and this is the radios,
    /// with no branch to take.
    @MainActor
    private static func defaultLocationProvider() -> any LocationProviding {
        #if DEBUG
        DeveloperSwitchableLocationProvider(system: SystemLocationProvider())
        #else
        SystemLocationProvider()
        #endif
    }

    /// The shipped configuration. Fails if the content resources are missing from the bundle or the
    /// Run directory cannot be created — both build or device problems rather than runtime ones.
    public static func bundled(defaults: UserDefaults = .standard) throws -> KultaraEnvironment {
        KultaraEnvironment(
            repository: try BundledContentRepository(),
            preferences: UserDefaultsAppPreferencesStore(defaults: defaults),
            runStore: try FileRunStore())
    }
}

public struct KultaraRootView: View {

    private let environment: KultaraEnvironment

    @State private var language: ContentLanguage
    @State private var showsOnboarding: Bool
    @State private var selectedQuestID: String?
    @State private var runDestination: RunDestination?
    /// Bumped whenever a walk changes, so the home screen's journal is rebuilt. The store is not
    /// observable — it is a protocol with a file behind it — and a counter is a smaller thing to
    /// own than an observation layer this milestone would use in exactly one place.
    @State private var journalRevision = 0

    /// Which walk the run screen should open, and whether an existing draft is being replaced.
    private struct RunDestination: Identifiable, Hashable {
        let id = UUID()
        let questID: String
        let existingRunID: UUID?
        let discardingExistingDraft: Bool
    }
    /// The floating bar's selection. Two destinations is what the app has in M5; the bar exists
    /// because the Home design puts one there, and because a settings screen reached only from a
    /// gear in a bar has nowhere to live once the bar is gone.
    @State private var tab = Tab.quests.rawValue

    private enum Tab: String { case quests, settings }

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
        // The bar is drawn rather than taken from `TabView`, and it is attached as a safe-area
        // inset rather than stacked on top: the inset reserves exactly the height the bar actually
        // has, so a bar whose labels have grown at an accessibility size cannot end up sitting on
        // the last card. The full-bleed map ignores the safe area and still runs underneath it.
        Group {
            if tab == Tab.settings.rawValue {
                NavigationStack { settingsDestination }
            } else {
                questsStack
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KultaraTabBar(tabs: tabs, selection: $tab)
        }
    }

    private var tabs: [KultaraTab] {
        [KultaraTab(id: Tab.quests.rawValue,
                    title: UIStrings.string(.questListTitle, language),
                    symbolName: "map"),
         KultaraTab(id: Tab.settings.rawValue,
                    title: UIStrings.string(.settingsTitle, language),
                    symbolName: "gearshape")]
    }

    private var questsStack: some View {
        NavigationStack {
            QuestListView(
                // Rebuilt when the language changes: every string in the list is resolved at
                // construction, so the identity of the view model *is* the language.
                model: QuestListViewModel(repository: environment.repository, language: language),
                mapModel: RegionMapViewModel(repository: environment.repository, language: language),
                journal: journal,
                onSelect: { selectedQuestID = $0 },
                onOpenRun: openRun)
                .navigationDestination(isPresented: Binding(
                    get: { selectedQuestID != nil },
                    set: { if !$0 { selectedQuestID = nil } })
                ) {
                    previewDestination
                }
                .navigationDestination(item: $runDestination) { destination in
                    runScreen(destination)
                }
        }
    }

    private var journal: RunJournalSummary {
        // `journalRevision` is read so the value is recomputed when a walk changes.
        _ = journalRevision
        return RunJournalSummary(store: environment.runStore, language: language)
    }

    private func openRun(_ runID: UUID) {
        guard let run = (try? environment.runStore.run(id: runID)) ?? nil else { return }
        runDestination = RunDestination(
            questID: run.questID, existingRunID: run.id, discardingExistingDraft: false)
    }

    @ViewBuilder private var previewDestination: some View {
        if let questID = selectedQuestID {
            ScreenHost {
                QuestPreviewViewModel(
                    repository: environment.repository,
                    questID: questID,
                    language: language,
                    runEngine: environment.runEngine)
            } content: { model in
                KultaraThemeProvider {
                    QuestPreviewView(model: model)
                        .onAppear {
                            model.onBeginRun = { restart in
                                let draft = (try? environment.runStore.activeRun(questID: questID)) ?? nil
                                runDestination = RunDestination(
                                    questID: questID,
                                    existingRunID: restart ? nil : draft?.id,
                                    discardingExistingDraft: restart)
                            }
                        }
                }
            }
        } else {
            // A quest that cannot be built is not a blank screen; the list stays reachable.
            EmptyView()
        }
    }

    private func runScreen(_ destination: RunDestination) -> some View {
        ScreenHost {
            let existing = destination.existingRunID
                .flatMap { (try? environment.runStore.run(id: $0)) ?? nil }
            return QuestRunViewModel(
                engine: environment.runEngine,
                repository: environment.repository,
                preferences: environment.preferences,
                locationProvider: environment.makeLocationProvider(),
                questID: destination.questID,
                language: language,
                existingRun: existing,
                discardingExistingDraft: destination.discardingExistingDraft)
        } content: { model in
            KultaraThemeProvider { QuestRunView(model: model) }
                .onDisappear { journalRevision += 1 }
        }
    }

    private var settingsDestination: some View {
        let model = SettingsViewModel(
            repository: environment.repository,
            store: environment.preferences,
            language: language,
            locationAuthorization: environment.locationAuthorization,
            eraser: RunAndPreferencesDataEraser(
                store: environment.runStore, preferences: environment.preferences),
            storage: environment.storage)
        model.onLanguageChange = { language = $0 }
        return KultaraThemeProvider { SettingsView(model: model) }
    }
}

/// Builds a screen's view model once and keeps it for as long as the screen is on screen.
///
/// SwiftUI re-evaluates a `body` whenever anything it reads changes, and a view model constructed
/// inside one is therefore constructed again — taking a fresh location provider with it, and
/// leaving the in-flight fix belonging to an object nobody holds any more. The arrival screen sat
/// on "looking for a location fix" forever because of exactly that. `@State` is what makes the
/// model outlive a redraw.
private struct ScreenHost<Model: AnyObject, Content: View>: View {
    let make: () -> Model?
    @ViewBuilder let content: (Model) -> Content

    @State private var model: Model?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                // A screen whose model cannot be built is not a blank one — whatever pushed it
                // stays reachable behind the back button.
                Color.clear
            }
        }
        .onAppear { if model == nil { model = make() } }
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
