// `c2` phase 1. `AD-3`, `FR-SET-02`, `01-architecture.md` R4.
import Foundation
import Testing
@testable import challange_5
import RunEngine

/// The rules phase 1 has to hold, none of which are about auth.
///
/// The session itself is `AuthClient`'s and is tested upstream. What is worth guarding here is the
/// shape around it: that an app with no backend behaves exactly as it did before there was one,
/// that erasure reaches the session, and that `deviceID` is one value per install rather than a
/// fresh one per read.
@MainActor
struct SupabaseSessionTests {

    final class SpySession: SupabaseSessionProviding, @unchecked Sendable {
        private let lock = NSLock()
        private var signedOut = false
        var didSignOut: Bool { lock.withLock { signedOut } }

        func accessToken() async -> String? { nil }
        func userID() async -> UUID? { nil }
        func signOut() async { lock.withLock { signedOut = true } }
    }

    /// The unconfigured case is not an edge case — it is every build with no `Backend.plist`, and
    /// every test that does not pass one.
    @Test func withNoBackendThereIsNoTokenAndNoUserAndNothingThrows() async {
        let session = UnconfiguredSupabaseSession()
        #expect(await session.accessToken() == nil)
        #expect(await session.userID() == nil)
        await session.signOut()
    }

    /// A `SupabaseSession` built with no configuration must answer the same way, because the
    /// difference between "no backend" and "no signal" is not one any caller above it may see.
    @Test func anUnconfiguredSessionAnswersTheSameWayAsNoSessionAtAll() async {
        let session = SupabaseSession(configuration: nil)
        #expect(await session.accessToken() == nil)
        #expect(await session.userID() == nil)
        session.prepare()
        await session.signOut()
    }

    /// `FR-SET-02`. A stored session left behind means the next launch silently resumes as the
    /// same `auth.users` row somebody just asked to be disconnected from.
    @Test func erasingLocalDataSignsTheSessionOut() async throws {
        let spy = SpySession()
        let eraser = RunAndPreferencesDataEraser(
            store: InMemoryRunStore(),
            session: spy,
            preferences: InMemoryAppPreferencesStore())
        _ = try eraser.eraseAllLocalData()
        // Sign-out is detached: erasure is synchronous and must not start waiting on the Keychain.
        for _ in 0..<100 where !spy.didSignOut { await Task.yield() }
        #expect(spy.didSignOut)
    }

    /// `schema.md` §C.2. One value per installation — a fresh one per read would make `device_id`
    /// meaningless and would do it silently, since every row would still be accepted.
    @Test func theDeviceIDIsStableAcrossReads() {
        let preferences = InMemoryAppPreferencesStore()
        let first = preferences.deviceID
        #expect(preferences.deviceID == first)
        #expect(preferences.deviceID == first)
    }

    /// And erasure resets it, which is the point rather than a side effect: a walker who erases
    /// should stop being the same device to the server as well as to this phone.
    @Test func erasureMintsANewDeviceID() {
        let preferences = InMemoryAppPreferencesStore()
        let before = preferences.deviceID
        preferences.removeAll()
        #expect(preferences.deviceID != before)
    }

    /// The same, through `UserDefaults`, because that is the implementation that ships and the
    /// in-memory double could agree with a rule the real one breaks.
    @Test func theStoredDeviceIDSurvivesANewStoreOverTheSameDefaults() throws {
        let suite = "kultara.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = UserDefaultsAppPreferencesStore(defaults: defaults).deviceID
        #expect(UserDefaultsAppPreferencesStore(defaults: defaults).deviceID == first)

        UserDefaultsAppPreferencesStore(defaults: defaults).removeAll()
        #expect(UserDefaultsAppPreferencesStore(defaults: defaults).deviceID != first)
    }
}
