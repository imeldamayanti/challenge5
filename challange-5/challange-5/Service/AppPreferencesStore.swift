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
    func removeAll()
}

@MainActor
final class UserDefaultsAppPreferencesStore: AppPreferencesStore {

    static let preferredLanguageKey = "kultara.preferredLanguage"
    static let onboardingCompletedAtKey = "kultara.onboardingCompletedAt"
    static let safetyNoticeAckedQuestIDsKey = "kultara.safetyNoticeAckedQuestIDs"

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

    func removeAll() {
        defaults.removeObject(forKey: Self.preferredLanguageKey)
        defaults.removeObject(forKey: Self.onboardingCompletedAtKey)
        defaults.removeObject(forKey: Self.safetyNoticeAckedQuestIDsKey)
    }
}

@MainActor
final class InMemoryAppPreferencesStore: AppPreferencesStore {
    var preferredLanguage: ContentLanguage?
    var onboardingCompletedAt: Date?
    var safetyNoticeAckedQuestIDs: Set<String>

    init(
        preferredLanguage: ContentLanguage? = nil,
        onboardingCompletedAt: Date? = nil,
        safetyNoticeAckedQuestIDs: Set<String> = []
    ) {
        self.preferredLanguage = preferredLanguage
        self.onboardingCompletedAt = onboardingCompletedAt
        self.safetyNoticeAckedQuestIDs = safetyNoticeAckedQuestIDs
    }

    func removeAll() {
        preferredLanguage = nil
        onboardingCompletedAt = nil
        safetyNoticeAckedQuestIDs = []
    }
}
