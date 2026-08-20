import ContentKit
import Foundation
import MapKit
import RunEngine
import Testing
@testable import challange_5

/// The discovery map's two grounds, and what happens when the live one does not answer.
@MainActor
struct QuestMapTests {

    private func pin(_ id: String, lat: Double, lon: Double) -> RegionMapPin {
        RegionMapPin(
            questID: id,
            title: id,
            placeName: id,
            point: MapPoint(x: 0.5, y: 0.5),
            coordinate: Coordinate(lat: lat, lon: lon),
            accessibilityLabel: id)
    }

    /// The app's own map is what it opens on. The real one is the alternative it offers.
    @Test func theMapOpensOnTheIllustratedGround() {
        let model = QuestMapViewModel()

        #expect(model.mode == .illustrated)
        #expect(model.showsIllustrationOverlay)
    }

    @Test func theWandSwapsTheGroundAndSwapsItBack() {
        let model = QuestMapViewModel()

        model.toggleMode()
        #expect(model.mode == .real)
        #expect(!model.showsIllustrationOverlay)

        model.toggleMode()
        #expect(model.mode == .illustrated)
        #expect(model.showsIllustrationOverlay)
    }

    /// **The regression this suite exists for.** The screen used to swap the whole surface out
    /// when a tile load failed, which destroyed the `MKMapView` — so nothing could ever report a
    /// load succeeding, and the reader was stuck on the fallback for the rest of the session with
    /// the wand gone too. The map is never unmounted now, and recovery is a fact the model records
    /// rather than a screen it has no way back from.
    @Test func aBasemapThatFailsAndThenAnswersComesBack() {
        let model = QuestMapViewModel()

        model.basemapDidFail()
        #expect(model.basemapFailed)

        model.basemapDidLoad()
        #expect(!model.basemapFailed)
    }

    /// `FR-OFF-03`/`AD-3`: with no tiles the chart is the whole of what there is to see, so the
    /// failure forces it on whichever mode the reader had chosen. It needs no network — a shipped
    /// asset and some arithmetic — and it covers the viewport by construction.
    @Test func aBasemapThatFailsForcesTheChartOnInEitherMode() {
        let model = QuestMapViewModel()
        model.toggleMode()
        #expect(!model.showsIllustrationOverlay)

        model.basemapDidFail()
        #expect(model.showsIllustrationOverlay)

        model.basemapDidLoad()
        #expect(!model.showsIllustrationOverlay)
    }

    /// Falling back while illustrated lands on exactly the picture the reader asked for, so saying
    /// a real map was lost would announce a loss nobody can see.
    @Test func theOfflineNoticeIsSaidOnlyWhenTheRealGroundWasTheOneAskedFor() {
        let model = QuestMapViewModel()

        model.basemapDidFail()
        #expect(!model.showsOfflineNotice)

        model.toggleMode()
        #expect(model.showsOfflineNotice)
    }

    // MARK: Location

    /// MapKit will not ask on the app's behalf, so a dot promised before there is permission for one
    /// draws nothing and explains nothing.
    @Test func theDotIsDrawnOnlyOncePermissionExists() {
        let provider = TestMapLocationProvider(authorization: .notRequested)
        let model = QuestMapViewModel(locationProvider: provider)
        model.prepareLocation()
        #expect(!model.showsUserLocation)

        // The answer arrives after the prompt, on the manager's own schedule. The dot appears when
        // it does, without the reader having to leave the map and come back.
        provider.change(to: .whenInUse)
        #expect(model.showsUserLocation)
    }

    @Test func aDeniedAnswerDrawsNoDot() {
        let provider = TestMapLocationProvider(authorization: .denied)
        let model = QuestMapViewModel(locationProvider: provider)
        model.prepareLocation()

        #expect(!model.showsUserLocation)
    }

    /// `FR-ONB-04` is about not asking before there is a reason. Opening a map that draws where you
    /// are is a reason; opening it a second time is not a new one.
    @Test func permissionIsAskedForOnceAndNeverAgainAfterAnAnswer() {
        let provider = TestMapLocationProvider(authorization: .notRequested)
        let model = QuestMapViewModel(locationProvider: provider)

        model.prepareLocation()
        #expect(provider.requestCount == 1)

        provider.change(to: .denied)
        model.prepareLocation()
        #expect(provider.requestCount == 1)
    }

    /// The map draws the dot; it never drives the sampler. `startUpdatingLocation` belongs to
    /// arrival (`NFR-BAT-04`), and `MKMapView.showsUserLocation` does its own.
    @Test func theMapNeverStartsTheArrivalSampler() {
        let provider = TestMapLocationProvider(authorization: .whenInUse)
        let model = QuestMapViewModel(locationProvider: provider)
        model.prepareLocation()

        #expect(!provider.isStarted)
    }

    /// `276:2520` opens on the quests, not on the island. A discovery map whose first frame is open
    /// sea makes the reader pan before it has told them anything.
    @Test func theMapOpensOnTheQuestsRatherThanOnTheIsland() {
        let region = QuestBaseMapView.openingRegion(for: [
            pin("a", lat: -8.6595, lon: 115.2077),
            pin("b", lat: -8.6535, lon: 115.2160),
        ])

        #expect(abs(region.center.latitude - -8.6565) < 0.0005)
        #expect(abs(region.center.longitude - 115.21185) < 0.0005)
    }

    /// One quest is what ships, and two identical corners give a span of zero — which opens the map
    /// zoomed to the pavement. The floor is set by the chart's own resolution: at a third of a
    /// degree the illustration is drawn near its native size, and well inside that it is blur.
    @Test func aSingleQuestStillOpensAtAReadableSpan() {
        let region = QuestBaseMapView.openingRegion(for: [pin("a", lat: -8.6595, lon: 115.2077)])

        #expect(region.span.latitudeDelta >= QuestBaseMapView.minimumOpeningSpan)
        #expect(region.span.longitudeDelta >= QuestBaseMapView.minimumOpeningSpan)
    }

    /// No quests at all still has to draw somewhere real rather than at the origin in the Gulf of
    /// Guinea, which is what an unguarded zero centre would be.
    @Test func noQuestsStillOpensOverBali() {
        let region = QuestBaseMapView.openingRegion(for: [])

        #expect(region.center.latitude < -8.0)
        #expect(region.center.longitude > 114.0)
    }
}

@MainActor
private final class TestMapLocationProvider: LocationProviding {
    var authorization: LocationAuthorizationSnapshot
    var onFix: ((LocationFix) -> Void)?
    var onAuthorizationChange: ((LocationAuthorizationSnapshot) -> Void)?
    private(set) var requestCount = 0
    private(set) var isStarted = false

    init(authorization: LocationAuthorizationSnapshot) {
        self.authorization = authorization
    }

    func requestWhenInUseAuthorization() { requestCount += 1 }
    func start(target: Coordinate) { isStarted = true }
    func stop() { isStarted = false }

    func change(to snapshot: LocationAuthorizationSnapshot) {
        authorization = snapshot
        onAuthorizationChange?(snapshot)
    }
}
