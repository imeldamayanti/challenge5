import ContentKit
import CoreGraphics
import Foundation
import RunEngine
import Testing
@testable import challange_5

@MainActor
struct HisploraMapTests {

    // MARK: - Projection Tests

    @Test func projectionMapsCenterCoordinateToViewportCenter() {
        let viewport = CGSize(width: 400, height: 800)
        let projection = HisploraMapProjection(
            center: HisploraDenpasarDistrict.centerCoordinate,
            zoom: 1.0,
            panOffset: .zero,
            viewportSize: viewport
        )

        let centerPoint = projection.project(HisploraDenpasarDistrict.centerCoordinate)
        #expect(abs(centerPoint.x - 200) < 0.001)
        #expect(abs(centerPoint.y - 400) < 0.001)
    }

    @Test func projectionRoundTripMaintainsHighGeographicAccuracy() {
        let viewport = CGSize(width: 390, height: 844)
        let projection = HisploraMapProjection(
            center: HisploraDenpasarDistrict.centerCoordinate,
            zoom: 1.5,
            panOffset: CGSize(width: 25, height: -40),
            viewportSize: viewport
        )

        // Test with Puri Agung Pemecutan coordinates
        let puriCoord = Coordinate(lat: -8.6595, lon: 115.2077)
        let projectedPoint = projection.project(puriCoord)
        let unprojectedCoord = projection.unproject(projectedPoint)

        #expect(abs(unprojectedCoord.lat - puriCoord.lat) < 0.00001)
        #expect(abs(unprojectedCoord.lon - puriCoord.lon) < 0.00001)
    }

    @Test func metersToPointsConvertsAccurately() {
        let viewport = CGSize(width: 390, height: 844)
        let projection = HisploraMapProjection(zoom: 1.0, viewportSize: viewport)

        let pointsFor100m = projection.metersToPoints(100.0)
        #expect(pointsFor100m > 10)
        #expect(pointsFor100m < 50)

        let metersBack = projection.pointsToMeters(pointsFor100m)
        #expect(abs(metersBack - 100.0) < 0.1)
    }

    @Test func panClampingPreventsLosingMap() {
        let viewport = CGSize(width: 400, height: 800)
        let projection = HisploraMapProjection(zoom: 1.0, viewportSize: viewport)

        let wildPan = CGSize(width: 50000, height: -50000)
        let clamped = projection.clampedPan(wildPan)

        #expect(abs(clamped.width) < 2000)
        #expect(abs(clamped.height) < 2000)
    }

    // MARK: - GeoData & Landmarks Tests

    @Test func denpasarHeritageDistrictContainsAllEssentialRoadsAndWaterways() {
        let roads = HisploraDenpasarDistrict.roads
        let waterways = HisploraDenpasarDistrict.waterways
        let areas = HisploraDenpasarDistrict.areas

        #expect(roads.contains { $0.name == "Jl. Thamrin" })
        #expect(roads.contains { $0.name == "Jl. Gajah Mada" })
        #expect(roads.contains { $0.name == "Jl. Hasanuddin" })
        #expect(roads.contains { $0.name == "Jl. Veteran" })
        #expect(roads.contains { $0.name == "Jl. Wahidin" })
        #expect(roads.contains { $0.name == "Jl. Gambuh" })
        #expect(roads.contains { $0.name == "Jl. Beliton" })

        #expect(waterways.contains { $0.name == "Tukad Badung" })
        #expect(areas.contains { $0.name == "Lapangan Puputan Badung" })
        #expect(areas.contains { $0.name == "Puri Agung Pemecutan" })
    }

    // MARK: - ViewModel & Traces Tests

    @Test func viewModelTracksActiveAndDiscoveredTraces() {
        let model = HisploraMapViewModel(
            activeTraceID: "trace-02",
            completedTraceIDs: ["trace-01"]
        )

        #expect(model.discoveredCount == 1)
        #expect(model.totalTracesCount == 5)
        #expect(model.activeTrace?.id == "trace-02")
        #expect(model.discoveryProgressText == "1/5 TRACES UNCOVERED")

        model.markTraceCompleted("trace-02")
        #expect(model.discoveredCount == 2)
        #expect(model.completedTraceIDs.contains("trace-02"))
        #expect(model.activeTrace?.id == "trace-03")
    }

    @Test func userLocationUpdateRecomputesTraceDistances() {
        let model = HisploraMapViewModel()
        let userPos = Coordinate(lat: -8.6595, lon: 115.2077) // At Puri Pemecutan
        model.updateUserLocation(userPos, heading: 90.0)

        #expect(model.userLocation == userPos)
        #expect(model.userHeading == 90.0)

        // Trace 1 (Puri Pemecutan) distance should be near 0
        let trace1 = model.traces.first { $0.id == "trace-01" }
        #expect(trace1?.distanceM != nil)
        #expect(trace1!.distanceM! < 10)
    }

    @Test func selectingAndDismissingTraceWorks() {
        let model = HisploraMapViewModel()
        let trace = model.traces[1]

        model.selectTrace(trace)
        #expect(model.selectedTrace?.id == trace.id)

        model.dismissSelectedTrace()
        #expect(model.selectedTrace == nil)
    }

    @Test func realtimeLocationFixUpdatesViewModel() {
        let provider = TestDenpasarLocationProvider()
        let model = HisploraMapViewModel(locationProvider: provider)

        model.startLiveTracking()
        #expect(provider.isStarted == true)

        let pasarBadung = Coordinate(lat: -8.6540, lon: 115.2115)
        provider.sendFix(pasarBadung)

        #expect(model.userLocation == pasarBadung)

        let pasarTrace = model.traces.first { $0.id == "trace-03" }
        #expect(pasarTrace != nil)
        #expect(pasarTrace?.distanceM != nil)
        #expect(pasarTrace!.distanceM! < 10.0)

        model.stopLiveTracking()
        #expect(provider.isStarted == false)
    }

    // MARK: - Reference Style & Deep Zoom Tests

    @Test func roundaboutsAndBadgesDefinedWithValidCoordinates() {
        let roundabouts = HisploraDenpasarDistrict.roundabouts
        #expect(roundabouts.count >= 2)
        for rb in roundabouts {
            #expect(rb.radiusM > 0)
            #expect(rb.coordinate.lat < 0)
            #expect(rb.coordinate.lon > 115.0)
        }

        let badges = HisploraDenpasarDistrict.transitBadges
        #expect(badges.count >= 4)
        #expect(badges.contains { $0.symbol == "M" })
        #expect(badges.contains { $0.symbol == "KL" })
        #expect(badges.contains { $0.symbol == "T" })
    }

    @Test func calligraphicLandmarksMatchReferenceArt() {
        let landmarks = HisploraDenpasarDistrict.calligraphicLandmarks
        #expect(landmarks.count >= 2)

        let pemecutan = landmarks.first { $0.id == "cal-puri-pemecutan" }
        #expect(pemecutan != nil)
        #expect(pemecutan?.title.contains("PURI AGUNG") == true)
        #expect(pemecutan?.title.contains("PEMECUTAN") == true)
        #expect(pemecutan?.textColorHex == "#2D4C6B")

        let puputan = landmarks.first { $0.id == "cal-lapangan-puputan" }
        #expect(puputan != nil)
        #expect(puputan?.title.contains("LAPANGAN") == true)
        #expect(puputan?.title.contains("PUPUTAN") == true)
        #expect(puputan?.textColorHex == "#295C38")
    }

    @Test func deepZoomProjectionAccuracy() {
        let center = HisploraDenpasarDistrict.centerCoordinate
        let viewport = CGSize(width: 393, height: 852)

        // Test normal zoom (1.0) and deep zoom (6.0)
        let normalProjection = HisploraMapProjection(center: center, zoom: 1.0, viewportSize: viewport)
        let deepProjection = HisploraMapProjection(center: center, zoom: 6.0, viewportSize: viewport)

        let ptNormal = normalProjection.project(center)
        let ptDeep = deepProjection.project(center)

        #expect(abs(ptNormal.x - viewport.width / 2.0) < 0.01)
        #expect(abs(ptNormal.y - viewport.height / 2.0) < 0.01)
        #expect(abs(ptDeep.x - viewport.width / 2.0) < 0.01)
        #expect(abs(ptDeep.y - viewport.height / 2.0) < 0.01)

        // Distance in screen points scales linearly with zoom
        let distNormal = normalProjection.metersToPoints(100)
        let distDeep = deepProjection.metersToPoints(100)
        #expect(abs(distDeep - distNormal * 6.0) < 0.01)
    }
}

@MainActor
private final class TestDenpasarLocationProvider: LocationProviding {
    var authorization: LocationAuthorizationSnapshot = .whenInUse
    var onFix: ((LocationFix) -> Void)?
    var onAuthorizationChange: ((LocationAuthorizationSnapshot) -> Void)?
    var isStarted = false
    var targetCoordinate: Coordinate?

    func requestWhenInUseAuthorization() {}
    func start(target: Coordinate) {
        isStarted = true
        targetCoordinate = target
    }
    func stop() {
        isStarted = false
        targetCoordinate = nil
    }

    func sendFix(_ coord: Coordinate) {
        onFix?(LocationFix(coordinate: coord, horizontalAccuracyM: 5.0, timestamp: Date()))
    }
}
