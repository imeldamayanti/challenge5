import Foundation
import Testing

/// `FR-ONB-04` — location permission must not be requested during onboarding; it is requested in
/// context at the first quest-start attempt. `FR-ONB-06` — no App Tracking Transparency prompt,
/// because nothing is collected for tracking. `NFR-BAT-01` — no continuous background location in
/// any release. `AD-3` — no reachability check anywhere. `FR-MAP-01` — no live map tiles.
///
/// Restored by `m7` Decision 1a. This suite scans source text and links nothing, so it never needed
/// to live beside the code it guards — which is why it can sit in the package and run under
/// `swift test` on macOS in under two seconds while the other 107 restored tests need a simulator.
/// `ImportBoundaryTests` next door already walks out from `#filePath`; this is the same technique
/// pointed at two trees instead of one.
///
/// Confinement rather than absence is what the requirements actually say about the two foreground
/// calls. A comment saying so would decay; this does not.
struct PermissionCallBoundaryTests {

    // MARK: Roots

    /// The Xcode app target — `Model/ ViewModel/ View/ Service/ Support/` since `b597b5b`.
    static var appTarget: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ContentKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // Kultara (package root)
            .deletingLastPathComponent()   // Packages
            .deletingLastPathComponent()   // challange-5 (Xcode project directory)
            .appendingPathComponent("challange-5")
    }

    static func packageTarget(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent(name)
    }

    // MARK: Ban lists
    //
    // m7 Decision 3: the lists themselves do not change when the roots do. A ban that gets shorter
    // to make a scan pass is not a ban.

    /// Permitted only where arrival lives.
    ///
    /// **The owning set has grown since `m7` was written, and this records why rather than quietly
    /// widening a ban.** The plan names `LocationService.swift` and `QuestRunViewModel.swift`. Two
    /// files have joined them since:
    ///
    /// - `ArrivalSampling.swift` — the sampler extracted out of `QuestRunViewModel`. It *is* the
    ///   arrival path; the extraction moved the call, it did not add one.
    /// - `SideQuestFlowViewModel.swift` — sidequest discovery is gated on the same radius rule
    ///   (`FR-SIDE-*`, `s2` §6), so it owns arrival for sidequests exactly as the quest run owns it
    ///   for checkpoints.
    ///
    /// Neither is a new *kind* of caller, which is the thing this guard exists to stop. A view, an
    /// onboarding screen or a settings model appearing here would be.
    static let foregroundArrivalCalls = [
        "requestWhenInUseAuthorization",   // FR-ONB-04, FR-START-02
        "startUpdatingLocation",           // FR-ARR-02, NFR-BAT-04
    ]

    /// Matched on file NAME, not path: moving a file between folders keeps the guard green while
    /// renaming it turns it red. That is the right sensitivity — the guard is about which component
    /// owns the call, and the folder layout is the thing that keeps changing.
    static let arrivalOwningFiles: Set<String> = [
        "LocationService.swift",
        "QuestRunViewModel.swift",
        "ArrivalSampling.swift",
        "SideQuestFlowViewModel.swift",
    ]

    /// Banned everywhere, in every release.
    static let forbiddenCalls = [
        "requestAlwaysAuthorization",      // FR-ONB-04, FR-PROX-03
        "startMonitoringSignificantLocationChanges",
        "startMonitoring(for:",            // FR-PROX / FR-SIDE-14 region monitoring is not built
        "allowsBackgroundLocationUpdates", // NFR-BAT-01
        "ATTrackingManager",               // FR-ONB-06
        "AppTrackingTransparency",
        "requestTrackingAuthorization",
    ]

    /// `AD-3`, and the specific mistake it exists to prevent. Every core flow works with the radio
    /// off, so there is nothing anywhere that should need to ask whether it is on.
    static let forbiddenReachability = [
        "NWPathMonitor",
        "SCNetworkReachability",
        "isReachable",
    ]

    // MARK: Tests

    @Test func theAppUsesNoBackgroundLocationAndNoTrackingPrompt() throws {
        var offenders = try Self.occurrences(of: Self.forbiddenCalls, under: Self.appTarget)
        offenders += try Self.occurrences(of: Self.forbiddenCalls, under: Self.packageTarget("DesignSystem"))
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test func foregroundLocationCallsStayInTheFilesThatOwnArrival() throws {
        let offenders = try Self
            .occurrences(of: Self.foregroundArrivalCalls, under: Self.appTarget)
            .filter { offender in
                let file = offender.split(separator: ":").first.map(String.init) ?? offender
                return !Self.arrivalOwningFiles.contains(file)
            }
        #expect(offenders.isEmpty,
                "Location sampling and its prompt belong to the arrival path only; found: \(offenders)")
    }

    @Test func theArrivalPathIsActuallyWhereThoseCallsAre() throws {
        // Without this the filter above passes vacuously the day someone renames the files, and a
        // guard that can pass by finding nothing is not a guard. FR-START-08 says a quest must not
        // be startable from outside the start radius by ANY path; this scan is the only mechanical
        // thing standing between that requirement and a second location call site.
        let found = try Self.occurrences(of: Self.foregroundArrivalCalls, under: Self.appTarget)
        #expect(!found.isEmpty)
    }

    @Test func noModuleChecksReachability() throws {
        var offenders = try Self.occurrences(of: Self.forbiddenReachability, under: Self.appTarget)
        // `GovernanceKit` and `TelemetryKit` are the two targets that actually touch the network
        // (`c1` §4b/§4c), which makes them the only place a reachability check would ever look
        // reasonable — "don't try if we're offline". Both attempt the request and read the outcome
        // instead: a failed fetch keeps the last good copy, a non-200 leaves rows queued, and a
        // thrown error is handled identically to a bad status. This is the guard on that.
        for target in ["ContentKit", "RunEngine", "DesignSystem", "UIStringsKit",
                       "GovernanceKit", "TelemetryKit"] {
            offenders += try Self.occurrences(of: Self.forbiddenReachability,
                                              under: Self.packageTarget(target))
        }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    @Test func theAppDoesNotDrawMapsFromLiveTiles() throws {
        // FR-MAP-01 / FR-OFF-03: the route display must not depend on live map tiles, and MapKit
        // exposes no public offline tile cache. The region map renders a shipped illustration and
        // the run map projects route.geojson onto a Canvas (RunRouteMapView).
        let offenders = try Self.occurrences(of: ["import MapKit", "MKMapView", "Map("],
                                             under: Self.appTarget)
        #expect(offenders.isEmpty, "\(offenders)")
    }

    // MARK: Scanner

    static func occurrences(of needles: [String], under root: URL) throws -> [String] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return ["No sources found under \(root.path)"]
        }
        let files = walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        // The same property one level down: a scan pointed at a directory that no longer exists
        // must fail, not pass.
        #expect(!files.isEmpty, "No Swift files under \(root.path) — the scan would pass vacuously.")

        var offenders: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                // Skip comments: these strings appear in the requirement notes on purpose.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("*"), !trimmed.hasPrefix("/*") else { continue }
                for needle in needles where contains(line: String(line), needle: needle) {
                    offenders.append("\(file.lastPathComponent):\(number + 1) \(needle)")
                }
            }
        }
        return offenders
    }

    /// Substring matching with a left word boundary, because a bare `contains` cannot tell
    /// SwiftUI's `Map(` from Swift's `flatMap(` — and a guard that fires on `flatMap` is a guard
    /// someone eventually deletes rather than fixes. The boundary is only needed on the left: the
    /// needles all end in a delimiter or are whole tokens.
    private static func contains(line: String, needle: String) -> Bool {
        var search = line[...]
        while let found = search.range(of: needle) {
            let isBoundary = found.lowerBound == line.startIndex
                || !isIdentifierCharacter(line[line.index(before: found.lowerBound)])
            if isBoundary { return true }
            search = line[found.upperBound...]
        }
        return false
    }

    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
