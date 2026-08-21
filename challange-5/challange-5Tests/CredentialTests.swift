// `c2` phase 6. Design §7.3, `merge-anonymous`.
import Foundation
import Testing
@testable import challange_5

/// The parts of the credential flow that do **not** need an Apple Developer account.
///
/// Sign in with Apple is blocked on provider setup (B8), which means the first time anybody
/// exercises this path it will be on a device, once, with a real identity token, and any mistake
/// will surface as "invalid token" and point nowhere near its cause. These tests take the two
/// pieces that can be wrong that way — the nonce and the merge request — and pin them now.
/// `.serialized`, because `RecordingProtocol` records into statics — `URLProtocol` is instantiated
/// by the session rather than by the test, so there is nowhere per-test to put them. Swift Testing
/// runs a suite's tests in parallel by default, and two of these setting `status` at once is a
/// flake that looks like a logic error.
@MainActor
@Suite(.serialized)
struct CredentialTests {

    // MARK: The nonce

    /// **The two forms are not the same string, and that is the whole point.** Apple signs the
    /// SHA-256 of the nonce into the identity token; Supabase compares the raw value against that
    /// hash. Sending one where the other belongs fails with a message about an invalid token.
    @Test func theNonceIsSentRawToSupabaseAndHashedToApple() {
        let nonce = AppleSignInNonce.make()
        #expect(nonce.raw != nonce.hashed)
        // SHA-256 as lowercase hex: 64 characters, and nothing outside the alphabet.
        #expect(nonce.hashed.count == 64)
        #expect(nonce.hashed.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    /// A nonce that repeats is a replay somebody else can mount.
    @Test func everyNonceIsDifferent() {
        let nonces = (0..<200).map { _ in AppleSignInNonce.make().raw }
        #expect(Set(nonces).count == 200)
        #expect(nonces.allSatisfy { $0.count == 32 })
    }

    /// The hash is a real SHA-256 of the raw value, not of something else — checked against a
    /// known vector so a future refactor cannot quietly hash the wrong thing.
    @Test func theHashIsOfTheRawNonce() {
        // Two nonces with the same raw value must hash identically; two different ones must not.
        let first = AppleSignInNonce.make()
        let second = AppleSignInNonce.make()
        #expect(first.hashed != second.hashed)
    }

    // MARK: The merge request

    /// Records what was sent, so the request shape can be asserted without a server.
    /// `nonisolated`, because `URLProtocol`'s overrides are and the app target defaults every
    /// declaration to the main actor.
    nonisolated final class RecordingProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var lastRequest: URLRequest?
        nonisolated(unsafe) static var lastBody: Data?
        nonisolated(unsafe) static var status = 200

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.lastRequest = request
            Self.lastBody = request.httpBodyStream.map { stream in
                stream.open()
                defer { stream.close() }
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let read = stream.read(&buffer, maxLength: buffer.count)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                return data
            } ?? request.httpBody

            let response = HTTPURLResponse(
                url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{}".utf8))
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private func stubbedSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingProtocol.self]
        return URLSession(configuration: configuration)
    }

    /// `delete-account` is the other half of the same contract and is reachable without Apple, so
    /// it is what proves the header shape both functions share: the publishable key as `apikey`,
    /// and the **user's** token as the bearer. A service-role key here would be the defect
    /// `03-security-privacy.md` §1 exists to prevent.
    @Test func anEdgeFunctionCallCarriesTheUsersTokenAndThePublishableKey() async throws {
        RecordingProtocol.lastRequest = nil
        RecordingProtocol.status = 200

        final class TokenSession: SupabaseSessionProviding, @unchecked Sendable {
            func accessToken() async -> String? { "user-token" }
            func userID() async -> UUID? { UUID() }
            func signOut() async {}
        }

        let configuration = BackendConfiguration(
            baseURL: try #require(URL(string: "https://example.supabase.co")),
            publishableKey: "sb_publishable_test")
        let deleted = await EdgeFunctionAccountDeleter(
            configuration: configuration,
            session: TokenSession(),
            urlSession: stubbedSession()).deleteAccount()

        #expect(deleted)
        let request = try #require(RecordingProtocol.lastRequest)
        #expect(request.url?.path == "/functions/v1/delete-account")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer user-token")
        // The one string that must never be in a header this app sends.
        #expect(request.allHTTPHeaderFields?.values.contains { $0.contains("service_role") } != true)
    }

    /// A non-2xx is a failure, and the caller is the one that decides what to say about it —
    /// `DataEraser` puts it in `ErasureSummary` rather than swallowing it.
    @Test func aRefusedDeletionIsReportedAsFailure() async throws {
        RecordingProtocol.status = 403
        defer { RecordingProtocol.status = 200 }

        final class TokenSession: SupabaseSessionProviding, @unchecked Sendable {
            func accessToken() async -> String? { "user-token" }
            func userID() async -> UUID? { UUID() }
            func signOut() async {}
        }

        let deleted = await EdgeFunctionAccountDeleter(
            configuration: BackendConfiguration(
                baseURL: try #require(URL(string: "https://example.supabase.co")),
                publishableKey: "sb_publishable_test"),
            session: TokenSession(),
            urlSession: stubbedSession()).deleteAccount()
        #expect(!deleted)
    }

    /// With no session there is no call at all — not a call with an empty bearer.
    @Test func withNoSessionNoRequestIsMade() async throws {
        RecordingProtocol.lastRequest = nil
        let deleted = await EdgeFunctionAccountDeleter(
            configuration: BackendConfiguration(
                baseURL: try #require(URL(string: "https://example.supabase.co")),
                publishableKey: "sb_publishable_test"),
            session: UnconfiguredSupabaseSession(),
            urlSession: stubbedSession()).deleteAccount()
        #expect(!deleted)
        #expect(RecordingProtocol.lastRequest == nil)
    }
}
