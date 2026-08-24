import ContentKit
import Foundation
import RunEngine
import SwiftUI

@MainActor
@Observable
final class HisploraMapViewModel {

    let language: ContentLanguage
    var traces: [HisploraQuestLocation]
    var activeTraceID: String?
    var completedTraceIDs: Set<String>
    var userLocation: Coordinate?
    var userHeading: Double?
    var walkingRoute: [Coordinate]?
    var selectedTrace: HisploraQuestLocation?

    private var locationProvider: (any LocationProviding)?

    init(
        language: ContentLanguage = .en,
        traces: [HisploraQuestLocation] = HisploraQuestLocation.badungTraces,
        activeTraceID: String? = "trace-02",
        completedTraceIDs: Set<String> = ["trace-01"],
        userLocation: Coordinate? = Coordinate(lat: -8.6585, lon: 115.2075),
        userHeading: Double? = 42.0,
        walkingRoute: [Coordinate]? = nil,
        locationProvider: (any LocationProviding)? = nil
    ) {
        self.language = language
        self.traces = traces
        self.activeTraceID = activeTraceID
        self.completedTraceIDs = completedTraceIDs
        self.userLocation = userLocation
        self.userHeading = userHeading
        self.locationProvider = locationProvider

        if let walkingRoute {
            self.walkingRoute = walkingRoute
        } else {
            // Default walking route from Puri Pemecutan to Pura Maospahit and Pasar Badung
            self.walkingRoute = [
                Coordinate(lat: -8.6595, lon: 115.2077),
                Coordinate(lat: -8.6580, lon: 115.2075),
                Coordinate(lat: -8.6570, lon: 115.2085),
                Coordinate(lat: -8.6565, lon: 115.2095),
                Coordinate(lat: -8.6552, lon: 115.2112),
                Coordinate(lat: -8.6540, lon: 115.2115)
            ]
        }

        recomputeDistances()
        setupLocationProvider()
    }

    public var activeTrace: HisploraQuestLocation? {
        guard let activeTraceID else { return nil }
        return traces.first { $0.id == activeTraceID }
    }

    public var discoveredCount: Int {
        completedTraceIDs.count
    }

    public var totalTracesCount: Int {
        traces.count
    }

    public var discoveryProgressText: String {
        "\(discoveredCount)/\(totalTracesCount) TRACES UNCOVERED"
    }

    public func selectTrace(_ trace: HisploraQuestLocation) {
        selectedTrace = trace
    }

    public func dismissSelectedTrace() {
        selectedTrace = nil
    }

    public func markTraceCompleted(_ id: String) {
        completedTraceIDs.insert(id)
        if activeTraceID == id {
            // Advance to next uncompleted trace
            let next = traces.first { !completedTraceIDs.contains($0.id) && $0.id != id }
            activeTraceID = next?.id
        }
        recomputeDistances()
    }

    public func updateUserLocation(_ coordinate: Coordinate, heading: Double? = nil) {
        self.userLocation = coordinate
        if let heading {
            self.userHeading = heading
        }
        recomputeDistances()
    }

    private func recomputeDistances() {
        guard let userLocation else { return }
        for i in 0..<traces.count {
            let dist = Geo.distanceM(userLocation, traces[i].coordinate)
            traces[i].distanceM = dist
        }
        if let sel = selectedTrace, let updated = traces.first(where: { $0.id == sel.id }) {
            selectedTrace = updated
        }
    }

    private func setupLocationProvider() {
        guard let locationProvider else { return }
        locationProvider.onFix = { [weak self] fix in
            self?.updateUserLocation(fix.coordinate)
        }
    }

    public func startLiveTracking() {
        if let active = activeTrace {
            locationProvider?.start(target: active.coordinate)
        } else if let first = traces.first {
            locationProvider?.start(target: first.coordinate)
        }
    }

    public func stopLiveTracking() {
        locationProvider?.stop()
    }
}
