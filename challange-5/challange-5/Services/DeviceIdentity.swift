import Foundation

/// The per-install UUID, and the one place it comes into existence (`c2` phase 1, `schema.md` §C.2).
///
/// A type of its own rather than a property on `AppPreferencesStore`, for one structural reason:
/// `AppPreferencesStore` is `@MainActor` and its existential is therefore not `Sendable`, so a push
/// running off the main actor cannot hold one. This is `nonisolated` and `Sendable`, so the sync
/// coordinator can read the identity without a hop — and reads it **at push time**, which is what
/// makes a push after `FR-SET-02` erasure carry the newly minted id rather than a captured stale one.
///
/// **Not a device identifier.** `identifierForVendor` and its relatives survive a delete and are
/// shared across an author's apps, which makes them a way to recognise a person. This is random, and
/// erasure resets it.
///
/// `@unchecked Sendable` because `UserDefaults` is not marked `Sendable` and is nevertheless
/// thread-safe by documented contract — the same reason every other cross-actor `UserDefaults` use
/// in this codebase is safe. Nothing else is stored here.
nonisolated final class DeviceIdentity: @unchecked Sendable {

    static let defaultsKey = "kultara.deviceID"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Minted on first read, so there is exactly one way for the value to exist. There is no setter:
    /// two callers disagreeing about which install this is would be the same class of mistake as
    /// two accuracy enums, one layer down.
    var current: UUID {
        if let raw = defaults.string(forKey: Self.defaultsKey), let existing = UUID(uuidString: raw) {
            return existing
        }
        let minted = UUID()
        defaults.set(minted.uuidString, forKey: Self.defaultsKey)
        return minted
    }

    /// `FR-SET-02`. The next read mints a new one, so a walker who erases stops being the same
    /// install to the server as well as to this device.
    func forget() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
