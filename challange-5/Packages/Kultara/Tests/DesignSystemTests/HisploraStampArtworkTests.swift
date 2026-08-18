import Foundation
import Testing
@testable import DesignSystem

/// Fifteen drawings and one rule for choosing between them. Both degrade silently: a dropped file
/// leaves an empty window that still lays out, and an off-by-one in the tier picks the wrong
/// picture for a place with nothing saying so.
struct HisploraStampArtworkTests {

    @Test func everyDrawingShips() {
        #expect(HisploraStampArtwork.allAreAvailable,
                "missing: \(HisploraStampArtwork.allResourceNames.filter { HisploraStampArtwork.url(named: $0) == nil })")
    }

    @Test func fivePlacesAtThreeTiers() {
        #expect(HisploraStampArtwork.allResourceNames.count == 15)
        #expect(Set(HisploraStampArtwork.allResourceNames).count == 15)
    }

    /// The rule as the reader is told it: one finished quest through a place shows the first
    /// drawing, two the second, three the third.
    @Test func aTierPerFinishedWalk() {
        #expect(HisploraStampArtwork.tier(completedVisits: 1) == 1)
        #expect(HisploraStampArtwork.tier(completedVisits: 2) == 2)
        #expect(HisploraStampArtwork.tier(completedVisits: 3) == 3)
    }

    /// A fourth walk does not earn a fourth drawing, because there is not one. Clamping rather than
    /// wrapping: wrapping would take a reader who walked a place four times *back* to the sketch.
    @Test func pastThreeItStaysOnTheThird() {
        #expect(HisploraStampArtwork.tier(completedVisits: 4) == 3)
        #expect(HisploraStampArtwork.tier(completedVisits: 99) == 3)
        #expect(HisploraStampArtwork.resourceName(slug: "caturmuka", completedVisits: 12)
                == "caturmuka-stamp3")
    }

    /// The floor is the first drawing, never a blank. A stamp is drawn only once it has been
    /// earned, and a walk in flight has earned its stamps without having finished the quest — a
    /// zero here would take back something the reader is holding.
    @Test func anUnfinishedWalkStillShowsTheFirstDrawing() {
        #expect(HisploraStampArtwork.tier(completedVisits: 0) == 1)
        #expect(HisploraStampArtwork.resourceName(slug: "pemecutan", completedVisits: 0)
                == "pemecutan-stamp1")
        // And a negative count — which nothing should produce — is a bug, not a crash.
        #expect(HisploraStampArtwork.tier(completedVisits: -3) == 1)
    }

    @Test func namesFollowTheDesignsOwnStems() {
        #expect(HisploraStampArtwork.resourceName(slug: "maospahit", tier: 2) == "maospahit-stamp2")
        #expect(HisploraStampArtwork.resourceName(slug: "balimuseum", tier: 9) == "balimuseum-stamp3")
        #expect(HisploraStampArtwork.resourceName(slug: "badung", tier: 0) == "badung-stamp1")
    }

    @Test func anUnknownPlaceHasNoDrawing() {
        // The empty state is a real one: `HisploraStampCard` falls back to aged paper, which is
        // what a place the design never drew has to show rather than a borrowed picture.
        #expect(HisploraStampArtwork.image(named: "nowhere-stamp1") == nil)
    }
}
