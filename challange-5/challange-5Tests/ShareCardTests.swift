// `c2` phase 5. `FR-DONE-06`, `NFR-PRIV-02`, `03-security-privacy.md` §4.
import ContentKit
import DesignSystem
import Foundation
import Testing
@testable import challange_5

/// **Phase 5 was switched on 2026-08-21**, at the owner's explicit instruction, over the consent
/// caveat: `docs/consent-log.md` still records the five sites' consent as a self-grant nobody has
/// asked them to sign. `supabase/functions/share/` is deployed and smoke-tested on prod. These
/// tests guard the shape of "on" now — a configured backend mints, an unconfigured one still
/// cannot — plus the privacy rules the card holds regardless of the switch.
@MainActor
struct ShareCardTests {

    /// The no-backend case is the one that must always stay off: there is nothing to mint against.
    /// This is not the consent switch — see the type's doc comment for that history.
    @Test func withNoBackendSharingIsUnavailable() async {
        #expect(!NoShareCardMinting().isAvailable)
    }

    /// A configured backend is available now that the function is deployed.
    @Test func withABackendConfiguredSharingIsAvailable() async {
        #expect(SupabaseShareCardMinting(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://example.invalid")!,
                publishableKey: "sb_publishable_test"),
            session: UnconfiguredSupabaseSession(),
            deviceID: { UUID() }).isAvailable)
    }

    /// Available does not mean unconditional: with no session there is still no token to mint
    /// with, and `mint` answers nil rather than trying an unauthenticated write.
    @Test func withNoSessionMintingProducesNoLinkEvenWhenAvailable() async {
        let minter = SupabaseShareCardMinting(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://example.invalid")!,
                publishableKey: "sb_publishable_test"),
            session: UnconfiguredSupabaseSession(),
            deviceID: { UUID() })
        #expect(minter.isAvailable)
        let url = await minter.mint(ShareCardDraft(
            runID: UUID(), png: Data(), template: "recap-v1"))
        #expect(url == nil)
    }

    /// `TripSummaryScreen`'s "Stop sharing" control depends on this: with no session there is no
    /// token to revoke with, and a caller that got `true` back for a call that touched nothing
    /// would think a link stopped working when it did not.
    @Test func withNoSessionRevokingAnswersFalseRatherThanClaimingSuccess() async {
        let minter = SupabaseShareCardMinting(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://example.invalid")!,
                publishableKey: "sb_publishable_test"),
            session: UnconfiguredSupabaseSession(),
            deviceID: { UUID() })
        #expect(await minter.revoke(runID: UUID()) == false)
    }

    /// A slug is the only thing between a stranger and a walker's card, so it is length rather
    /// than prettiness: 32 characters over a 64-symbol alphabet is 192 bits.
    @Test func slugsAreLongUnpredictableAndURLSafe() {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        var seen = Set<String>()
        for _ in 0..<200 {
            let slug = SupabaseShareCardMinting.slug()
            #expect(slug.count == 32)
            #expect(slug.unicodeScalars.allSatisfy(allowed.contains))
            seen.insert(slug)
        }
        #expect(seen.count == 200)
    }

    /// It has to actually produce an image, or every rule above is about nothing.
    @Test func theCardRendersToPNGBytes() throws {
        let card = ShareCardArtwork(
            questTitle: "The Last Traces of Badung",
            placeNames: ["Puri Agung Pemecutan", "Pura Maospahit"],
            stampCount: 2,
            dayText: "21 August 2026",
            reflections: [],
            language: .en,
            palette: HisploraPalette.standard)
        let data = try #require(card.pngData())
        #expect(data.count > 1_000)
        // PNG magic, so a zero-byte or JPEG answer cannot pass as a render.
        #expect(data.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
    }
}
