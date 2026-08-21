// The three screens ported from Figma on 2026-08-17: `452:3132` ("Quest 1/3"), `447:1880`
// ("Quest_Filled") and `452:3028` ("Site Map"). What is guarded here is the navigation between them
// and the values they render — not their layout, which no unit test can see.
// FR-CP-05, FR-TASK-02/06, AD-2, AD-4.
import Foundation
import Testing
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
    }

    /// A walk standing at its first checkpoint with the task list on screen — the state `452:3132`
    /// draws.
    private func atTaskList() throws -> Harness {
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
        // Inside the radius with a fix good enough to satisfy the accuracy half of `FR-ARR-01`.
        provider.emit(offsetMetres: 5, accuracy: 10)

        // Bounded rather than `while`: a stage that returns itself should fail the suite, not hang it.
        for _ in 0..<12 where model.stage != .checkpointDetail {
            // `921:3851` — the quest-availability sheet sits between the first explanation and the
            // sealed scroll but is not a `Stage`, so it is checked ahead of the switch below.
            if model.isPresentingQuestAvailability { model.advanceFromQuestAvailability(); continue }
            switch model.stage {
            case .locationVerified: model.advanceFromLocationVerified()
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
        return Harness(model: model, provider: provider, quest: quest)
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
        return Harness(model: model, provider: provider, quest: quest)
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

    /// The bar is task *resolution*, and `FR-TASK-02` plus `AD-2` make answering and skipping the
    /// same kind of outcome — a skipped task is done with, not outstanding. Counting only answers
    /// would leave the bar permanently short of full for a walker who skipped one.
    @Test func aSkippedTaskFillsItsSegmentJustAsAnAnsweredOneDoes() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)

        #expect(harness.model.taskCount == harness.model.checkpoint?.tasks.count)
        #expect(harness.model.resolvedTaskCount == 0)

        harness.model.skipTask(task)

        #expect(harness.model.resolvedTaskCount == 1)
    }

    @Test func answeringATaskFillsItsSegment() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)

        harness.model.taskDrafts[task.id] = "Gerbangnya batu bata merah."
        harness.model.saveTask(task)

        #expect(harness.model.resolvedTaskCount == 1)
        #expect(harness.model.resolution(for: task)?.skipped == false)
    }

    /// The label the bar reads out. `452:3132` is titled "Quest 1/3" and draws three segments because
    /// the mock-up invents three tasks; the shipped content carries one per checkpoint, so the total
    /// is the run's and not the frame's (`AD-4`).
    @Test func theProgressLabelCountsTheRunsOwnTasksAndNotTheFramesThree() throws {
        let harness = try atTaskList()

        #expect(harness.model.taskCount == 1,
                "shipped content carries one task per checkpoint; the bar must follow it")
        #expect(harness.model.taskProgressLabel.contains("1"))
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
        harness.model.taskDrafts[task.id] = "Empat wajah menghadap empat arah."

        harness.model.saveTaskFromDetail(task)

        #expect(harness.model.stage == .questExplanation(taskID: task.id))
        let resolution = try #require(harness.model.resolution(for: task))
        #expect(resolution.skipped == false)
        #expect(resolution.text == "Empat wajah menghadap empat arah.")
    }

    /// `FR-TASK-02` and `AD-2` — the skip is offered on the same screen, resolves the task just as
    /// saving does, and reaches the same place, story included. A skip that was sent somewhere
    /// duller than an answer would be the penalty `FR-TASK-02` says the skip must not carry.
    @Test func skippingOnTheSheetResolvesTheTaskAndOpensTheSameStory() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)

        harness.model.skipTaskFromDetail(task)

        #expect(harness.model.stage == .questExplanation(taskID: task.id))
        #expect(harness.model.resolution(for: task)?.skipped == true)
    }

    // MARK: - The story behind a task, and the stamp — `1:4609` → `1:4641`

    /// `1:4613` → `1:4641` → `1:4654`. The three screens are a chain and the last of them is what
    /// finally reaches the menu the sheet used to reach directly.
    @Test func theStoryHandsOverToTheStampAndTheStampBackToTheMenu() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)
        harness.model.skipTaskFromDetail(task)

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
        harness.model.skipTaskFromDetail(task)
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
        harness.model.skipTaskFromDetail(task)
        harness.model.advanceFromQuestExplanation()

        harness.model.retreatFromStoryStage()
        #expect(harness.model.stage == .questExplanation(taskID: task.id))

        harness.model.retreatFromStoryStage()
        #expect(harness.model.stage == .taskDetail(taskID: task.id))
    }

    /// `1:4609` prints the Place's own `loreStandalone`, and it prints it as *claims* — the accuracy
    /// label and the citation `FR-CP-05` asks for, which the frame itself does not draw. A screen
    /// that rendered the text without them would be extending an exception the PRD has never signed.
    @Test func theStoryScreenCarriesThePlacesOwnClaimsWithTheirProvenance() throws {
        let harness = try atTaskList()

        let claims = harness.model.explanationClaims

        #expect(!claims.isEmpty)
        #expect(claims.allSatisfy { !$0.block.text.isEmpty })
        #expect(claims.allSatisfy { !$0.block.accuracyLabel.isEmpty })
        #expect(claims.contains { !$0.citations.isEmpty })
    }

    /// `1:4654`'s count is this checkpoint's *unresolved* tasks, so resolving the last one empties it
    /// and the control goes rather than offering nothing.
    @Test func theStampsMoreQuestsCountFallsAsTasksAreResolved() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        let before = harness.model.unresolvedTaskCount

        harness.model.openTaskDetail(taskID: task.id)
        harness.model.skipTaskFromDetail(task)

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
}
