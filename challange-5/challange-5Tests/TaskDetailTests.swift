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
        for _ in 0..<9 where model.stage != .checkpointDetail {
            switch model.stage {
            case .locationVerified: model.advanceFromLocationVerified()
            case .cutsceneIntro: model.advanceFromCutsceneIntro()
            case .cutscenePortrait: model.advanceFromCutscenePortrait()
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

    /// The same walk, stopped at the sacred-Place notice — `1:4592`, the screen before the first
    /// task. `atTaskList` walks straight past it.
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

        for _ in 0..<8 where model.stage != .placeNotice {
            switch model.stage {
            case .locationVerified: model.advanceFromLocationVerified()
            case .cutsceneIntro: model.advanceFromCutsceneIntro()
            case .cutscenePortrait: model.advanceFromCutscenePortrait()
            case .storyReveal: model.advanceFromStoryReveal()
            case .transition: model.advanceFromTransition()
            default: break
            }
        }
        try #require(model.stage == .placeNotice,
                     "the first stop is a sacred Place, so the notice is on the path")
        return Harness(model: model, provider: provider, quest: quest)
    }

    // MARK: - `1:4592` → `1:4711` → `1:4904`

    /// The flow the board draws: the place notice hands over to the checkpoint's **first** task, not
    /// to the task menu. The menu is what the walker reaches after resolving it.
    @Test func thePlaceNoticeOpensTheFirstTaskRatherThanTheMenu() throws {
        let harness = try atPlaceNotice()
        let first = try #require(harness.model.checkpoint?.tasks.first)

        harness.model.advanceFromPlaceNotice()

        #expect(harness.model.stage == .taskDetail(taskID: first.id))
        #expect(harness.model.firstTask?.id == first.id)
    }

    /// Backing out of the first task returns to the notice it was opened from — not to the menu,
    /// which the walker has not seen yet. The same sheet opened from a row backs out to the menu;
    /// that is what `stageBeforeTaskDetail` is for.
    @Test func backingOutOfTheFirstTaskReturnsToTheNoticeItCameFrom() throws {
        let harness = try atPlaceNotice()
        harness.model.advanceFromPlaceNotice()

        harness.model.retreatFromStoryStage()

        #expect(harness.model.stage == .placeNotice)
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
        for _ in 0..<9 where harness.model.stage != .checkpointDetail {
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
    /// it opens: saving writes a `TaskResult` and lands on the menu (`1:4711` → `1:4904`). It writes
    /// through the same `saveTask` the checkpoint screen's `TaskCard` writes through — two ways in,
    /// one writer.
    @Test func savingOnTheSheetWritesTheResultAndLandsOnTheMenu() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)
        harness.model.taskDrafts[task.id] = "Empat wajah menghadap empat arah."

        harness.model.saveTaskFromDetail(task)

        #expect(harness.model.stage == .checkpointDetail)
        let resolution = try #require(harness.model.resolution(for: task))
        #expect(resolution.skipped == false)
        #expect(resolution.text == "Empat wajah menghadap empat arah.")
    }

    /// `FR-TASK-02` and `AD-2` — the skip is offered on the same screen, resolves the task just as
    /// saving does, and reaches the same place. A walk that could not leave this sheet without
    /// answering would be a task gating progression.
    @Test func skippingOnTheSheetResolvesTheTaskAndLandsOnTheMenu() throws {
        let harness = try atTaskList()
        let task = try #require(harness.model.checkpoint?.tasks.first)
        harness.model.openTaskDetail(taskID: task.id)

        harness.model.skipTaskFromDetail(task)

        #expect(harness.model.stage == .checkpointDetail)
        #expect(harness.model.resolution(for: task)?.skipped == true)
    }

    /// The menu's own action still leaves the checkpoint for the walk to the next place.
    @Test func theMenuContinuesIntoTheCheckpointScreen() throws {
        let harness = try atTaskList()

        harness.model.advanceFromCheckpointDetail()

        #expect(harness.model.stage == .atCheckpoint)
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
