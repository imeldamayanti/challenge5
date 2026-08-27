import Auth
import Foundation

/// Whatever phases 3, 4 and 7 need in order to speak as a user.
///
/// Deliberately three members and no more. A view model that could see this protocol could sign a
/// user out, read their id, or wait for a token — and none of those is a thing a screen in this app
/// does (`c2` phase 1, `01-architecture.md` §2).
protocol SupabaseSessionProviding: Sendable {
    /// The access token to put on a request, refreshing first if it is close to expiry. `nil` when
    /// there is no session — which is the ordinary offline case and never an error.
    func accessToken() async -> String?
    /// The signed-in user's id, or `nil`. Phases 3 and 4 stamp it on rows; RLS is what enforces it.
    func userID() async -> UUID?
    /// Forget the session locally. `FR-SET-02`.
    func signOut() async
}

/// An anonymous Supabase session, obtained without asking anybody for anything.
///
/// **This is not the auth feature.** `config.toml` has carried `enable_anonymous_sign_ins = true`
/// since `b1`, with the comment that every user has an `auth.users` row from first launch. Every
/// `app.*` table declares `user_id uuid not null references auth.users(id)` and every policy reads
/// `user_id = (select auth.uid())`, so without a session there is no row that can be inserted and
/// no policy that can pass. The credential — Apple, Google, the linking screen — is phase 6.
///
/// Three properties hold the offline rules, and each is a decision rather than an implementation
/// detail:
///
/// - **Nothing waits for it.** `prepare()` returns immediately and the work happens in a detached
///   task. A cold launch in airplane mode reaches the quest list at the same speed it does today.
/// - **No reachability check** (`AD-3`). Sign-in is attempted and the outcome read. A failure is
///   indistinguishable from being offline on purpose: both mean "no session yet, try again later".
/// - **No error surface** (`01-architecture.md` R4). A walker who never gets a session sees an app
///   that behaves exactly as it did before there was a backend.
actor SupabaseSession: SupabaseSessionProviding {

    /// How close to expiry a token may be before it is refreshed rather than used.
    ///
    /// `jwt_expiry = 3600`, and a token that is valid when checked can still expire in flight on a
    /// slow connection. Sixty seconds is comfortably longer than any request this app makes and
    /// short enough that the refresh is not effectively per-call.
    private nonisolated static let refreshMargin: TimeInterval = 60

    /// `AuthClient` rather than the umbrella `SupabaseClient`, and that is the same decision as
    /// linking four products instead of `Supabase`: the umbrella carries `Realtime`, which holds a
    /// WebSocket open for a feature this app does not have (`01-architecture.md` §5).
    private let client: AuthClient?
    /// Guards against two callers racing into two anonymous sign-ins, which would leave one
    /// `auth.users` row orphaned per race and count twice against the 30-per-hour rate limit.
    private var signIn: Task<Session?, Never>?

    init(configuration: BackendConfiguration?) {
        guard let configuration else {
            client = nil
            return
        }
        client = AuthClient(configuration: .init(
            url: configuration.authURL,
            headers: ["apikey": configuration.publishableKey],
            // The default on Apple platforms is `KeychainLocalStorage`, which is what phase 1 asks
            // for: a refresh token is a bearer credential for a walker's own history and has no
            // business in `UserDefaults`. Named rather than defaulted so a change to the SDK's
            // default cannot quietly move it.
            localStorage: AuthClient.Configuration.defaultLocalStorage,
            logger: Self.debugLogger,
            autoRefreshToken: true))
    }

    /// Everything below this is silent to a walker by design (`01-architecture.md` R4), which
    /// leaves nobody able to see *why* a session did not arrive. In a debug build the SDK's own
    /// log is that answer; a release build has no logger and prints nothing.
    private nonisolated static var debugLogger: (any SupabaseLogger)? {
        #if DEBUG
        return ConsoleSupabaseLogger()
        #else
        return nil
        #endif
    }

    /// Ask for a session if there is not one. Returns immediately; nothing waits on the result.
    ///
    /// Called from the root view's launch task beside the governance refresh, and for the same
    /// reason: the app draws whatever it has, and this arrives when it arrives.
    /// Handed to `SupabaseCredentialLinking` so the credential flow signs into **this** session
    /// rather than a second client with its own storage — two clients would mean two stored
    /// sessions and a walker signed in on one of them.
    nonisolated var authClient: AuthClient? { client }

    nonisolated func prepare() {
        Task { await ensureSession() }
    }

    func accessToken() async -> String? {
        await ensureSession()?.accessToken
    }

    func userID() async -> UUID? {
        await ensureSession()?.user.id
    }

    func signOut() async {
        signIn = nil
        // Local only. Revoking server-side would need the network to be up for a Settings action
        // that must work offline, and the row this forgets is the device's copy of a token.
        try? await client?.signOut(scope: .local)
    }

    /// The one path to a session: reuse the stored one, refresh it if it is nearly expired, and
    /// sign in anonymously only when there is nothing to reuse.
    private func ensureSession() async -> Session? {
        guard let client else { return nil }

        if let existing = try? await client.session {
            guard isExpiring(existing) else { return existing }
            // A refresh that fails leaves the old token in hand. It may still be good — the margin
            // is a margin, not an expiry — and a caller getting a token that turns out stale is a
            // 401 it can survive, where returning nil is a push that does not happen at all.
            if let refreshed = try? await client.refreshSession() { return refreshed }
            return existing
        }

        if let signIn { return await signIn.value }
        let task = Task<Session?, Never> { [client] in
            try? await client.signInAnonymously()
        }
        signIn = task
        let session = await task.value
        // Cleared either way. Keeping a failed attempt would cache "no session" for the lifetime of
        // the app, so a walker who was in a tunnel at launch never gets one.
        signIn = nil
        return session
    }

    private func isExpiring(_ session: Session) -> Bool {
        Date(timeIntervalSince1970: session.expiresAt).timeIntervalSinceNow <= Self.refreshMargin
    }
}

/// What the app uses when no backend is configured, and what the tests use by default.
///
/// Not a stub for convenience: a build with no `Backend.plist` is a normal, working app, and every
/// caller below this has to behave the same way whether the answer is "no backend" or "no signal".
struct UnconfiguredSupabaseSession: SupabaseSessionProviding {
    func accessToken() async -> String? { nil }
    func userID() async -> UUID? { nil }
    func signOut() async {}
}


#if DEBUG
/// The SDK's own diagnostics, written to a file under Application Support.
///
/// **A file rather than `print` or `NSLog`, and that is not a preference.** On this machine the
/// simulator's unified log renders every message from this process as `<compose failure>` and
/// `simctl launch --console` drops almost everything, so neither can be read back. Finding out that
/// phase 1's sign-in had worked all along cost an hour for exactly that reason; leaving the file
/// behind is what makes phases 3, 4 and 7 debuggable at all.
///
/// Debug only, so a release build contains neither this type nor a call to it, and capped so a long
/// session cannot fill a device.
///
///     xcrun simctl get_app_container <udid> com.astungkara.hisplora data
///     cat "<that>/Library/Application Support/supabase-trace.log"
struct ConsoleSupabaseLogger: SupabaseLogger {

    /// Truncated rather than rotated past this. The interesting part of a diagnostic like this is
    /// always the most recent launch, and a rotation scheme is a second thing to get wrong.
    static let byteCap = 2 * 1024 * 1024

    func log(message: SupabaseLogMessage) {
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return }
        let url = directory.appendingPathComponent("supabase-trace.log")
        let entry = Data("\(Date()) \(message)\n".utf8)

        guard let handle = try? FileHandle(forWritingTo: url) else {
            try? entry.write(to: url)
            return
        }
        defer { try? handle.close() }
        let end = (try? handle.seekToEnd()) ?? 0
        if end > UInt64(Self.byteCap) {
            try? handle.truncate(atOffset: 0)
        }
        try? handle.write(contentsOf: entry)
    }
}
#endif
