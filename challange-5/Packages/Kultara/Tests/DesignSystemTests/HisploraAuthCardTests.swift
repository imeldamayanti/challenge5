import CoreGraphics
import Foundation
import Testing
@testable import DesignSystem

/// The login / register frames' own numbers — `1429:2829` and `1429:3260`.
///
/// These are guards about a *drawing*, so they assert the relationships a reader would notice if
/// they broke, not every constant in the file. A metric that is only ever read once and never
/// compared to anything is guarded by the frame reference in its own comment.
struct HisploraAuthCardTests {

    /// Both pictures have to ship, or the masthead is a flat brown band with no mark on it.
    /// `Package.swift` copies `Resources/Images` wholesale, so a file dropped from the directory
    /// fails here rather than leaving a blank header nobody notices until a device build.
    @Test(arguments: HisploraAuthArt.allCases)
    func everyEntryPictureShipped(_ art: HisploraAuthArt) {
        #expect(art.isAvailable, "\(art.resourceName).png is missing from Resources/Images")
    }

    /// The masthead export is the frame's own 402 × 397 at 3×. If it is ever re-exported at a
    /// different crop, the declared ratio has to move with it or the texture is drawn stretched.
    @Test func theMastheadTextureIsTheFramesOwnBandAndNotASquare() {
        #expect(abs(HisploraAuthArt.headTexture.aspectRatio - 402.0 / 397.0) < 0.01)
        #expect(HisploraAuthArt.shield.aspectRatio == 1)
    }

    /// The one relationship a reader actually sees on these two screens: the card starts *inside*
    /// the brown band and hangs 140 points above its foot. Both numbers are taken below the frame's
    /// 44-point status bar, which is what lets the band grow on a phone with a deeper notch without
    /// the card sliding up or down it.
    @Test func theCardOverlapsTheMastheadByTheFramesOwnHundredAndForty() {
        #expect(AuthCardMetrics.headHeight - AuthCardMetrics.cardTop == 140)
        // ...and the card really does start inside the band rather than under it.
        #expect(AuthCardMetrics.cardTop < AuthCardMetrics.headHeight)
    }

    /// `1429:2830` is 397 tall and `1429:3241` starts at 257 on a canvas whose status bar is 44.
    /// The values here are those, less the status bar — so if someone "corrects" one of them back
    /// to the absolute figure, the overlap above changes and this says which number moved.
    @Test func theFramesCoordinatesAreHeldBelowTheStatusBarRatherThanAbsolute() {
        #expect(AuthCardMetrics.headHeight == CGFloat(397 - 44))
        #expect(AuthCardMetrics.cardTop == CGFloat(257 - 44))
        #expect(AuthCardMetrics.headlineTop == CGFloat(68 - 44))
    }

    /// A field is a 46-point box with a 10-point radius, not a capsule. The cream entry frames
    /// these replaced drew capsules, and `HisploraFieldRow` still does for the guest screen — the
    /// two are easy to confuse and they are on different screens for a reason.
    @Test func theCardsFieldsAreBoxesAndTheGuestScreensAreStillCapsules() {
        #expect(AuthCardMetrics.fieldRadius == 10)
        #expect(AuthCardMetrics.fieldHeight == 46)
        // The card's own corner is the same 10, which is what makes the fields read as printed on
        // it rather than as objects laid over it.
        #expect(AuthCardMetrics.cardRadius == AuthCardMetrics.fieldRadius)
    }

    /// The provider row is nearly a capsule at 40 and the field is nearly square at 10. If those
    /// two ever converge the card loses the distinction between "a box you type in" and "a button
    /// you press", which on this design is carried by shape alone.
    @Test func aProviderRowAndAFieldAreTellableApartByShape() {
        #expect(AuthCardMetrics.providerRadius > AuthCardMetrics.fieldRadius * 3)
    }
}
