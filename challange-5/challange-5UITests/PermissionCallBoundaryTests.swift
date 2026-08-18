import XCTest

/// `AD-1` splits location by purpose: foreground arrival sampling in one file, background region
/// monitoring in another, and nothing else in the app target ever touches `CLLocationManager`
/// directly. Nothing enforces that boundary but this scan — a new call site anywhere else compiles
/// cleanly, and the first sign of it today is a walker's phone doing something `NFR-BAT-01`
/// forbids (`s6` §1).
///
/// Text-scanned rather than reflected, the same way `ContentKitTests.ImportBoundaryTests` holds
/// the package's import boundary: this target has no import boundary to lean on, so the source
/// itself is the only thing left to check. Each assertion also requires its call site to still
/// exist, so a rewrite that quietly deletes the call cannot pass by finding nothing
/// (`s6` §1's own warning about this suite).
final class PermissionCallBoundaryTests: XCTestCase {

    /// `…/challange-5UITests/PermissionCallBoundaryTests.swift` → `…/challange-5` (this file's
    /// grandparent) → the app target's own source root, `…/challange-5/challange-5`.
    private static var appTargetRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/challange-5UITests
            .deletingLastPathComponent()   // …/challange-5 (the Xcode project directory)
            .appendingPathComponent("challange-5")
    }

    private static func swiftFiles() throws -> [(name: String, source: String)] {
        let root = appTargetRoot
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        else { return [] }
        let files = walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertFalse(files.isEmpty, "No Swift files found under \(root.path) — the scan would pass vacuously.")
        return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    /// Every file whose source contains `needle`, restricted to a call on the `manager` instance
    /// each of the two location services holds — `locationProvider.foo()` and `sampling.foo()`
    /// are the `LocationProviding` abstraction working as intended and are not what this confines;
    /// `manager.foo()` is the one line in each file that reaches `CLLocationManager` itself.
    private func filesCalling(_ needle: String) throws -> Set<String> {
        Set(try Self.swiftFiles()
            .filter { $0.source.contains("manager.\(needle)") }
            .map(\.name))
    }

    // MARK: - Foreground sampling — LocationService.swift

    func testRequestWhenInUseAuthorizationIsConfinedToLocationService() throws {
        let offenders = try filesCalling("requestWhenInUseAuthorization()")
        XCTAssertEqual(offenders, ["LocationService.swift"],
                        "manager.requestWhenInUseAuthorization() must be called from LocationService.swift alone.")
    }

    func testStartUpdatingLocationIsConfinedToLocationService() throws {
        let offenders = try filesCalling("startUpdatingLocation()")
        XCTAssertEqual(offenders, ["LocationService.swift"],
                        "manager.startUpdatingLocation() must be called from LocationService.swift alone — anywhere else is a step towards NFR-BAT-01's forbidden continuous background updates.")
    }

    // MARK: - Background region monitoring — SideQuestProximityService.swift (`s3`)

    func testRequestAlwaysAuthorizationIsConfinedToSideQuestProximityService() throws {
        let offenders = try filesCalling("requestAlwaysAuthorization()")
        XCTAssertEqual(offenders, ["SideQuestProximityService.swift"],
                        "manager.requestAlwaysAuthorization() must be called from SideQuestProximityService.swift alone.")
    }

    func testStartMonitoringForRegionIsConfinedToSideQuestProximityService() throws {
        let offenders = try filesCalling("startMonitoring(for:")
        XCTAssertEqual(offenders, ["SideQuestProximityService.swift"],
                        "manager.startMonitoring(for:) must be called from SideQuestProximityService.swift alone.")
    }

    // MARK: - The outright ban — NFR-BAT-01

    /// `NFR-BAT-01`: "MUST NOT use continuous background location updates in any release." Region
    /// monitoring does not need `allowsBackgroundLocationUpdates`, and setting it anywhere is the
    /// single line that would cross into what this forbids.
    func testNothingEnablesContinuousBackgroundLocationUpdates() throws {
        let offenders = try Self.swiftFiles()
            .filter { $0.source.contains("allowsBackgroundLocationUpdates = true") }
            .map(\.name)
        XCTAssertTrue(offenders.isEmpty,
                       "allowsBackgroundLocationUpdates must never be set: \(offenders)")
    }

    /// The `Info.plist` half of the same claim: region monitoring needs no `UIBackgroundModes`
    /// entry, and `CLAUDE.md` is explicit that finding one means something has gone wrong.
    func testProjectDeclaresNoBackgroundLocationMode() throws {
        let pbxproj = Self.appTargetRoot
            .deletingLastPathComponent()   // …/challange-5 (Xcode project directory)
            .appendingPathComponent("challange-5.xcodeproj/project.pbxproj")
        let source = try String(contentsOf: pbxproj, encoding: .utf8)
        XCTAssertFalse(source.contains("UIBackgroundModes"),
                        "No target may declare UIBackgroundModes — region monitoring needs none, and NFR-BAT-01 forbids continuous background location updates in any release.")
    }
}
