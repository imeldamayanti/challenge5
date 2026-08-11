import Foundation

/// One validation pass over an authored content directory: the whole rule set, in one place, so
/// the CLI and any future CI step cannot drift apart (`NFR-MAINT-02`).
public struct ValidationReport: Sendable {
    public let findings: [ValidationFinding]
    /// Problems that are not rule violations — an unreadable directory, JSON that does not parse.
    /// Kept separate because they mean *no rule could be checked*, which is worse news than a
    /// rule failing.
    public let blockers: [String]
    public let placeCount: Int
    public let questCount: Int
    public let payloadBytes: Int

    public var exitCode: Int32 {
        (findings.isEmpty && blockers.isEmpty) ? 0 : 1
    }

    public var text: String {
        var lines: [String] = []
        for blocker in blockers {
            lines.append("BLOCKED  \(blocker)")
        }
        for finding in findings.sorted(by: { ($0.rule.rawValue, $0.path) < ($1.rule.rawValue, $1.path) }) {
            lines.append(finding.description)
        }
        if lines.isEmpty {
            lines.append("OK  \(questCount) quest(s), \(placeCount) place(s), \(payloadBytes) bytes — all \(ValidationRule.allCases.count) rules pass.")
        } else {
            lines.append("")
            lines.append("\(findings.count) finding(s), \(blockers.count) blocker(s).")
        }
        return lines.joined(separator: "\n")
    }
}

public enum ContentValidationRun {

    /// Validates the authored tree at `contentRoot` — the directory holding `manifest.json`,
    /// `places/`, `quests/`, `assets/` and, at build time only, `consent/`.
    public static func run(contentRoot: URL, today: CalendarDay = CalendarDay.today()) -> ValidationReport {
        var blockers: [String] = []
        var findings: [ValidationFinding] = []

        // V1 and V7 run over raw JSON, so they still work when something else fails to decode —
        // which is the common case, since a translation gap is what prevents decoding.
        let rawDocuments = readAllJSON(under: contentRoot)
        if rawDocuments.isEmpty {
            blockers.append("No JSON documents found under \(contentRoot.path).")
        }

        let repository = try? BundledContentRepository(contentRoot: contentRoot)
        let bundle = try? repository?.bundle()

        // Sacred Place ids come from decoded Places when available. When they are not, V7 is
        // checked against every Place id present as a raw document, which over-applies the rule
        // rather than skipping it — a false positive is reviewable, a missed one is not.
        let sacredPlaceIds: Set<String>
        if let bundle {
            sacredPlaceIds = Set(bundle.places.filter(\.isSacred).map(\.id))
        } else {
            sacredPlaceIds = Set(rawDocuments.keys
                .filter { $0.hasPrefix("places/") }
                .map { $0.replacingOccurrences(of: "places/", with: "")
                         .replacingOccurrences(of: ".json", with: "") })
        }

        for (path, data) in rawDocuments.sorted(by: { $0.key < $1.key }) {
            findings.append(contentsOf: ContentValidator.validateRawDocument(
                path: path, json: data, sacredPlaceIds: sacredPlaceIds))
        }

        guard let repository, let bundle else {
            blockers.append(loadFailureDescription(contentRoot: contentRoot))
            return ValidationReport(
                findings: findings, blockers: blockers,
                placeCount: 0, questCount: 0, payloadBytes: 0)
        }

        let assets = (try? repository.assetInventory()) ?? DirectoryAssetInventory(root: contentRoot)
        findings.append(contentsOf: ContentValidator.validate(bundle, assets: assets, today: today))

        if bundle.consentRecords.isEmpty {
            blockers.append("No consent records found under \(contentRoot.path)/consent — V4 and V5 cannot be judged, and NFR-GOV-01 is exactly the rule that must not be skipped.")
        }

        return ValidationReport(
            findings: findings,
            blockers: blockers,
            placeCount: bundle.places.count,
            questCount: bundle.quests.count,
            payloadBytes: assets.totalPayloadBytes())
    }

    /// Re-attempts the load purely to render a useful message; the fast path never calls this.
    private static func loadFailureDescription(contentRoot: URL) -> String {
        do {
            _ = try BundledContentRepository(contentRoot: contentRoot)
            return "Content at \(contentRoot.path) could not be loaded."
        } catch let error as ContentRepositoryError {
            return error.description
        } catch {
            return String(describing: error)
        }
    }

    private static func readAllJSON(under root: URL) -> [String: Data] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var documents: [String: Data] = [:]
        let prefix = root.standardizedFileURL.path + "/"
        for case let url as URL in walker where url.pathExtension == "json" {
            guard let data = FileManager.default.contents(atPath: url.path) else { continue }
            let relative = url.standardizedFileURL.path.replacingOccurrences(of: prefix, with: "")
            documents[relative] = data
        }
        return documents
    }
}
