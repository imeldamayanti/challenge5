import CoreGraphics
import Foundation
import Testing
@testable import DesignSystem

/// The rule that ends `98:1588` and moves the flow to `187:866`.
///
/// It is here rather than in a view test for the reason the whole package exists: "the walker has
/// rubbed enough of the picture away" is arithmetic over a grid, and arithmetic tested through a
/// simulator is arithmetic tested slowly and flakily.
@Suite("Scratch reveal field")
struct ScratchRevealFieldTests {

    private let size = CGSize(width: 360, height: 450)

    @Test func anUntouchedFieldIsCoveredAndUnfinished() {
        let field = ScratchRevealField()
        #expect(field.revealedFraction == 0)
        #expect(!field.isComplete)
    }

    /// The threshold is below 1.0 on purpose — the picture is clipped to an ellipse, so the corner
    /// cells are never part of it. A field that demanded every cell would strand the walker on the
    /// screen with the whole face already uncovered, which is the bug the constant exists to stop.
    @Test func theThresholdLeavesRoomForTheCornersAnEllipseNeverFills() {
        let ellipseFillOfItsBox = Double.pi / 4
        #expect(ScratchRevealField.defaultCompletionThreshold < ellipseFillOfItsBox)
    }

    @Test func oneTouchUncoversItsOwnNeighbourhoodAndNoMore() {
        var field = ScratchRevealField()
        field.reveal(at: CGPoint(x: 180, y: 225), in: size, brushRadius: 34)

        #expect(field.revealedFraction > 0)
        #expect(!field.isComplete)
    }

    /// A single swipe across the middle must not finish the reveal: the design asks the walker to
    /// wipe the frame, not to flick it.
    @Test func oneStraightSwipeAcrossTheMiddleIsNotEnough() {
        var field = ScratchRevealField()
        for step in 0...360 {
            field.reveal(at: CGPoint(x: CGFloat(step), y: 225), in: size, brushRadius: 34)
        }
        #expect(!field.isComplete)
    }

    @Test func rubbingTheWholeFrameFinishesIt() {
        var field = ScratchRevealField()
        for row in stride(from: 0, through: 450, by: 15) {
            for column in stride(from: 0, through: 360, by: 15) {
                field.reveal(
                    at: CGPoint(x: CGFloat(column), y: CGFloat(row)), in: size, brushRadius: 34)
            }
        }
        #expect(field.isComplete)
        #expect(field.revealedFraction == 1)
    }

    /// Crossing the same place again is not progress. Without the distinct-cell count a walker
    /// scrubbing one corner would "finish" a frame that is still covered.
    @Test func rubbingTheSameSpotTwiceAddsNothing() {
        var field = ScratchRevealField()
        field.reveal(at: CGPoint(x: 100, y: 100), in: size, brushRadius: 34)
        let afterFirst = field.revealedFraction
        for _ in 0..<50 {
            field.reveal(at: CGPoint(x: 100, y: 100), in: size, brushRadius: 34)
        }
        #expect(field.revealedFraction == afterFirst)
    }

    @Test func revealingEverythingFinishesItAtOnce() {
        var field = ScratchRevealField()
        field.revealEverything()
        #expect(field.revealedFraction == 1)
        #expect(field.isComplete)
    }

    /// The view hands over whatever the drag reports, including points outside the frame once a
    /// finger leaves it. Those must be ignored rather than indexing off the end of the grid.
    @Test func touchesOutsideTheFrameAreIgnored() {
        var field = ScratchRevealField()
        field.reveal(at: CGPoint(x: -500, y: -500), in: size, brushRadius: 34)
        field.reveal(at: CGPoint(x: 5_000, y: 5_000), in: size, brushRadius: 34)
        #expect(field.revealedFraction == 0)
    }

    @Test func aZeroSizedFrameIsNotADivideByZero() {
        var field = ScratchRevealField()
        field.reveal(at: .zero, in: .zero, brushRadius: 34)
        #expect(field.revealedFraction == 0)
    }
}
