import CoreGraphics
import Testing

@testable import DesignSystem

/// The geometry behind a drawing the reader drags — the site plan (`452:2651`) and the region map.
///
/// Every assertion here is about something that is wrong in a way nobody notices by looking: a
/// letterboxed plan still reads, a marker two points off still lands on a building, and a pan that
/// accumulates past the artwork's edge only shows itself on the drag *back*.
@Suite("Artwork viewport")
struct ArtworkViewportTests {

    private static let planAspect = 1.1247   // the shipped Puri Agung Pemecutan plan

    @Test("A wider-than-tall drawing fills a taller window by its height and overflows the width")
    func fillsByHeightInAPortraitWindow() {
        let window = CGSize(width: 386, height: 595)

        let size = ArtworkViewport.filledSize(aspectRatio: Self.planAspect, in: window)

        #expect(size.height == window.height)
        #expect(size.width > window.width)
        // `452:2651` draws the plan 673.9 wide in a 386-wide window. Filling by height reaches the
        // same crop from the shipped aspect ratio rather than from a hard-coded number.
        #expect(abs(size.width - 669.2) < 1)
    }

    @Test("A drawing narrower than the window fills by width instead, so nothing letterboxes")
    func fillsByWidthWhenTheWindowIsWide() {
        let window = CGSize(width: 800, height: 200)

        let size = ArtworkViewport.filledSize(aspectRatio: Self.planAspect, in: window)

        #expect(size.width == window.width)
        #expect(size.height >= window.height)
    }

    @Test("A non-positive aspect ratio is floored rather than trusted")
    func refusesADegenerateAspectRatio() {
        let window = CGSize(width: 386, height: 595)

        let size = ArtworkViewport.filledSize(aspectRatio: 0, in: window)

        #expect(size.width > 0)
        #expect(size.height > 0)
    }

    @Test("The pan limit is zero on an axis the drawing does not overflow")
    func doesNotPanAnAxisThatFits() {
        let window = CGSize(width: 386, height: 595)
        let content = ArtworkViewport.filledSize(aspectRatio: Self.planAspect, in: window)

        let limit = ArtworkViewport.panLimit(content: content, scale: 1, in: window)

        #expect(limit.height == 0)
        #expect(limit.width > 0)
    }

    @Test("A pan past the drawing's edge is brought back to it")
    func clampsAPanToTheDrawingsEdges() {
        let window = CGSize(width: 386, height: 595)
        let content = ArtworkViewport.filledSize(aspectRatio: Self.planAspect, in: window)
        let limit = ArtworkViewport.panLimit(content: content, scale: 1, in: window)

        let clamped = ArtworkViewport.clampedPan(CGSize(width: 5_000, height: 5_000),
                                                 content: content, scale: 1, in: window)

        #expect(clamped.width == limit.width)
        #expect(clamped.height == 0)
    }

    @Test("Zooming in widens how far the drawing may be panned")
    func panLimitGrowsWithZoom() {
        let window = CGSize(width: 386, height: 595)
        let content = ArtworkViewport.filledSize(aspectRatio: Self.planAspect, in: window)

        let atRest = ArtworkViewport.panLimit(content: content, scale: 1, in: window)
        let zoomed = ArtworkViewport.panLimit(content: content, scale: 4, in: window)

        #expect(zoomed.width > atRest.width)
        // The axis that could not pan at rest can once the drawing is four times its height.
        #expect(zoomed.height > 0)
    }

    @Test("Opening on the leading edge puts the drawing's left against the window's")
    func opensOnTheLeadingEdge() {
        let window = CGSize(width: 386, height: 595)
        let content = ArtworkViewport.filledSize(aspectRatio: Self.planAspect, in: window)

        let pan = ArtworkViewport.leadingPan(content: content, scale: 1, in: window)
        // The drawing's own left edge, carried through the same centre-anchored transform the
        // artwork gets, lands on the window's left edge.
        let leftEdge = ArtworkViewport.position(of: CGPoint(x: 0, y: 0.5), drawnAt: content,
                                                in: window, scale: 1, offset: pan)

        #expect(abs(leftEdge.x) < 0.001)
    }

    @Test("A marker's position follows the same scale and offset the drawing does")
    func placesAMarkerOnTheDrawingItMarks() {
        let window = CGSize(width: 400, height: 400)
        let content = CGSize(width: 400, height: 400)

        // Unzoomed and unpanned, the centre of the artwork is the centre of the window.
        let centred = ArtworkViewport.position(of: CGPoint(x: 0.5, y: 0.5), drawnAt: content,
                                               in: window, scale: 1, offset: .zero)
        #expect(centred == CGPoint(x: 200, y: 200))

        // At 2×, a point a quarter across the artwork moves twice as far from the centre as it did.
        let quarter = ArtworkViewport.position(of: CGPoint(x: 0.25, y: 0.25), drawnAt: content,
                                               in: window, scale: 2, offset: .zero)
        #expect(quarter == CGPoint(x: 0, y: 0))

        // An offset moves a marker by exactly the offset, at any zoom.
        let shifted = ArtworkViewport.position(of: CGPoint(x: 0.5, y: 0.5), drawnAt: content,
                                               in: window, scale: 2,
                                               offset: CGSize(width: 30, height: -10))
        #expect(shifted == CGPoint(x: 230, y: 190))
    }
}
