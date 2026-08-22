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
    /// When the entry screens were last passed — sign up, sign in, or the guest name (Figma
    /// `791:5145`, `791:5109`, `822:2235`).
    ///
    /// Persisted, where the wireframes these replaced were held in `@State` on purpose: a drawing
    /// is something the team wants to see again on every launch, and a form that asks a walker for
    /// their name every time they open the app is a defect. Cleared by `removeAll`, so
    /// Settings → erase local data puts them back (`FR-SET-02`).
    var accountEntryCompletedAt: Date? { get set }
    /// What the walker asked to be called, from the guest screen's one field or the sign-up form's
    /// name.
    ///
    /// **A local profile, not an account.** Nothing is sent anywhere and nothing authenticates
    /// it — `822:2249` promises this name appears on the Explorer's Card and in the journal, and
    /// that promise is kept locally. Empty is `nil` rather than `""`, so the Explorer's Card falls
    /// back to naming the reader by their role the way it did before there was a field at all.
    var explorerDisplayName: String? { get set }
    /// `FR-START-04` — the safety notice is acknowledged once per quest, before its first Run.
    /// Per quest rather than once globally: the notice names that route's traffic, pavements and
    /// terrain, so a blanket acknowledgement would be an acknowledgement of nothing.
    var safetyNoticeAckedQuestIDs: Set<String> { get set }
    /// `FR-PROX-03`, `NFR-PRIV-10` — off by default, and only ever turned on from the Settings row
    /// that explains it. Nothing else in the app reads or writes this.
    var nearbyAlertsEnabled: Bool { get set }
    /// The per-install id lives on `DeviceIdentity`, not here — see that type for why it has to be
    /// `Sendable` and this protocol cannot be. `removeAll()` still forgets it, so `FR-SET-02` stays
    /// one call.
    func removeAll()
}

@MainActor
final class UserDefaultsAppPreferencesStore: AppPreferencesStore {

    static let preferredLanguageKey = "kultara.preferredLanguage"
    static let onboardingCompletedAtKey = "kultara.onboardingCompletedAt"
    static let accountEntryCompletedAtKey = "kultara.accountEntryCompletedAt"
    static let explorerDisplayNameKey = "kultara.explorerDisplayName"
    static let safetyNoticeAckedQuestIDsKey = "kultara.safetyNoticeAckedQuestIDs"
    static let nearbyAlertsEnabledKey = "kultara.nearbyAlertsEnabled"

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

    var accountEntryCompletedAt: Date? {
        get { defaults.object(forKey: Self.accountEntryCompletedAtKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.accountEntryCompletedAtKey)
            } else {
                defaults.removeObject(forKey: Self.accountEntryCompletedAtKey)
            }
        }
    }

    var explorerDisplayName: String? {
        get {
            // A stored empty string is the same as no name; normalising on read means a build that
            // once wrote one cannot leave the card headed with nothing.
            let stored = defaults.string(forKey: Self.explorerDisplayNameKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (stored?.isEmpty ?? true) ? nil : stored
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                defaults.set(trimmed, forKey: Self.explorerDisplayNameKey)
            } else {
                defaults.removeObject(forKey: Self.explorerDisplayNameKey)
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

    func removeAll() {
        defaults.removeObject(forKey: Self.preferredLanguageKey)
        defaults.removeObject(forKey: Self.onboardingCompletedAtKey)
        defaults.removeObject(forKey: Self.accountEntryCompletedAtKey)
        defaults.removeObject(forKey: Self.explorerDisplayNameKey)
        defaults.removeObject(forKey: Self.safetyNoticeAckedQuestIDsKey)
        defaults.removeObject(forKey: Self.nearbyAlertsEnabledKey)
        // `FR-SET-02`. The next read mints a new one, so a user who erases stops being the same
        // install to the server as well as to this device.
        DeviceIdentity(defaults: defaults).forget()
    }
}

@MainActor
final class InMemoryAppPreferencesStore: AppPreferencesStore {
    var preferredLanguage: ContentLanguage?
    var onboardingCompletedAt: Date?
    var accountEntryCompletedAt: Date?
    var safetyNoticeAckedQuestIDs: Set<String>
    var nearbyAlertsEnabled: Bool

    /// Normalised on write, the way the `UserDefaults` store normalises on read: a double that
    /// accepts `"  "` where the real one does not is a double that hides a bug.
    var explorerDisplayName: String? {
        get { storedExplorerDisplayName }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            storedExplorerDisplayName = (trimmed?.isEmpty ?? true) ? nil : trimmed
        }
    }

    private var storedExplorerDisplayName: String?

    init(
        preferredLanguage: ContentLanguage? = nil,
        onboardingCompletedAt: Date? = nil,
        accountEntryCompletedAt: Date? = nil,
        explorerDisplayName: String? = nil,
        safetyNoticeAckedQuestIDs: Set<String> = [],
        nearbyAlertsEnabled: Bool = false
    ) {
        self.preferredLanguage = preferredLanguage
        self.onboardingCompletedAt = onboardingCompletedAt
        self.accountEntryCompletedAt = accountEntryCompletedAt
        self.safetyNoticeAckedQuestIDs = safetyNoticeAckedQuestIDs
        self.nearbyAlertsEnabled = nearbyAlertsEnabled
        self.explorerDisplayName = explorerDisplayName
    }

    func removeAll() {
        preferredLanguage = nil
        onboardingCompletedAt = nil
        accountEntryCompletedAt = nil
        explorerDisplayName = nil
        safetyNoticeAckedQuestIDs = []
        nearbyAlertsEnabled = false
    }
}
