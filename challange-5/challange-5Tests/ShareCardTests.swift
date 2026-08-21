// `c2` phase 5. `FR-DONE-06`, `NFR-PRIV-02`, `03-security-privacy.md` §4.
import ContentKit
import DesignSystem
import Foundation
import Testing
@testable import challange_5

/// Phase 5 is **built and switched off**. These are the guards that make "off" a fact rather than a
/// claim, plus the two privacy rules the card itself has to hold if it is ever turned on.
@MainActor
struct ShareCardTests {

    /// The whole safety position in one assertion. Sharing is blocked on the consent question, not
    /// on engineering, and this is what keeps the engineering from shipping ahead of the answer.
    @Test func sharingIsOff() async {
        #expect(!NoShareCardMinting().isAvailable)
        #expect(!SupabaseShareCardMinting(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://example.invalid")!,
                publishableKey: "sb_publishable_test"),
            session: UnconfiguredSupabaseSession(),
            deviceID: { UUID() }).isAvailable)
    }

    /// And off means nothing is minted, not that a link is minted and hidden.
    @Test func mintingAnythingWhileOffProducesNoLink() async {
        let minter = SupabaseShareCardMinting(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://example.invalid")!,
                publishableKey: "sb_publishable_test"),
            session: UnconfiguredSupabaseSession(),
            deviceID: { UUID() })
        let url = await minter.mint(ShareCardDraft(
            runID: UUID(), png: Data(), template: "recap-v1"))
        #expect(url == nil)
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
