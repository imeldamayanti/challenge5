import Foundation

/// The published kill-switch document (`schema.md` §A.8, `AD-5`).
///
/// One static JSON file, fetched over TLS, listing what has been withdrawn. It is the only thing
/// the running app is told by a server, and it is deliberately the smallest possible thing: three
/// arrays of ids and a version.
public struct SuppressionsDocument: Codable, Sendable, Equatable {

    /// The version this client understands. A **higher** number is not a failure — see the decoder.
    public static let supportedSchemaVersion = 2

    public let schemaVersion: Int
    public let updatedAt: String
    public let suppressedPlaceIDs: [String]
    public let suppressedQuestIDs: [String]
    public let suppressedSideQuestIDs: [String]

    public static let empty = SuppressionsDocument(
        schemaVersion: supportedSchemaVersion,
        updatedAt: "",
        suppressedPlaceIDs: [],
        suppressedQuestIDs: [],
        suppressedSideQuestIDs: [])

    public init(
        schemaVersion: Int,
        updatedAt: String,
        suppressedPlaceIDs: [String],
        suppressedQuestIDs: [String],
        suppressedSideQuestIDs: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.suppressedPlaceIDs = suppressedPlaceIDs
        self.suppressedQuestIDs = suppressedQuestIDs
        self.suppressedSideQuestIDs = suppressedSideQuestIDs
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case updatedAt
        case suppressedPlaceIDs = "suppressedPlaceIds"
        case suppressedQuestIDs = "suppressedQuestIds"
        case suppressedSideQuestIDs = "suppressedSideQuestIds"
    }

    /// The load-bearing decode (`c1` D3).
    ///
    /// `suppressedSideQuestIds` arrived with schema 2 and is decoded as `decodeIfPresent ?? []`.
    /// A schema-1 document — a rollback, an older publisher, a half-migrated environment — must
    /// still validate and simply carry no sidequests.
    ///
    /// Making it required would be the opposite of safe. A validation failure sends the app to its
    /// last good copy, so a schema-1 document reaching a schema-2 client would mean **a withdrawal
    /// silently stops applying** — the exact failure `AD-5` exists to prevent, arriving through the
    /// mechanism meant to prevent it. The two arrays that predate schema 2 stay required, because
    /// their absence is a malformed document rather than an older one.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decode(Int.self, forKey: .schemaVersion)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
        suppressedPlaceIDs = try c.decode([String].self, forKey: .suppressedPlaceIDs)
        suppressedQuestIDs = try c.decode([String].self, forKey: .suppressedQuestIDs)
        suppressedSideQuestIDs =
            try c.decodeIfPresent([String].self, forKey: .suppressedSideQuestIDs) ?? []
    }

    /// Structural validity beyond decoding: no empty ids, and a version this client can act on.
    ///
    /// A *newer* schema is accepted rather than rejected, for the same reason the sidequest array is
    /// optional: the arrays this client reads are still there and still mean what they meant, and
    /// refusing a document because it also carries something unfamiliar turns a forward-compatible
    /// addition into a kill-switch outage.
    public var isWellFormed: Bool {
        guard schemaVersion >= 1 else { return false }
        let everyID = suppressedPlaceIDs + suppressedQuestIDs + suppressedSideQuestIDs
        return everyID.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
