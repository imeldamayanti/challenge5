// `c2` phase 0. `NFR-SEC-01`, `03-security-privacy.md` §1.
import Foundation
import Testing
@testable import challange_5

/// The scheme rule, which is a security control rather than a parsing detail.
///
/// The kill-switch's whole trust model is TLS plus schema validation (design §5), so a backend
/// reached over cleartext removes half of it and leaves a document any network in between can
/// rewrite. The loopback exception exists so a suppression can be watched applying without holding
/// the production service-role key — the thing §1 forbids outright — and it is confined to `#if
/// DEBUG` and to loopback addresses.
@MainActor
struct BackendConfigurationTests {

    private func accepts(_ text: String) -> Bool {
        guard let url = URL(string: text) else { return false }
        return BackendConfiguration.isAcceptable(url)
    }

    @Test func tlsIsAlwaysAccepted() {
        #expect(accepts("https://ppwcxmvetmmwliusliac.supabase.co"))
    }

    @Test func cleartextIsRefusedForAnythingThatIsNotLoopback() {
        #expect(!accepts("http://ppwcxmvetmmwliusliac.supabase.co"))
        #expect(!accepts("http://192.168.1.10:54321"))
        #expect(!accepts("http://staging.internal:54321"))
        // The obvious way to smuggle a real host past a naive check.
        #expect(!accepts("http://127.0.0.1.evil.example:54321"))
        #expect(!accepts("ws://127.0.0.1:54321"))
    }

    /// `supabase start` serves `http://127.0.0.1:54321` and cannot be made to do otherwise.
    @Test func theLocalStackIsAcceptedInDebugAndOnlyInDebug() {
        #if DEBUG
        #expect(accepts("http://127.0.0.1:54321"))
        #expect(accepts("http://localhost:54321"))
        #else
        #expect(!accepts("http://127.0.0.1:54321"))
        #endif
    }

    /// The two paths the phase actually calls, built from the base URL rather than written out.
    @Test func theTwoEndpointsAreDerivedFromTheBaseURL() throws {
        let configuration = BackendConfiguration(
            baseURL: try #require(URL(string: "https://example.supabase.co")),
            publishableKey: "sb_publishable_test")
        #expect(configuration.suppressionsURL.absoluteString
            == "https://example.supabase.co/storage/v1/object/public/content/suppressions.json")
        #expect(configuration.ingestURL.absoluteString
            == "https://example.supabase.co/functions/v1/ingest")
    }
}
