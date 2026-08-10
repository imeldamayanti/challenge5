import ContentKit
import Foundation

/// `FR-ONB-05` — language defaults to the device language when that is Indonesian or English, and
/// to English otherwise, and is changeable in Settings.
public enum LanguageResolver {

    public static func resolve(
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
public protocol AppPreferencesStore: AnyObject {
    var preferredLanguage: ContentLanguage? { get set }
    var onboardingCompletedAt: Date? { get set }
    func removeAll()
}

@MainActor
public final class UserDefaultsAppPreferencesStore: AppPreferencesStore {

    public static let preferredLanguageKey = "kultara.preferredLanguage"
    public static let onboardingCompletedAtKey = "kultara.onboardingCompletedAt"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var preferredLanguage: ContentLanguage? {
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

    public var onboardingCompletedAt: Date? {
        get { defaults.object(forKey: Self.onboardingCompletedAtKey) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.onboardingCompletedAtKey)
            } else {
                defaults.removeObject(forKey: Self.onboardingCompletedAtKey)
            }
        }
    }

    public func removeAll() {
        defaults.removeObject(forKey: Self.preferredLanguageKey)
        defaults.removeObject(forKey: Self.onboardingCompletedAtKey)
    }
}

@MainActor
public final class InMemoryAppPreferencesStore: AppPreferencesStore {
    public var preferredLanguage: ContentLanguage?
    public var onboardingCompletedAt: Date?

    public init(preferredLanguage: ContentLanguage? = nil, onboardingCompletedAt: Date? = nil) {
        self.preferredLanguage = preferredLanguage
        self.onboardingCompletedAt = onboardingCompletedAt
    }

    public func removeAll() {
        preferredLanguage = nil
        onboardingCompletedAt = nil
    }
}
