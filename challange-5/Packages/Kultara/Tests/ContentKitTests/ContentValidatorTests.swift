import Foundation
import Testing
@testable import ContentKit

/// One test per rule in `schema.md` §A.9, each constructing content that **violates** the rule
/// and asserting the violation is reported. A test that only confirms valid content is accepted
/// proves nothing about a validator — an empty function passes it.
///
/// The single acceptance test below (`validContentProducesNoFindings`) exists only to prove the
/// rules are not firing on everything, which would make the rejections meaningless too.
struct ContentValidatorTests {

    // MARK: - Control

    @Test func validContentProducesNoFindings() {
        let findings = ContentValidator.validate(
            ContentFactory.bundle(), assets: ContentFactory.assets(), today: ContentFactory.today)
        #expect(findings.isEmpty, "Valid content produced findings: \(findings)")
    }

    // MARK: - V1 · LocalizedText parity (NFR-I18N-02)

    /// V1 runs over raw JSON rather than decoded content, because `LocalizedText` cannot decode
    /// with a gap at all — the gap must still be reported as V1 and not as an opaque decode
    /// failure that names no rule and no requirement.
    @Test(arguments: [
        #"{ "title": { "en": "Only English" } }"#,
        #"{ "title": { "id": "Hanya Indonesia" } }"#,
        #"{ "title": { "id": "Ada", "en": "" } }"#,
        #"{ "title": { "id": "   ", "en": "Present" } }"#,
        #"{ "nested": [ { "text": { "id": "Ada" } } ] }"#,
    ])
    func v1RejectsALocalizedTextWithATranslationGap(_ json: String) {
        let findings = ContentValidator.validateRawDocument(path: "quests/q.json", json: Data(json.utf8))
        #expect(findings.contains { $0.rule == .v1 }, "Expected V1 for \(json), got \(findings)")
    }

    @Test func v1AcceptsACompletePair() {
        let findings = ContentValidator.validateRawDocument(
            path: "quests/q.json", json: Data(#"{ "title": { "id": "Ada", "en": "Present" } }"#.utf8))
        #expect(findings.isEmpty)
    }

    // MARK: - V2 · every Place cites at least one source (NFR-CONT-02)

    @Test func v2RejectsAPlaceWithNoSources() {
        let bundle = ContentFactory.bundle(places: [
            ContentFactory.place(id: "place-a", sources: []),
            ContentFactory.place(id: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v2 })
    }

    // MARK: - V3 · every LoreBlock carries accuracy and source refs (NFR-CONT-01)

    @Test func v3RejectsALoreBlockWithNoSourceRefs() {
        let cp = Checkpoint(
            id: "cp1", orderIndex: 0, placeId: "place-a", role: .start,
            loreSegment: [LoreBlock(text: ContentFactory.text(), accuracy: .oral, sourceRefs: [])],
            clueToNext: ContentFactory.text(), tasks: [], bonusPrompts: [], stampId: "s1")
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            cp, ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v3 })
    }

    @Test func v3RejectsASourceRefPointingPastTheEndOfThePlacesSources() {
        // The Place has exactly one source, so index 4 cites nothing. Rendering would show a
        // claim with an empty citation — the failure FR-CP-06 is meant to prevent.
        let cp = ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start)
        let broken = Checkpoint(
            id: cp.id, orderIndex: cp.orderIndex, placeId: cp.placeId, role: cp.role,
            loreSegment: [ContentFactory.lore(sourceRefs: [4])],
            clueToNext: cp.clueToNext, tasks: cp.tasks, bonusPrompts: [], stampId: cp.stampId)
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            broken, ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v3 })
    }

    // MARK: - V4 · consent resolves, is granted, and is unexpired (NFR-GOV-01/03)

    @Test func v4RejectsAPlaceWhoseConsentRecordIsMissing() {
        let bundle = ContentFactory.bundle(consentRecords: [ContentFactory.consent(placeId: "place-b")])
        #expect(findings(bundle).contains { $0.rule == .v4 })
    }

    @Test(arguments: [ConsentStatus.withdrawn, .expired])
    func v4RejectsAPlaceWhoseConsentIsNotGranted(_ status: ConsentStatus) {
        let bundle = ContentFactory.bundle(consentRecords: [
            ContentFactory.consent(placeId: "place-a", status: status),
            ContentFactory.consent(placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v4 })
    }

    @Test func v4RejectsAPlaceWhoseConsentHasExpired() {
        let bundle = ContentFactory.bundle(consentRecords: [
            ContentFactory.consent(placeId: "place-a", expiresAt: CalendarDay(year: 2026, month: 8, day: 9)),
            ContentFactory.consent(placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v4 })
    }

    @Test func v4RejectsConsentExpiringToday() {
        // "Unexpired" cannot mean "expires at some point today" — the app ships and runs past
        // midnight. The boundary is deliberately strict.
        let bundle = ContentFactory.bundle(consentRecords: [
            ContentFactory.consent(placeId: "place-a", expiresAt: ContentFactory.today),
            ContentFactory.consent(placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v4 })
    }

    // MARK: - V5 · consent names people, not committees (NFR-GOV-02/07)

    @Test(arguments: ["grantedByName", "grantedByRole", "regionOwner"])
    func v5RejectsAConsentRecordMissingANamedIndividual(_ blankField: String) {
        let record = ContentFactory.consent(
            placeId: "place-a",
            grantedByName: blankField == "grantedByName" ? "  " : "I Gusti Ngurah Contoh",
            grantedByRole: blankField == "grantedByRole" ? "" : "Penglingsir",
            regionOwner: blankField == "regionOwner" ? "" : "Alief Fauzan")
        let bundle = ContentFactory.bundle(consentRecords: [record, ContentFactory.consent(placeId: "place-b")])
        #expect(findings(bundle).contains { $0.rule == .v5 })
    }

    // MARK: - V6 · no photo task where photography is prohibited (FR-TASK-06)

    @Test func v6RejectsAPhotoTaskAtAPlaceWherePhotographyIsProhibited() {
        let bundle = ContentFactory.bundle(
            places: [
                ContentFactory.place(id: "place-a", photoPolicy: .prohibited),
                ContentFactory.place(id: "place-b"),
            ],
            quests: [ContentFactory.quest(checkpoints: [
                ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start,
                                          tasks: [ContentFactory.task(type: .photo)]),
                ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish, clueToNext: nil),
            ])])
        #expect(findings(bundle).contains { $0.rule == .v6 })
    }

    @Test func v6AcceptsAPhotoTaskWherePhotographyIsMerelyRestricted() {
        let bundle = ContentFactory.bundle(
            places: [
                ContentFactory.place(id: "place-a", photoPolicy: .restricted),
                ContentFactory.place(id: "place-b"),
            ],
            quests: [ContentFactory.quest(checkpoints: [
                ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start,
                                          tasks: [ContentFactory.task(type: .photo)]),
                ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish, clueToNext: nil),
            ])])
        #expect(!findings(bundle).contains { $0.rule == .v6 })
    }

    // MARK: - V7 · no game mechanic at a sacred Place (FR-TASK-05)

    /// Like V1, V7 runs over raw JSON. `TaskType` has only the three permitted cases, so a
    /// puzzle task cannot exist in decoded content — but it can certainly be *authored*, and it
    /// must be rejected by name rather than as an unreadable enum error.
    @Test(arguments: ["puzzle", "scavenger", "timed", "quiz-timer"])
    func v7RejectsANonPermittedMechanicAtASacredPlace(_ mechanic: String) {
        let findings = ContentValidator.validateRawDocument(
            path: "quests/q.json",
            json: Data(#"""
            { "checkpoints": [ { "placeId": "place-sacred", "tasks": [
                { "id": "t1", "type": "\#(mechanic)",
                  "prompt": { "id": "P", "en": "P" }, "blocksProgression": false } ] } ] }
            """#.utf8),
            sacredPlaceIds: ["place-sacred"])
        #expect(findings.contains { $0.rule == .v7 }, "Expected V7 for \(mechanic), got \(findings)")
    }

    @Test func v7AcceptsAPermittedMechanicAtASacredPlace() {
        let findings = ContentValidator.validateRawDocument(
            path: "quests/q.json",
            json: Data(#"""
            { "checkpoints": [ { "placeId": "place-sacred", "tasks": [
                { "id": "t1", "type": "reflection",
                  "prompt": { "id": "P", "en": "P" }, "blocksProgression": false } ] } ] }
            """#.utf8),
            sacredPlaceIds: ["place-sacred"])
        #expect(!findings.contains { $0.rule == .v7 })
    }

    // MARK: - V8 · no task gates progression (AD-2)

    @Test func v8RejectsATaskThatBlocksProgression() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start,
                                      tasks: [ContentFactory.task(blocksProgression: true)]),
            ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v8 })
    }

    // MARK: - V9 · checkpoint ordering and roles (FR-CP-01)

    @Test func v9RejectsANonContiguousOrderIndex() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start),
            ContentFactory.checkpoint(id: "cp2", orderIndex: 2, placeId: "place-b", role: .finish, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v9 })
    }

    @Test func v9RejectsAnOrderIndexNotStartingAtZero() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            ContentFactory.checkpoint(id: "cp1", orderIndex: 1, placeId: "place-a", role: .start),
            ContentFactory.checkpoint(id: "cp2", orderIndex: 2, placeId: "place-b", role: .finish, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v9 })
    }

    @Test func v9RejectsTwoStartCheckpoints() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start),
            ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .start, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v9 })
    }

    @Test func v9RejectsNoFinishCheckpoint() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start),
            ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .middle, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v9 })
    }

    @Test func v9RejectsAQuestWithNoCheckpoints() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [])])
        #expect(findings(bundle).contains { $0.rule == .v9 })
    }

    @Test func v9RejectsACheckpointPointingAtAPlaceThatDoesNotExist() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-missing", role: .start),
            ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v9 })
    }

    // MARK: - V10 · clue presence follows position (FR-CP-02)

    @Test func v10RejectsAMissingClueOnANonFinalCheckpoint() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start, clueToNext: nil),
            ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish, clueToNext: nil),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v10 })
    }

    @Test func v10RejectsAClueOnTheFinalCheckpoint() {
        // A clue on the last checkpoint sends the user walking somewhere after the quest ends.
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(checkpoints: [
            ContentFactory.checkpoint(id: "cp1", orderIndex: 0, placeId: "place-a", role: .start),
            ContentFactory.checkpoint(id: "cp2", orderIndex: 1, placeId: "place-b", role: .finish,
                                      clueToNext: ContentFactory.text("Ke mana?")),
        ])])
        #expect(findings(bundle).contains { $0.rule == .v10 })
    }

    // MARK: - V11 · distances come from walking directions (NFR-CONT-05)

    @Test func v11RejectsAHaversineDistance() {
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(distanceSource: .haversine)])
        #expect(findings(bundle).contains { $0.rule == .v11 })
    }

    // MARK: - V12 · proximity radius exceeds arrival radius (FR-PROX-11)

    @Test(arguments: [75, 50, 0])
    func v12RejectsAProximityRadiusNotLargerThanTheStartArrivalRadius(_ proximity: Int) {
        // Start place arrival radius is 75 m, so 75 and below are all violations: the point is
        // a warning on approach, not a confirmation at the gate.
        let bundle = ContentFactory.bundle(quests: [ContentFactory.quest(proximityRadiusM: proximity)])
        #expect(findings(bundle).contains { $0.rule == .v12 })
    }

    // MARK: - V13 · arrival radius stays within tunable bounds (FR-ARR-07)

    @Test(arguments: [0, 29, 251, 1000])
    func v13RejectsAnArrivalRadiusOutsideThirtyToTwoHundredFifty(_ radius: Int) {
        let bundle = ContentFactory.bundle(places: [
            ContentFactory.place(id: "place-a", arrivalRadiusM: radius),
            ContentFactory.place(id: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v13 })
    }

    @Test(arguments: [30, 75, 250])
    func v13AcceptsAnArrivalRadiusAtOrInsideTheBounds(_ radius: Int) {
        let bundle = ContentFactory.bundle(places: [
            ContentFactory.place(id: "place-a", arrivalRadiusM: radius),
            ContentFactory.place(id: "place-b"),
        ])
        #expect(!findings(bundle).contains { $0.rule == .v13 })
    }

    // MARK: - V14 · referenced assets exist

    @Test func v14RejectsAMissingRoutePreviewImage() {
        let assets = ContentFactory.assets(present: ["quests/quest-a/route.geojson"])
        let found = ContentValidator.validate(ContentFactory.bundle(), assets: assets, today: ContentFactory.today)
        #expect(found.contains { $0.rule == .v14 })
    }

    @Test func v14RejectsAMissingRouteGeometry() {
        let assets = ContentFactory.assets(present: ["quests/quest-a/route-preview.png"])
        let found = ContentValidator.validate(ContentFactory.bundle(), assets: assets, today: ContentFactory.today)
        #expect(found.contains { $0.rule == .v14 })
    }

    // MARK: - V18 · the route geometry is a route (FR-MAP-02)

    private func assetsCarryingGeometry(_ bytes: Data) -> StubAssetInventory {
        ContentFactory.assets(contents: ["quests/quest-a/route.geojson": bytes])
    }

    @Test func v18RejectsAGeometryThatIsNotJSON() {
        let found = ContentValidator.validate(
            ContentFactory.bundle(),
            assets: assetsCarryingGeometry(Data("<svg/>".utf8)),
            today: ContentFactory.today)
        #expect(found.contains { $0.rule == .v18 })
    }

    /// The file exists, parses as JSON, and still cannot be drawn — which is exactly the gap V14
    /// leaves open.
    @Test func v18RejectsAGeometryWithNoLine() {
        let pointsOnly = Data("""
        { "type": "FeatureCollection", "features": [
          { "type": "Feature", "properties": {},
            "geometry": { "type": "Point", "coordinates": [115.2, -8.6] } } ] }
        """.utf8)
        let found = ContentValidator.validate(
            ContentFactory.bundle(),
            assets: assetsCarryingGeometry(pointsOnly),
            today: ContentFactory.today)
        #expect(found.contains { $0.rule == .v18 })
    }

    @Test func v18RejectsASinglePointRoute() {
        let found = ContentValidator.validate(
            ContentFactory.bundle(),
            assets: assetsCarryingGeometry(
                ContentFactory.routeGeometryJSON(coordinates: "[[115.2085, -8.6570]]")),
            today: ContentFactory.today)
        #expect(found.contains { $0.rule == .v18 })
    }

    @Test func v18AcceptsARealRoute() {
        let found = ContentValidator.validate(
            ContentFactory.bundle(),
            assets: assetsCarryingGeometry(ContentFactory.routeGeometryJSON()),
            today: ContentFactory.today)
        #expect(!found.contains { $0.rule == .v18 })
    }

    // MARK: - V15 · content payload budget (NFR-PERF-07)

    @Test func v15RejectsAPayloadOverTwoHundredMegabytes() {
        let assets = ContentFactory.assets(totalBytes: 201 * 1024 * 1024)
        let found = ContentValidator.validate(ContentFactory.bundle(), assets: assets, today: ContentFactory.today)
        #expect(found.contains { $0.rule == .v15 })
    }

    @Test func v15AcceptsAPayloadExactlyAtTheBudget() {
        let assets = ContentFactory.assets(totalBytes: 200 * 1024 * 1024)
        let found = ContentValidator.validate(ContentFactory.bundle(), assets: assets, today: ContentFactory.today)
        #expect(!found.contains { $0.rule == .v15 })
    }

    // MARK: - V16 · hardLatestStart is recomputed, not trusted (FR-DISC-06)

    @Test func v16RejectsAStaleHardLatestStart() {
        // Earliest closing time across the quest's places is 17:00 and the quest runs 105
        // minutes, so the only correct value is 15:15. A stale figure sends a user off on a
        // walk that cannot finish before the gate shuts.
        let bundle = ContentFactory.bundle(quests: [
            ContentFactory.quest(hardLatestStart: TimeOfDay(hour: 16, minute: 15), totalDurationMin: 105),
        ])
        #expect(findings(bundle).contains { $0.rule == .v16 })
    }

    @Test func v16UsesTheEarliestClosingTimeAcrossAllOfTheQuestsPlaces() {
        // place-b closes at 15:00, earlier than place-a's 17:00, so 15:00 − 105 min = 13:15.
        let bundle = ContentFactory.bundle(
            places: [
                ContentFactory.place(id: "place-a", close: TimeOfDay(hour: 17, minute: 0)),
                ContentFactory.place(id: "place-b", close: TimeOfDay(hour: 15, minute: 0)),
            ],
            quests: [ContentFactory.quest(hardLatestStart: TimeOfDay(hour: 13, minute: 15), totalDurationMin: 105)])
        #expect(!findings(bundle).contains { $0.rule == .v16 })

        let stale = ContentFactory.bundle(
            places: [
                ContentFactory.place(id: "place-a", close: TimeOfDay(hour: 17, minute: 0)),
                ContentFactory.place(id: "place-b", close: TimeOfDay(hour: 15, minute: 0)),
            ],
            quests: [ContentFactory.quest(hardLatestStart: TimeOfDay(hour: 15, minute: 15), totalDurationMin: 105)])
        #expect(findings(stale).contains { $0.rule == .v16 })
    }

    // MARK: - Rule coverage

    @Test func everyRuleInTheSchemaIsRepresented() {
        // If a rule is added to the enum without a test, this fails and names it.
        let tested: Set<ValidationRule> = [.v1, .v2, .v3, .v4, .v5, .v6, .v7, .v8,
                                           .v9, .v10, .v11, .v12, .v13, .v14, .v15, .v16, .v17,
                                           .v18, .v19, .v20, .v21, .v22, .v23, .v24, .v25, .v26,
                                           .v27, .v28]
        #expect(Set(ValidationRule.allCases) == tested)
        #expect(ValidationRule.allCases.count == 28)
    }

    @Test func everyRuleNamesTheRequirementItEnforces() {
        for rule in ValidationRule.allCases {
            #expect(!rule.requirement.isEmpty, "\(rule) does not name a requirement")
            #expect(!rule.title.isEmpty, "\(rule) has no title")
        }
    }

    // MARK: - Helper

    private func findings(_ bundle: ContentBundle) -> [ValidationFinding] {
        ContentValidator.validate(bundle, assets: ContentFactory.assets(), today: ContentFactory.today)
    }
}

/// V17 — when content ships a region map, every Place a quest visits must have a pin on it, inside
/// the image. A Place with no pin is a quest the map screen silently drops.
struct RegionMapValidationTests {

    private func bundle(
        regionMap: RegionMapAsset? = RegionMapAsset(asset: "maps/region.png", aspectRatio: 0.46),
        mapPoints: [String: MapPoint?] = ["place-a": MapPoint(x: 0.4, y: 0.5),
                                          "place-b": MapPoint(x: 0.6, y: 0.7)]
    ) -> ContentBundle {
        let places = ["place-a", "place-b"].map { id in
            ContentFactory.place(id: id, mapPoint: mapPoints[id] ?? nil)
        }
        let base = ContentFactory.bundle(places: places)
        return ContentBundle(
            manifest: Manifest(
                schemaVersion: 1,
                contentBundleVersion: base.manifest.contentBundleVersion,
                languages: base.manifest.languages,
                places: base.manifest.places,
                quests: base.manifest.quests,
                regionMap: regionMap),
            places: base.places,
            quests: base.quests,
            consentRecords: base.consentRecords)
    }

    private func findings(_ bundle: ContentBundle) -> [ValidationFinding] {
        ContentValidator.validate(
            bundle,
            assets: ContentFactory.assets(present: [
                "quests/quest-a/route.geojson", "quests/quest-a/route-preview.png", "maps/region.png",
            ]),
            today: ContentFactory.today)
    }

    @Test func v17AcceptsContentWhereEveryVisitedPlaceHasAPin() {
        #expect(!findings(bundle()).contains { $0.rule == .v17 })
    }

    @Test func v17RejectsAVisitedPlaceWithNoPin() {
        let broken = bundle(mapPoints: ["place-a": MapPoint(x: 0.4, y: 0.5), "place-b": nil])
        #expect(findings(broken).contains { $0.rule == .v17 })
    }

    @Test(arguments: [-0.01, 1.01, 2.0])
    func v17RejectsAPinOutsideTheImage(_ offending: Double) {
        let broken = bundle(mapPoints: [
            "place-a": MapPoint(x: offending, y: 0.5),
            "place-b": MapPoint(x: 0.6, y: 0.7),
        ])
        #expect(findings(broken).contains { $0.rule == .v17 })
    }

    @Test func v17IsSilentWhenContentShipsNoRegionMap() {
        // No map, no pins required. The map screen has nothing to draw and says so.
        let noMap = bundle(regionMap: nil, mapPoints: ["place-a": nil, "place-b": nil])
        #expect(!findings(noMap).contains { $0.rule == .v17 })
    }

    @Test func v14CoversTheRegionMapAssetItself() {
        let missing = ContentValidator.validate(
            bundle(),
            assets: ContentFactory.assets(present: [
                "quests/quest-a/route.geojson", "quests/quest-a/route-preview.png",
            ]),
            today: ContentFactory.today)
        #expect(missing.contains { $0.rule == .v14 })
    }

    @Test func v14CoversAQuestHeroImage() {
        let base = ContentFactory.bundle(quests: [ContentFactory.quest(heroImageAsset: "quests/quest-a/hero.jpg")])
        let found = ContentValidator.validate(base, assets: ContentFactory.assets(), today: ContentFactory.today)
        #expect(found.contains { $0.rule == .v14 })
    }
}

/// V19–V28 — sidequests and letter collections (PRD §5.15, `schema.md` §A.10–A.11). Same discipline
/// as above: every rule is proved by content that **violates** it, and the two acceptance tests
/// exist only to show the rules are not firing on everything.
struct SideQuestValidationTests {

    // MARK: - Control

    @Test func validSideQuestContentProducesNoFindings() {
        #expect(findings(ContentFactory.sideQuestBundle()).isEmpty,
                "Valid sidequest content produced findings: \(findings(ContentFactory.sideQuestBundle()))")
    }

    @Test func contentShippingNoSideQuestsIsSilentOnAllOfTheseRules() {
        // A schema 1 bundle, or a rollback to one. None of V19–V28 may fire on it.
        let sidequestRules: Set<ValidationRule> = [.v19, .v20, .v21, .v22, .v23, .v24, .v25, .v26, .v27, .v28]
        #expect(!findings(ContentFactory.bundle()).contains { sidequestRules.contains($0.rule) })
    }

    // MARK: - V19 · the Place resolves and ships (FR-SIDE-02, NFR-GOV-01)

    @Test func v19RejectsASideQuestPointingAtAPlaceThatDoesNotExist() {
        // No Place means no coordinate to gate arrival on and no consent record for V4 to judge.
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", placeId: "place-missing"),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v19 })
    }

    @Test func v19RejectsASideQuestAtAPlaceTheManifestDoesNotShip() {
        let base = ContentFactory.sideQuestBundle()
        let withoutPlaceA = ContentBundle(
            manifest: Manifest(
                schemaVersion: 2,
                contentBundleVersion: base.manifest.contentBundleVersion,
                languages: base.manifest.languages,
                places: ["place-b"],
                quests: base.manifest.quests,
                sideQuests: base.manifest.sideQuests,
                collections: base.manifest.collections),
            places: base.places,
            quests: base.quests,
            sideQuests: base.sideQuests,
            collections: base.collections,
            consentRecords: base.consentRecords)
        #expect(findings(withoutPlaceA).contains { $0.rule == .v19 })
    }

    // MARK: - V20 · radii (FR-ARR-07, FR-PROX-11)

    @Test(arguments: [0, 29, 251, 1000])
    func v20RejectsATriggerRadiusOutsideThirtyToTwoHundredFifty(_ radius: Int) {
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", triggerRadiusM: radius, noticeRadiusM: 2000),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v20 })
    }

    @Test(arguments: [75, 50, 0])
    func v20RejectsANoticeRadiusNotLargerThanTheTriggerRadius(_ notice: Int) {
        // The alert warns on approach; it does not confirm arrival at the gate.
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", triggerRadiusM: 75, noticeRadiusM: notice),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v20 })
    }

    // MARK: - V21 · sidequest lore cites its sources (NFR-CONT-01, FR-SIDE-04)

    @Test func v21RejectsASideQuestLoreBlockWithNoSourceRefs() {
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", lore: [ContentFactory.lore(sourceRefs: [])]),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v21 })
    }

    @Test func v21RejectsASourceRefPointingPastTheEndOfThePlacesSources() {
        // The Place has one source, so index 4 renders a claim with an empty citation — the
        // failure FR-CP-06 exists to prevent, on a new surface.
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", lore: [ContentFactory.lore(sourceRefs: [4])]),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v21 })
    }

    // MARK: - V22 · quiz shape (FR-SIDE-06)

    @Test(arguments: [1, 5, 6])
    func v22RejectsAQuizWithTooFewOrTooManyOptions(_ count: Int) {
        let options = (0..<count).map { ContentFactory.text("Opsi \($0)") }
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", challenge: ContentFactory.quiz(options: options, correctIndex: 0)),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v22 })
    }

    @Test func v22RejectsAQuizWithTwoIdenticalOptions() {
        // Two identical options make one of them unmarkable: a walker who taps the other correct
        // answer is told they are wrong.
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", challenge: ContentFactory.quiz(
                options: [ContentFactory.text("Sama"), ContentFactory.text("Sama"), ContentFactory.text("Beda")],
                correctIndex: 0)),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v22 })
    }

    @Test(arguments: [-1, 3, 99])
    func v22RejectsACorrectIndexOutsideTheOptions(_ index: Int) {
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", challenge: ContentFactory.quiz(correctIndex: index)),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v22 })
    }

    // MARK: - V23 · no photo challenge where photography is prohibited (FR-TASK-06)

    @Test func v23RejectsAPhotoChallengeAtAPlaceWherePhotographyIsProhibited() {
        let bundle = ContentFactory.sideQuestBundle(
            sideQuests: [
                ContentFactory.sideQuest(
                    id: "sq-a",
                    challenge: .photo(PhotoChallenge(prompt: ContentFactory.text("Foto gerbangnya.")))),
                ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
            ],
            places: [
                ContentFactory.place(id: "place-a", photoPolicy: .prohibited),
                ContentFactory.place(id: "place-b"),
            ])
        #expect(findings(bundle).contains { $0.rule == .v23 })
    }

    @Test func v23AcceptsAPhotoChallengeWherePhotographyIsMerelyRestricted() {
        let bundle = ContentFactory.sideQuestBundle(
            sideQuests: [
                ContentFactory.sideQuest(
                    id: "sq-a",
                    challenge: .photo(PhotoChallenge(prompt: ContentFactory.text("Foto gerbangnya.")))),
                ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
            ],
            places: [
                ContentFactory.place(id: "place-a", photoPolicy: .restricted),
                ContentFactory.place(id: "place-b"),
            ])
        #expect(!findings(bundle).contains { $0.rule == .v23 })
    }

    // MARK: - V24 · one sidequest, one slot, both directions (FR-SIDE-05)

    @Test func v24RejectsASideQuestThatFillsNoSlot() {
        // A place the walker can complete for no letter. Silent in the app, loud here.
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a"),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
            ContentFactory.sideQuest(id: "sq-orphan", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v24 })
    }

    @Test func v24RejectsASideQuestFillingSlotsInTwoCollections() {
        let second = ContentFactory.collection(
            id: "collection-b", phrase: "AB",
            slots: [
                LetterSlot(index: 0, letter: "A", sideQuestId: "sq-a"),
                LetterSlot(index: 1, letter: "B", sideQuestId: "sq-b"),
            ],
            badgeId: "badge-collection-b")
        let bundle = ContentFactory.sideQuestBundle(collections: [ContentFactory.collection(), second])
        #expect(findings(bundle).contains { $0.rule == .v24 })
    }

    // MARK: - V25 · slots match the phrase (FR-SIDE-08)

    @Test func v25RejectsAPhraseLongerThanItsSlotList() {
        // The phrase *is* the place count: three letters means three places to author.
        let bundle = ContentFactory.sideQuestBundle(collections: [ContentFactory.collection(phrase: "ABC")])
        #expect(findings(bundle).contains { $0.rule == .v25 })
    }

    @Test func v25RejectsASlotLetterThatIsNotThePhrasesLetterAtThatPosition() {
        let bundle = ContentFactory.sideQuestBundle(collections: [ContentFactory.collection(
            phrase: "AB",
            slots: [
                LetterSlot(index: 0, letter: "A", sideQuestId: "sq-a"),
                LetterSlot(index: 1, letter: "Z", sideQuestId: "sq-b"),
            ])])
        #expect(findings(bundle).contains { $0.rule == .v25 })
    }

    @Test func v25CountsThePhrasesSpacesAsDisplayOnly() {
        // "A B" is two letters and therefore two slots, not three.
        let bundle = ContentFactory.sideQuestBundle(collections: [ContentFactory.collection(phrase: "A B")])
        #expect(!findings(bundle).contains { $0.rule == .v25 })
    }

    // MARK: - V26 · slot indices and references (FR-SIDE-08)

    @Test func v26RejectsANonContiguousSlotIndex() {
        let bundle = ContentFactory.sideQuestBundle(collections: [ContentFactory.collection(
            slots: [
                LetterSlot(index: 0, letter: "A", sideQuestId: "sq-a"),
                LetterSlot(index: 2, letter: "B", sideQuestId: "sq-b"),
            ])])
        #expect(findings(bundle).contains { $0.rule == .v26 })
    }

    @Test func v26RejectsASlotNamingASideQuestThatDoesNotExist() {
        // A letter nobody can earn.
        let bundle = ContentFactory.sideQuestBundle(collections: [ContentFactory.collection(
            slots: [
                LetterSlot(index: 0, letter: "A", sideQuestId: "sq-a"),
                LetterSlot(index: 1, letter: "B", sideQuestId: "sq-missing"),
            ])])
        #expect(findings(bundle).contains { $0.rule == .v26 })
    }

    @Test func v26RejectsOneSideQuestFillingTwoSlotsInTheSameCollection() {
        let bundle = ContentFactory.sideQuestBundle(collections: [ContentFactory.collection(
            slots: [
                LetterSlot(index: 0, letter: "A", sideQuestId: "sq-a"),
                LetterSlot(index: 1, letter: "B", sideQuestId: "sq-a"),
            ])])
        #expect(findings(bundle).contains { $0.rule == .v26 })
    }

    // MARK: - V27 · the iOS region budget (FR-PROX-14, FR-SIDE-16)

    @Test func v27RejectsACollectionOfTwentyOneSideQuests() {
        // iOS monitors 20 regions per app. The twenty-first place simply never notifies, which in
        // the field is indistinguishable from a GPS problem.
        let letters = (0..<21).map { String(UnicodeScalar(UInt8(65 + $0))) }
        let sideQuests = letters.enumerated().map { index, _ in
            ContentFactory.sideQuest(id: "sq-\(index)", placeId: index.isMultiple(of: 2) ? "place-a" : "place-b")
        }
        let slots = letters.enumerated().map { index, letter in
            LetterSlot(index: index, letter: letter, sideQuestId: "sq-\(index)")
        }
        let bundle = ContentFactory.sideQuestBundle(
            sideQuests: sideQuests,
            collections: [ContentFactory.collection(phrase: letters.joined(), slots: slots)])
        #expect(findings(bundle).contains { $0.rule == .v27 })
    }

    // MARK: - V28 · sidequest assets exist

    @Test func v28RejectsAMissingSideQuestHeroImage() {
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", heroImageAsset: "sidequests/sq-a/hero.jpg"),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v28 })
    }

    @Test func v28AcceptsAHeroImageThatIsPresent() {
        let bundle = ContentFactory.sideQuestBundle(sideQuests: [
            ContentFactory.sideQuest(id: "sq-a", heroImageAsset: "sidequests/sq-a/hero.jpg"),
            ContentFactory.sideQuest(id: "sq-b", placeId: "place-b"),
        ])
        let found = ContentValidator.validate(
            bundle,
            assets: ContentFactory.assets(present: [
                "quests/quest-a/route.geojson", "quests/quest-a/route-preview.png",
                "sidequests/sq-a/hero.jpg",
            ]),
            today: ContentFactory.today)
        #expect(!found.contains { $0.rule == .v28 })
    }

    // MARK: - The rules a sidequest Place inherits for free

    @Test func aSideQuestPlaceIsAnOrdinaryPlaceAndIsJudgedByV4() {
        // The main reason a sidequest points at a `Place` rather than carrying its own coordinate
        // and hours: consent, sources and radius are covered with no new rule.
        let bundle = ContentFactory.sideQuestBundle(places: [
            ContentFactory.place(id: "place-a", consentRecordId: "place-missing"),
            ContentFactory.place(id: "place-b"),
        ])
        #expect(findings(bundle).contains { $0.rule == .v4 })
    }

    // MARK: - Helper

    private func findings(_ bundle: ContentBundle) -> [ValidationFinding] {
        ContentValidator.validate(bundle, assets: ContentFactory.assets(), today: ContentFactory.today)
    }
}
