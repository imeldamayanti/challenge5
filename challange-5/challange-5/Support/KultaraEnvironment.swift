import ContentKit
import Foundation
import RunEngine

/// Everything the app needs, assembled once. Content is read-only and bundled; the Run store and
/// preferences are the writable side.
@MainActor
struct KultaraEnvironment {
    let repository: any ContentRepository
    let preferences: any AppPreferencesStore
    let runStore: any RunStore
    /// Sidequest user data, stored separately from Runs and never referenced by one — modelling a
    /// sidequest as a one-checkpoint Run would put it into the home screen's resume entry and make
    /// `FR-PROX-08` suppress the very alerts the feature exists to send (`FR-SIDE-01`, `s0` D1).
    let sideQuestStore: any SideQuestStore
    let locationAuthorization: any LocationAuthorizationReporting
    let storage: any StorageUsageReporting
    /// A factory rather than a single instance: each arrival screen owns its own sampling and its
    /// own callbacks, and two screens sharing one provider would have the second silently steal the
    /// first's fixes.
    let makeLocationProvider: @MainActor () -> any LocationProviding

    init(
        repository: any ContentRepository,
        preferences: any AppPreferencesStore,
        runStore: any RunStore,
        sideQuestStore: any SideQuestStore,
        locationAuthorization: any LocationAuthorizationReporting = SystemLocationAuthorizationReporter(),
        storage: any StorageUsageReporting = ContainerStorageReporter(),
        makeLocationProvider: (@MainActor () -> any LocationProviding)? = nil
    ) {
        self.repository = repository
        self.preferences = preferences
        self.runStore = runStore
        self.sideQuestStore = sideQuestStore
        self.locationAuthorization = locationAuthorization
        self.storage = storage
        self.makeLocationProvider = makeLocationProvider ?? Self.defaultLocationProvider
    }

    var runEngine: RunEngine {
        RunEngine(repository: repository, store: runStore)
    }

    /// The only thing that writes sidequest user data. Nothing here touches `runEngine` or
    /// `runStore`, which is `FR-SIDE-01` held by there being no call that could.
    var sideQuestEngine: SideQuestEngine {
        SideQuestEngine(repository: repository, store: sideQuestStore)
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
    static func bundled(defaults: UserDefaults = .standard) throws -> KultaraEnvironment {
        KultaraEnvironment(
            repository: try BundledContentRepository(),
            preferences: UserDefaultsAppPreferencesStore(defaults: defaults),
            runStore: try FileRunStore(),
            sideQuestStore: try FileSideQuestStore())
    }
}
