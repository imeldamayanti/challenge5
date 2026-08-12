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
            // `Content/consent` is a build input, not a runtime resource (`schema.md` §A.1).
            // It is excluded rather than moved so consent records live beside the content they
            // govern, while staying out of every user's copy of the app — shipping the names,
            // roles and document references of named individuals would serve no purpose the
            // build-time validator does not already serve.
            exclude: ["Content/consent"],
            resources: [
                .copy("Content/manifest.json"),
                .copy("Content/places"),
                .copy("Content/quests"),
                .copy("Content/assets"),
            ]
        ),
        .target(
            name: "DesignSystem",
            resources: [
                // Instrument Serif, SIL OFL 1.1 (licence shipped beside the faces). Registered at
                // runtime by `KultaraFonts` rather than declared in the app's Info.plist, so the
                // package carries its own typeface instead of depending on the host target
                // remembering to list it.
                .copy("Resources/Fonts"),
            ]
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
