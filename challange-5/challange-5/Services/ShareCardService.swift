import Foundation
import PostgREST
import RunEngine
import Storage

/// Minting and revoking a shareable recap card. `c2` phase 5.
///
/// **The engineering is done and the feature is off.** Phase 5 is blocked on the consent position
/// (`c2-wiring/03-security-privacy.md` §4): publishing a walk publishes five sites whose consent
/// records are a self-grant nobody has been asked to sign. The serve function
/// (`supabase/functions/share/`) is written and **not deployed**, and `isAvailable` is what keeps
/// this unreachable until somebody decides otherwise — one flag rather than commented-out code, so
/// turning it on is a decision and not an excavation.
nonisolated protocol ShareCardMinting: Sendable {
    /// Whether sharing is switched on at all. `false` today, deliberately.
    var isAvailable: Bool { get }
    /// Renders, uploads and mints. Answers the public URL, or nil.
    func mint(_ card: ShareCardDraft) async -> URL?
    /// Stops the link working on the **next request**, not the next cache expiry.
    func revoke(runID: UUID) async -> Bool
}

/// Everything the card needs, already resolved from the Run's own snapshots by the caller.
nonisolated struct ShareCardDraft: Sendable {
    let runID: UUID
    /// PNG bytes, rendered at `ShareCardArtwork.size`.
    let png: Data
    /// The template the card was drawn with, so a future one can be told apart in the table.
    let template: String
}

nonisolated struct SupabaseShareCardMinting: ShareCardMinting {

    static let bucket = "share-cards"

    let configuration: BackendConfiguration
    let session: any SupabaseSessionProviding
    let deviceID: @Sendable () -> UUID

    /// **Off.** See the type's note. Flipping this without deploying `supabase/functions/share/`
    /// mints links that 404, which is a worse failure than the feature being absent.
    var isAvailable: Bool { false }

    func mint(_ card: ShareCardDraft) async -> URL? {
        guard isAvailable,
              let token = await session.accessToken(),
              let userID = await session.userID()
        else { return nil }

        let id = UUID()
        let slug = Self.slug()
        // Same prefix rule as `trip-photos`: `{user_id}/…` is what the bucket's policy checks, and
        // the bucket is not part of the object name.
        let path = "\(userID.uuidString.lowercased())/\(id.uuidString.lowercased()).png"

        let headers = [
            "apikey": configuration.publishableKey,
            "Authorization": "Bearer \(token)",
        ]
        let storage = SupabaseStorageClient(configuration: .init(
            url: configuration.storageURL, headers: headers))
        let database = PostgrestClient(
            url: configuration.restURL, schema: "app", headers: headers,
            encoder: SyncWireFormat.encoder, decoder: SyncWireFormat.decoder)

        // Bytes before the row, which is the opposite of `app.photos` and deliberate: a photograph
        // with no bytes is an orphan the sweeper can find, but a *share row* with no bytes is a
        // live link that serves nothing to whoever the walker just sent it to.
        guard (try? await storage.from(Self.bucket).upload(
            path, data: card.png,
            options: FileOptions(contentType: "image/png", upsert: true))) != nil
        else { return nil }

        let row = ShareCardRow(
            id: id, userID: userID, runID: card.runID, template: card.template,
            storagePath: path, slug: slug, deviceID: deviceID())
        guard (try? await database.from("share_cards").upsert(row).execute()) != nil else {
            return nil
        }
        return configuration.functionURL("share").appending(path: slug)
    }

    func revoke(runID: UUID) async -> Bool {
        guard let token = await session.accessToken() else { return false }
        let database = PostgrestClient(
            url: configuration.restURL, schema: "app",
            headers: [
                "apikey": configuration.publishableKey,
                "Authorization": "Bearer \(token)",
            ],
            encoder: SyncWireFormat.encoder, decoder: SyncWireFormat.decoder)

        // **The revision bump is what makes this work at all.** Without it
        // `resolve_sync_conflict` reads the update as an idempotent retry and returns null — the
        // row is untouched, PostgREST answers 200, and the walker is told the link is off while it
        // keeps serving. See `SyncConflictTrigger`; a local test found this.
        guard let revision = await SyncConflictTrigger.nextRevision(
            table: "share_cards", idColumn: "run_id", id: runID, client: database)
        else { return false }

        // `revoked_at` rather than a delete: the serve function checks it per request, so the link
        // stops on the next fetch, and the record that a card was ever shared survives — which is
        // the thing a walker might want to see.
        return (try? await database.from("share_cards")
            .update([
                "revoked_at": SyncWireFormat.formatter.string(from: Date()),
                "revision": "\(revision)",
            ])
            .eq("run_id", value: runID.uuidString)
            .execute()) != nil
    }

    /// 32 characters from a 64-symbol alphabet — 192 bits. A slug is the *only* thing standing
    /// between a stranger and a walker's card, so it is guessed-at length rather than pretty.
    static func slug() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }
}

nonisolated struct ShareCardRow: Codable, Sendable, Equatable {
    let id: UUID
    let user_id: UUID
    let run_id: UUID
    let template: String
    let storage_path: String
    let public_slug: String
    let device_id: UUID

    init(
        id: UUID, userID: UUID, runID: UUID, template: String,
        storagePath: String, slug: String, deviceID: UUID
    ) {
        self.id = id
        user_id = userID
        run_id = runID
        self.template = template
        storage_path = storagePath
        public_slug = slug
        device_id = deviceID
    }
}

/// What the app uses. Sharing is off; `mint` answers nil and the Trip pages keep handing over
/// plain text, exactly as they did before this file existed.
nonisolated struct NoShareCardMinting: ShareCardMinting {
    var isAvailable: Bool { false }
    func mint(_ card: ShareCardDraft) async -> URL? { nil }
    func revoke(runID: UUID) async -> Bool { false }
}
