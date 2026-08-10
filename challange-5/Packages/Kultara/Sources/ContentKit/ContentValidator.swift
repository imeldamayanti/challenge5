import Foundation

/// The build-time validation rules from `schema.md` §A.9.
///
/// This is the mechanism that turns cultural governance from a promise into a build failure.
/// `NFR-GOV-01` is not enforceable by review discipline at scale; it is enforceable by a script
/// that refuses to produce an `.ipa` (`system-design.md` §5).
public enum ValidationRule: String, Codable, Sendable, CaseIterable {
    case v1 = "V1", v2 = "V2", v3 = "V3", v4 = "V4"
    case v5 = "V5", v6 = "V6", v7 = "V7", v8 = "V8"
    case v9 = "V9", v10 = "V10", v11 = "V11", v12 = "V12"
    case v13 = "V13", v14 = "V14", v15 = "V15", v16 = "V16"

    public var title: String {
        switch self {
        case .v1: "Every LocalizedText has non-empty id and en"
        case .v2: "Every Place cites at least one source"
        case .v3: "Every LoreBlock has an accuracy label and resolvable source refs"
        case .v4: "Every Place consent record resolves, is granted, and is unexpired"
        case .v5: "Every consent record names a grantor, their role, and a region owner"
        case .v6: "No photo task at a Place where photography is prohibited"
        case .v7: "No mechanic outside photo/reflection/question at a sacred Place"
        case .v8: "No task blocks progression"
        case .v9: "Checkpoint order is contiguous from 0 with one start, one finish, resolvable Places"
        case .v10: "clueToNext is present on every checkpoint but the last, and absent on the last"
        case .v11: "Route distance comes from walking directions"
        case .v12: "proximityRadiusM exceeds the start checkpoint's arrivalRadiusM"
        case .v13: "arrivalRadiusM is within 30–250 m"
        case .v14: "Every referenced asset path exists"
        case .v15: "Total content payload is at most 200 MB"
        case .v16: "hardLatestStart matches recomputation from visiting hours"
        }
    }

    /// The requirement the rule exists to enforce. Present so a failing build can say *why*
    /// rather than only *what*.
    public var requirement: String {
        switch self {
        case .v1: "NFR-I18N-02"
        case .v2: "NFR-CONT-02"
        case .v3: "NFR-CONT-01"
        case .v4: "NFR-GOV-01, NFR-GOV-03"
        case .v5: "NFR-GOV-02, NFR-GOV-07"
        case .v6: "FR-TASK-06"
        case .v7: "FR-TASK-05"
        case .v8: "AD-2"
        case .v9: "FR-CP-01"
        case .v10: "FR-CP-02"
        case .v11: "NFR-CONT-05"
        case .v12: "FR-PROX-11"
        case .v13: "FR-ARR-07"
        case .v14: "—"
        case .v15: "NFR-PERF-07"
        case .v16: "FR-DISC-06"
        }
    }
}

public struct ValidationFinding: Sendable, Equatable, CustomStringConvertible {
    public let rule: ValidationRule
    /// Where the violation is, precise enough to open the file and fix it.
    public let path: String
    public let message: String

    public init(rule: ValidationRule, path: String, message: String) {
        self.rule = rule
        self.path = path
        self.message = message
    }

    public var description: String {
        "\(rule.rawValue) [\(rule.requirement)] \(path): \(message)"
    }
}

public enum ContentValidator {

    /// Maximum total content payload, leaving headroom under the 250 MB app budget
    /// (`NFR-PERF-07`).
    public static let payloadBudgetBytes = 200 * 1024 * 1024

    public static let permittedTaskTypesAtSacredPlaces: Set<String> = ["photo", "reflection", "question"]

    // MARK: - Raw-document rules: V1 and V7

    /// Two rules cannot be checked against decoded content, because the type system already
    /// makes their violations unrepresentable: `LocalizedText` refuses to decode with a gap
    /// (V1), and `TaskType` has only the three permitted cases (V7). Both violations are
    /// nevertheless perfectly *authorable*, and both must be reported by rule name — otherwise
    /// a translation gap surfaces as an opaque `keyNotFound` that names no requirement, and a
    /// puzzle task at a temple surfaces as an unreadable enum error.
    ///
    /// So these two run over the raw JSON, before and independently of decoding.
    public static func validateRawDocument(
        path: String,
        json: Data,
        sacredPlaceIds: Set<String> = []
    ) -> [ValidationFinding] {
        guard let root = try? JSONSerialization.jsonObject(with: json) else {
            return [ValidationFinding(
                rule: .v1, path: path,
                message: "Not valid JSON, so no rule can be checked against it.")]
        }
        var findings: [ValidationFinding] = []
        walk(root, keyPath: "", path: path, sacredPlaceIds: sacredPlaceIds, findings: &findings)
        return findings
    }

    private static func walk(
        _ node: Any,
        keyPath: String,
        path: String,
        sacredPlaceIds: Set<String>,
        findings: inout [ValidationFinding]
    ) {
        switch node {
        case let dictionary as [String: Any]:
            checkLocalizedTextShape(dictionary, keyPath: keyPath, path: path, findings: &findings)
            checkSacredMechanics(dictionary, keyPath: keyPath, path: path,
                                 sacredPlaceIds: sacredPlaceIds, findings: &findings)
            for (key, value) in dictionary {
                walk(value, keyPath: keyPath.isEmpty ? key : "\(keyPath).\(key)",
                     path: path, sacredPlaceIds: sacredPlaceIds, findings: &findings)
            }
        case let array as [Any]:
            for (index, value) in array.enumerated() {
                walk(value, keyPath: "\(keyPath)[\(index)]",
                     path: path, sacredPlaceIds: sacredPlaceIds, findings: &findings)
            }
        default:
            break
        }
    }

    /// A `LocalizedText` in JSON is an object whose keys are drawn only from `id` and `en` and
    /// whose values are strings. Nothing else in the schema has that shape, so the test
    /// identifies the type without needing to know which field it sits in — which is the point,
    /// since a gap can appear anywhere a writer types.
    private static func checkLocalizedTextShape(
        _ dictionary: [String: Any],
        keyPath: String,
        path: String,
        findings: inout [ValidationFinding]
    ) {
        let keys = Set(dictionary.keys)
        guard !keys.isEmpty, keys.isSubset(of: ["id", "en"]) else { return }
        guard dictionary.values.allSatisfy({ $0 is String }) else {
            // A localized field whose translation is null or a number.
            if keys.contains("id") || keys.contains("en") {
                findings.append(ValidationFinding(
                    rule: .v1, path: path,
                    message: "\(keyPathLabel(keyPath)) has a non-string translation."))
            }
            return
        }

        for language in ContentLanguage.allCases {
            let value = dictionary[language.rawValue] as? String
            guard let value else {
                findings.append(ValidationFinding(
                    rule: .v1, path: path,
                    message: "\(keyPathLabel(keyPath)) is missing the \(language.rawValue) translation."))
                continue
            }
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(ValidationFinding(
                    rule: .v1, path: path,
                    message: "\(keyPathLabel(keyPath)) has an empty \(language.rawValue) translation."))
            }
        }
    }

    private static func checkSacredMechanics(
        _ dictionary: [String: Any],
        keyPath: String,
        path: String,
        sacredPlaceIds: Set<String>,
        findings: inout [ValidationFinding]
    ) {
        guard let placeId = dictionary["placeId"] as? String, sacredPlaceIds.contains(placeId),
              let tasks = dictionary["tasks"] as? [Any]
        else { return }

        for task in tasks {
            guard let task = task as? [String: Any], let type = task["type"] as? String else { continue }
            guard !permittedTaskTypesAtSacredPlaces.contains(type) else { continue }
            let taskId = task["id"] as? String ?? "?"
            findings.append(ValidationFinding(
                rule: .v7, path: path,
                message: "Task \(taskId) at sacred Place \(placeId) uses mechanic \"\(type)\"; permitted mechanics are \(permittedTaskTypesAtSacredPlaces.sorted().joined(separator: ", "))."))
        }
    }

    private static func keyPathLabel(_ keyPath: String) -> String {
        keyPath.isEmpty ? "the root object" : keyPath
    }

    // MARK: - Decoded-bundle rules: V2–V6, V8–V16

    public static func validate(
        _ bundle: ContentBundle,
        assets: any AssetInventory,
        today: CalendarDay
    ) -> [ValidationFinding] {
        var findings: [ValidationFinding] = []

        for place in bundle.places {
            let path = "places/\(place.id).json"

            // V2 — NFR-CONT-02
            if place.sources.isEmpty {
                findings.append(ValidationFinding(
                    rule: .v2, path: path, message: "Place \(place.id) cites no sources."))
            }

            // V3 — NFR-CONT-01, over the Place's own standalone lore
            findings.append(contentsOf: loreFindings(
                place.loreStandalone, sourceCount: place.sources.count,
                path: path, label: "loreStandalone"))

            // V13 — FR-ARR-07
            if !(30...250).contains(place.arrivalRadiusM) {
                findings.append(ValidationFinding(
                    rule: .v13, path: path,
                    message: "arrivalRadiusM is \(place.arrivalRadiusM) m; must be within 30–250 m."))
            }

            // V4 — NFR-GOV-01/03
            guard let consent = bundle.consentRecord(id: place.consentRecordId) else {
                findings.append(ValidationFinding(
                    rule: .v4, path: path,
                    message: "consentRecordId \"\(place.consentRecordId)\" resolves to no record."))
                continue
            }
            if consent.status != .granted {
                findings.append(ValidationFinding(
                    rule: .v4, path: path,
                    message: "Consent for \(place.id) has status \(consent.status.rawValue); must be granted."))
            }
            // Strictly after today: "expires today" is not unexpired, since the build ships and
            // then runs past midnight.
            if consent.expiresAt <= today {
                findings.append(ValidationFinding(
                    rule: .v4, path: path,
                    message: "Consent for \(place.id) expires \(consent.expiresAt.text), on or before today (\(today.text))."))
            }
        }

        // V5 — NFR-GOV-02/07
        for consent in bundle.consentRecords {
            let path = "consent/\(consent.placeId).json"
            let named: [(String, String)] = [
                ("grantedByName", consent.grantedByName),
                ("grantedByRole", consent.grantedByRole),
                ("regionOwner", consent.regionOwner),
            ]
            for (field, value) in named where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                findings.append(ValidationFinding(
                    rule: .v5, path: path,
                    message: "\(field) is empty; a relationship owned by nobody in particular is owned by nobody."))
            }
        }

        for quest in bundle.quests {
            findings.append(contentsOf: questFindings(quest, bundle: bundle, assets: assets))
        }

        // V15 — NFR-PERF-07
        let bytes = assets.totalPayloadBytes()
        if bytes > payloadBudgetBytes {
            findings.append(ValidationFinding(
                rule: .v15, path: "Content/",
                message: "Payload is \(bytes) bytes; budget is \(payloadBudgetBytes) bytes (200 MB)."))
        }

        return findings
    }

    private static func questFindings(
        _ quest: Quest,
        bundle: ContentBundle,
        assets: any AssetInventory
    ) -> [ValidationFinding] {
        var findings: [ValidationFinding] = []
        let path = "quests/\(quest.id).json"
        let ordered = quest.orderedCheckpoints

        // V11 — NFR-CONT-05
        if quest.route.distanceSource != .walkingDirections {
            findings.append(ValidationFinding(
                rule: .v11, path: path,
                message: "distanceSource is \(quest.route.distanceSource.rawValue); must be walking-directions."))
        }

        // V14 — referenced assets
        for asset in [quest.route.geometryAsset, quest.route.previewImageAsset] {
            if !assets.exists(asset) {
                findings.append(ValidationFinding(
                    rule: .v14, path: path, message: "Referenced asset \"\(asset)\" does not exist."))
            }
        }

        // V3 — hook lore. Hook lore is quest-level, so its refs are resolved against the start
        // Place's sources; a hook with no Place to cite is reported rather than skipped.
        let hookSourceCount = ordered.first.flatMap { bundle.place(id: $0.placeId)?.sources.count } ?? 0
        findings.append(contentsOf: loreFindings(
            quest.hookLore, sourceCount: hookSourceCount, path: path, label: "hookLore"))

        // V9 — FR-CP-01
        if ordered.isEmpty {
            findings.append(ValidationFinding(
                rule: .v9, path: path, message: "Quest has no checkpoints."))
            return findings
        }
        let indices = ordered.map(\.orderIndex)
        if indices != Array(0..<ordered.count) {
            findings.append(ValidationFinding(
                rule: .v9, path: path,
                message: "orderIndex values are \(indices); must be contiguous from 0."))
        }
        let startCount = ordered.filter { $0.role == .start }.count
        let finishCount = ordered.filter { $0.role == .finish }.count
        if startCount != 1 {
            findings.append(ValidationFinding(
                rule: .v9, path: path, message: "Quest has \(startCount) start checkpoints; must have exactly 1."))
        }
        if finishCount != 1 {
            findings.append(ValidationFinding(
                rule: .v9, path: path, message: "Quest has \(finishCount) finish checkpoints; must have exactly 1."))
        }

        for checkpoint in ordered {
            let isFinal = checkpoint.orderIndex == ordered.count - 1

            guard let place = bundle.place(id: checkpoint.placeId) else {
                findings.append(ValidationFinding(
                    rule: .v9, path: path,
                    message: "Checkpoint \(checkpoint.id) references Place \"\(checkpoint.placeId)\", which does not exist."))
                continue
            }

            // V3 — NFR-CONT-01
            findings.append(contentsOf: loreFindings(
                checkpoint.loreSegment, sourceCount: place.sources.count,
                path: path, label: "checkpoint \(checkpoint.id) loreSegment"))

            // V10 — FR-CP-02
            if isFinal, checkpoint.clueToNext != nil {
                findings.append(ValidationFinding(
                    rule: .v10, path: path,
                    message: "Final checkpoint \(checkpoint.id) has a clueToNext; it must be null."))
            }
            if !isFinal, checkpoint.clueToNext == nil {
                findings.append(ValidationFinding(
                    rule: .v10, path: path,
                    message: "Checkpoint \(checkpoint.id) is not final and has no clueToNext."))
            }

            for task in checkpoint.tasks {
                // V8 — AD-2
                if task.blocksProgression {
                    findings.append(ValidationFinding(
                        rule: .v8, path: path,
                        message: "Task \(task.id) sets blocksProgression true; no task may gate progression."))
                }
                // V6 — FR-TASK-06
                if task.type == .photo, place.photoPolicy.level == .prohibited {
                    findings.append(ValidationFinding(
                        rule: .v6, path: path,
                        message: "Photo task \(task.id) is offered at \(place.id), where photography is prohibited."))
                }
            }
        }

        // V12 — FR-PROX-11
        if let start = quest.startCheckpoint, let startPlace = bundle.place(id: start.placeId) {
            if quest.proximityRadiusM <= startPlace.arrivalRadiusM {
                findings.append(ValidationFinding(
                    rule: .v12, path: path,
                    message: "proximityRadiusM \(quest.proximityRadiusM) m must exceed the start Place's arrivalRadiusM \(startPlace.arrivalRadiusM) m — the alert warns on approach, it does not confirm arrival at the gate."))
            }
        }

        // V16 — FR-DISC-06
        if let expected = recomputedHardLatestStart(quest, bundle: bundle), expected != quest.hardLatestStart {
            findings.append(ValidationFinding(
                rule: .v16, path: path,
                message: "hardLatestStart is \(quest.hardLatestStart.text); recomputation from visiting hours gives \(expected.text)."))
        }

        return findings
    }

    private static func loreFindings(
        _ blocks: [LoreBlock],
        sourceCount: Int,
        path: String,
        label: String
    ) -> [ValidationFinding] {
        var findings: [ValidationFinding] = []
        for (index, block) in blocks.enumerated() {
            if block.sourceRefs.isEmpty {
                findings.append(ValidationFinding(
                    rule: .v3, path: path,
                    message: "\(label)[\(index)] cites no source."))
            }
            for ref in block.sourceRefs where ref < 0 || ref >= sourceCount {
                findings.append(ValidationFinding(
                    rule: .v3, path: path,
                    message: "\(label)[\(index)] cites source index \(ref); the Place has \(sourceCount) source(s)."))
            }
        }
        return findings
    }

    /// `hardLatestStart` is derived, not authored: the earliest closing time across every Place
    /// the quest visits, minus the quest's total duration (`schema.md` §A.5). Taking the earliest
    /// close across all days and all Places is the conservative reading — a start time that
    /// works on the site's shortest day works on every other one.
    static func recomputedHardLatestStart(_ quest: Quest, bundle: ContentBundle) -> TimeOfDay? {
        let closingTimes = bundle.places(for: quest).flatMap { $0.visitingHours.weekly.map(\.close) }
        guard let earliest = closingTimes.min() else { return nil }
        return earliest.subtracting(minutes: quest.route.totalDurationMin)
    }
}
