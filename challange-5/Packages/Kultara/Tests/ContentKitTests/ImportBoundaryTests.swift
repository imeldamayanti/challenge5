import Foundation
import Testing

/// `ContentKit` must remain loadable and testable without a device, a simulator, or a UI
/// framework (`system-design.md` §3). Target linkage already keeps SwiftUI and UIKit out of
/// the app build, but on macOS every one of these modules is present in the SDK, so an
/// `import` would compile happily and the constraint would erode file by file. The scan is
/// what actually holds it.
struct ImportBoundaryTests {

    static let forbiddenModules = ["SwiftUI", "UIKit", "CoreLocation", "MapKit", "AppKit"]

    @Test func contentKitImportsNoUIOrLocationFramework() throws {
        let offenders = try Self.forbiddenImports(inTargetNamed: "ContentKit")
        #expect(offenders.isEmpty, "ContentKit must not import \(Self.forbiddenModules.joined(separator: ", ")); found: \(offenders)")
    }

    @Test func contentValidatorCLIImportsNoUIOrLocationFramework() throws {
        let offenders = try Self.forbiddenImports(inTargetNamed: "ContentValidatorCLI")
        #expect(offenders.isEmpty, "The validator CLI must stay headless; found: \(offenders)")
    }

    // MARK: - Scanning

    /// `<package root>/Sources/<target>` derived from this file's location, so the scan
    /// cannot silently pass by looking at nothing.
    static func sourcesDirectory(forTargetNamed target: String) -> URL {
        URL(fileURLWithPath: #filePath)          // …/Tests/ContentKitTests/ImportBoundaryTests.swift
            .deletingLastPathComponent()          // …/Tests/ContentKitTests
            .deletingLastPathComponent()          // …/Tests
            .deletingLastPathComponent()          // …/ (package root)
            .appendingPathComponent("Sources")
            .appendingPathComponent(target)
    }

    static func forbiddenImports(inTargetNamed target: String) throws -> [String] {
        let root = sourcesDirectory(forTargetNamed: target)
        let files = try swiftFiles(under: root)
        #expect(!files.isEmpty, "No Swift files found under \(root.path) — the scan would pass vacuously.")

        var offenders: [String] = []
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for line in source.split(separator: "\n", omittingEmptySubsequences: true) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") || trimmed.hasPrefix("@_exported import ") else { continue }
                let module = trimmed
                    .replacingOccurrences(of: "@_exported import ", with: "")
                    .replacingOccurrences(of: "import ", with: "")
                    .split(separator: ".").first.map(String.init)?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if forbiddenModules.contains(module) {
                    offenders.append("\(file.lastPathComponent): import \(module)")
                }
            }
        }
        return offenders
    }

    static func swiftFiles(under root: URL) throws -> [URL] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }
}
