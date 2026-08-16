import Foundation
import Testing
@testable import DesignSystem

/// `NFR-A11Y-02`, `NFR-A11Y-06` — the room a scrolling screen leaves for the floating tab bar has
/// to grow with the text, because the bar does.
///
/// The bug this holds: the clearance was a fixed 88 points while `KultaraTabBar` is a `minHeight`
/// that grows with its labels. At the largest accessibility size the bar is roughly 210 points
/// tall, the last control on a scrolling screen came to rest underneath it, and a tap on that
/// control's centre belonged to the bar — so tapping "Settings" switched to the Journal tab
/// instead of opening Settings. It reached the simulator; nothing but a test at this level would
/// have caught it, because the rule cannot live in a view the app target can test.
@Suite("Floating tab bar clearance")
struct FloatingTabBarClearanceTests {

    /// The default size is exactly what the design drew: 64 for the pill, 8 under it, 16 of air.
    @Test func theDefaultSizeIsUnchanged() {
        #expect(KultaraMetrics.floatingTabBarClearance(labelScale: 1)
                == KultaraMetrics.floatingTabBarClearance)
    }

    /// Smaller text does not license less room than the design drew. The bar has a *minimum*
    /// height, so shrinking the labels does not shrink it.
    @Test func smallerTextDoesNotShrinkTheClearance() {
        for scale in [0.1, 0.5, 0.85, 0.999] {
            #expect(KultaraMetrics.floatingTabBarClearance(labelScale: scale)
                    == KultaraMetrics.floatingTabBarClearance)
        }
    }

    /// The whole point: at every accessibility scale the clearance is at least as tall as the bar
    /// that has to fit under it. A control resting inside that band is a control whose centre the
    /// bar owns.
    @Test func theClearanceAlwaysExceedsTheBarItClears() {
        for scale in stride(from: 1.0, through: 3.6, by: 0.1) {
            let barHeight = KultaraMetrics.floatingTabBarContentHeight * scale + KultaraMetrics.sm
            let clearance = KultaraMetrics.floatingTabBarClearance(labelScale: scale)
            #expect(clearance > barHeight,
                    "At scale \(scale) the clearance \(clearance) does not clear \(barHeight)")
        }
    }

    /// Monotonic — a larger text size never buys less room.
    @Test func theClearanceNeverDecreasesAsTextGrows() {
        var previous = KultaraMetrics.floatingTabBarClearance(labelScale: 1)
        for scale in stride(from: 1.0, through: 3.6, by: 0.05) {
            let clearance = KultaraMetrics.floatingTabBarClearance(labelScale: scale)
            #expect(clearance >= previous)
            previous = clearance
        }
    }

    /// The size the failure was found at. AX5 runs a caption at roughly 3.1× its default, which is
    /// the case the fixed 88 could not survive.
    @Test func theLargestAccessibilitySizeGetsRoomForTheWholeBar() {
        let clearance = KultaraMetrics.floatingTabBarClearance(labelScale: 3.1)
        #expect(clearance > 200)
        #expect(clearance > KultaraMetrics.floatingTabBarClearance * 2)
    }
}
