import Foundation
import SwiftUI
import Testing
@testable import DesignSystem

/// The Journal's idle turn (`791:5637`), the two papers in the pocket (`791:5585` → `791:5533`)
/// and the cards they become (`791:5551`).
///
/// All three are the kind of thing that degrades silently: a turn with its faces swapped still
/// animates, two sheets with the same travel still move, and a dropped export leaves a blank
/// rectangle that still lays out.
struct HisploraEnvelopeFlipTests {

    @Test func theCardTurnsOutAndBackRatherThanRoundAndRound() {
        // A card that kept turning the same way would show the reader its back, then its front
        // *mirrored*, and then its back again. `791:5637` is one object being turned over and
        // turned back.
        #expect(HisploraEnvelopeFlip.front.next == .turningToBack)
        #expect(HisploraEnvelopeFlip.turningToBack.next == .back)
        #expect(HisploraEnvelopeFlip.back.next == .turningToFront)
        #expect(HisploraEnvelopeFlip.turningToFront.next == .front)
        // Both half turns stand at the same quarter, which is what makes the second one a reversal
        // of the first rather than a continuation.
        #expect(HisploraEnvelopeFlip.turningToBack.angle == HisploraEnvelopeFlip.turningToFront.angle)
        #expect(HisploraEnvelopeFlip.front.angle == 0)
        #expect(HisploraEnvelopeFlip.back.angle == 180)
    }

    @Test func theFaceSwapsWhereTheCardIsEdgeOn() {
        // The two beats that show the front are the ones at or before the quarter turn, and the
        // two that show the back are at or after it. Swapping anywhere else means one picture
        // visibly becoming the other.
        #expect(!HisploraEnvelopeFlip.front.showsBack)
        #expect(!HisploraEnvelopeFlip.turningToBack.showsBack)
        #expect(HisploraEnvelopeFlip.back.showsBack)
        #expect(HisploraEnvelopeFlip.turningToFront.showsBack)
    }

    @Test func everyBeatHasAWayBackToTheFront() {
        // The designer's rule: tapping open mid-turn returns the card to its front *first*. The
        // flap and the wax are drawn on the front, so an opening that started anywhere else would
        // swing a flap the reader cannot see.
        for beat in HisploraEnvelopeFlip.allCases {
            var walked = beat
            for step in beat.returningToFront { walked = step }
            #expect(walked == .front, "\(beat) does not end at the front")
        }
        #expect(HisploraEnvelopeFlip.front.returningToFront.isEmpty)
        // From the addressed side it is two beats — a quarter turn, then the rest — and from a
        // half turn it is one, because the card is already halfway home.
        #expect(HisploraEnvelopeFlip.back.returningToFront.count == 2)
        #expect(HisploraEnvelopeFlip.turningToBack.returningToFront.count == 1)
        #expect(HisploraEnvelopeFlip.turningToFront.returningToFront.count == 1)
    }

    @Test func theTurnIsRarerThanTheNudgeAndSlowerThanIt() {
        // Two idle animations on the same card at the same cadence is a screen that never settles.
        #expect(HisploraEnvelopeSequence.flipInterval > HisploraEnvelopeSequence.wiggleInterval)
        // And the addressed side is held long enough to be read, not glimpsed.
        #expect(HisploraEnvelopeSequence.flipBackDwell > HisploraEnvelopeSequence.flipHalfDuration)
    }

    @Test func reduceMotionStopsTheTurnRatherThanCollapsingIt() {
        // Unlike the opening, which still runs every beat in zero time so the screen arrives where
        // it was going, a turn collapsed to a cut is a card that snaps to its back and stays there.
        // Zero-length beats are what let `SealedLettersViewModel` skip the cycle instead.
        let sequence = HisploraEnvelopeSequence(rendersImmediately: true)
        for beat in HisploraEnvelopeFlip.allCases {
            #expect(sequence.duration(ofFlip: beat) == .zero, "\(beat)")
            #expect(sequence.animation(ofFlip: beat) == nil, "\(beat)")
        }
    }
}

struct HisploraEnvelopePaperTests {

    @Test func bothSheetsRiseAndNeitherSinks() {
        for slot in HisploraEnvelopeMetrics.PaperSlot.allCases {
            #expect(slot.risenOffset.y < slot.tuckedOffset.y, "\(slot) does not rise")
        }
    }

    @Test func theSummaryComesFurtherOutThanTheHistory() {
        // `791:5533` is the whole reason there are two slots rather than one repeated: the summary
        // comes nearly clear of the envelope and drifts left, the history rises about a quarter of
        // the card and stays put. Equal travel would read as one object splitting in two.
        let summary = HisploraEnvelopeMetrics.PaperSlot.summary
        let history = HisploraEnvelopeMetrics.PaperSlot.history
        #expect(summary.risenOffset.y < history.risenOffset.y)
        #expect(summary.risenOffset.x < summary.tuckedOffset.x, "the summary drifts left")
        #expect(history.risenOffset.x == history.tuckedOffset.x, "the history stays put")
        // They lean opposite ways, which is what keeps them two sheets rather than a thick one.
        #expect(summary.rotation < 0)
        #expect(history.rotation > 0)
    }

    @Test func theSheetsAreNarrowerThanThePocketThatHoldsThem() {
        #expect(HisploraEnvelopeMetrics.paperWidthRatio < 1)
        #expect(HisploraEnvelopeMetrics.paperWidthRatio > 0.4)
        // Landscape, as the frames cut them — a portrait thumbnail would be a different object in
        // the pocket from the card the modal opens.
        #expect(HisploraEnvelopeMetrics.paperAspectRatio > 1)
    }

    @Test func theZoomIsGentlerThanTheOneASinglePageGotAwayWith() {
        // Two sheets already spread across more than the card's width, so the 2.1 a lone page grew
        // to would throw both off the screen before the modal arrives.
        #expect(HisploraEnvelopeMetrics.zoomScale > 1)
        #expect(HisploraEnvelopeMetrics.zoomScale < 2)
    }
}

struct HisploraJournalPaperCardTests {

    @Test func everyPackagedPaperShips() {
        #expect(HisploraJournalPaperMetrics.allAreAvailable,
                "missing: \(HisploraJournalPaperMetrics.allResourceNames.filter { HisploraWaxSealMetrics.url(named: $0) == nil })")
    }

    @Test func theCardKeepsTheFramesBox() {
        // 344 × 321 at 29 from each edge of a 402-point screen, 20 apart.
        #expect(HisploraJournalPaperMetrics.width == 344)
        #expect(HisploraJournalPaperMetrics.height == 321)
        #expect(HisploraJournalPaperMetrics.screenInset * 2
                + HisploraJournalPaperMetrics.width == 402)
    }

    @Test func theTornSheetCoversTheCardItIsPrintedOn() {
        // `791:5569` is deliberately larger than the card and hangs off it to the left and above —
        // that overhang is what puts the torn edge along the foot. A sheet that fitted the card
        // would print a straight edge on all four sides, which is the opposite of the effect.
        #expect(HisploraJournalPaperMetrics.groundBox.width > HisploraJournalPaperMetrics.width)
        #expect(HisploraJournalPaperMetrics.groundBox.height > HisploraJournalPaperMetrics.height)
        #expect(HisploraJournalPaperMetrics.groundOrigin.x < 0)
        #expect(HisploraJournalPaperMetrics.groundOrigin.y < 0)
    }

    @Test func theTwoArtworksAreSetDifferentlyAndBothAreTurned() {
        // A disc and a landscape plate, leaning opposite ways: the frames draw them as two things
        // laid on a page rather than as one slot filled twice.
        let roundel = HisploraJournalPaperArtwork.Style.roundel
        let plate = HisploraJournalPaperArtwork.Style.plate
        #expect(roundel.size.width == roundel.size.height)
        #expect(plate.size.width > plate.size.height)
        #expect(roundel.rotation > 0)
        #expect(plate.rotation < 0)
    }

    @Test func theThumbnailIsTheWholeCardAtHalfSize() {
        // `791:5595` is 172.5 × 113.5 — half the card's width, and shorter than half its height,
        // because the export stops where the pocket covers the sheet. The pocket is what hides the
        // rest in the app; cutting the view there too ships a card with its picture and its control
        // sliced off, which shows the moment the sheet rises clear of the envelope.
        let scale = 172.5 / HisploraJournalPaperMetrics.width
        #expect(abs(scale - 0.5) < 0.01)
        #expect(113.5 < HisploraJournalPaperMetrics.height * scale)
        // So what the envelope holds keeps the card's own shape, not the frame's crop of it.
        #expect(HisploraJournalPaperMetrics.cardAspectRatio
                == HisploraJournalPaperMetrics.width / HisploraJournalPaperMetrics.height)
        #expect(HisploraEnvelopeMetrics.paperAspectRatio
                == HisploraJournalPaperMetrics.cardAspectRatio)
        #expect(HisploraEnvelopeMetrics.paperAspectRatio
                < HisploraJournalPaperMetrics.thumbnailAspectRatio)
    }
}
