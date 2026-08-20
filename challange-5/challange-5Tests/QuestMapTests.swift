import ContentKit
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

    /// `AD-3`/`FR-OFF-03`: a basemap that does not load hands the screen to the surface that never
    /// needed one. Nothing predicts the failure — the model only records one that happened.
    @Test func aBasemapThatFailsHandsOverToTheOfflineSurface() {
        let model = QuestMapViewModel()
        #expect(!model.usesOfflineSurface)

        model.basemapDidFail()
        #expect(model.usesOfflineSurface)

        model.basemapDidLoad()
        #expect(!model.usesOfflineSurface)
    }

    /// Falling back while illustrated lands on very nearly the same picture, so saying a real map
    /// was lost would announce a loss the reader cannot see. It is said only when the reader had
    /// asked for the thing that went missing.
    @Test func theOfflineNoticeIsSaidOnlyWhenTheRealGroundWasTheOneAskedFor() {
        let model = QuestMapViewModel()

        model.basemapDidFail()
        #expect(!model.showsOfflineNotice)

        model.toggleMode()
        #expect(model.showsOfflineNotice)
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
