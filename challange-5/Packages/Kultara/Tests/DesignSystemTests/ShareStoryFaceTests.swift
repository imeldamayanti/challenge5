import Testing
@testable import DesignSystem

/// The two faces the share-story postcard is set in (`921:2654`, `921:2960`). Both are resources,
/// and a resource that stops shipping degrades silently — the card still renders, it just stops
/// being the design. `theTypewriterFaceRegisters` exists for the same reason; these are its
/// postcard counterparts.
@Suite("ShareStoryFaces")
struct ShareStoryFaceTests {

    /// Bodoni Moda sets the postcard's printed labels. The fallback is a system serif, which is a
    /// legitimate state — but only if somebody decided it, not because the TTF quietly failed to
    /// ship.
    @Test func bodoniModaRegisters() {
        #expect(KultaraFonts.bodoniIsAvailable,
                "Bodoni Moda did not register; the card's printing falls back to the system serif")
    }

    /// Shadows Into Light Two stands in for the walker's handwriting.
    @Test func shadowsIntoLightTwoRegisters() {
        #expect(KultaraFonts.handwritingIsAvailable,
                "Shadows Into Light Two did not register; the handwriting falls back to SF Pro rounded")
    }
}
