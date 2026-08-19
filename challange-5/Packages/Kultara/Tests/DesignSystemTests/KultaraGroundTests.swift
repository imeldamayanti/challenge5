import Testing
import SwiftUI
@testable import DesignSystem

struct KultaraGroundTests {
    /// The sheet ships. Without this test the resource can be dropped from `Package.swift` and every
    /// museum screen quietly flattens to the plain token, which looks deliberate.
    @Test func groundResourceIsPackaged() {
        #expect(KultaraGround.isAvailable)
    }

    /// The dark gap is a decision, not a bug. The artwork is a cream sheet with no dark counterpart,
    /// so dark appearance keeps the flat token rather than showing a light ground under light ink.
    @Test func darkAppearanceGetsNoSheet() {
        #expect(KultaraGround.sheet(for: .dark) == nil)
    }

    /// The speckle is texture, not pattern — `KultaraThemeTests` measures the token, and a sheet
    /// dense enough to obscure it would make every one of those numbers describe something other
    /// than what is on screen.
    ///
    /// Measured on the *combination*, not on `opacity` alone. The design's own alpha is baked into
    /// the render and the sheet is opaque, so an opacity assertion would now pass or fail for the
    /// wrong reason; the density lives in the artwork's coverage instead.
    @Test func theSpeckleStaysBelowTheRatioMovingRange() {
        #expect(KultaraGround.opacity > 0)
        #expect(KultaraGround.opacity <= 1)
        #expect(KultaraGround.speckleCoverage > 0, "a ground that speckles nothing is not shipping")
        #expect(KultaraGround.speckleInkCoverage <= 0.05)
    }

    /// The stock the render is printed on *is* the token. If they drift, every ratio
    /// `KultaraThemeTests` reports stops describing the sheet a reader is looking at — which is the
    /// whole reason the artwork is drawn over the colour rather than instead of it.
    @Test func theSheetsStockIsThePaperToken() {
        #expect(KultaraTheme.light.paper == SRGBColor(hex: "#FDF2DE"))
    }
}
