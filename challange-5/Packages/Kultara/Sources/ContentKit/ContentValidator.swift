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
    case v17 = "V17", v18 = "V18"
    // Sidequests and letter collections (PRD §5.15, `schema.md` §A.10–A.11).
    case v19 = "V19", v20 = "V20", v21 = "V21", v22 = "V22"
    case v23 = "V23", v24 = "V24", v25 = "V25", v26 = "V26"
    case v27 = "V27", v28 = "V28"

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
        case .v17: "Every Place a quest visits has a map pin inside the region map"
        case .v18: "Every route geometry parses as a LineString of at least two points"
        case .v19: "Every sidequest's placeId resolves and that Place is listed in the manifest"
        case .v20: "triggerRadiusM is 30–250 m, and noticeRadiusM exceeds it"
        case .v21: "Every sidequest lore block has an accuracy label and resolvable source refs"
        case .v22: "A quiz has 2–4 distinct options and a correctIndex inside that range"
        case .v23: "No photo challenge at a Place where photography is prohibited"
        case .v24: "Every sidequest fills exactly one slot, in exactly one collection"
        case .v25: "slots.count equals the phrase's letters, and each slot's letter matches its position"
        case .v26: "Slot indices are contiguous from 0 and each sideQuestId resolves and appears once"
        case .v27: "A collection has at most 20 sidequests"
        case .v28: "Every sidequest asset path exists"
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
        case .v17: "FR-DISC-02, FR-DISC-03"
        case .v18: "FR-MAP-02"
        case .v19: "FR-SIDE-02, NFR-GOV-01"
        case .v20: "FR-ARR-07, FR-PROX-11"
        case .v21: "NFR-CONT-01, FR-SIDE-04"
        case .v22: "FR-SIDE-06"
        case .v23: "FR-TASK-06, FR-SIDE-13"
        case .v24: "FR-SIDE-05"
        case .v25: "FR-SIDE-08"
        case .v26: "FR-SIDE-08"
        case .v27: "FR-PROX-14, FR-SIDE-16"
        case .v28: "—"
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

    /// iOS monitors at most 20 regions per app, and quest start regions share the same budget with
    /// sidequest notice regions. V27 is therefore a backstop rather than a guarantee: the real
    /// ceiling is lower than 20, and the runtime half of the problem is nearest-N selection
    /// (`FR-SIDE-16`, superseding `FR-PROX-14`'s v3 timing). What this catches at build time is the
    /// authoring mistake whose field symptom — some places simply never notify — is
    /// indistinguishable from a GPS problem.
    public static let monitoredRegionBudget = 20

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

        // V19–V23, V28
        for sideQuest in bundle.sideQuests {
            findings.append(contentsOf: sideQuestFindings(sideQuest, bundle: bundle, assets: assets))
        }

        // V24–V27
        findings.append(contentsOf: collectionFindings(bundle: bundle))

        // V17 — every Place a quest visits must be findable on the map, or the map screen
        // silently drops a stop the list shows.
        if let regionMap = bundle.manifest.regionMap {
            if !assets.exists(regionMap.asset) {
                findings.append(ValidationFinding(
                    rule: .v14, path: "manifest.json",
                    message: "Region map asset \"\(regionMap.asset)\" does not exist."))
            }
            let visited = Set(bundle.quests.flatMap { $0.checkpoints.map(\.placeId) })
            for placeID in visited.sorted() {
                guard let place = bundle.place(id: placeID) else { continue }
                let path = "places/\(place.id).json"
                guard let point = place.mapPoint else {
                    findings.append(ValidationFinding(
                        rule: .v17, path: path,
                        message: "Content ships a region map but \(place.id) has no mapPoint, so the map cannot show it."))
                    continue
                }
                if !point.isInsideImage {
                    findings.append(ValidationFinding(
                        rule: .v17, path: path,
                        message: "mapPoint (\(point.x), \(point.y)) is outside the image; both values must be within 0…1."))
                }
            }
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
        for asset in [quest.route.geometryAsset, quest.route.previewImageAsset, quest.heroImageAsset].compactMap({ $0 }) {
            if !assets.exists(asset) {
                findings.append(ValidationFinding(
                    rule: .v14, path: path, message: "Referenced asset \"\(asset)\" does not exist."))
            }
        }

        // V18 — FR-MAP-02. V14 proves the geometry file is there; it does not prove it is a route.
        // The run map draws from this file, and a geometry that does not parse degrades to a blank
        // canvas at the one moment the walker is standing in a street looking for a gate.
        if assets.exists(quest.route.geometryAsset), let bytes = assets.data(quest.route.geometryAsset) {
            do {
                _ = try RouteGeometryDecoder.decode(bytes)
            } catch let error as RouteGeometryError {
                findings.append(ValidationFinding(
                    rule: .v18, path: quest.route.geometryAsset, message: error.description))
            } catch {
                findings.append(ValidationFinding(
                    rule: .v18, path: quest.route.geometryAsset,
                    message: String(describing: error)))
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

    // MARK: - Sidequest rules: V19–V28

    private static func sideQuestFindings(
        _ sideQuest: SideQuest,
        bundle: ContentBundle,
        assets: any AssetInventory
    ) -> [ValidationFinding] {
        var findings: [ValidationFinding] = []
        let path = "sidequests/\(sideQuest.id).json"

        // V20 — FR-ARR-07 for the trigger, the FR-PROX-11 argument for the notice. The alert warns
        // on approach; it does not confirm arrival at the gate.
        if !(30...250).contains(sideQuest.triggerRadiusM) {
            findings.append(ValidationFinding(
                rule: .v20, path: path,
                message: "triggerRadiusM is \(sideQuest.triggerRadiusM) m; must be within 30–250 m."))
        }
        if sideQuest.noticeRadiusM <= sideQuest.triggerRadiusM {
            findings.append(ValidationFinding(
                rule: .v20, path: path,
                message: "noticeRadiusM \(sideQuest.noticeRadiusM) m must exceed triggerRadiusM \(sideQuest.triggerRadiusM) m."))
        }

        // V28 — a hero the notice card is built around, missing, is a card that silently falls back
        // to type on paper.
        if let asset = sideQuest.heroImageAsset, !assets.exists(asset) {
            findings.append(ValidationFinding(
                rule: .v28, path: path, message: "Referenced asset \"\(asset)\" does not exist."))
        }

        // V19 — FR-SIDE-02, NFR-GOV-01. A sidequest whose Place is not in the manifest resolves to
        // nothing: no coordinate to gate arrival on, and no consent record for V4 to judge.
        guard let place = bundle.place(id: sideQuest.placeId) else {
            findings.append(ValidationFinding(
                rule: .v19, path: path,
                message: "placeId \"\(sideQuest.placeId)\" resolves to no Place."))
            return findings
        }
        if !bundle.manifest.places.contains(place.id) {
            findings.append(ValidationFinding(
                rule: .v19, path: path,
                message: "Place \(place.id) is not listed in manifest.places, so it does not ship."))
        }

        // V21 — NFR-CONT-01, FR-SIDE-04. The accuracy label is structural; the citations are not.
        findings.append(contentsOf: loreFindings(
            sideQuest.lore, sourceCount: place.sources.count, path: path, label: "lore", rule: .v21))

        switch sideQuest.challenge {
        case .quiz(let quiz):
            // V22 — FR-SIDE-06. Read one-handed, in daylight, standing in a street.
            if !(2...4).contains(quiz.options.count) {
                findings.append(ValidationFinding(
                    rule: .v22, path: path,
                    message: "Quiz has \(quiz.options.count) option(s); must have 2–4."))
            }
            if Set(quiz.options).count != quiz.options.count {
                findings.append(ValidationFinding(
                    rule: .v22, path: path,
                    message: "Quiz options are not distinct; two identical options make one of them unmarkable."))
            }
            if !quiz.options.indices.contains(quiz.correctIndex) {
                findings.append(ValidationFinding(
                    rule: .v22, path: path,
                    message: "correctIndex \(quiz.correctIndex) is outside the \(quiz.options.count) authored option(s)."))
            }
        case .photo:
            // V23 — FR-TASK-06 applied to the sidequest surface. Enforced again at runtime, but a
            // build failure is the version that cannot be shipped by accident.
            if place.photoPolicy.level == .prohibited {
                findings.append(ValidationFinding(
                    rule: .v23, path: path,
                    message: "Photo challenge is offered at \(place.id), where photography is prohibited."))
            }
        }

        return findings
    }

    private static func collectionFindings(bundle: ContentBundle) -> [ValidationFinding] {
        var findings: [ValidationFinding] = []

        // V24 — FR-SIDE-05, and it is bidirectional on purpose. A sidequest with no slot is a place
        // the walker can complete for no letter; a slot with no sidequest is a letter nobody can
        // earn. Both are silent in the app and loud here.
        for sideQuest in bundle.sideQuests {
            let filled = bundle.collections.reduce(0) { total, collection in
                total + collection.slots.filter { $0.sideQuestId == sideQuest.id }.count
            }
            if filled != 1 {
                findings.append(ValidationFinding(
                    rule: .v24, path: "sidequests/\(sideQuest.id).json",
                    message: filled == 0
                        ? "Sidequest fills no collection slot, so completing it awards no letter."
                        : "Sidequest fills \(filled) collection slots; it must fill exactly one."))
            }
        }

        for collection in bundle.collections {
            let path = "collections/\(collection.id).json"
            let ordered = collection.orderedSlots
            let letters = collection.phraseLetters

            // V27 — the iOS 20-region cap, as an authoring rule.
            if ordered.count > monitoredRegionBudget {
                findings.append(ValidationFinding(
                    rule: .v27, path: path,
                    message: "Collection has \(ordered.count) sidequests; iOS monitors at most \(monitoredRegionBudget) regions per app, shared with quest start regions."))
            }

            // V26 — FR-SIDE-08. Indices are what the collection screen lays out in; a gap draws a
            // blank slot no place can ever fill.
            let indices = ordered.map(\.index)
            if indices != Array(0..<ordered.count) {
                findings.append(ValidationFinding(
                    rule: .v26, path: path,
                    message: "Slot indices are \(indices); must be contiguous from 0."))
            }
            var seen: Set<String> = []
            for slot in ordered {
                if bundle.sideQuest(id: slot.sideQuestId) == nil {
                    findings.append(ValidationFinding(
                        rule: .v26, path: path,
                        message: "Slot \(slot.index) names sideQuestId \"\(slot.sideQuestId)\", which does not exist."))
                }
                if !seen.insert(slot.sideQuestId).inserted {
                    findings.append(ValidationFinding(
                        rule: .v26, path: path,
                        message: "sideQuestId \"\(slot.sideQuestId)\" fills more than one slot in this collection."))
                }
            }

            // V25 — FR-SIDE-08. The phrase *is* the place count: spaces are display only and get no
            // slot, so `BALI THE EXPLORER` is 15 letters and therefore 15 places.
            if ordered.count != letters.count {
                findings.append(ValidationFinding(
                    rule: .v25, path: path,
                    message: "Collection has \(ordered.count) slot(s) for a phrase of \(letters.count) letter(s) (\"\(collection.phrase)\", spaces excluded)."))
                continue
            }
            for (position, slot) in ordered.enumerated() where slot.letter != letters[position] {
                findings.append(ValidationFinding(
                    rule: .v25, path: path,
                    message: "Slot \(slot.index) carries letter \"\(slot.letter)\"; the phrase has \"\(letters[position])\" at that position."))
            }
        }

        return findings
    }

    private static func loreFindings(
        _ blocks: [LoreBlock],
        sourceCount: Int,
        path: String,
        label: String,
        rule: ValidationRule = .v3
    ) -> [ValidationFinding] {
        var findings: [ValidationFinding] = []
        for (index, block) in blocks.enumerated() {
            if block.sourceRefs.isEmpty {
                findings.append(ValidationFinding(
                    rule: rule, path: path,
                    message: "\(label)[\(index)] cites no source."))
            }
            for ref in block.sourceRefs where ref < 0 || ref >= sourceCount {
                findings.append(ValidationFinding(
                    rule: rule, path: path,
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
