import Foundation
import Testing
@testable import AppFeatures
@testable import ContentKit

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

    @Test func walkingTimeAndTotalDurationAreShownAsSeparateFigures() throws {
        // NFR-CONT-06. A single "duration" figure is the version of this that misleads a walker.
        let row = try #require(try model().rows.first)
        #expect(row.walkingTimeText != row.totalDurationText)
    }

    @Test func costIsVisibleOnTheCardWhenTheQuestCostsMoney() throws {
        // FR-DISC-05: the total must be on the card, not only inside preview.
        let row = try #require(try model().rows.first)
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
        #expect(model.rows.isEmpty)
        #expect(model.isEmpty)
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
        let model = try model()
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
        let rows = try model(language: .en).checkpoints
        let prohibited = try #require(rows.first { $0.photoPolicyText.contains("prohibited") })
        #expect(!prohibited.photoPolicyText.isEmpty)
    }

    // MARK: - FR-DISC-06, the late-start warning

    @Test func noWarningBeforeTheLatestStart() throws {
        // Fixture hardLatestStart is 13:30.
        #expect(try model(now: Self.at(hour: 13, minute: 29)).lateStartWarning == nil)
    }

    @Test func aWarningAfterTheLatestStart() throws {
        let warning = try #require(try model(language: .en, now: Self.at(hour: 14)).lateStartWarning)
        #expect(!warning.isEmpty)
    }

    @Test func exactlyAtTheLatestStartIsStillAllowed() throws {
        // The boundary belongs to the user: 13:30 sharp is a start time the content endorses.
        #expect(try model(now: Self.at(hour: 13, minute: 30)).lateStartWarning == nil)
    }

    @Test func theWarningNamesTheSiteThatClosesAndItsClosingTime() throws {
        // FR-DISC-06 requires both, or the warning is unactionable.
        let model = try model(language: .en, now: Self.at(hour: 15))
        let warning = try #require(model.lateStartWarning)
        let repository = try BundledContentRepository()
        let earliest = try #require(try repository.place(id: "contoh-museum-arsip-kota"))
        #expect(warning.contains(earliest.nameOfficial.en), "\(warning)")
        // The closing time is rendered in the device's 12/24-hour convention (`NFR-I18N-05`), so
        // the expectation is built with the same formatter rather than hardcoding "15:30".
        let expectedTime = ContentFormatter(language: .en)
            .time(TimeOfDay(hour: 15, minute: 30), calendar: Self.calendar)
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

    @Test func previewOffersNoWayToStartFromHere() throws {
        // FR-START-08: a quest must not be startable from outside the start radius by any path,
        // and M5 ships no arrival detection at all — so preview must not present a start control
        // that appears to work.
        let model = try model()
        #expect(model.startIsUnavailable)
        #expect(!model.startUnavailableExplanation.isEmpty)
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
}
