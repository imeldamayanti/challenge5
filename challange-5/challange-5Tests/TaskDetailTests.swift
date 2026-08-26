// The three screens ported from Figma on 2026-08-17: `452:3132` ("Quest 1/3"), `447:1880`
// ("Quest_Filled") and `452:3028` ("Site Map"). What is guarded here is the navigation between them
// and the values they render — not their layout, which no unit test can see.
// FR-CP-05, FR-TASK-02/06, AD-2, AD-4.
import Foundation
import Testing
import UIKit
@testable import challange_5
import UIStringsKit
@testable import ContentKit
@testable import RunEngine

@MainActor
struct TaskDetailTests {

    private struct Harness {
        let model: QuestRunViewModel
        let provider: FakeLocationProvider
        let quest: Quest
        let photoStore: InMemoryPhotoStore
    }

    /// Resolves a task the way its own mechanic is resolved — a photograph for a `photo` task, words
    /// for the two written ones.
    ///
    /// The tests below used to write into `taskDrafts` and assume that answered the checkpoint's
    /// first task. Since `2026.09.14` every stop carries three tasks and the first of several is a
    /// photograph, and `saveTask` turns a written draft on a photo task into a *skip* — so the
    /// assumption did not fail loudly, it resolved the task as the wrong kind. The answer has to
    /// follow the mechanic the content authored.
    @discardableResult
    private func answer(_ task: ContentTask, on harness: Harness, words: String) -> String? {
        if task.type == .photo {
            // `photoDrafts` is private and the shutter is the only way in, so the sheet has to be
            // open on this task — which is where a photograph is taken anyway.
            harness.model.openTaskDetail(taskID: task.id)
            harness.model.capturedPhoto(UIImage())
            return nil
        }
        harness.model.taskDrafts[task.id] = words
        return words
    }

    /// A walk standing at its first checkpoint with the task list on screen — the state `452:3132`
    /// draws.
    private func atTaskList() throws -> Harness {
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        let provider = FakeLocationProvider(authorization: .whenInUse)
        let photoStore = InMemoryPhotoStore()
        let model = try #require(QuestRunViewModel(
            engine: RunEngine(repository: repository, store: InMemoryRunStore()),
            repository: repository,
            preferences: InMemoryAppPreferencesStore(safetyNoticeAckedQuestIDs: [quest.id]),
            locationProvider: provider,
            questID: quest.id,
            language: .id,
            manualOverrideDelay: .milliseconds(20),
            photoStore: photoStore))

        model.advanceFromStoryPreview()
        if model.stage == .awaitingArrival, !provider.isSampling { model.screenAppeared() }
        // Inside the radius with a fix good enough to satisfy the accuracy half of `FR-ARR-01`.
        provider.emit(offsetMetres: 5, accuracy: 10)

        // Bounded rather than `while`: a stage that returns itself should fail the suite, not hang it.
        for _ in 0..<12 where model.stage != .checkpointDetail {
            // `921:3851` — the quest-availability sheet sits between the first explanation and the
            // sealed scroll but is not a `Stage`, so it is checked ahead of the switch below.
            if model.isPresentingQuestAvailability { model.advanceFromQuestAvailability(); continue }
            switch model.stage {
            case .locationVerified: model.advanceFromLocationVerified()
            case .arrivalNotice: model.advanceFromArrivalNotice()
            case .cutsceneIntro: model.advanceFromCutsceneIntro()
            case .cutscenePortrait: model.advanceFromCutscenePortrait()
            case .approachTransition: model.advanceFromApproachTransition()
            case .storyReveal: model.advanceFromStoryReveal()
            case .transition: model.advanceFromTransition()
            case .placeNotice: model.advanceFromPlaceNotice()
            // `1:4592` → `1:4711` → `1:4904`: the menu is reached *through* the checkpoint's first
            // task, so getting to the state `1:4904` draws means passing that sheet.
            case .taskDetail: model.advanceFromTaskDetail()
            default: break
            }
        }
        try #require(model.stage == .checkpointDetail)
        return Harness(model: model, provider: provider, quest: quest, photoStore: photoStore)
    }

    /// The same walk, stopped at the sacred-Place notice — `1:4592`, now the screen right after the
    /// story reveal, before the sealed-scroll transition and the first task. `atTaskList` walks
    /// straight past it.
    private func atPlaceNotice() throws -> Harness {
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        let provider = FakeLocationProvider(authorization: .whenInUse)
        let model = try #require(QuestRunViewModel(
            engine: RunEngine(repository: repository, store: InMemoryRunStore()),
            repository: repository,
            preferences: InMemoryAppPreferencesStore(safetyNoticeAckedQuestIDs: [quest.id]),
            locationProvider: provider,
            questID: quest.id,
            language: .id,
            manualOverrideDelay: .milliseconds(20)))

        model.advanceFromStoryPreview()
        if model.stage == .awaitingArrival, !provider.isSampling { model.screenAppeared() }
        provider.emit(offsetMetres: 5, accuracy: 10)

        for _ in 0..<10 where model.stage != .placeNotice {
            switch model.stage {
            case .locationVerified: model.advanceFromLocationVerified()
            case .arrivalNotice: model.advanceFromArrivalNotice()
            case .cutsceneIntro: model.advanceFromCutsceneIntro()
            case .cutscenePortrait: model.advanceFromCutscenePortrait()
            case .approachTransition: model.advanceFromApproachTransition()
            case .storyReveal: model.advanceFromStoryReveal()
            case .transition: model.advanceFromTransition()
            default: break
            }
        }
        try #require(model.stage == .placeNotice,
                     "the first stop is a sacred Place, so the notice is on the path")
        return Harness(model: model, provider: provider, quest: quest,
                       photoStore: InMemoryPhotoStore())
    }

    // MARK: - `1:4592` → `921:3851` → `1:4586` → `1:4711` → `1:4904`

    /// The reordered flow: the place notice hands over to the quest-availability sheet, which hands
    /// over to the sealed-scroll transition, and the transition is what opens the checkpoint's
    /// **first** task — not the task menu. The menu is what the walker reaches after resolving it.
    @Test func thePlaceNoticeHandsToTheTransitionWhichOpensTheFirstTask() throws {
        let harness = try atPlaceNotice()
        let first = try #require(harness.model.checkpoint?.tasks.first)

        harness.model.advanceFromPlaceNotice()
        #expect(harness.model.isPresentingQuestAvailability)
        #expect(harness.model.stage == .placeNotice, "the sheet sits over the notice, not a new stage")

        harness.model.advanceFromQuestAvailability()
        #expect(!harness.model.isPresentingQuestAvailability)
        #expect(harness.model.stage == .transition)

        harness.model.advanceFromTransition()
        #expect(harness.model.stage == .taskDetail(taskID: first.id))
        #expect(harness.model.firstTask?.id == first.id)
    }

    /// Backing out of the first task returns to the transition it was opened from — not to the
    /// menu, which the walker has not seen yet. The same sheet opened from a row backs out to the
    /// menu; that is what `stageBeforeTaskDetail` is for.
    @Test func backingOutOfTheFirstTaskReturnsToTheTransitionItCameFrom() throws {
        let harness = try atPlaceNotice()
        harness.model.advanceFromPlaceNotice()
        harness.model.advanceFromQuestAvailability()
        harness.model.advanceFromTransition()

        harness.model.retreatFromStoryStage()

        #expect(harness.model.stage == .transition)
    }

    /// And backing out of the menu returns to that first task rather than skipping over it back to
    /// the notice, so the two directions agree about the order of the screens.
    @Test func backingOutOfTheMenuReturnsToTheFirstTask() throws {
        let harness = try atTaskList()
        let first = try #require(harness.model.checkpoint?.tasks.first)

        harness.model.retreatFromStoryStage()

        #expect(harness.model.stage == .taskDetail(taskID: first.id))
    }

    // MARK: - `452:3132` → `447:1880`

    @Test func tappingARowOpensThatTasksOwnSheet() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)

        harness.model.openTaskDetail(taskID: task.id)

        #expect(harness.model.stage == .taskDetail(taskID: task.id))
        #expect(harness.model.detailTask?.id == task.id)
    }

    /// The stage carries a task **id**, not an index, and the guard is why. `FR-TASK-06` filters a
    /// photo task out of the list at a Place where photography is prohibited, so an index means a
    /// different task depending on the Place — and an id nothing resolves would draw an empty sheet
    /// with a back button and no way to tell what went wrong.
    @Test func anIdThatResolvesToNoTaskAtThisCheckpointChangesNothing() throws {
        let harness = try atTaskList()

        harness.model.openTaskDetail(taskID: "not-a-task-at-this-checkpoint")

        #expect(harness.model.stage == .checkpointDetail)
        #expect(harness.model.detailTask == nil)
    }

    /// A task belonging to a *later* checkpoint is refused for the same reason: it is not what is
    /// waiting here, and the sheet names the place the walker is standing at.
    @Test func aTaskFromAnotherCheckpointIsRefused() throws {
        let harness = try atTaskList()
        let laterTask = try #require(
            harness.quest.orderedCheckpoints.first { $0.orderIndex == 1 }?.tasks.first)

        harness.model.openTaskDetail(taskID: laterTask.id)

        #expect(harness.model.stage == .checkpointDetail)
    }

    @Test func detailTaskIsNilOnEveryOtherStage() throws {
        let harness = try atTaskList()
        #expect(harness.model.detailTask == nil)
    }

    @Test func backingOutOfTheSheetReturnsToTheListRatherThanLeavingTheWalk() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)

        harness.model.retreatFromStoryStage()

        #expect(harness.model.stage == .checkpointDetail)
        #expect(harness.model.run != nil, "the draft walk survives backing out of a task")
    }

    // MARK: - The segmented bar on `452:3138`

    /// The bar counts *answers*, as of 2026-08-26. A skipped task fills no segment and draws no
    /// checkmark: it reads as still open, because the walker can come back to it and the stamp it
    /// would move has not moved. This inverts the rule that stood earlier the same day, and the
    /// cost it accepts is the one that argued against it — a walker who skips a task leaves the bar
    /// permanently short of full. That is now the intended reading rather than a defect.
    ///
    /// `AD-2` is untouched: nothing gates on this, and `advanceFromCheckpointDetail` leaves the
    /// checkpoint whatever the bar says.
    @Test func aSkippedTaskFillsNoSegment() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)

        #expect(harness.model.taskCount == harness.model.checkpoint?.tasks.count)
        #expect(harness.model.resolvedTaskCount == 0)

        harness.model.skipTask(task)

        #expect(harness.model.resolvedTaskCount == 0)
        #expect(harness.model.resolution(for: task)?.skipped == true,
                "the skip is still recorded — it is the *reading* that changed, not the record")
    }

    /// A skipped task is still open work, so it stays in the count "More Quests (N)" offers. The
    /// stamp screen and the task list have to agree about the same checkpoint.
    @Test func aSkippedTaskStaysInTheRemainingCount() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        let before = harness.model.unresolvedTaskCount

        harness.model.skipTask(task)

        #expect(harness.model.unresolvedTaskCount == before)
    }

    @Test func answeringATaskFillsItsSegment() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)

        answer(task, on: harness, words: "Gerbangnya batu bata merah.")
        harness.model.saveTask(task)

        #expect(harness.model.resolvedTaskCount == 1)
        #expect(harness.model.resolution(for: task)?.skipped == false)
    }

    /// The label the bar reads out. `452:3132` is titled "Quest 1/3" and draws three segments, and
    /// the mock-up's three are copy invented for it — the total the bar prints is the checkpoint's
    /// own task list, whatever length content gives it (`AD-4`). Asserting the literal number is
    /// what this test used to do, and a content edit made it red for no requirement's sake.
    @Test func theProgressLabelCountsTheRunsOwnTasksAndNotTheFramesThree() throws {
        let harness = try atTaskList()
        let authored = try #require(harness.model.checkpoint?.tasks.count)

        #expect(authored > 0)
        #expect(harness.model.taskCount == authored,
                "the bar must follow the checkpoint's authored tasks, not a drawn number")
        #expect(harness.model.taskProgressLabel.contains("\(authored)"))
    }

    // MARK: - `452:3028` — the site plan

    /// **The plan is a claim and it carries its source.** `452:3031` annotates a real puri with real
    /// distances — "171 meters", an entrance gate — and `FR-CP-05` holds that to the same standard as
    /// a sentence of lore. The screen prints this citation, so as long as the drawing is a generated
    /// illustration the citation has to say so.
    @Test func theStartCheckpointsPlanCarriesTheCitationTheScreenPrints() throws {
        let harness = try atTaskList()
        let siteMap = try #require(harness.model.checkpoint?.siteMap)

        #expect(siteMap.imageURL != nil)
        #expect(siteMap.aspectRatio > 0)
        #expect(siteMap.citation.hasPrefix("BELUM DIVERIFIKASI"),
                "the shipped plan is generated and unsurveyed; the screen must say so")
    }

    /// The three dots `452:3032`–`3034` draw are not authored anywhere in the content tree. Inventing
    /// coordinates for them would be the app asserting where three things stand inside a real puri,
    /// which is exactly the claim the citation above exists to qualify.
    @Test func noMarkersAreInventedForThePlan() throws {
        let harness = try atTaskList()
        let siteMap = try #require(harness.model.checkpoint?.siteMap)

        #expect(siteMap.markers.isEmpty)
    }

    @Test func thePlanOpensAndClosesWithoutChangingTheStage() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)

        harness.model.presentSiteMap()
        #expect(harness.model.isPresentingSiteMap)
        // A cover, not a stage: the walker glances at the plan and comes back to the same task, so
        // backing out of it must not be ambiguous with backing out of the task.
        #expect(harness.model.stage == .taskDetail(taskID: task.id))

        harness.model.dismissSiteMap()
        #expect(!harness.model.isPresentingSiteMap)
        #expect(harness.model.stage == .taskDetail(taskID: task.id))
    }

    /// Four of the five stops are a temple wall, a market floor, a road junction and a museum, and
    /// none ships a plan. The hint that opens this screen hides itself in that case; the model refuses
    /// to open it either way, so a stale binding cannot present an empty document.
    @Test func aCheckpointWithNoPlanCannotOpenOne() throws {
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        // The second stop — Pura Maospahit, which ships no plan.
        let checkpoint = try #require(quest.orderedCheckpoints.first { $0.orderIndex == 1 })
        let place = try #require(try repository.place(id: checkpoint.placeId))
        #expect(place.siteMap == nil, "this test's premise: the second stop ships no plan")

        let harness = try atTaskList()
        harness.model.advanceFromCheckpointDetail()
        harness.model.advance()
        harness.provider.emit(offsetMetres: 5, accuracy: 10)
        for _ in 0..<12 where harness.model.stage != .checkpointDetail {
            if harness.model.isPresentingQuestAvailability {
                harness.model.advanceFromQuestAvailability()
                continue
            }
            switch harness.model.stage {
            case .locationVerified: harness.model.advanceFromLocationVerified()
            case .arrivalNotice: harness.model.advanceFromArrivalNotice()
            case .storyReveal: harness.model.advanceFromStoryReveal()
            case .transition: harness.model.advanceFromTransition()
            case .placeNotice: harness.model.advanceFromPlaceNotice()
            case .taskDetail: harness.model.advanceFromTaskDetail()
            default: break
            }
        }

        #expect(harness.model.checkpoint?.siteMap == nil)
        harness.model.presentSiteMap()
        #expect(!harness.model.isPresentingSiteMap)
    }

    // MARK: - The sheet writes the result itself

    /// The sheet is the first screen of a checkpoint's task half, so it has to be able to finish what
    /// it opens: saving writes a `TaskResult` and hands over to the story behind that task
    /// (`1:4711` → `1:4609`). It writes through the same `saveTask` the checkpoint screen's
    /// `TaskCard` writes through — two ways in, one writer.
    @Test func savingOnTheSheetWritesTheResultAndOpensTheStory() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)
        let written = answer(task, on: harness, words: "Empat wajah menghadap empat arah.")

        harness.model.saveTaskFromDetail(task)

        #expect(harness.model.stage == .questExplanation(taskID: task.id))
        let resolution = try #require(harness.model.resolution(for: task))
        #expect(resolution.skipped == false)
        #expect(resolution.text == written)
        if task.type == .photo { #expect(resolution.photoRelativePath != nil) }
    }

    /// `FR-TASK-02` and `AD-2` — the skip is offered on the same screen and resolves the task just
    /// as saving does. Where it goes is the owner's rule of 2026-08-26 and the one thing that is
    /// *not* the same as saving: the story and the stamp are what doing a task buys, so a skip is
    /// returned to the checkpoint's task list rather than shown a plate and a franking. `AD-2` is
    /// untouched — the task is resolved, nothing is gated, and the walk can leave the checkpoint.
    @Test func skippingOnTheSheetResolvesTheTaskAndReturnsToTheTaskList() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)

        harness.model.skipTaskFromDetail(task)

        #expect(harness.model.stage == .checkpointDetail)
        #expect(harness.model.resolution(for: task)?.skipped == true)
    }

    /// The blank-field fallback goes where the skip goes, not where an answer goes. `saveTask`
    /// records an empty draft as a skip (`AD-2`), and a walker who tapped Save on an empty sheet
    /// did the same thing as one who tapped Skip — showing one of them a stamp would make the two
    /// controls mean different things for no reason the walker could see.
    @Test func savingAnEmptySheetIsASkipAndLandsWhereASkipLands() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)
        // Nothing supplied by either mechanic — no words, no photograph. Written by the task's own
        // kind rather than by assuming one: the start checkpoint's three tasks are all photographs
        // since `2026.09.14`, and a written draft on a photo task is a skip for a different reason
        // than the one under test.
        harness.model.taskDrafts[task.id] = "   "

        harness.model.saveTaskFromDetail(task)

        #expect(harness.model.stage == .checkpointDetail)
        #expect(harness.model.resolution(for: task)?.skipped == true)
    }

    // MARK: - The story behind a task, and the stamp — `1:4609` → `1:4641`

    /// `1:4613` → `1:4641` → `1:4654`. The three screens are a chain and the last of them is what
    /// finally reaches the menu the sheet used to reach directly.
    @Test func theStoryHandsOverToTheStampAndTheStampBackToTheMenu() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)
        answer(task, on: harness, words: "Sebuah jawaban.")
        harness.model.saveTaskFromDetail(task)

        harness.model.advanceFromQuestExplanation()
        #expect(harness.model.stage == .stampAward(taskID: task.id))

        harness.model.stampAwardMoreQuests()
        #expect(harness.model.stage == .checkpointDetail)
    }

    /// `15:2798` — the stamp's other action is the same exit the menu's own is, so a checkpoint has
    /// one way off it and two controls that reach it.
    @Test func theStampsOtherActionLeavesTheCheckpointJustAsTheMenuDoes() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)
        answer(task, on: harness, words: "Sebuah jawaban.")
        harness.model.saveTaskFromDetail(task)
        harness.model.advanceFromQuestExplanation()

        harness.model.stampAwardNextLocation()

        #expect(harness.model.stage == .atCheckpoint)
    }

    /// Backing out of either new screen returns to the one before it rather than out of the walk —
    /// the rule every other story stage follows.
    @Test func backingOutOfTheStoryAndTheStampWalksTheChainInReverse() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)
        answer(task, on: harness, words: "Sebuah jawaban.")
        harness.model.saveTaskFromDetail(task)
        harness.model.advanceFromQuestExplanation()

        harness.model.retreatFromStoryStage()
        #expect(harness.model.stage == .questExplanation(taskID: task.id))

        harness.model.retreatFromStoryStage()
        #expect(harness.model.stage == .taskDetail(taskID: task.id))
    }

    /// `.atCheckpoint` draws the same "All Quest" screen as `.checkpointDetail`, and a *resumed*
    /// walk opens on it — which is why its back arrow now leaves the run screen entirely. Reached
    /// mid-walk from the stamp it is not the walk's root, so it must still step back into the walk.
    @Test func theMenuReachedFromTheStampStepsBackToTheStampRatherThanLeavingTheWalk() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)
        answer(task, on: harness, words: "Sebuah jawaban.")
        harness.model.saveTaskFromDetail(task)
        harness.model.advanceFromQuestExplanation()
        harness.model.stampAwardNextLocation()
        #expect(harness.model.stage == .atCheckpoint)
        #expect(!harness.model.backLeavesTheRun)

        harness.model.retreatFromStoryStage()

        #expect(harness.model.stage == .stampAward(taskID: task.id))
    }

    /// `1:4609` prints the Place's own passage from `QuestExplanationText` — the owner's copy of
    /// 2026-08-26, one per Place, shared by that checkpoint's tasks until each has its own topic.
    /// The lead is that Place's own hook rather than the generic "Let me tell you something…".
    @Test func theStoryScreenCarriesThePlacesOwnPassage() throws {
        let harness = try atTaskList()

        let passage = try #require(harness.model.explanationPassage)

        #expect(passage.contains("pecut"))
        #expect(harness.model.explanationLead
            == QuestExplanationText.puriAgungPemecutan.lead.value(for: .id))
        #expect(harness.model.explanationLead
            != UIStrings.string(.questExplanationLead, .id))
    }

    /// Every shipped Place carries both languages. `LocalizedText`'s no-fallback rule reaches this
    /// table too: an Indonesian walker handed an English passage is the mixed-language page
    /// `NFR-I18N-03` exists to prevent, arriving through a door content validation cannot see.
    @Test func everyPlaceInTheTableCarriesBothLanguages() {
        #expect(!QuestExplanationText.byPlaceID.isEmpty)
        for (_, text) in QuestExplanationText.byPlaceID {
            #expect(!text.lead.id.isEmpty)
            #expect(!text.lead.en.isEmpty)
            #expect(!text.body.id.isEmpty)
            #expect(!text.body.en.isEmpty)
        }
    }

    /// The fallback path is still there and still sourced. A Place the table does not name gets the
    /// cited `loreStandalone` with its accuracy label — which is what a sixth authored place gets,
    /// and the reason the citation rendering was kept rather than deleted (`FR-CP-05`).
    @Test func thePlacesCitedLoreIsStillWhatAnUnnamedPlaceWouldPrint() throws {
        let harness = try atTaskList()

        let claims = harness.model.explanationClaims

        #expect(!claims.isEmpty)
        #expect(claims.allSatisfy { !$0.block.text.isEmpty })
        #expect(claims.allSatisfy { !$0.block.accuracyLabel.isEmpty })
        #expect(claims.contains { !$0.citations.isEmpty })
    }

    /// `1:4654`'s count is this checkpoint's still-open tasks, so answering the last one empties it
    /// and the control goes rather than offering nothing. A skip does not move it — see
    /// `aSkippedTaskStaysInTheRemainingCount`.
    @Test func theStampsMoreQuestsCountFallsAsTasksAreAnswered() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        let before = harness.model.unresolvedTaskCount

        harness.model.openTaskDetail(taskID: task.id)
        answer(task, on: harness, words: "Sebuah jawaban.")
        harness.model.saveTaskFromDetail(task)

        #expect(harness.model.unresolvedTaskCount == before - 1)
    }

    /// The menu's own action still leaves the checkpoint for the walk to the next place.
    /// The menu's own action still leaves the checkpoint for the walk to the next place — but,
    /// since `197:148` replaced `452:3194`'s single button, it does so directly (`advance()`)
    /// rather than by way of `.atCheckpoint`'s own advance button. `AD-2`: nothing here gates
    /// progression, so this is not a shorter path through a requirement, only through a screen.
    @Test func theMenuContinuesIntoTheWalkToTheNextPlace() throws {
        let harness = try atTaskList()
        let startIndex = harness.model.currentIndex

        harness.model.advanceFromCheckpointDetail()

        #expect(harness.model.stage == .awaitingArrival)
        #expect(harness.model.currentIndex == startIndex + 1)
    }

    /// `1:4647`'s window. The drawing is picked from the walker's *finished* walks, and on a first
    /// walk there are none — so the resolver has to be handed this walk too, or its quest is in no
    /// stamp → place table at all and the window comes back empty. An empty window is the honest
    /// state for a place the design never drew; Puri Agung Pemecutan is not one of those.
    @Test func theStampScreenFranksThePlacesDrawingOnAFirstWalk() throws {
        let harness = try atTaskList()

        #expect(harness.model.stampArtworkName == "pemecutan-stamp1")
    }

    /// The caption counts this walk's checkpoints rather than the awards array — that array also holds
    /// the badge at the final stop (`FR-DONE-02`), and counting it would print the wrong total.
    @Test func theStampCaptionCountsCheckpointsRatherThanAwards() throws {
        let harness = try atTaskList()

        #expect(harness.model.stampNumber == 1)
        #expect(harness.model.stampTotal == harness.quest.checkpoints.count)
    }

    // MARK: - The camera — `1:4681`

    /// Two things have to be true before the camera is offered: hardware to take the picture, and
    /// somewhere to write it. Missing either turns `447:1900`'s pill into the note that says so —
    /// the task is still resolvable by skipping, because `AD-2` means it gates nothing.
    @Test func theCameraIsOfferedOnlyWithBothHardwareAndSomewhereToWrite() throws {
        #expect(try model(hasCamera: true, store: InMemoryPhotoStore()).isCameraAvailable)
        #expect(try !model(hasCamera: false, store: InMemoryPhotoStore()).isCameraAvailable)
        #expect(try !model(hasCamera: true, store: nil).isCameraAvailable)
    }

    /// The camera is a cover over the task sheet, not a stage — so it opens from that sheet and from
    /// nowhere else. Asked for anywhere in the story flow it does nothing, rather than covering a
    /// screen it cannot return to.
    @Test func theCameraOpensFromTheTaskSheetAndNowhereElse() throws {
        let harness = try atTaskList()
        harness.model.presentCamera()
        #expect(!harness.model.isPresentingCamera)
    }

    /// A model at the start of the walk, built with the camera's two dependencies set explicitly.
    private func model(hasCamera: Bool, store: (any PhotoStore)?) throws -> QuestRunViewModel {
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        return try #require(QuestRunViewModel(
            engine: RunEngine(repository: repository, store: InMemoryRunStore()),
            repository: repository,
            preferences: InMemoryAppPreferencesStore(safetyNoticeAckedQuestIDs: [quest.id]),
            locationProvider: FakeLocationProvider(authorization: .whenInUse),
            questID: quest.id,
            language: .id,
            photoStore: store,
            hasCameraHardware: hasCamera))
    }

    /// The only photo task the content ships, and the Place it is at. `FR-TASK-06` drops a photo task
    /// where photography is prohibited, so if that Place's policy is ever corrected to `prohibited`
    /// the task disappears from the list and the sheet is never reachable — which is the rule working,
    /// and this is what would say so.
    @Test func theOnePhotoTaskIsStillOfferedAtItsPlace() throws {
        let repository = try BundledContentRepository()
        let quest = try #require(try repository.quests().first)
        let photoCheckpoint = try #require(
            quest.orderedCheckpoints.first { $0.tasks.contains { $0.type == .photo } })
        let place = try #require(try repository.place(id: photoCheckpoint.placeId))

        #expect(place.photoPolicy.level != .prohibited,
                "a photo task at a prohibited Place must not be authored (V9)")
    }

    // MARK: - The stamp in the progress bar (`452:3142`)

    /// The walker's own report: two of this place's quests resolved by tapping "skip" — the row's
    /// own checkmark ("cuz we dont have checking system"), and the stamp above the progress bar
    /// still showed the first drawing.
    ///
    /// Three things were wrong and all three are fixed here. The bar's stamp was filled with the
    /// *quest's hero image*, so it could never move at all; the tier was counted from walks
    /// finished across the whole history rather than from the work done at this place; and the bar
    /// could not move at all. `stampArtworkName` is what the bar draws now, and it climbs a drawing
    /// per **answered** task while the walker stands there.
    ///
    /// The skip half of that report was fixed twice, in opposite directions. It was first made to
    /// count like an answer, on the grounds that the row's checkmark drew the same either way; on
    /// 2026-08-26 the owner's rule inverted, and the checkmark went with it — see
    /// `skippingAQuestLeavesTheStampWhereItWas`.
    @Test func theStampClimbsADrawingPerQuestResolvedAtThisPlace() throws {
        let harness = try atTaskList()
        let tasks = try #require(harness.model.checkpoint?.tasks)
        try #require(tasks.count >= 3)

        #expect(harness.model.stampArtworkName == "pemecutan-stamp1")

        for (index, expected) in [(0, "pemecutan-stamp1"), (1, "pemecutan-stamp2"),
                                  (2, "pemecutan-stamp3")] {
            answer(tasks[index], on: harness, words: "Sebuah jawaban.")
            harness.model.saveTask(tasks[index])
            #expect(harness.model.stampArtworkName == expected,
                    "After \(index + 1) resolved task(s)")
        }
    }

    /// **A skip does not move the stamp**, as of 2026-08-26 — the inversion of what this test
    /// asserted earlier the same day. The drawing is what doing a quest buys, and a walker who
    /// skips their way through a place stays on the first plate. The row in front of them agrees:
    /// a skipped task draws no checkmark and fills no segment either, which is what the earlier
    /// rule was protecting and what makes this consistent rather than merely stricter.
    ///
    /// `AD-2` still holds — no answer key is needed to tell a skip from an answer, because
    /// `TaskResult.skipped` records the walker's own choice rather than a judgement of their words.
    @Test func skippingAQuestLeavesTheStampWhereItWas() throws {
        let harness = try atTaskList()
        let tasks = try #require(harness.model.checkpoint?.tasks)
        try #require(tasks.count >= 3)

        harness.model.skipTask(tasks[0])
        #expect(harness.model.stampArtworkName == "pemecutan-stamp1")

        harness.model.skipTask(tasks[1])
        #expect(harness.model.stampArtworkName == "pemecutan-stamp1")

        answer(tasks[2], on: harness, words: "Sebuah jawaban.")
        harness.model.saveTask(tasks[2])
        #expect(harness.model.stampArtworkName == "pemecutan-stamp1",
                "one answer among two skips is one answer — the first drawing")
    }

    /// The corner stamp on this screen previews the *next* drawing rather than recording the one
    /// already earned: none resolved shows the first as something to work towards, one resolved
    /// shows the second — "the stamp the user will get if they do next quest" — and two resolved
    /// shows the third. `stampArtworkName` (the award screen, the Journal) stays one tier behind
    /// this the whole way, which is the split the two tests above and these two guard between them.
    @Test func theCornerStampPreviewsOneTierAheadOfWhatIsActuallyEarned() throws {
        let harness = try atTaskList()
        let tasks = try #require(harness.model.checkpoint?.tasks)
        try #require(tasks.count >= 3)

        #expect(harness.model.progressStampArtworkName == "pemecutan-stamp1")
        #expect(harness.model.stampArtworkName == "pemecutan-stamp1")

        answer(tasks[0], on: harness, words: "Sebuah jawaban.")
        harness.model.saveTask(tasks[0])
        #expect(harness.model.progressStampArtworkName == "pemecutan-stamp2")
        #expect(harness.model.stampArtworkName == "pemecutan-stamp1")

        answer(tasks[1], on: harness, words: "Sebuah jawaban.")
        harness.model.saveTask(tasks[1])
        #expect(harness.model.progressStampArtworkName == "pemecutan-stamp3")
        #expect(harness.model.stampArtworkName == "pemecutan-stamp2")
    }

    /// Once every task at a place is answered there is no further drawing to tease, so the preview
    /// stops one tier ahead exactly where the record does — both read the third drawing.
    @Test func theCornerStampStopsPreviewingOnceThePlaceIsFullyAnswered() throws {
        let harness = try atTaskList()
        let tasks = try #require(harness.model.checkpoint?.tasks)
        try #require(tasks.count == 3)

        for task in tasks {
            answer(task, on: harness, words: "Sebuah jawaban.")
            harness.model.saveTask(task)
        }

        #expect(harness.model.stampArtworkName == "pemecutan-stamp3")
        #expect(harness.model.progressStampArtworkName == "pemecutan-stamp3")
    }

    /// Skipping every task at a place leaves both readings where they started. The preview is still
    /// one tier ahead of the record — it is teasing the drawing the *first* answer would buy, which
    /// is the reason the corner previews at all.
    @Test func skippingEveryTaskLeavesBothTheRecordAndThePreviewWhereTheyBegan() throws {
        let harness = try atTaskList()
        let tasks = try #require(harness.model.checkpoint?.tasks)
        try #require(tasks.count == 3)

        for task in tasks { harness.model.skipTask(task) }

        #expect(harness.model.stampArtworkName == "pemecutan-stamp1")
        #expect(harness.model.progressStampArtworkName == "pemecutan-stamp2")
    }
}
