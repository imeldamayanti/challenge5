// Restored by m7 step 8 from b597b5b^ (Tests/AppFeaturesTests/DiscoveryTests.swift).
// FR-DISC-02/03/04/05/06/08, FR-START-06/08, FR-MAP-01, NFR-A11Y-01/06, NFR-REL-04.
import Foundation
import Testing
@testable import challange_5
import UIStringsKit
@testable import ContentKit
@testable import RunEngine

@MainActor
struct QuestListTests {

    private func model(_ language: ContentLanguage = .id) throws -> QuestListViewModel {
        QuestListViewModel(repository: try BundledContentRepository(), language: language)
    }

    @Test func theListShowsEveryFieldFRDISC02Requires() throws {
        // title, region, distance, walking time, total duration, estimated cost
        let row = try #require(try model().rows.first)
        #expect(!row.title.isEmpty)
        #expect(!row.region.isEmpty)
        #expect(!row.distanceText.isEmpty)
        #expect(!row.walkingTimeText.isEmpty)
        #expect(!row.totalDurationText.isEmpty)
        #expect(!row.costText.isEmpty)
    }

    // MARK: - Search
    //
    // The Home design puts a search field above the list. It filters what is already loaded and
    // asks nothing of the network — `FR-DISC-01` and `AD-3` mean discovery has to keep working in
    // airplane mode, and a search that queries anything would be the first thing in the app that
    // does not.

    @Test func anEmptySearchLeavesEveryQuestVisible() throws {
        let model = try model()
        model.searchText = "   "
        #expect(model.visibleRows.count == model.rows.count)
    }

    @Test func searchMatchesOnTitleAndOnRegion() throws {
        let model = try model()
        let row = try #require(model.rows.first)

        model.searchText = String(row.title.prefix(6))
        #expect(model.visibleRows.contains { $0.questID == row.questID })

        model.searchText = row.region
        #expect(model.visibleRows.contains { $0.questID == row.questID })
    }

    @Test func searchIgnoresCaseAndDiacritics() throws {
        // Indonesian place names carry diacritics the reader will not type, and a search that only
        // matches an exact byte sequence is a search that appears broken.
        let model = try model()
        let row = try #require(model.rows.first)
        let folded = row.title.folding(options: [.diacriticInsensitive], locale: nil).uppercased()

        model.searchText = folded
        #expect(model.visibleRows.contains { $0.questID == row.questID })
    }

    @Test func aSearchThatMatchesNothingEmptiesTheListRatherThanFallingBackToEverything() throws {
        // Silently showing all results when nothing matched is worse than showing none: the reader
        // cannot tell the difference between "no match" and "search is broken".
        let model = try model()
        model.searchText = "zzzzz-no-such-quest"
        #expect(model.visibleRows.isEmpty)
        #expect(model.hasNoSearchResults)
    }

    @Test func searchDoesNotDisturbTheAuthoredOrder() throws {
        // FR-DISC-03 fixes the order of the list. Filtering may remove rows; it may not reorder
        // what is left by relevance or by anything else.
        let model = try model()
        model.searchText = ""
        let authored = model.visibleRows.map(\.questID)
        model.searchText = "a"
        let filtered = model.visibleRows.map(\.questID)
        #expect(filtered == authored.filter(filtered.contains))
    }

    @Test func walkingTimeAndTotalDurationAreShownAsSeparateFigures() throws {
        // NFR-CONT-06. A single "duration" figure is the version of this that misleads a walker.
        let row = try #require(try model().rows.first)
        #expect(row.walkingTimeText != row.totalDurationText)
    }

    @Test func costIsVisibleOnTheCardWhenTheQuestCostsMoney() throws {
        // FR-DISC-05: the total must be on the card, not only inside preview.
        //
        // Against a fixture rather than the shipped tree (m7 group A): the shipped quest is free,
        // so on live content this guard asserted nothing about a paid quest, and it went red the
        // day an author replaced the placeholders. The rule needs a quest that costs money; the
        // shipped content does not have to be one.
        let model = QuestListViewModel(repository: FixtureContentRepository(), language: .id)
        let row = try #require(model.rows.first { $0.questID == ContentFixture.paidQuestID })
        #expect(row.showsCostOnCard)
        #expect(row.costText.contains("50"))
    }

    @Test func aFreeQuestShowsFreeRatherThanZero() throws {
        let row = QuestListRow(
            questID: "q", title: "T", region: "R",
            distanceText: "1 km", walkingTimeText: "10", totalDurationText: "20",
            costText: UIStrings.string(.costFree, .id), showsCostOnCard: false)
        #expect(row.costText == "Gratis")
        #expect(!row.showsCostOnCard)
    }

    @Test func rowsCarryTheQuestIdSoPreviewIsOneTapAway() throws {
        // FR-DISC-07. Navigation by value: the row already holds everything the destination needs
        // to be built, so reaching preview is a single tap and not a fetch.
        let row = try #require(try model().rows.first)
        #expect(!row.questID.isEmpty)
        #expect(row.id == row.questID)
    }

    @Test func theListRendersInWhicheverLanguageIsActive() throws {
        let indonesian = try #require(try model(.id).rows.first)
        let english = try #require(try model(.en).rows.first)
        #expect(indonesian.title != english.title)
        #expect(indonesian.questID == english.questID)
    }

    @Test func suppressedQuestsDoNotAppear() throws {
        // FR-DISC-08, list side.
        let repository = try BundledContentRepository()
        let victim = try #require(try repository.quests().first).id
        let model = QuestListViewModel(
            repository: repository, language: .id, suppressedQuestIDs: [victim])
        #expect(!model.rows.contains { $0.questID == victim })
        #expect(model.rows.count == (try repository.quests().count) - 1)
    }

    @Test func anEmptyListSaysSoRatherThanShowingNothing() throws {
        let repository = try BundledContentRepository()
        let model = QuestListViewModel(
            repository: repository, language: .id,
            suppressedQuestIDs: Set(try repository.quests().map(\.id)))
        #expect(model.isEmpty)
    }

    @Test func aBrokenRepositoryLeavesTheScreenUsableRatherThanCrashing() {
        // NFR-REL-04 in spirit: a content problem must not take the app down.
        let model = QuestListViewModel(repository: FailingContentRepository(), language: .id)
        #expect(model.rows.isEmpty)
        #expect(model.loadFailed)
    }
}

@MainActor
struct QuestPreviewTests {

    private func model(
        language: ContentLanguage = .id,
        now: Date = Self.at(hour: 9)
    ) throws -> QuestPreviewViewModel {
        let repository = try BundledContentRepository()
        let questID = try #require(try repository.quests().first).id
        return try #require(QuestPreviewViewModel(
            repository: repository, questID: questID, language: language,
            now: now, calendar: Self.calendar))
    }

    /// The same screen, built over `ContentFixture` instead of the shipped tree.
    ///
    /// m7 group A: four of the guards below are about content *shape* — a paid quest, a place
    /// where photography is prohibited, a known `hardLatestStart` and a known earliest closing.
    /// Asserting those against whatever is authored this week made them go red when the `contoh-*`
    /// placeholders were replaced, with no requirement having changed. The fixture is what the
    /// rule needs; the shipped content is not edited to supply it.
    private func fixtureModel(
        language: ContentLanguage = .id,
        now: Date = Self.at(hour: 9)
    ) throws -> QuestPreviewViewModel {
        try #require(QuestPreviewViewModel(
            repository: FixtureContentRepository(), questID: ContentFixture.paidQuestID,
            language: language, now: now, calendar: Self.calendar))
    }

    /// The first quest in the shipped bundle — the same one `model()` builds.
    static var questID: String {
        get throws {
            try #require(try BundledContentRepository().quests().first).id
        }
    }

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Makassar") ?? .gmt
        return calendar
    }()

    static func at(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone, year: 2026, month: 8, day: 11, hour: hour, minute: minute))!
    }

    // MARK: - FR-DISC-03, everything preview must show

    @Test func previewShowsEveryFieldFRDISC03Requires() throws {
        // Fixture-backed (m7 group A). The field list is the requirement; the quest that carries
        // every field is a fixture, so an author shipping a free quest or a quest with no hero
        // image cannot silently narrow what this checks.
        let model = try fixtureModel()
        #expect(!model.hookLore.isEmpty)                 // opening lore hook
        #expect(!model.descriptionText.isEmpty)          // description
        #expect(model.checkpoints.count == 5)            // ordered checkpoint list…
        #expect(model.checkpoints.allSatisfy { !$0.placeName.isEmpty })   // …with Place names
        #expect(model.routeImageURL != nil)              // route map (FR-MAP-01)
        #expect(!model.distanceText.isEmpty)             // total distance
        #expect(!model.walkingTimeText.isEmpty)          // walking time
        #expect(!model.totalDurationText.isEmpty)        // total duration
        #expect(!model.costText.isEmpty)                 // estimated cost…
        #expect(!model.costBreakdown.isEmpty)            // …with breakdown
        #expect(!model.terrainText.isEmpty)              // terrain…
        #expect(model.checkpoints.contains { $0.stepsText != nil })  // …and steps
        #expect(!model.recommendedWindowText.isEmpty)    // recommended start window
        #expect(!model.safetyNotes.isEmpty)              // safety notice
    }

    @Test func checkpointsAreListedInWalkingOrder() throws {
        #expect(try model().checkpoints.map(\.orderIndex) == [0, 1, 2, 3, 4])
    }

    @Test func theCostBreakdownSumsToTheTotal() throws {
        let model = try model()
        #expect(model.costBreakdownTotalMinor == model.estimatedCostMinorUnits)
    }

    // MARK: - FR-DISC-04, the story is not here

    @Test func noCheckpointLoreTextAppearsAnywhereInThePreview() throws {
        // The load-bearing test for FR-DISC-04. Not "does the view model have a lore property" —
        // whether the *text itself* has leaked into any string the screen renders.
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        let model = try model()

        let rendered = model.allRenderedText.joined(separator: "\n")
        for checkpoint in quest.orderedCheckpoints {
            for block in checkpoint.loreSegment {
                for language in ContentLanguage.allCases {
                    let sentence = block.text.value(for: language)
                    #expect(!rendered.contains(sentence),
                            "Checkpoint lore leaked into preview: \(sentence)")
                }
            }
        }
    }

    @Test func noClueTextAppearsAnywhereInThePreview() throws {
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        let rendered = try model().allRenderedText.joined(separator: "\n")

        for checkpoint in quest.orderedCheckpoints {
            guard let clue = checkpoint.clueToNext else { continue }
            for language in ContentLanguage.allCases {
                #expect(!rendered.contains(clue.value(for: language)),
                        "Clue leaked into preview: \(clue.value(for: language))")
            }
        }
    }

    @Test func theCheckpointRowTypeHasNoFieldThatCouldHoldLoreOrAClue() throws {
        // Structural backstop: even a future careless edit has nowhere to put it.
        let row = try #require(try model().checkpoints.first)
        let fields = Mirror(reflecting: row).children.compactMap(\.label).map { $0.lowercased() }
        #expect(!fields.contains { $0.contains("lore") }, "\(fields)")
        #expect(!fields.contains { $0.contains("clue") }, "\(fields)")
    }

    @Test func theQuestHookIsShownBecauseItIsNotCheckpointLore() throws {
        // FR-DISC-03 asks for the opening lore hook explicitly. Withholding it too would be
        // over-reading FR-DISC-04.
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        let model = try model(language: .en)
        #expect(model.hookLore.count == quest.hookLore.count)
        #expect(model.allRenderedText.joined().contains(quest.hookLore[0].text.en))
    }

    @Test func hookLoreCarriesItsAccuracyLabelVisibly() throws {
        // FR-CP-05 / NFR-A11Y-05: label present as text, and never behind a tap.
        let model = try model()
        for block in model.hookLore {
            #expect(!block.accuracyLabel.isEmpty)
            #expect(block.appearance.isInteractive == false)
        }
    }

    // MARK: - NFR-A11Y-07 / FR-TASK-05 disclosure

    @Test func eachCheckpointDisclosesStepsSurfaceDressCodeAndPhotoPolicy() throws {
        for row in try model().checkpoints {
            #expect(!row.surfaceText.isEmpty)
            #expect(!row.dressCodeText.isEmpty)
            #expect(!row.photoPolicyText.isEmpty)
        }
    }

    @Test func aSacredPlaceIsMarkedAsOne() throws {
        // FR-TASK-05's disclosure half, surfaced before the user ever arrives.
        #expect(try model().checkpoints.contains { $0.isSacred })
    }

    @Test func aPlaceWherePhotographyIsProhibitedSaysSoInWords() throws {
        // Fixture-backed (m7 group A). No place on the shipped route prohibits photography, and
        // authoring one there to satisfy a test would be a claim about a real institution with no
        // source and no consent record behind it.
        let rows = try fixtureModel(language: .en).checkpoints
        let prohibited = try #require(rows.first { $0.photoPolicyText.contains("prohibited") })
        #expect(!prohibited.photoPolicyText.isEmpty)
    }

    // MARK: - FR-DISC-06, the late-start warning
    //
    // All four boundary cases run against `ContentFixture`, whose `hardLatestStart` is 13:30 and
    // whose earliest closing is 15:30 at a named place — 120 minutes apart, so the derivation V16
    // describes actually holds. On the shipped tree these read whatever the author last wrote,
    // which is how three of them went red without FR-DISC-06 changing.

    @Test func noWarningBeforeTheLatestStart() throws {
        #expect(try fixtureModel(now: Self.at(hour: 13, minute: 29)).lateStartWarning == nil)
    }

    @Test func aWarningAfterTheLatestStart() throws {
        let warning = try #require(
            try fixtureModel(language: .en, now: Self.at(hour: 14)).lateStartWarning)
        #expect(!warning.isEmpty)
    }

    @Test func exactlyAtTheLatestStartIsStillAllowed() throws {
        // The boundary belongs to the user: 13:30 sharp is a start time the content endorses.
        #expect(try fixtureModel(now: Self.at(hour: 13, minute: 30)).lateStartWarning == nil)
    }

    @Test func theWarningNamesTheSiteThatClosesAndItsClosingTime() throws {
        // FR-DISC-06 requires both, or the warning is unactionable.
        let model = try fixtureModel(language: .en, now: Self.at(hour: 15))
        let warning = try #require(model.lateStartWarning)
        let earliest = try #require(
            try FixtureContentRepository().place(id: ContentFixture.earliestClosingPlaceID))
        #expect(warning.contains(earliest.nameOfficial.en), "\(warning)")
        // The closing time is rendered in the device's 12/24-hour convention (`NFR-I18N-05`), so
        // the expectation is built with the same formatter rather than hardcoding "15:30".
        let expectedTime = ContentFormatter(language: .en)
            .time(ContentFixture.earliestClosing, calendar: Self.calendar)
        #expect(warning.contains(expectedTime), "\(warning) — expected \(expectedTime)")
    }

    @Test func theWarningIsNonBlocking() throws {
        // Everything else must still be readable behind it.
        let model = try model(now: Self.at(hour: 20))
        #expect(model.lateStartWarning != nil)
        #expect(model.checkpoints.count == 5)
        #expect(!model.safetyNotes.isEmpty)
    }

    // MARK: - FR-START-08 / FR-DISC-01

    @Test func previewWithNoRunStoreOffersNoStartControl() throws {
        // FR-START-08 / FR-DISC-01: preview works anywhere, and it never starts a Run itself. With
        // no Run store wired the screen says so rather than showing a control that does nothing.
        let model = try model()
        #expect(model.startState == .unavailable)
        #expect(!model.startUnavailableExplanation.isEmpty)
    }

    @Test func previewOffersAStartControlWhenARunStoreIsWired() throws {
        // The control leads to the arrival screen; it does not start the walk. The radius and
        // accuracy gate live there, which is what keeps FR-START-08 true with a live button.
        let repository = try BundledContentRepository()
        let engine = RunEngine(repository: repository, store: InMemoryRunStore())
        let model = try #require(QuestPreviewViewModel(
            repository: repository, questID: Self.questID, language: .id, runEngine: engine))
        #expect(model.startState == .start)
    }

    @Test func previewOffersResumeWhenADraftExists() throws {
        // FR-START-06 — an existing draft is surfaced as resume-or-restart, never as a second Run.
        let repository = try BundledContentRepository()
        let store = InMemoryRunStore()
        let engine = RunEngine(repository: repository, store: store)
        let draft = try engine.start(
            questID: Self.questID, language: .id, method: .gps, accuracyM: 8)

        let model = try #require(QuestPreviewViewModel(
            repository: repository, questID: Self.questID, language: .id, runEngine: engine))
        guard case .resume(let runID, let progressText) = model.startState else {
            Issue.record("Expected a resume state, got \(model.startState)")
            return
        }
        #expect(runID == draft.id)
        #expect(!progressText.isEmpty)
    }

    @Test func aMissingQuestYieldsNoViewModelRatherThanAnEmptyScreen() throws {
        #expect(QuestPreviewViewModel(
            repository: try BundledContentRepository(), questID: "no-such-quest",
            language: .id, now: Date(), calendar: .current) == nil)
    }
}

/// A repository that fails every read, for the "content is broken, keep the app usable" path.
struct FailingContentRepository: ContentRepository {
    struct Failure: Error {}

    func manifest() throws -> Manifest { throw Failure() }
    func contentBundleVersion() throws -> String { throw Failure() }
    func quests() throws -> [Quest] { throw Failure() }
    func quest(id: String) throws -> Quest? { throw Failure() }
    func place(id: String) throws -> Place? { throw Failure() }
    func quests(suppressingQuestIDs: Set<String>, suppressingPlaceIDs: Set<String>) throws -> [Quest] {
        throw Failure()
    }
    func assetURL(_ relativePath: String) throws -> URL? { throw Failure() }

    // Added when this suite was restored (m7 step 8): the protocol gained sidequests and letter
    // collections in s1 §6. A repository that fails every read fails these too — the point of the
    // double is that NOTHING it is asked for succeeds.
    func sideQuests() throws -> [SideQuest] { throw Failure() }
    func sideQuest(id: String) throws -> SideQuest? { throw Failure() }
    func sideQuests(atPlaceID placeID: String) throws -> [SideQuest] { throw Failure() }
    func collections() throws -> [LetterCollection] { throw Failure() }
    func collection(id: String) throws -> LetterCollection? { throw Failure() }
    func sideQuests(suppressingSideQuestIDs: Set<String>,
                    suppressingPlaceIDs: Set<String>) throws -> [SideQuest] { throw Failure() }
}

@MainActor
struct QuestCardAndMapTests {

    // MARK: - The card from the Home design, with the fields the mockup dropped

    @Test func theCardCarriesAHeroImageAndACheckpointCount() throws {
        let row = try #require(QuestListViewModel(
            repository: try BundledContentRepository(), language: .en).rows.first)
        #expect(row.heroImageURL != nil)
        #expect(row.checkpointCount == 5)
        #expect(row.checkpointCountText.contains("5"))
    }

    @Test func theCardSaysCheckpointsRatherThanQuests() throws {
        // The mockup labels this "5 quests". The glossary calls them checkpoints and FR-CP-08
        // counts progress in them; a quest containing quests makes both readings ambiguous.
        let row = try #require(QuestListViewModel(
            repository: try BundledContentRepository(), language: .en).rows.first)
        #expect(row.checkpointCountText.lowercased().contains("checkpoint"))
        #expect(!row.checkpointCountText.lowercased().contains("quest"))
    }

    @Test func theCardStillCarriesDistanceAndCostThatTheMockupOmitted() throws {
        // FR-DISC-02 requires distance; FR-DISC-05 requires the cost total on the card itself.
        // The design shows neither, so this test is the reason both survived the restyle.
        for row in try QuestListViewModel(repository: try BundledContentRepository(), language: .en).rows {
            #expect(!row.distanceText.isEmpty)
            #expect(!row.costText.isEmpty)
        }
    }

    @Test func theCardStillSeparatesWalkingTimeFromTotalTime() throws {
        // The mockup shows a single "30 mins". NFR-CONT-06 requires two figures.
        for row in try QuestListViewModel(repository: try BundledContentRepository(), language: .en).rows {
            #expect(row.walkingTimeText != row.totalDurationText)
        }
    }

    // MARK: - The map screen

    @Test func theMapModelPlacesOnePinPerQuestAtItsStartPlace() throws {
        let repository = try BundledContentRepository()
        let model = try #require(RegionMapViewModel(repository: repository, language: .en))
        let quests = try repository.quests()

        #expect(model.pins.count == quests.count)
        for quest in quests {
            let pin = try #require(model.pins.first { $0.questID == quest.id })
            let startPlaceID = try #require(quest.startCheckpoint?.placeId)
            let place = try #require(try repository.place(id: startPlaceID))
            #expect(pin.point == place.mapPoint)
            #expect(pin.title == quest.title.value(for: .en))
        }
    }

    @Test func aClusterOfPinsOpensZoomedInFarEnoughToSeparateTheMarkers() throws {
        // The Home design draws the island whole. Whole is only usable when the pins are spread:
        // quests inside one town land on top of one another at island scale (`NFR-A11Y-01`) and
        // stop being 44-point targets (`NFR-A11Y-06`). So the opening zoom is derived from the
        // content.
        //
        // Fixture-backed (m7 group C). The shipped tree now holds one quest, so on live content
        // there is nothing to cluster and `closestPinSeparation` is nil — the guard could not run,
        // let alone fail correctly. Two fixture start places a thousandth of the illustration
        // apart are what the rule is about.
        let model = try #require(RegionMapViewModel(
            repository: FixtureContentRepository(), language: .en))
        let drawn = CGSize(width: 402, height: 874)

        let zoom = model.initialZoom(drawnAt: drawn, minimumSeparation: 132, maximum: 4)
        let separation = try #require(model.closestPinSeparation(drawnAt: drawn))

        #expect(zoom > 1, "quests in one town should not open at island scale")
        #expect(separation * zoom >= 132 || zoom == 4)
    }

    @Test func pinsThatAreAlreadyFarApartOpenTheMapWhole() throws {
        // The other half of the same rule: content whose quests are spread across the island must
        // open showing the island, not zoomed into nothing.
        let model = try #require(RegionMapViewModel(
            repository: try BundledContentRepository(), language: .en))
        // A drawn size large enough that even the clustered example content clears the threshold
        // stands in for spread-out content, and exercises the same branch.
        let zoom = model.initialZoom(
            drawnAt: CGSize(width: 40_000, height: 87_000), minimumSeparation: 132, maximum: 4)
        #expect(zoom == 1)
    }

    @Test func everyPinSitsInsideTheImage() throws {
        // A pin at 1.4 would render off the map and be untappable — V17 catches it at build time,
        // and this catches a runtime transform that reintroduces it.
        let model = try #require(RegionMapViewModel(
            repository: try BundledContentRepository(), language: .en))
        for pin in model.pins {
            #expect(pin.point.isInsideImage, "\(pin.questID) at \(pin.point)")
        }
    }

    @Test func theMapDrawsFromAShippedImageRatherThanTiles() throws {
        // FR-MAP-01 / FR-OFF-03.
        let model = try #require(RegionMapViewModel(
            repository: try BundledContentRepository(), language: .en))
        #expect(model.mapImageURL != nil)
        #expect(model.aspectRatio > 0)
    }

    @Test func suppressedQuestsLoseTheirPinToo() throws {
        // FR-DISC-08: hidden from discovery means hidden from every discovery surface, not just
        // the list. A pin for a withdrawn site is the failure this rule exists to prevent.
        let repository = try BundledContentRepository()
        let victim = try #require(try repository.quests().first).id
        let model = try #require(RegionMapViewModel(
            repository: repository, language: .en, suppressedQuestIDs: [victim]))
        #expect(!model.pins.contains { $0.questID == victim })
    }

    @Test func contentWithNoRegionMapYieldsNoMapModelRatherThanAnEmptyFrame() throws {
        #expect(RegionMapViewModel(repository: MapLessContentRepository(), language: .en) == nil)
    }

    @Test func aPinCarriesEnoughToOpenPreviewInOneTap() throws {
        let model = try #require(RegionMapViewModel(
            repository: try BundledContentRepository(), language: .en))
        for pin in model.pins {
            #expect(!pin.questID.isEmpty)
            #expect(!pin.title.isEmpty)
            #expect(!pin.accessibilityLabel.isEmpty)
            // NFR-A11Y-02: a pin is a control, so it says what it is and where it goes.
            #expect(pin.accessibilityLabel.contains(pin.title))
        }
    }
}

/// A repository whose content ships no illustrated map.
struct MapLessContentRepository: ContentRepository {
    struct Unavailable: Error {}
    private let inner = try? BundledContentRepository()

    func manifest() throws -> Manifest {
        guard let inner else { throw Unavailable() }
        let m = try inner.manifest()
        return Manifest(schemaVersion: m.schemaVersion, contentBundleVersion: m.contentBundleVersion,
                        languages: m.languages, places: m.places, quests: m.quests, regionMap: nil)
    }
    func contentBundleVersion() throws -> String { try manifest().contentBundleVersion }
    func quests() throws -> [Quest] { try inner?.quests() ?? [] }
    func quest(id: String) throws -> Quest? { try inner?.quest(id: id) ?? nil }
    func place(id: String) throws -> Place? { try inner?.place(id: id) ?? nil }
    func quests(suppressingQuestIDs: Set<String>, suppressingPlaceIDs: Set<String>) throws -> [Quest] {
        try inner?.quests(suppressingQuestIDs: suppressingQuestIDs, suppressingPlaceIDs: suppressingPlaceIDs) ?? []
    }

    // s1 §6, as above. This double only withholds the region map, so everything else delegates.
    func sideQuests() throws -> [SideQuest] { try inner?.sideQuests() ?? [] }
    func sideQuest(id: String) throws -> SideQuest? { try inner?.sideQuest(id: id) ?? nil }
    func sideQuests(atPlaceID placeID: String) throws -> [SideQuest] {
        try inner?.sideQuests(atPlaceID: placeID) ?? []
    }
    func collections() throws -> [LetterCollection] { try inner?.collections() ?? [] }
    func collection(id: String) throws -> LetterCollection? { try inner?.collection(id: id) ?? nil }
    func sideQuests(suppressingSideQuestIDs: Set<String>,
                    suppressingPlaceIDs: Set<String>) throws -> [SideQuest] {
        try inner?.sideQuests(suppressingSideQuestIDs: suppressingSideQuestIDs,
                              suppressingPlaceIDs: suppressingPlaceIDs) ?? []
    }
    func assetURL(_ relativePath: String) throws -> URL? { try inner?.assetURL(relativePath) ?? nil }
}
