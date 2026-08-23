import Auth
import AuthenticationServices
import CommonCrypto
import Foundation
import RunEngine

/// Turning an anonymous walker into one who can come back on another phone. `c2` phase 6.
///
/// **This is the credential, not the session.** The session has existed since phase 1 and is what
/// every row is written under; this attaches an identity to it so a reinstall can find those rows
/// again — which is the entire reason phases 3, 4 and 7 are worth having.
///
/// `enable_manual_linking = false` in `config.toml`, deliberately: linking goes through the
/// deployed `merge-anonymous` function, which validates both tokens server-side before it moves a
/// single row. A client that could link identities itself would be a client that could move
/// somebody else's rows by asking nicely.
nonisolated protocol CredentialLinking: Sendable {
    /// Signs in with the identity token Apple just issued, merging the anonymous account's rows
    /// into it. Answers what happened, in the walker's terms.
    func signInWithApple(
        idToken: String, nonce: String, givenName: String?, familyName: String?
    ) async -> CredentialOutcome
    /// The display name this walker's account already carries server-side, if any. Apple hands its
    /// name over only on the very first authorisation and never again, so the account itself is
    /// the only place a later sign-in can recover one from.
    func storedDisplayName() async -> String?
    /// Forgets the credential and returns to walking anonymously. Local only.
    func signOut() async
}

nonisolated enum CredentialOutcome: Sendable, Equatable {
    /// Signed in, and the anonymous walk history came with them.
    case signedInAndMerged
    /// Signed in, but the merge did not run — the walks made anonymously on this device are still
    /// on the anonymous account and are **not** lost, they are just not attached to this identity.
    /// Distinguished from success because it is the one outcome a walker may need to hear about.
    case signedInWithoutMerge
    case failed
}

nonisolated struct SupabaseCredentialLinking: CredentialLinking {

    let configuration: BackendConfiguration
    let session: any SupabaseSessionProviding
    let client: AuthClient
    /// Whether the telemetry queue has been flushed. `merge-anonymous` refuses to run while the
    /// anonymous account may still receive writes (`anon_queue_empty`), and lying about it would
    /// move rows out from under a queue that is about to add more.
    let telemetryQueueIsEmpty: @Sendable () -> Bool
    let urlSession: URLSession

    init(
        configuration: BackendConfiguration,
        session: any SupabaseSessionProviding,
        client: AuthClient,
        telemetryQueueIsEmpty: @escaping @Sendable () -> Bool,
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
        self.client = client
        self.telemetryQueueIsEmpty = telemetryQueueIsEmpty
        self.urlSession = urlSession
    }

    func signInWithApple(
        idToken: String, nonce: String, givenName: String?, familyName: String?
    ) async -> CredentialOutcome {
        // Captured **before** the sign-in, because signing in replaces the session and the
        // anonymous token is the thing `merge-anonymous` needs in order to know what to move.
        let anonymousToken = await session.accessToken()

        do {
            _ = try await client.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
        } catch {
            return .failed
        }

        // Apple hands its name over once and never again, so the account is where it is kept —
        // `raw_user_meta_data`, merged rather than replaced, read back by `storedDisplayName` on
        // every later sign-in that arrives without one. `full_name`/`given_name`/`family_name`
        // are the keys Supabase's own docs use, and `display_name` now carries the whole name too:
        // it used to hold the given name alone, back when that was what the Explorer's Card headed
        // its reader by, and a stored half-name is what a later sign-in would have read back.
        // Fire-and-forget: the entry flow never waits on the network, and a failed save costs a
        // walker their role-named card, not their walks.
        Self.debugTrace("apple name from sheet: given=\(givenName ?? "nil") family=\(familyName ?? "nil")")
        if givenName != nil || familyName != nil {
            var data: [String: AnyJSON] = [:]
            if let givenName { data["given_name"] = .string(givenName) }
            if let familyName { data["family_name"] = .string(familyName) }
            let whole = [givenName, familyName].compactMap(\.self).joined(separator: " ")
            if !whole.isEmpty {
                data["full_name"] = .string(whole)
                data["display_name"] = .string(whole)
            }
            Task { [client] in
                do {
                    _ = try await client.update(user: .init(data: data))
                    Self.debugTrace("apple name update: ok \(data.keys.sorted().joined(separator: ","))")
                } catch {
                    Self.debugTrace("apple name update FAILED: \(error)")
                }
            }
        }

        #if DEBUG
        if givenName == nil && familyName == nil {
            Self.debugTrace(
                "apple handed no name — expected on repeat authorisations; revoke in "
                + "Settings → Sign-In & Security → Sign in with Apple to receive one again")
        }
        #endif

        guard let anonymousToken, telemetryQueueIsEmpty() else {
            // Nothing to merge, or the queue is not settled. The walker is signed in either way,
            // and their anonymous walks are still where they were.
            return .signedInWithoutMerge
        }
        return await merge(anonymousToken: anonymousToken) ? .signedInAndMerged : .signedInWithoutMerge
    }

    /// The name the account carries, read from the same metadata the sign-in above writes. A fetch
    /// that fails is the offline case and answers `nil`, never an error — the caller has a role-named
    /// card to fall back to and no reason to be told.
    ///
    /// **Four keys, not one.** Reading `display_name` alone answered nil for every account whose
    /// metadata was written by something other than the branch above — an account Supabase populated
    /// from the identity token's own claims (`name`), or one saved by a build that wrote the parts
    /// and not the join. A walker in that state signs in successfully and still reads "Explorer",
    /// which is the symptom this exists to close. The order prefers the whole name, then the parts,
    /// and takes `display_name` last precisely because older builds left the given name alone there.
    func storedDisplayName() async -> String? {
        guard let user = try? await client.user() else { return nil }
        let metadata = user.userMetadata
        func text(_ key: String) -> String? {
            let value = metadata[key]?.stringValue?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty ?? true) ? nil : value
        }
        if let whole = text("full_name") ?? text("name") { return whole }
        let parts = [text("given_name"), text("family_name")].compactMap(\.self)
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return text("display_name")
    }

    /// One line in the same debug trace file `ConsoleSupabaseLogger` writes, so what Apple handed
    /// over and whether the metadata save landed are readable next to the SDK's own account of the
    /// sign-in. Release builds compile none of it — same rule as every other trace here.
    private nonisolated static func debugTrace(_ line: String) {
        #if DEBUG
        guard let directory = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true) else { return }
        let url = directory.appendingPathComponent("supabase-trace.log")
        let entry = Data("\(Date()) [apple-name] \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: entry)
        } else {
            try? entry.write(to: url)
        }
        #endif
    }

    func signOut() async {
        await session.signOut()
    }

    /// `POST /functions/v1/merge-anonymous`, `verify_jwt = true` — the new identity's own JWT
    /// authorises the call and the anonymous token is the argument. Both are verified server-side
    /// before a row moves; the function is idempotent, so a retry is safe.
    private func merge(anonymousToken: String) async -> Bool {
        guard let token = await session.accessToken() else { return false }
        var request = URLRequest(url: configuration.functionURL("merge-anonymous"))
        request.httpMethod = "POST"
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "anon_access_token": anonymousToken,
            "anon_queue_empty": true,
        ])
        guard let (_, response) = try? await urlSession.data(for: request),
              let http = response as? HTTPURLResponse
        else { return false }
        return (200..<300).contains(http.statusCode)
    }
}

/// What the app uses with no backend, and what the tests use by default.
nonisolated struct NoCredentialLinking: CredentialLinking {
    func signInWithApple(
        idToken: String, nonce: String, givenName: String?, familyName: String?
    ) async -> CredentialOutcome { .failed }
    func storedDisplayName() async -> String? { nil }
    func signOut() async {}
}

/// The nonce Apple's flow requires, and the one detail of it that is easy to get subtly wrong.
///
/// Apple signs the **SHA-256 of** the nonce into the identity token, and Supabase compares the raw
/// nonce against that hash. So the request carries the hash and the verification carries the raw
/// value — sending the same string to both is the mistake, and it fails with a message about an
/// invalid token that says nothing about nonces.
nonisolated enum AppleSignInNonce {
    static func make() -> (raw: String, hashed: String) {
        let raw = randomString(length: 32)
        return (raw, sha256(raw))
    }

    private static func randomString(length: Int) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { characters[Int($0) % characters.count] })
    }

    private static func sha256(_ input: String) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        let data = Data(input.utf8)
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
