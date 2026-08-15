import Testing
@testable import DesignSystem

/// The story reveal's packaged background art. Without this test the resource can be dropped from
/// `Package.swift` and the screen quietly degrades to its plain-colour fallback on a page nobody
/// opens during review — the same failure mode `PortraitFrameTests` and `TypewriterTests` guard.
@Suite("Story illustration")
struct StoryIllustrationTests {

    @Test func illustrationResourceIsPackaged() {
        #expect(StoryIllustrationMetrics.isAvailable)
    }
}
