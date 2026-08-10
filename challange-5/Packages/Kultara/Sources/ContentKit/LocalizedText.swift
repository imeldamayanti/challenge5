import Foundation

/// The two languages v1 ships at full parity (`NFR-I18N-02`).
public enum ContentLanguage: String, Codable, Sendable, CaseIterable {
    case id
    case en

    /// The BCP 47 primary subtags iOS may report for each. Indonesian has a legacy code,
    /// `in`, which older locales and some devices still surface; treating it as unknown
    /// would silently push Indonesian speakers onto the English build (`FR-ONB-05`).
    public var languageCodes: [String] {
        switch self {
        case .id: ["id", "in"]
        case .en: ["en"]
        }
    }
}

public enum LocalizedTextError: Error, Equatable, Sendable {
    /// A translation was present as a key but carried no readable text.
    case emptyTranslation(language: ContentLanguage)
}

/// Every user-facing string in content is a pair, never a bare string, so an Indonesian/English
/// parity gap is a structural error the loader and the validator can both see (`schema.md` §A.2).
///
/// There is deliberately **no fallback**. `NFR-I18N-03` forbids mixing languages within a
/// passage under any condition, and a fallback is precisely the mechanism that would do it —
/// one untranslated sentence in the middle of Indonesian lore. A gap fails the decode instead,
/// which fails the validator, which fails the build.
public struct LocalizedText: Codable, Sendable, Equatable, Hashable {
    /// Bahasa Indonesia.
    public let id: String
    public let en: String

    public init(id: String, en: String) {
        self.id = id
        self.en = en
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A missing key throws `DecodingError.keyNotFound` from `decode(_:forKey:)` — the
        // parity gap surfaces as a decode failure without any help from us.
        id = try container.decode(String.self, forKey: .id)
        en = try container.decode(String.self, forKey: .en)

        // A present-but-blank translation is the same gap wearing a disguise.
        if id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LocalizedTextError.emptyTranslation(language: .id)
        }
        if en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LocalizedTextError.emptyTranslation(language: .en)
        }
    }

    public func value(for language: ContentLanguage) -> String {
        switch language {
        case .id: id
        case .en: en
        }
    }
}
