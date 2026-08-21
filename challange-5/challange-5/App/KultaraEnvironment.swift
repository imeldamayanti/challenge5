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
    /// The background half of `AD-1` (`s3`). One instance, not a factory: unlike arrival sampling,
    /// region monitoring is not scoped to a screen — it has to keep running (or keep *not*
    /// running) no matter what is on screen, so every caller shares the same monitor.
    let proximityMonitor: any ProximityMonitoring
    /// `s4` §7. One instance, not a factory: unlike `makeLocationProvider`, nothing about a photo
    /// write is scoped to a screen's lifetime, and every caller can share the same directory.
    let photoStore: any PhotoStore
    /// A factory rather than a single instance: each arrival screen owns its own sampling and its
    /// own callbacks, and two screens sharing one provider would have the second silently steal the
    /// first's fixes.
    let makeLocationProvider: @MainActor () -> any LocationProviding
    /// The kill-switch (`AD-5`, `c2` phase 0). Available synchronously from disk at construction;
    /// the refresh that updates it is the caller's, and nothing on screen waits for it.
    let governance: GovernanceGate
    /// Anonymous telemetry (`c2` phase 0). One instance, not a factory: the queue is the app's, not
    /// a screen's, and two of them would race for the same file.
    let telemetry: AppTelemetry
    /// The anonymous Supabase session (`c2` phase 1). Nothing on screen reads it — it exists so
    /// that phases 3, 4 and 7 have a `user_id` to write under and a token to write with.
    let session: any SupabaseSessionProviding
    /// Pushes walks to the server (`c2` phase 3). Nothing reads it and nothing waits on it;
    /// deleting the type removes syncing and breaks nothing else.
    let sync: any RunSyncing
    /// Removes the server copy on `FR-SET-02` erasure. `nil` with no backend, which is the same as
    /// "there is nothing on a server to remove".
    let accountDeleter: (any AccountDeleting)?
    /// What has already been pushed, so erasure can forget it (`c2` phase 3).
    let syncState: any SyncStateStore

    init(
        repository: any ContentRepository,
        preferences: any AppPreferencesStore,
        runStore: any RunStore,
        sideQuestStore: any SideQuestStore,
        locationAuthorization: any LocationAuthorizationReporting = SystemLocationAuthorizationReporter(),
        storage: any StorageUsageReporting = ContainerStorageReporter(),
        proximityMonitor: (any ProximityMonitoring)? = nil,
        photoStore: (any PhotoStore)? = nil,
        makeLocationProvider: (@MainActor () -> any LocationProviding)? = nil,
        backend: BackendConfiguration? = BackendConfiguration(),
        governance: GovernanceGate? = nil,
        telemetry: AppTelemetry? = nil,
        session: (any SupabaseSessionProviding)? = nil,
        sync: (any RunSyncing)? = nil
    ) {
        self.repository = repository
        self.preferences = preferences
        self.runStore = runStore
        self.sideQuestStore = sideQuestStore
        self.locationAuthorization = locationAuthorization
        self.storage = storage
        self.proximityMonitor = proximityMonitor ?? SystemProximityMonitor(
            repository: repository,
            sideQuestEngine: SideQuestEngine(repository: repository, store: sideQuestStore),
            runStore: runStore,
            preferences: preferences,
            alertStore: FileProximityAlertStore())
        self.photoStore = photoStore ?? FilePhotoStore()
        self.makeLocationProvider = makeLocationProvider ?? Self.defaultLocationProvider
        // Both are optional at runtime: with no backend configured they are constructed, do
        // nothing, and the app behaves exactly as it does today (`AD-3`).
        self.governance = governance ?? GovernanceGate(configuration: backend)
        self.telemetry = telemetry ?? AppTelemetry(configuration: backend)
        // The unconfigured double rather than a `SupabaseSession` holding a nil client: the two
        // behave identically, and this way a test that forgets to pass one cannot accidentally
        // reach the network.
        let resolvedSession = session ?? (backend.map { SupabaseSession(configuration: $0) }
            ?? UnconfiguredSupabaseSession())
        self.session = resolvedSession
        let resolvedSyncState: any SyncStateStore = backend == nil
            ? InMemorySyncStateStore()
            : FileSyncStateStore()
        self.syncState = resolvedSyncState
        self.accountDeleter = backend.map {
            EdgeFunctionAccountDeleter(configuration: $0, session: resolvedSession)
        }
        // Both closures rather than the objects themselves: `RunStore` and `AppPreferencesStore`
        // are `@MainActor` and the coordinator is not. Reading `deviceID` through a closure also
        // means a push after `FR-SET-02` erasure sees the newly minted one rather than the one this
        // environment was built with.
        self.sync = sync ?? (backend == nil ? NoRunSyncing() : SyncCoordinator(
            loadRuns: { [runStore] in try runStore.runs() },
            session: resolvedSession,
            configuration: backend,
            state: resolvedSyncState,
            deviceID: { [identity = DeviceIdentity()] in identity.current }))
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
