import CoreLocation
import Foundation

protocol LocationAuthorizationReporting: Sendable {
    func currentAuthorization() -> LocationAuthorizationSnapshot
}

protocol StorageUsageReporting: Sendable {
    func bytesUsedOnDevice() -> Int
}

/// Reads the current authorisation without ever asking for it. Constructing a `CLLocationManager`
/// and reading `authorizationStatus` presents no prompt; `FR-ONB-04` reserves the prompt for the
/// first quest-start attempt, which M5 does not build.
struct SystemLocationAuthorizationReporter: LocationAuthorizationReporting {
    init() {}

    func currentAuthorization() -> LocationAuthorizationSnapshot {
        switch CLLocationManager().authorizationStatus {
        case .notDetermined: .notRequested
        case .denied: .denied
        case .restricted: .restricted
        case .authorizedWhenInUse: .whenInUse
        case .authorizedAlways: .always
        @unknown default: .notRequested
        }
    }
}

/// The app's own container size. `FR-SET-01` asks for storage used, and the honest number is what
/// the app occupies on this device, not the content payload the validator measures.
struct ContainerStorageReporter: StorageUsageReporting {
    init() {}

    func bytesUsedOnDevice() -> Int {
        let candidates = [
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
        ].compactMap { $0 }

        var total = 0
        for root in candidates {
            guard let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else { continue }
            for case let url as URL in walker {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                total += values?.fileSize ?? 0
            }
        }
        return total
    }
}
