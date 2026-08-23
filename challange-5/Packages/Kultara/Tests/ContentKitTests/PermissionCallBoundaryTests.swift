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
        // **A different kind of caller, admitted deliberately and recorded as such.** The three
        // above own *arrival*; this one owns nothing of the sort — it is the discovery map asking
        // for location so it can draw a dot for where the reader is standing.
        //
        // `FR-ONB-04` bans the prompt during onboarding and says it is asked at the first
        // quest-start attempt. It does not ban a second in-context moment, and a map that draws no
        // dot and explains nothing was the bug this fixed — but the requirement names one moment
        // and there are now two, so this is a deviation and not a reading. It is written down in
        // `docs/prd-amendments/fr-map-01-discovery-basemap.md` and is **unsigned**.
        //
        // It asks only from `.notRequested`, and only `requestWhenInUseAuthorization` — the map
        // never calls `startUpdatingLocation`; `MKMapView.showsUserLocation` does its own.
        "QuestMapViewModel.swift",
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

    /// The three files of the discovery map's live basemap, and nothing else.
    ///
    /// **This list is a narrowing of an outright ban, and the reason is written down rather than
    /// implied.** `FR-MAP-01` bans live map tiles for *in-quest* use, on the stated ground that
    /// MapKit exposes no public offline tile cache — so a walk cannot depend on one. Choosing a
    /// walk is not walking it: the discovery map stands `275:2309`'s chart over a live basemap
    /// (`276:2520`) and falls back to the illustrated surface the moment the basemap does not load.
    /// The PRD amendment scoping the requirement to in-quest use is drafted at
    /// `docs/prd-amendments/fr-map-01-discovery-basemap.md` and **is not signed**; until it is,
    /// this list is the record of exactly how far the exception reaches.
    ///
    /// Matched on file NAME for the same reason `arrivalOwningFiles` is: moving one of these
    /// between folders keeps the guard green, and a *new* file reaching for MapKit turns it red.
    /// That is the sensitivity that matters — the danger is a fourth caller, not a rename.
    static let liveBasemapOwningFiles: Set<String> = [
        "QuestBaseMapView.swift",
        "IllustratedMapOverlay.swift",
        "QuestMapAnnotation.swift",
    ]

    /// The **one** in-quest file allowed to draw live tiles, and the reason, written down rather
    /// than implied — the same shape of record `liveBasemapOwningFiles` is.
    ///
    /// `223:2004` ("Not Quite There") pastes a real street map into its map slot, and on 2026-08-21
    /// the owner instructed that the screen match the frame. So the arrival screen's slot is now an
    /// `MKMapView`. This is a **deviation from `FR-MAP-01`, not a reading of it**: the requirement
    /// is about the walk, and this is the walk.
    ///
    /// What keeps `FR-OFF-03` from being traded away with it: `ArrivalRouteMap` falls back to
    /// `RunRouteMapView` — the authored `route.geojson` on a `Canvas` — on
    /// `mapViewDidFailLoadingMap`, which is a report of a failed load and not a reachability check
    /// (`AD-3`). A walker with the radio off still sees where the next checkpoint is, and nothing
    /// else on that screen is gated on tiles.
    ///
    /// The amendment is `docs/prd-amendments/fr-map-01-arrival-basemap.md` and is **unsigned**.
    /// `theRunItselfNeverDrawsAMapFromLiveTiles` below still bans every other file under
    /// `Features/QuestRun/`, which is what stops this from becoming a general permission.
    static let arrivalBasemapOwningFiles: Set<String> = [
        "ArrivalRouteMapView.swift",
    ]

    static let liveMapTileCalls = ["import MapKit", "MKMapView", "Map("]

    @Test func onlyTheDiscoveryBasemapDrawsMapsFromLiveTiles() throws {
        let permitted = Self.liveBasemapOwningFiles.union(Self.arrivalBasemapOwningFiles)
        let offenders = try Self.occurrences(of: Self.liveMapTileCalls, under: Self.appTarget)
            .filter { offender in
                !permitted.contains { offender.hasPrefix($0 + ":") }
            }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    /// The line that actually matters, asserted separately so narrowing the one above can never
    /// widen this one by accident.
    ///
    /// `FR-MAP-01`/`FR-OFF-03` are about the walk. `RunRouteMapView` projects the authored
    /// `route.geojson` onto a `Canvas` and **must never become a MapKit view** — a walker inside a
    /// covered market with no signal still has to be able to see where the next checkpoint is.
    /// That is precisely why it survives as `ArrivalRouteMap`'s fallback rather than being deleted
    /// when the arrival slot went to live tiles on 2026-08-21.
    ///
    /// One file is exempted, by name, and `arrivalBasemapOwningFiles` carries the reason. Every
    /// other file under `Features/QuestRun/` — `RunRouteMapView` included — still turns this red on
    /// the first `import MapKit`.
    @Test func theRunItselfNeverDrawsAMapFromLiveTiles() throws {
        let run = Self.appTarget
            .appendingPathComponent("Features")
            .appendingPathComponent("QuestRun")
        let offenders = try Self.occurrences(of: Self.liveMapTileCalls, under: run)
            .filter { offender in
                !Self.arrivalBasemapOwningFiles.contains { offender.hasPrefix($0 + ":") }
            }
        #expect(offenders.isEmpty, "\(offenders)")
    }

    /// And the drawn fallback is still drawn. Without this, the exemption above could be widened by
    /// simply moving the canvas into the exempt file and deleting it — which is the one change that
    /// would turn a scoped deviation into losing `FR-OFF-03` outright.
    @Test func theDrawnRunMapSurvivesAsTheOfflineFallback() throws {
        let canvas = Self.appTarget
            .appendingPathComponent("Features")
            .appendingPathComponent("QuestRun")
            .appendingPathComponent("RunRouteMapView.swift")
        let source = try String(contentsOf: canvas, encoding: .utf8)
        #expect(source.contains("Canvas {"))
        #expect(!source.contains("import MapKit"))

        let arrival = Self.appTarget
            .appendingPathComponent("Features")
            .appendingPathComponent("QuestRun")
            .appendingPathComponent("ArrivalRouteMapView.swift")
        let wrapper = try String(contentsOf: arrival, encoding: .utf8)
        #expect(wrapper.contains("RunRouteMapView("),
                "The live basemap must fall back to the drawn map (FR-OFF-03).")
        #expect(wrapper.contains("mapViewDidFailLoadingMap"),
                "The fallback must be driven by a failed load, never by a reachability check (AD-3).")
    }

    /// And no package target may reach for it at all. `ContentKit` and `RunEngine` are Foundation
    /// layers, `DesignSystem` knows nothing about geography, and the exception above is a decision
    /// the app target owns.
    @Test func noPackageTargetDrawsMapsFromLiveTiles() throws {
        var offenders: [String] = []
        for target in ["ContentKit", "RunEngine", "DesignSystem"] {
            offenders += try Self.occurrences(of: Self.liveMapTileCalls,
                                              under: Self.packageTarget(target))
        }
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
