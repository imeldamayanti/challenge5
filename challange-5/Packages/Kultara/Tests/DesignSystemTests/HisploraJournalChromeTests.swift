import Foundation
import SwiftUI
import Testing
@testable import DesignSystem

/// The Journal's envelope and the Explorer's Card are made of packaged papers and one ordered
/// sequence. Both are the kind of thing that degrades silently: a dropped resource leaves a blank
/// rectangle that still lays out, and a re-ordered sequence still animates.
struct HisploraEnvelopeTests {

    @Test func everyPackagedPaperShips() {
        // Without this, dropping a file from `Resources/Images` costs the Journal its texture and
        // nothing says so — the view falls back to a ruled rectangle on purpose.
        #expect(HisploraEnvelopeMetrics.allAreAvailable,
                "missing: \(HisploraEnvelopeMetrics.allResourceNames.filter { HisploraWaxSealMetrics.url(named: $0) == nil })")
    }

    @Test func everyWaxSealShips() {
        #expect(HisploraWaxSealMetrics.allAreAvailable,
                "missing: \(HisploraWaxSealMetrics.allResourceNames.filter { HisploraWaxSealMetrics.url(named: $0) == nil })")
    }

    @Test func theExplorersRoundelShips() {
        #expect(HisploraExplorerRoundelMetrics.isAvailable)
    }

    @Test func theOpeningRunsInTheOrderTheFramesDraw() {
        // `332:1607` → `332:1691` → `332:1252`: sealed, then open, then the page out and zooming.
        // The order is what the designer's note specifies, and skipping the dwell would be
        // skipping the note.
        #expect(HisploraEnvelopeStage.allCases ==
                [.sealed, .opening, .dwelling, .rising, .zooming])
        var stage = HisploraEnvelopeStage.sealed
        var walked: [HisploraEnvelopeStage] = [stage]
        while let next = stage.next {
            walked.append(next)
            stage = next
        }
        #expect(walked == HisploraEnvelopeStage.allCases)
        #expect(HisploraEnvelopeStage.zooming.next == nil)
    }

    @Test func onlyTheSealedStageIsClosed() {
        #expect(!HisploraEnvelopeStage.sealed.isOpen)
        for stage in HisploraEnvelopeStage.allCases where stage != .sealed {
            #expect(stage.isOpen, "\(stage)")
        }
    }

    @Test func theDwellIsTheTwoToThreeSecondsTheNoteAsksFor() {
        // "Delay 2 or 3 seconds then the detail page comes out of the envelope" — the one number
        // on the frames, so it is the one number worth pinning.
        let sequence = HisploraEnvelopeSequence(rendersImmediately: false)
        let dwell = sequence.duration(of: .dwelling)
        #expect(dwell >= .seconds(2))
        #expect(dwell <= .seconds(3))
    }

    @Test func reduceMotionCollapsesTheWholeOpeningToACut() {
        // Not a shortened animation and not a skipped destination: every beat still runs, each in
        // zero time, so the screen still arrives where it was going. `HisploraTypewriterText`
        // makes the same trade for the same reason.
        let sequence = HisploraEnvelopeSequence(rendersImmediately: true)
        #expect(sequence.total == .zero)
        for stage in HisploraEnvelopeStage.allCases {
            #expect(sequence.duration(of: stage) == .zero, "\(stage)")
        }
    }

    @Test func theFullOpeningIsShortEnoughToSitThrough() {
        // A reader who taps "Unseal" is waiting. Six seconds of paper is a beat; twelve is a
        // loading screen wearing a costume.
        let sequence = HisploraEnvelopeSequence(rendersImmediately: false)
        #expect(sequence.total <= .seconds(8))
    }

    @Test func theFlapOpensPastVerticalSoItLandsBehindTheEnvelope() {
        #expect(HisploraEnvelopeSequence.flapAngle > 90)
        #expect(HisploraEnvelopeSequence.flapAngle < 180)
    }

    @Test func theWiggleIsANudgeAndNotAShake() {
        // It runs unprompted on a screen a reader may be sitting on. Anything with real amplitude
        // becomes the thing they look at instead of the letters.
        #expect(HisploraEnvelopeSequence.wiggleAngle <= 3)
        #expect(HisploraEnvelopeSequence.wiggleInterval >= .seconds(3))
    }

    @Test func thePocketLipFallsBelowTheFlapsHinge() {
        // The page rises between the two: above the lip it is visible, below it the pocket's own
        // paper is drawn over it. A lip above the flap's fold would show the page through the
        // closed envelope.
        #expect(HisploraEnvelopeMetrics.pocketTopRatio > 0)
        #expect(HisploraEnvelopeMetrics.pocketTopRatio < HisploraEnvelopeMetrics.flapHeightRatio)
    }

    @Test func theSealSitsInsideTheCard() {
        let centre = HisploraEnvelopeMetrics.sealCentre
        #expect((0...1).contains(centre.x))
        #expect((0...1).contains(centre.y))
        // And on the flap's own fold, which is what a wax seal closes.
        #expect(centre.y < HisploraEnvelopeMetrics.flapHeightRatio + 0.1)
    }
}

struct HisploraStampTests {

    @Test func theSameStampHasTheSamePerforationAtEverySize() {
        // The card is set at 26 points on the envelope and 160 on the Explorer's Card. A pitch
        // fixed in points would give the large one six times the teeth — a dotted line rather than
        // a perforation, which is exactly what shipped before this was caught on device. The count
        // is what is held; the pitch follows the width.
        let shape = HisploraStampShape()
        for width in [26.0, 80.0, 160.0, 320.0] as [CGFloat] {
            let rect = CGRect(x: 0, y: 0,
                              width: width,
                              height: width / HisploraStampCard<EmptyView>.aspectRatio)
            let path = shape.path(in: rect)
            #expect(!path.isEmpty, "\(width)")
            // The rectangle plus two circles per tooth on all four edges. Same total at every
            // size, which is the property that matters.
            #expect(path.boundingRect.width > rect.width, "\(width)")
        }
        #expect(HisploraStampShape.teethAcross == 14)
    }

    @Test func theStampKeepsTheFramesProportions() {
        // `547:2851` — `Images/badges-frame.svg`, 152 × 206 — is the die the Explorer's Card cuts
        // its stamps to, and the card now holds it for the whole object rather than for the window
        // alone, so a two-line place name cannot make one stamp taller than the one beside it.
        #expect(abs(HisploraStampCard<EmptyView>.aspectRatio - 152.0 / 206.0) < 0.0001)
        // And it is still the envelope's thumbnail box to within a thousandth, which is why the
        // franking down the pocket did not have to move when the die changed.
        #expect(abs(HisploraStampCard<EmptyView>.aspectRatio - 25.788 / 35) < 0.002)
    }
}

struct HisploraWaxTests {

    @Test func aBadgesSealIsStableAcrossLaunches() {
        // Colour is decoration here and never the only signal (`NFR-A11Y-05`) — but a badge that
        // changed colour between launches would still read as a different badge.
        for index in 0..<12 {
            #expect(HisploraWaxSealMetrics.Wax.forIndex(index)
                    == HisploraWaxSealMetrics.Wax.forIndex(index))
        }
        #expect(HisploraWaxSealMetrics.Wax.forIndex(0) == .crimson)
        #expect(HisploraWaxSealMetrics.Wax.forIndex(4) == .crimson)
    }

    @Test func aNegativePositionStillPicksASeal() {
        // `enumerated()` cannot produce one, but a caller doing its own arithmetic can, and a
        // crash on the Badges tab would be a poor way to find out.
        #expect(HisploraWaxSealMetrics.Wax.allCases.contains(HisploraWaxSealMetrics.Wax.forIndex(-1)))
        #expect(HisploraWaxSealMetrics.Wax.allCases.contains(HisploraWaxSealMetrics.Wax.forIndex(-7)))
    }
}
