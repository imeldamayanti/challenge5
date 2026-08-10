// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Kultara",
    platforms: [
        // iOS 18.0 is the app's deployment target (see .claude/plans/m5-discovery-preview.plan.md,
        // Decision 1). macOS is declared only so the pure-logic suites run under `swift test`
        // without booting a simulator.
        .iOS(.v18),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ContentKit", targets: ["ContentKit"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "AppFeatures", targets: ["AppFeatures"]),
        .executable(name: "content-validator", targets: ["ContentValidatorCLI"]),
    ],
    targets: [
        // Foundation only. Linking SwiftUI, UIKit, CoreLocation or MapKit here is a
        // build-level impossibility, which is the point — see system-design.md §3.
        .target(
            name: "ContentKit",
            resources: [.copy("Content")]
        ),
        .target(
            name: "DesignSystem"
        ),
        .target(
            name: "AppFeatures",
            dependencies: ["ContentKit", "DesignSystem"]
        ),
        .executableTarget(
            name: "ContentValidatorCLI",
            dependencies: ["ContentKit"]
        ),
        .testTarget(
            name: "ContentKitTests",
            dependencies: ["ContentKit"]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"]
        ),
        .testTarget(
            name: "AppFeaturesTests",
            dependencies: ["AppFeatures"]
        ),
    ]
)
