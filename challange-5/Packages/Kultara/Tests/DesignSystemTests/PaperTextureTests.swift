import Testing
import SwiftUI
@testable import DesignSystem

struct PaperTextureTests {
    /// The grain ships. Without this test the resource can be dropped from `Package.swift` and every
    /// museum screen quietly flattens to the plain token, which looks deliberate.
    @Test func grainResourceIsPackaged() {
        #expect(KultaraPaperTexture.grainIsAvailable)
    }

    /// The dark gap is a decision, not a bug. The artwork is a cream sheet with no dark counterpart,
    /// so dark appearance keeps the flat token rather than showing a light ground under light ink.
    @Test func darkAppearanceGetsNoGrain() {
        #expect(KultaraPaperTexture.paperGrain(for: .dark) == nil)
    }

    /// The grain is texture, not pattern. Anything approaching opacity 1 would put a picture between
    /// the reader and `palette.paper`, and `KultaraThemeTests` measures the token, not the picture.
    @Test func grainStaysBelowTheRatioMovingRange() {
        #expect(KultaraPaperTexture.grainOpacity > 0)
        #expect(KultaraPaperTexture.grainOpacity <= 0.6)
    }
}
