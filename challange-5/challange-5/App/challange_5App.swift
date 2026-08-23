import SwiftUI
import UserNotifications

@main
struct challange_5App: App {
    @State private var router = SideQuestRouter()
    /// Held here rather than constructed inline: `UNUserNotificationCenter.current().delegate` is
    /// `weak`, and a delegate nothing retains is a delegate iOS silently drops.
    @State private var notificationDelegate = SideQuestNotificationDelegate()

    var body: some Scene {
        WindowGroup {
            // The app target is a shell. Everything it shows lives in the Kultara package, which
            // keeps ContentKit's no-UI, no-location boundary enforced by target linkage rather
            // than by convention (system-design.md §3).
            switch Self.environment {
            case .success(let environment):
                KultaraRootView(environment: environment, router: router)
                    .onAppear { configureProximity(environment) }
            case .failure(let error):
                ContentUnavailableScreen(message: String(describing: error))
            }
        }
    }

    /// `system-design.md` §6.2 — `registerRegions()` runs on launch, and the notification delegate
    /// has to be in place before any tap can arrive. All of these are idempotent, so re-running this
    /// on a later `onAppear` (a scene reactivation) costs nothing.
    @MainActor
    private func configureProximity(_ environment: KultaraEnvironment) {
        // A tap on a proximity notification is the discovery journey (`1108:2780` → `949:2461`),
        // not the nearby list's. `SideQuestRouter` carries the two separately and says why.
        notificationDelegate.onTap = { sideQuestID in router.discoveredSideQuestID = sideQuestID }
        UNUserNotificationCenter.current().delegate = notificationDelegate
        // `FR-ONB-05` — the app's language, not the device's; mirrors the resolve call in
        // `SideQuestProximityService.handleRegionEntered`.
        let language = LanguageResolver.resolve(override: environment.preferences.preferredLanguage)
        SideQuestNotificationCategory.register(language: language)
        // Same journey as a notification tap — the region fired, the app just happened to be
        // open when it did.
        environment.proximityMonitor.onSideQuestNearby = { sideQuestID in
            router.discoveredSideQuestID = sideQuestID
        }
        environment.proximityMonitor.refreshRegions()
    }

    /// Resolved once. A missing content bundle is a build problem, so it is surfaced as a screen
    /// rather than as a launch crash.
    @MainActor
    private static let environment: Result<KultaraEnvironment, any Error> = {
        do {
            return .success(try KultaraEnvironment.bundled())
        } catch {
            return .failure(error)
        }
    }()
}
