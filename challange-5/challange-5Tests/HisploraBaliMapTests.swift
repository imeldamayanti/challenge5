import ContentKit
import Foundation
import RunEngine
import Testing
@testable import challange_5

@Suite("Hisplora Bali Map Tests")
struct HisploraBaliMapTests {

    let viewport = CGSize(width: 393, height: 852)

    @Test("Whole Bali projection maps island center to viewport center")
    func projectionMapsIslandCenterToViewportCenter() {
        let center = HisploraBaliGeoData.islandCenter
        let projection = HisploraBaliMapProjection(
            center: center,
            zoom: 1.0,
            panOffset: .zero,
            viewportSize: viewport
        )

        let projected = projection.project(center)
        #expect(abs(projected.x - 393 / 2.0) < 0.001)
        #expect(abs(projected.y - 852 / 2.0) < 0.001)
    }

    @Test("Whole Bali projection round trip maintains high geographic precision across all extremities")
    func projectionRoundTripMaintainsPrecision() {
        let projection = HisploraBaliMapProjection(
            center: HisploraBaliGeoData.islandCenter,
            zoom: 1.5,
            panOffset: CGSize(width: 15, height: -10),
            viewportSize: viewport
        )

        let testLocations = [
            Coordinate(lat: -8.165, lon: 114.435), // Gilimanuk (West)
            Coordinate(lat: -8.115, lon: 115.090), // Singaraja (North)
            Coordinate(lat: -8.410, lon: 115.720), // Tanjung Seraya (East)
            Coordinate(lat: -8.850, lon: 115.150), // Ungasan (South)
            Coordinate(lat: -8.770, lon: 115.620), // Nusa Penida (Southeast)
            Coordinate(lat: -8.343, lon: 115.508)  // Gunung Agung Peak
        ]

        for loc in testLocations {
            let pt = projection.project(loc)
            let back = projection.unproject(pt)
            #expect(abs(back.lat - loc.lat) < 0.0001)
            #expect(abs(back.lon - loc.lon) < 0.0001)
        }
    }

    @Test("Meters to points converts accurately at Bali latitude")
    func metersToPointsConvertsAccurately() {
        let projection = HisploraBaliMapProjection(
            center: HisploraBaliGeoData.islandCenter,
            zoom: 1.0,
            panOffset: .zero,
            viewportSize: viewport
        )

        let points10km = projection.metersToPoints(10000)
        #expect(points10km > 10.0)
        #expect(points10km < 100.0)

        let backMeters = projection.pointsToMeters(points10km)
        #expect(abs(backMeters - 10000) < 1.0)
    }

    @Test("Bali GeoData contains complete coastlines, islands, peaks, lakes, and 9 regencies")
    func baliGeoDataCompleteness() {
        // Coastlines
        #expect(HisploraBaliGeoData.mainlandCoastline.count >= 20)
        #expect(HisploraBaliGeoData.nusaPenidaCoastline.count >= 8)
        #expect(HisploraBaliGeoData.nusaLembonganCoastline.count >= 4)
        #expect(HisploraBaliGeoData.pulauMenjanganCoastline.count >= 4)

        // Peaks
        #expect(HisploraBaliGeoData.mountainPeaks.count >= 5)
        #expect(HisploraBaliGeoData.mountainPeaks.contains { $0.id == "gunung-agung" && $0.elevationM == 3142 })

        // Lakes
        #expect(HisploraBaliGeoData.lakes.count >= 4)
        #expect(HisploraBaliGeoData.lakes.contains { $0.id == "danau-batur" })
        #expect(HisploraBaliGeoData.lakes.contains { $0.id == "danau-beratan" })

        // Regencies
        #expect(HisploraBaliGeoData.regencies.count == 9)

        // Landmarks
        #expect(HisploraBaliGeoData.landmarks.count >= 15)

        // All coordinates inside bounding box
        let bounds = HisploraBaliGeoData.baliBounds
        for landmark in HisploraBaliGeoData.landmarks {
            #expect(landmark.coordinate.lat >= bounds.minLat && landmark.coordinate.lat <= bounds.maxLat)
            #expect(landmark.coordinate.lon >= bounds.minLon && landmark.coordinate.lon <= bounds.maxLon)
        }
    }

    @Test("Bali Map View Model category filtering works correctly")
    @MainActor
    func viewModelCategoryFiltering() {
        let vm = HisploraBaliMapViewModel()
        #expect(vm.activeFilteredLandmarks.count == HisploraBaliGeoData.landmarks.count)

        vm.selectCategory(.pura)
        #expect(vm.activeFilteredLandmarks.allSatisfy { $0.category == .pura })
        #expect(vm.activeFilteredLandmarks.count > 0)

        vm.selectCategory(.puri)
        #expect(vm.activeFilteredLandmarks.allSatisfy { $0.category == .puri })
        #expect(vm.activeFilteredLandmarks.count > 0)

        vm.selectCategory(.nature)
        #expect(vm.activeFilteredLandmarks.allSatisfy { $0.category == .nature })

        vm.selectCategory(.village)
        #expect(vm.activeFilteredLandmarks.allSatisfy { $0.category == .village })

        vm.selectCategory(.all)
        #expect(vm.activeFilteredLandmarks.count == HisploraBaliGeoData.landmarks.count)
    }

    @Test("Updating user location updates landmark distances")
    @MainActor
    func userLocationUpdatesDistances() {
        let vm = HisploraBaliMapViewModel()
        let denpasar = Coordinate(lat: -8.6565, lon: 115.2125)
        vm.updateUserLocation(denpasar)

        let pemecutan = vm.landmarks.first { $0.id == "denpasar-heritage-district" }
        #expect(pemecutan != nil)
        #expect(pemecutan?.distanceM != nil)
        #expect(pemecutan!.distanceM! < 2000.0) // Very close to Denpasar center
    }

    @Test("Pan clamping keeps map bounded")
    func panClampingKeepsMapBounded() {
        let projection = HisploraBaliMapProjection(
            center: HisploraBaliGeoData.islandCenter,
            zoom: 1.0,
            panOffset: .zero,
            viewportSize: viewport
        )

        let wildPan = CGSize(width: 5000, height: -5000)
        let clamped = projection.clampedPan(wildPan)
        #expect(abs(clamped.width) < 5000)
        #expect(abs(clamped.height) < 5000)
    }

    @Test("Real-time location provider streams GPS fixes and updates ViewModel distances")
    @MainActor
    func realtimeLocationFixUpdatesViewModel() {
        let provider = TestMapLocationProvider()
        let vm = HisploraBaliMapViewModel(locationProvider: provider)

        vm.startLiveTracking()
        #expect(provider.isStarted == true)

        let uluwatu = Coordinate(lat: -8.8290, lon: 115.0849)
        provider.sendFix(uluwatu)

        #expect(vm.userLocation == uluwatu)

        let uluwatuSite = vm.landmarks.first { $0.id == "pura-luhur-uluwatu" }
        #expect(uluwatuSite != nil)
        #expect(uluwatuSite?.distanceM != nil)
        #expect(uluwatuSite!.distanceM! < 500.0) // Right at Uluwatu

        vm.stopLiveTracking()
        #expect(provider.isStarted == false)
    }
}

@MainActor
private final class TestMapLocationProvider: LocationProviding {
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
