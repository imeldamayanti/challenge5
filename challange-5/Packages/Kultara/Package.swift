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
        .library(name: "RunEngine", targets: ["RunEngine"]),
        .library(name: "UIStringsKit", targets: ["UIStringsKit"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "GovernanceKit", targets: ["GovernanceKit"]),
        .library(name: "TelemetryKit", targets: ["TelemetryKit"]),
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
                .copy("Content/sidequests"),
                .copy("Content/collections"),
                .copy("Content/assets"),
            ]
        ),
        // The user store and the rules that write it. Foundation and `ContentKit` only: the
        // ordering, award and snapshot rules are where correctness bugs hide, and they are worth
        // being able to test without a simulator (`system-design.md` §3, §14).
        .target(
            name: "RunEngine",
            dependencies: ["ContentKit"]
        ),
        // The interface string table. It lived in the app target until `s4`, where it had no
        // unit-test bundle to hold it: `everyKeyHasAnEntry`,
        // `everyEntryIsTranslatedInBothLanguages` and `indonesianAndEnglishAreActuallyDifferentText`
        // were deleted with `AppFeaturesTests` at `b597b5b`, and a `UIStringKey` case added without
        // a table entry rendered its own raw name at runtime with nothing failing
        // (`NFR-I18N-01/02`). Moving the table into a package is what puts those three guards back
        // under `swift test` (`s4` §8, option 2).
        //
        // It depends on `ContentKit` for `LocalizedText` alone — the same no-fallback type content
        // uses, so an untranslated label cannot appear mid-screen in the other language
        // (`NFR-I18N-03`). `DesignSystem` deliberately does **not** depend on it: components take
        // `String` and the caller localises (`NFR-I18N-01`).
        .target(
            name: "UIStringsKit",
            dependencies: ["ContentKit"]
        ),
        .target(
            name: "DesignSystem",
            resources: [
                // Instrument Serif, SIL OFL 1.1 (licence shipped beside the faces). Registered at
                // runtime by `KultaraFonts` rather than declared in the app's Info.plist, so the
                // package carries its own typeface instead of depending on the host target
                // remembering to list it.
                .copy("Resources/Fonts"),
                // Chrome the theme draws with, never content. The distinction matters: content
                // assets live in `ContentKit` and are replaced wholesale by an update, while these
                // are part of the design and travel with it. See `PortraitFrame.swift` for the
                // provenance of the one image in here.
                .copy("Resources/Images"),
            ]
        ),
        // The two Edge Services phase-0 clients (`c1`). Both are Foundation only and depend on
        // nothing in this package: they sit at the platform layer, they are optional at runtime,
        // and if either fails entirely the app behaves exactly as it does today.
        //
        // `GovernanceKit` fetches the kill-switch document (`AD-5`); `TelemetryKit` queues and
        // posts anonymous events (design §10). Neither contains a reachability check and neither
        // may acquire one — `AD-3`, held by `PermissionCallBoundaryTests`. Neither imports
        // CoreLocation, which is what makes "no coordinate leaves the device" (`c1` D5) structural
        // rather than a habit; `ImportBoundaryTests` scans both.
        .target(name: "GovernanceKit"),
        .target(name: "TelemetryKit"),
        .executableTarget(
            name: "ContentValidatorCLI",
            dependencies: ["ContentKit"]
        ),
        .testTarget(
            name: "ContentKitTests",
            dependencies: ["ContentKit"]
        ),
        .testTarget(
            name: "RunEngineTests",
            dependencies: ["RunEngine", "ContentKit"]
        ),
        .testTarget(
            name: "UIStringsKitTests",
            dependencies: ["UIStringsKit", "ContentKit"]
        ),
        .testTarget(
            name: "DesignSystemTests",
            dependencies: ["DesignSystem"]
        ),
        .testTarget(
            name: "GovernanceKitTests",
            dependencies: ["GovernanceKit"]
        ),
        // `RunEngine` for `UUID.v7` alone (`c1` D7). The dependency is on the TEST target, not on
        // `TelemetryKit`: the service takes ids from its caller, and a telemetry kit that reached
        // into the Run engine would be the wrong direction of dependency for a platform edge.
        .testTarget(
            name: "TelemetryKitTests",
            dependencies: ["TelemetryKit", "RunEngine"]
        ),
    ]
)
