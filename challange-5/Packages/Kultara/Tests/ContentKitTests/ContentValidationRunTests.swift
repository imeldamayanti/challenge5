import Foundation
import Testing
@testable import ContentKit

/// `NFR-MAINT-02` — content is validated at build time and the build fails on missing consent
/// references, missing sources, missing accuracy labels, or language gaps. This is the part the
/// CLI wraps: directory in, findings and an exit code out. `main.swift` adds only argument
/// handling, so the behaviour that matters is tested here rather than through a subprocess.
struct ContentValidationRunTests {

    /// The authored tree, consent directory included — not the shipped resource bundle.
    static var authoredContentRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ContentKitTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // package root
            .appendingPathComponent("Sources/ContentKit/Content")
    }

    // MARK: - The fixture is valid, consent included

    @Test func theAuthoredFixturePassesEveryRule() throws {
        let report = ContentValidationRun.run(contentRoot: Self.authoredContentRoot)
        #expect(report.findings.isEmpty, "Authored fixture is invalid:\n\(report.text)")
        #expect(report.exitCode == 0)
    }

    @Test func theAuthoredFixtureCarriesConsentForEveryPlace() throws {
        // V4/V5 can only be judged where consent is present, so prove it is present here — the
        // one place it should be.
        let repository = try BundledContentRepository(contentRoot: Self.authoredContentRoot)
        let bundle = try repository.bundle()
        #expect(bundle.consentRecords.count == bundle.places.count)
        #expect(bundle.consentRecords.allSatisfy { $0.status == .granted })
    }

    // MARK: - Corruption is caught, by rule, with a non-zero exit

    @Test func aTranslationGapFailsTheRunAsV1() throws {
        let root = try corruptedCopy { directory in
            let quest = directory.appendingPathComponent("quests/contoh-jejak-kota-lama.json")
            var json = try String(contentsOf: quest, encoding: .utf8)
            json = json.replacingOccurrences(
                of: #""en": "Example Old-Town Trail""#, with: #""en": """#)
            try json.write(to: quest, atomically: true, encoding: .utf8)
        }
        let report = ContentValidationRun.run(contentRoot: root)
        #expect(report.exitCode == 1)
        #expect(report.findings.contains { $0.rule == .v1 }, "\(report.text)")
    }

    @Test func aWithdrawnConsentRecordFailsTheRunAsV4() throws {
        let root = try corruptedCopy { directory in
            let consent = directory.appendingPathComponent("consent/contoh-pura-tirta-sari.json")
            var json = try String(contentsOf: consent, encoding: .utf8)
            json = json.replacingOccurrences(of: #""status": "granted""#, with: #""status": "withdrawn""#)
            try json.write(to: consent, atomically: true, encoding: .utf8)
        }
        let report = ContentValidationRun.run(contentRoot: root)
        #expect(report.exitCode == 1)
        #expect(report.findings.contains { $0.rule == .v4 }, "\(report.text)")
    }

    @Test func aMissingConsentFileFailsTheRunAsV4() throws {
        let root = try corruptedCopy { directory in
            try FileManager.default.removeItem(
                at: directory.appendingPathComponent("consent/contoh-pasar-pagi-timur.json"))
        }
        let report = ContentValidationRun.run(contentRoot: root)
        #expect(report.exitCode == 1)
        #expect(report.findings.contains { $0.rule == .v4 }, "\(report.text)")
    }

    @Test func aTaskThatGatesProgressionFailsTheRunAsV8() throws {
        let root = try corruptedCopy { directory in
            let quest = directory.appendingPathComponent("quests/contoh-jejak-kota-lama.json")
            var json = try String(contentsOf: quest, encoding: .utf8)
            json = json.replacingOccurrences(
                of: #""blocksProgression": false"#, with: #""blocksProgression": true"#)
            try json.write(to: quest, atomically: true, encoding: .utf8)
        }
        let report = ContentValidationRun.run(contentRoot: root)
        #expect(report.exitCode == 1)
        #expect(report.findings.contains { $0.rule == .v8 }, "\(report.text)")
    }

    @Test func aPuzzleMechanicAtASacredPlaceFailsTheRunAsV7() throws {
        let root = try corruptedCopy { directory in
            let quest = directory.appendingPathComponent("quests/contoh-jejak-kota-lama.json")
            var json = try String(contentsOf: quest, encoding: .utf8)
            // The first checkpoint sits at a sacred Place and carries a reflection task.
            json = json.replacingOccurrences(
                of: #""type": "reflection""#, with: #""type": "puzzle""#, options: [], range: nil)
            try json.write(to: quest, atomically: true, encoding: .utf8)
        }
        let report = ContentValidationRun.run(contentRoot: root)
        #expect(report.exitCode == 1)
        #expect(report.findings.contains { $0.rule == .v7 }, "\(report.text)")
    }

    @Test func aMissingRoutePreviewAssetFailsTheRunAsV14() throws {
        let root = try corruptedCopy { directory in
            try FileManager.default.removeItem(at: directory.appendingPathComponent(
                "assets/quests/contoh-jejak-kota-lama/route-preview.png"))
        }
        let report = ContentValidationRun.run(contentRoot: root)
        #expect(report.exitCode == 1)
        #expect(report.findings.contains { $0.rule == .v14 }, "\(report.text)")
    }

    @Test func aHaversineDistanceFailsTheRunAsV11() throws {
        let root = try corruptedCopy { directory in
            let quest = directory.appendingPathComponent("quests/contoh-jejak-kota-lama.json")
            var json = try String(contentsOf: quest, encoding: .utf8)
            json = json.replacingOccurrences(
                of: #""distanceSource": "walking-directions""#, with: #""distanceSource": "haversine""#)
            try json.write(to: quest, atomically: true, encoding: .utf8)
        }
        let report = ContentValidationRun.run(contentRoot: root)
        #expect(report.exitCode == 1)
        #expect(report.findings.contains { $0.rule == .v11 }, "\(report.text)")
    }

    // MARK: - Failure modes that are not rule violations

    @Test func anUnreadableDirectoryFailsTheRunWithoutCrashing() {
        let report = ContentValidationRun.run(
            contentRoot: URL(fileURLWithPath: "/tmp/kultara-does-not-exist-\(UUID().uuidString)"))
        #expect(report.exitCode == 1)
        #expect(!report.text.isEmpty)
    }

    @Test func syntacticallyBrokenJSONFailsTheRunAndSaysWhere() throws {
        let root = try corruptedCopy { directory in
            try "{ not json".write(
                to: directory.appendingPathComponent("quests/contoh-jejak-kota-lama.json"),
                atomically: true, encoding: .utf8)
        }
        let report = ContentValidationRun.run(contentRoot: root)
        #expect(report.exitCode == 1)
        #expect(report.text.contains("contoh-jejak-kota-lama"), "\(report.text)")
    }

    @Test func theReportNamesTheRequirementBehindEachFinding() throws {
        let root = try corruptedCopy { directory in
            let quest = directory.appendingPathComponent("quests/contoh-jejak-kota-lama.json")
            var json = try String(contentsOf: quest, encoding: .utf8)
            json = json.replacingOccurrences(
                of: #""distanceSource": "walking-directions""#, with: #""distanceSource": "haversine""#)
            try json.write(to: quest, atomically: true, encoding: .utf8)
        }
        let report = ContentValidationRun.run(contentRoot: root)
        // A build that fails should say which requirement it is protecting.
        #expect(report.text.contains("NFR-CONT-05"), "\(report.text)")
    }

    // MARK: - Helper

    /// A throwaway copy of the authored tree with one thing broken in it.
    private func corruptedCopy(_ break_: (URL) throws -> Void) throws -> URL {
        let destination = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kultara-content-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: Self.authoredContentRoot, to: destination)
        try break_(destination)
        return destination
    }
}
