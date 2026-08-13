import SwiftUI

@main
struct challange_5App: App {
    var body: some Scene {
        WindowGroup {
            // The app target is a shell. Everything it shows lives in the Kultara package, which
            // keeps ContentKit's no-UI, no-location boundary enforced by target linkage rather
            // than by convention (system-design.md §3).
            switch Self.environment {
            case .success(let environment):
                KultaraRootView(environment: environment)
            case .failure(let error):
                ContentUnavailableScreen(message: String(describing: error))
            }
        }
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
