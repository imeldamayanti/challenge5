import ContentKit
import Foundation
import RunEngine
import SwiftUI

@MainActor
@Observable
final class HisploraBaliMapViewModel {

    let language: ContentLanguage
    var landmarks: [HisploraBaliLandmark]
    var selectedCategory: HisploraBaliLandmarkCategory = .all
    var selectedLandmark: HisploraBaliLandmark?
    var userLocation: Coordinate?
    var userHeading: Double?

    private var locationProvider: (any LocationProviding)?

    init(
        language: ContentLanguage = .en,
        landmarks: [HisploraBaliLandmark] = HisploraBaliGeoData.landmarks,
        userLocation: Coordinate? = Coordinate(lat: -8.6565, lon: 115.2125), // Denpasar default
        userHeading: Double? = 35.0,
        locationProvider: (any LocationProviding)? = nil
    ) {
        self.language = language
        self.landmarks = landmarks
        self.userLocation = userLocation
        self.userHeading = userHeading
        self.locationProvider = locationProvider

        recomputeDistances()
        setupLocationProvider()
    }

    var totalLandmarksCount: Int {
        landmarks.count
    }

    var activeFilteredLandmarks: [HisploraBaliLandmark] {
        if selectedCategory == .all {
            return landmarks
        } else {
            return landmarks.filter { $0.category == selectedCategory }
        }
    }

    func selectCategory(_ category: HisploraBaliLandmarkCategory) {
        selectedCategory = category
    }

    func selectLandmark(_ landmark: HisploraBaliLandmark) {
        selectedLandmark = landmark
    }

    func dismissSelectedLandmark() {
        selectedLandmark = nil
    }

    func updateUserLocation(_ coordinate: Coordinate, heading: Double? = nil) {
        self.userLocation = coordinate
        if let heading {
            self.userHeading = heading
        }
        recomputeDistances()
    }

    private func recomputeDistances() {
        guard let userLocation else { return }
        for i in 0..<landmarks.count {
            let dist = Geo.distanceM(userLocation, landmarks[i].coordinate)
            landmarks[i].distanceM = dist
        }
        if let sel = selectedLandmark, let updated = landmarks.first(where: { $0.id == sel.id }) {
            selectedLandmark = updated
        }
    }

    private func setupLocationProvider() {
        guard let locationProvider else { return }
        locationProvider.onFix = { [weak self] fix in
            self?.updateUserLocation(fix.coordinate)
        }
    }

    func startLiveTracking() {
        if let first = landmarks.first {
            locationProvider?.start(target: first.coordinate)
        }
    }

    func stopLiveTracking() {
        locationProvider?.stop()
    }
}
