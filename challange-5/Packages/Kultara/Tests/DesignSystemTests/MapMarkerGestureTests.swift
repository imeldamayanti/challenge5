import CoreGraphics
import Testing
@testable import DesignSystem

/// QA reported that map pins fired during pinch and pan ("kayak pas zoom in dan zoom out dia terlalu
/// sensitif kepencet"). The arbitration itself is only checkable by hand on a device; the threshold
/// it depends on is not, so it is held here.
@Suite("Map marker gesture")
struct MapMarkerGestureTests {

    @Test func aStationaryTouchSelects() {
        #expect(MapMarkerGesture.isTap(translation: .zero))
    }

    /// The reported case: a finger that started on a pin and then dragged the map.
    @Test func aTouchThatTravelledFortyPointsDoesNotSelect() {
        #expect(!MapMarkerGesture.isTap(translation: CGSize(width: 40, height: 0)))
        #expect(!MapMarkerGesture.isTap(translation: CGSize(width: 0, height: -40)))
        #expect(!MapMarkerGesture.isTap(translation: CGSize(width: 30, height: 30)))
    }

    /// Travel is radial, not per-axis: 8 points on each axis is 11.3 points of movement and must not
    /// pass a 10-point limit.
    @Test func travelIsMeasuredAsDistanceNotPerAxis() {
        #expect(!MapMarkerGesture.isTap(translation: CGSize(width: 8, height: 8)))
        #expect(MapMarkerGesture.isTap(translation: CGSize(width: 6, height: 6)))
    }

    /// A finger resting on the glass drifts a point or two before it lifts; that is still a tap.
    @Test func smallDriftStillSelects() {
        #expect(MapMarkerGesture.isTap(translation: CGSize(width: 2, height: -3)))
    }

    /// The settle window has to be long enough to outlast the stagger between two fingers lifting,
    /// and short enough that a reader who pans and then taps is not left pressing a dead pin.
    @Test func theSettleWindowIsBoundedAtBothEnds() {
        #expect(MapMarkerGesture.settleDelay >= .milliseconds(100))
        #expect(MapMarkerGesture.settleDelay <= .milliseconds(300))
    }
}
