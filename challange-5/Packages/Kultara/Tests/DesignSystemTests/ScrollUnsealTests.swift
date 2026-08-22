import CoreGraphics
import Foundation
import ImageIO
import Testing

@testable import DesignSystem

/// The transition screen's scroll unties itself and unrolls into the task sheet's parchment. Two
/// things hold that together and neither is visible in a screenshot: the order of the beats, and the
/// two roll fractions the sheet is sliced on. Both are asserted here.
@Suite struct ScrollUnsealTests {

    // MARK: The beats

    @Test func theBeatsRunInOneOrderAndEndAtOpen() {
        var stage = HisploraScrollUnsealStage.sealed
        var seen: [HisploraScrollUnsealStage] = [stage]
        while let next = stage.next {
            stage = next
            seen.append(stage)
        }
        #expect(seen == [.sealed, .widening, .unbinding, .unrolling, .open])
    }

    /// The tied roll is on screen until the moment it and the shut sheet are the same silhouette at
    /// the same size. Swapping earlier shows a roll changing width mid-fade; swapping later means
    /// the ribbon is still on a sheet that has started unrolling.
    @Test func theTiedRollGivesWayToTheSheetAtUnbinding() {
        #expect(HisploraScrollUnsealStage.sealed.showsSealedRoll)
        #expect(HisploraScrollUnsealStage.widening.showsSealedRoll)
        #expect(!HisploraScrollUnsealStage.unbinding.showsSealedRoll)
        #expect(!HisploraScrollUnsealStage.unrolling.showsSealedRoll)
        #expect(!HisploraScrollUnsealStage.open.showsSealedRoll)
    }

    /// The paper comes off the rolls on one beat and stays off. `unbinding` at anything but 0 would
    /// mean the swap lands on a sheet already half open.
    @Test func thePaperComesOffTheRollsOnlyAtUnrolling() {
        #expect(HisploraScrollUnsealStage.sealed.openFraction == 0)
        #expect(HisploraScrollUnsealStage.widening.openFraction == 0)
        #expect(HisploraScrollUnsealStage.unbinding.openFraction == 0)
        #expect(HisploraScrollUnsealStage.unrolling.openFraction == 1)
        #expect(HisploraScrollUnsealStage.open.openFraction == 1)
    }

    /// The reference render runs 4.04 s. This is a door the walk goes through at every checkpoint of
    /// every quest, so it is shorter than that — and long enough that the unrolling still reads as
    /// paper rather than as a cut.
    @Test func theSequenceIsShorterThanTheReferenceRender() {
        let sequence = HisploraScrollUnsealSequence(rendersImmediately: false)
        #expect(sequence.total < .seconds(4.04))
        #expect(sequence.total > .seconds(1.2))
    }

    /// The unrolling is the beat the walker is actually watching, so it is the longest of the four.
    @Test func theUnrollingIsTheLongestBeat() {
        let sequence = HisploraScrollUnsealSequence(rendersImmediately: false)
        let unrolling = sequence.duration(of: .unrolling)
        for beat in HisploraScrollUnsealStage.allCases where beat != .unrolling {
            #expect(sequence.duration(of: beat) < unrolling)
        }
    }

    /// Reduce Motion and VoiceOver do not watch a shorter opening — they do not watch one. The tap
    /// goes to the task sheet, which is where it was going.
    @Test func reducedMotionSkipsTheOpeningEntirely() {
        let sequence = HisploraScrollUnsealSequence(rendersImmediately: true)
        #expect(sequence.total == .zero)
        for beat in HisploraScrollUnsealStage.allCases {
            #expect(sequence.duration(of: beat) == .zero)
            #expect(sequence.animation(of: beat) == nil)
        }
    }

    /// Every beat that moves something moves for exactly as long as it lasts — the correction
    /// `HisploraEnvelopeSequence` records, applied here rather than re-learned.
    @Test func onlyTheStillBeatsCarryNoAnimation() {
        let sequence = HisploraScrollUnsealSequence(rendersImmediately: false)
        #expect(sequence.animation(of: .sealed) == nil)
        #expect(sequence.animation(of: .open) == nil)
        #expect(sequence.animation(of: .widening) != nil)
        #expect(sequence.animation(of: .unbinding) != nil)
        #expect(sequence.animation(of: .unrolling) != nil)
    }

    /// Every moving beat hands over before it has finished, which is what keeps the opening one
    /// movement instead of four. A `hold` equal to its `duration` is the stutter this replaced.
    @Test func everyMovingBeatHandsOverBeforeItSettles() {
        let sequence = HisploraScrollUnsealSequence(rendersImmediately: false)
        for beat in [HisploraScrollUnsealStage.widening, .unbinding, .unrolling] {
            #expect(sequence.hold(of: beat) < sequence.duration(of: beat))
            #expect(sequence.hold(of: beat) > .zero)
        }
    }

    /// The overlap is a tail, not a chord. A beat that gives away more than a third of itself starts
    /// the next one while this one is still visibly travelling, and the two read as a collision.
    @Test func theOverlapIsATailRatherThanAChord() {
        let sequence = HisploraScrollUnsealSequence(rendersImmediately: false)
        for beat in [HisploraScrollUnsealStage.widening, .unbinding, .unrolling] {
            let overlap = sequence.duration(of: beat) - sequence.hold(of: beat)
            #expect(overlap.seconds < sequence.duration(of: beat).seconds / 3)
        }
    }

    /// A skipped opening waits for nothing, the same way it animates nothing.
    @Test func reducedMotionHoldsOnNoBeatAtAll() {
        let sequence = HisploraScrollUnsealSequence(rendersImmediately: true)
        for beat in HisploraScrollUnsealStage.allCases {
            #expect(sequence.hold(of: beat) == .zero)
        }
    }

    /// The idle breath is below the threshold where it reads as an animation playing — it is there
    /// to say the picture is a control, not to be watched. Numbers rather than a screenshot, because
    /// this is exactly the kind of value that gets nudged up until it competes with the opening.
    @Test func theIdleBreathStaysUnderTheThresholdOfAnAnimation() {
        #expect(HisploraScrollIdleMotion.floatOffset <= 10)
        #expect(HisploraScrollIdleMotion.tiltDegrees <= 2.5)
        #expect(HisploraScrollIdleMotion.scaleRange <= 0.03)
        #expect(HisploraScrollIdleMotion.period >= 2.5)
        // It must be off the roll well before `widening` is doing anything the eye can follow.
        #expect(HisploraScrollIdleMotion.settle
            < HisploraScrollUnsealSequence(rendersImmediately: false)
                .duration(of: .widening).seconds)
        #expect(HisploraScrollIdleMotion.captionFloor > 0.5,
                "a caption that fades further than this reads as broken, not as breathing")
    }

    /// The tilt is the frame's, not a second copy of it that can drift. It is also constant — see
    /// `sealedTiltDegrees`.
    @Test func theRestingTiltIsTheFramesOwn() {
        #expect(HisploraScrollUnsealSequence.sealedTiltDegrees
            == TransitionScrollMetrics.rotationDegrees)
    }

    // MARK: The slices

    private var parchment: CGImage? {
        guard let url = HisploraScrollArt.sheet.url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// How much of a row is opaque, 0…1. A roll runs the picture's full width; the sheet's sides bow
    /// in, so its rows cover visibly less.
    private func coverage(ofRow y: Int, in image: CGImage) -> Double {
        let width = image.width, height = image.height
        guard y >= 0, y < height,
              let data = image.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else { return 0 }
        let rowBytes = image.bytesPerRow
        let pixelBytes = image.bitsPerPixel / 8
        var first = -1, last = -1
        for x in 0..<width {
            let alpha = bytes[y * rowBytes + x * pixelBytes + (pixelBytes - 1)]
            if alpha > 127 {
                if first < 0 { first = x }
                last = x
            }
        }
        guard first >= 0 else { return 0 }
        return Double(last - first) / Double(width)
    }

    @Test func theParchmentShipsWithThePackage() {
        #expect(HisploraScrollArt.sheet.isAvailable,
                "quest-parchment.png is what the transition unrolls into; without it the opening has nothing to open")
    }

    /// Inside each roll fraction the row is the roll's full width; just past it the sheet's bow has
    /// already narrowed it. That pair is what makes the fractions a measurement of this file rather
    /// than two numbers somebody typed — and a re-export cropped differently fails here rather than
    /// stretching half a roll on device.
    @Test func theRollFractionsFallOnTheRollsOfTheShippedFile() throws {
        let image = try #require(parchment)
        let height = image.height
        // The rolls cover about 0.96 of the width and the sheet's first rows about 0.86, so anything
        // between the two separates them.
        let rollCoverage = 0.92

        let topEdge = Int(HisploraParchmentUnrollMetrics.topRollHeight * CGFloat(height))
        #expect(coverage(ofRow: topEdge - 4, in: image) > rollCoverage,
                "the top slice should end on the head roll, not before it")
        #expect(coverage(ofRow: topEdge + 4, in: image) < rollCoverage,
                "the top slice should end at the head roll, not past it into the sheet")

        let bottomEdge = height - Int(HisploraParchmentUnrollMetrics.bottomRollHeight * CGFloat(height))
        #expect(coverage(ofRow: bottomEdge + 4, in: image) > rollCoverage,
                "the bottom slice should start on the foot roll, not after it")
        #expect(coverage(ofRow: bottomEdge - 4, in: image) < rollCoverage,
                "the bottom slice should start at the foot roll, not before it inside the sheet")
    }

    /// The three slices are the whole picture. A gap would show the ground through the sheet; an
    /// overlap would draw a band of paper twice.
    @Test func theThreeSlicesAccountForTheWholePicture() {
        let total = HisploraParchmentUnrollMetrics.topRollHeight
            + HisploraParchmentUnrollMetrics.sheetHeight
            + HisploraParchmentUnrollMetrics.bottomRollHeight
        #expect(abs(total - 1) < 0.0001)
    }

    /// Shut, the sheet is exactly its two rolls, head against foot — the shape the tied roll is
    /// cross-faded into.
    @Test func theShutSheetIsTheTwoRollsAndNothingElse() {
        #expect(HisploraParchmentUnrollMetrics.closedHeight
            == HisploraParchmentUnrollMetrics.topRollHeight
                + HisploraParchmentUnrollMetrics.bottomRollHeight)
        #expect(HisploraParchmentUnrollMetrics.closedHeight < 0.32,
                "a shut sheet that is a third of the open one is not shut")
    }
}
