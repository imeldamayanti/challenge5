import Foundation

/// Where the backend is (`c2` phase 0, `01-architecture.md` §2).
///
/// The two values are read from `Backend.plist` in the app bundle, which a build phase writes from
/// the build settings `Config/Backend.xcconfig` supplies. Neither is written as a Swift literal
/// anywhere: a fork, a staging project or a throwaway one is a change to that one file rather than
/// an edit to source.
///
/// A separate resource rather than `Info.plist` keys, and that is not a preference: with
/// `GENERATE_INFOPLIST_FILE = YES` an `INFOPLIST_KEY_<custom>` build setting is silently dropped —
/// only Apple's own keys are mapped — and setting `INFOPLIST_FILE` alongside it does not merge
/// either. Both were tried; both built cleanly and produced an app whose plist did not contain the
/// keys, which is the worst of the available failures.
///
/// **`fromBundle` returns nil rather than trapping.** A build with no backend configured is a
/// normal, working app — every phase-0 caller is optional at runtime by design, and a missing
/// Info.plist key must not be the first crash a walker sees (`AD-3`, `FR-ERR-09`).
///
/// **The service-role key is not here and may never be**, in any build configuration. It bypasses
/// RLS entirely; anything needing elevated access belongs in an Edge Function
/// (`03-security-privacy.md` §1).
struct BackendConfiguration: Sendable, Equatable {

    /// `https://<ref>.supabase.co`, with no trailing path.
    let baseURL: URL
    /// The **publishable** key. Designed to be public — RLS is what protects the data.
    let publishableKey: String

    static let resourceName = "Backend"
    static let urlInfoKey = "KultaraBackendURL"
    static let publishableKeyInfoKey = "KultaraBackendPublishableKey"

    init(baseURL: URL, publishableKey: String) {
        self.baseURL = baseURL
        self.publishableKey = publishableKey
    }

    init?(bundle: Bundle = .main) {
        guard let values = Self.values(in: bundle),
              let urlText = Self.string(values, Self.urlInfoKey),
              let url = URL(string: urlText),
              // A backend reached over anything but TLS is not one this app has (`NFR-SEC-01`), and
              // the kill-switch's entire trust model is TLS plus schema validation.
              url.scheme == "https",
              let key = Self.string(values, Self.publishableKeyInfoKey)
        else { return nil }
        self.init(baseURL: url, publishableKey: key)
    }

    /// The kill-switch document (`AD-5`, design §6.1). World-readable: this is fetched with no
    /// header at all, which is why phase 0 needs the URL and not the key.
    var suppressionsURL: URL {
        baseURL.appending(path: "storage/v1/object/public/content/suppressions.json")
    }

    /// Anonymous telemetry (design §6.2). `verify_jwt = false` by design, so this too carries no
    /// token and asks nobody to have an account.
    var ingestURL: URL {
        baseURL.appending(path: "functions/v1/ingest")
    }

    private static func values(in bundle: Bundle) -> [String: Any]? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return nil }
        return plist as? [String: Any]
    }

    private static func string(_ values: [String: Any], _ key: String) -> String? {
        guard let value = values[key] as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
