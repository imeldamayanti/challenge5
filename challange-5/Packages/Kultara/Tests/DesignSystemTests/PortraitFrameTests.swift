import SwiftUI
import Testing
@testable import DesignSystem

/// The frame's geometry is the whole component — a portrait placed a few percent off sits visibly
/// crooked inside a carved opening, and that is not something a screenshot review catches reliably.
@Suite("Portrait frame")
struct PortraitFrameTests {

    /// The ornament ships. Without this test the resource can be dropped from `Package.swift` and the
    /// app degrades to a plain oval on a screen nobody opens during review.
    @Test func ornamentResourceIsPackaged() {
        #expect(PortraitFrameMetrics.ornamentIsAvailable)
    }

    @Test func frameKeepsTheDesignsProportions() {
        #expect(abs(PortraitFrameMetrics.aspectRatio - 0.8) < 0.0001)
    }

    /// The two instances in the design draw the same group at 360 × 450 and at 320 × 400. If the
    /// ratios taken from one do not reproduce the other, they were rounding, not proportions.
    @Test func openingRatiosReproduceBothDrawnInstances() {
        let origin = PortraitFrameMetrics.openingOrigin
        let size = PortraitFrameMetrics.openingSize

        // `98:1588` — group at (21, 258) 360 × 450, opening at (77.25, 317.0625) 260.156 × 331.875.
        #expect(abs(origin.x * 360 - 56.25) < 0.05)
        #expect(abs(origin.y * 450 - 59.0625) < 0.05)
        #expect(abs(size.width * 360 - 260.156) < 0.05)
        #expect(abs(size.height * 450 - 331.875) < 0.05)

        // `187:866` — group at (41, 82.5) 320 × 400, opening at (91, 135) 231.25 × 295.
        #expect(abs(origin.x * 320 - 50) < 0.05)
        #expect(abs(origin.y * 400 - 52.5) < 0.05)
        #expect(abs(size.width * 320 - 231.25) < 0.05)
        #expect(abs(size.height * 400 - 295) < 0.05)
    }

    /// The opening sits inside the frame with room for the carving on every side. A ratio typo that
    /// pushed it past an edge would otherwise only show as a portrait bleeding over the gilt.
    @Test func openingStaysInsideTheFrame() {
        let origin = PortraitFrameMetrics.openingOrigin
        let size = PortraitFrameMetrics.openingSize

        #expect(origin.x > 0)
        #expect(origin.y > 0)
        #expect(origin.x + size.width < 1)
        #expect(origin.y + size.height < 1)
    }
}
