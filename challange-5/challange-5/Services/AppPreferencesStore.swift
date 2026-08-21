import ContentKit
import Foundation

/// `FR-ONB-05` — language defaults to the device language when that is Indonesian or English, and
/// to English otherwise, and is changeable in Settings.
enum LanguageResolver {

    static func resolve(
        override: ContentLanguage?,
        deviceLanguageCodes: [String] = Locale.preferredLanguages
    ) -> ContentLanguage {
        if let override { return override }

        // The device's *first* preference decides. Scanning the whole list for any match would
        // hand an Indonesian interface to someone whose first choice is German and who merely
        // also reads Indonesian.
        guard let primary = deviceLanguageCodes.first else { return .en }
        let subtag = primary
            .split(separator: "-").first.map(String.init)?
            .lowercased() ?? ""

        for language in ContentLanguage.allCases where language.languageCodes.contains(subtag) {
            return language
        }
        return .en
    }
}

/// The little that M5 persists.
///
/// `schema.md` §B.9 specifies this as a SwiftData `AppStateRecord`. M5 stores only a language
/// override and an onboarding timestamp and has no other entity, so standing up a `ModelContainer`
/// now would write a schema version to disk holding a single singleton row and force a migration in
/// M6 when `RunRecord` and its children arrive. The protocol is the seam: M6 swaps the
/// implementation for `AppStateRecord` when the store is created for the first time with its real
/// schema, and nothing above this line changes.
@MainActor
protocol AppPreferencesStore: AnyObject {
    var preferredLanguage: ContentLanguage? { get set }
    var onboardingCompletedAt: Date? { get set }
    /// `FR-START-04` — the safety notice is acknowledged once per quest, before its first Run.
    /// Per quest rather than once globally: the notice names that route's traffic, pavements and
    /// terrain, so a blanket acknowledgement would be an acknowledgement of nothing.
    var safetyNoticeAckedQuestIDs: Set<String> { get set }
    /// `FR-PROX-03`, `NFR-PRIV-10` — off by default, and only ever turned on from the Settings row
    /// that explains it. Nothing else in the app reads or writes this.
    var nearbyAlertsEnabled: Bool { get set }
    /// One UUID per installation, minted on first read and stable until the app is deleted
    /// (`c2` phase 1, `schema.md` §C.2's `device_id`).
    ///
    /// **Not a device identifier.** `identifierForVendor` and its relatives survive a delete and
    /// are shared across an author's apps, which makes them a way to recognise a person; this is a
    /// random value that says only "the same install wrote these rows". `FR-SET-02` erasure resets
    /// it, and that is the point rather than a side effect.
    var deviceID: UUID { get }
    func removeAll()
}

@MainActor
final class UserDefaultsAppPreferencesStore: AppPreferencesStore {

    static let preferredLanguageKey = "kultara.preferredLanguage"
    static let onboardingCompletedAtKey = "kultara.onboardingCompletedAt"
    static let safetyNoticeAckedQuestIDsKey = "kultara.safetyNoticeAckedQuestIDs"
    static let nearbyAlertsEnabledKey = "kultara.nearbyAlertsEnabled"
    static let deviceIDKey = "kultara.deviceID"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferredLanguage: ContentLanguage? {
        get {
            // An unrecognised value — a build that once shipped a third language, a corrupted
            // domain — is treated as "no override" rather than taking launch down.
            guard let raw = defaults.string(forKey: Self.preferredLanguageKey) else { return nil }
            return ContentLanguage(rawValue: raw)
        }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Self.preferredLanguageKey)
            } else {
                defaults.removeObject(forKey: Self.preferredLanguageKey)
            }
        }
    }

    var onboardingCompletedAt: Date? {
        get { defaults.object(forKey: Self.onboardingCompletedAtKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.onboardingCompletedAtKey)
            } else {
                defaults.removeObject(forKey: Self.onboardingCompletedAtKey)
            }
        }
    }

    var safetyNoticeAckedQuestIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Self.safetyNoticeAckedQuestIDsKey) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Self.safetyNoticeAckedQuestIDsKey) }
    }

    var nearbyAlertsEnabled: Bool {
        get { defaults.bool(forKey: Self.nearbyAlertsEnabledKey) }
        set { defaults.set(newValue, forKey: Self.nearbyAlertsEnabledKey) }
    }

    /// Read-only from the outside and minted on first access, so there is exactly one way for this
    /// value to come into existence. A settable property would let two callers disagree about
    /// which install this is, which is the same class of mistake as two accuracy enums.
    var deviceID: UUID {
        if let raw = defaults.string(forKey: Self.deviceIDKey), let existing = UUID(uuidString: raw) {
            return existing
        }
        let minted = UUID()
        defaults.set(minted.uuidString, forKey: Self.deviceIDKey)
        return minted
    }

    func removeAll() {
        defaults.removeObject(forKey: Self.preferredLanguageKey)
        defaults.removeObject(forKey: Self.onboardingCompletedAtKey)
        defaults.removeObject(forKey: Self.safetyNoticeAckedQuestIDsKey)
        defaults.removeObject(forKey: Self.nearbyAlertsEnabledKey)
        // `FR-SET-02`. The next read mints a new one, so a user who erases stops being the same
        // install to the server as well as to this device.
        defaults.removeObject(forKey: Self.deviceIDKey)
    }
}

@MainActor
final class InMemoryAppPreferencesStore: AppPreferencesStore {
    var preferredLanguage: ContentLanguage?
    var onboardingCompletedAt: Date?
    var safetyNoticeAckedQuestIDs: Set<String>
    var nearbyAlertsEnabled: Bool
    private(set) var storedDeviceID: UUID?

    var deviceID: UUID {
        if let storedDeviceID { return storedDeviceID }
        let minted = UUID()
        storedDeviceID = minted
        return minted
    }

    init(
        preferredLanguage: ContentLanguage? = nil,
        onboardingCompletedAt: Date? = nil,
        safetyNoticeAckedQuestIDs: Set<String> = [],
        nearbyAlertsEnabled: Bool = false
    ) {
        self.preferredLanguage = preferredLanguage
        self.onboardingCompletedAt = onboardingCompletedAt
        self.safetyNoticeAckedQuestIDs = safetyNoticeAckedQuestIDs
        self.nearbyAlertsEnabled = nearbyAlertsEnabled
    }

    func removeAll() {
        preferredLanguage = nil
        onboardingCompletedAt = nil
        safetyNoticeAckedQuestIDs = []
        nearbyAlertsEnabled = false
        storedDeviceID = nil
    }
}
