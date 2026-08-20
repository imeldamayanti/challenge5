import AVFoundation
import ContentKit
import DesignSystem
import Foundation
import RunEngine
import UIKit
import UIStringsKit

@MainActor
@Observable
final class QuestRunViewModel {

    enum Stage: Equatable {
        /// `81:588` — the hook, typed out, with the walk's distance and duration under it. The
        /// board opens the flow here, before the arrival gate.
        case storyPreview
        case awaitingArrival
        /// `1:4458` ("Location Verified" on the New Hisplora board) — the fix landed, inside the
        /// radius and precise enough, and the walk says so on its own screen before the story
        /// starts. `LocationState.verified` was drawn before this stage existed, but only ever in
        /// passing: `record` recorded the arrival and moved straight to the cutscene, so the state
        /// was reachable for a frame and no walker saw it.
        case locationVerified
        /// The Hisplora cutscene — the quest's hook and a framed image, shown once at the first
        /// arrival of a walk. A presentation of `hookLore`, not a new content type: see
        /// `CutsceneScreens.swift`.
        case cutsceneIntro
        case cutscenePortrait
        /// `187:1103` — the approach map on the open scroll, with a dot beating over the place the
        /// cutscene has just finished pointing at.
        ///
        /// **It sits after the cutscene and nowhere else.** The cutscene is the once-per-walk
        /// introduction, and this is the sentence that lands it somewhere: *that story starts here,
        /// and here is where here is*. Every later checkpoint reaches its story from an arrival the
        /// walker made on purpose, and already has `locationVerified`'s map for the same job.
        ///
        /// **It has no control and moves itself on** (`ApproachTransitionScreen`). That is what the
        /// frame draws, and it is why the back chevron matters: a screen that leaves on its own must
        /// still be leavable on purpose.
        case approachTransition
        /// The lore reveal — one passage, joined from every `LoreBlock` at the checkpoint.
        case storyReveal
        /// `1:4592` ("Quest" on the New Hisplora board, `50:137` before it) — the sacred-Place
        /// notice, reached straight from the story reveal, before the sealed-scroll transition.
        /// Only reached when `checkpoint.isSacred`; every other checkpoint's story goes straight
        /// to the transition. Deliberately reordered ahead of `transition` — the board drew it the
        /// other way round.
        case placeNotice
        /// `1:4904` ("All Quest", `452:3132` before it) — every task at this checkpoint, with the
        /// ones already resolved sealed. Reached *after* the checkpoint's first task
        /// (`1:4711`), not before it.
        case checkpointDetail
        /// `1:4711` ("Quest_Filled", `447:1880` before it) — one task on its own parchment sheet,
        /// with its answer field, its save and its skip.
        ///
        /// Two ways in: the checkpoint's **first** task opens automatically from the sealed-scroll
        /// `transition` (`1:4586`), before the menu exists to be tapped, and every other visit comes
        /// from a row on `checkpointDetail`. `stageBeforeTaskDetail` remembers which, so backing out
        /// returns where the walker came from.
        ///
        /// It carries the task id rather than an index: the presentation's `tasks` are already
        /// filtered (`FR-TASK-06` drops a photo task at a Place where photography is prohibited), so
        /// an index into the list would point at a different task depending on the Place.
        case taskDetail(taskID: String)
        /// `1:4609` ("Explanation per Quest") — the story behind the task just resolved, on the
        /// ornate plate, reached from `taskDetail` whichever way that task was resolved.
        ///
        /// **Reached on a skip as well as on an answer, deliberately.** `AD-2` and `FR-TASK-02` make
        /// the two resolutions the same kind of outcome; withholding the story from a walker who
        /// skipped would turn "offered without apology" into a penalty. It carries the task id for
        /// the same reason `taskDetail` does — the presentation's task list is filtered
        /// (`FR-TASK-06`), so an index would name a different task at a different Place.
        case questExplanation(taskID: String)
        /// `1:4641` ("Quest") — the checkpoint's stamp, shown after the story.
        ///
        /// **Presented here, awarded on arrival.** `FR-CP-07` grants the stamp in
        /// `RunEngine.applyArrival`, before any task exists; this stage writes nothing and only shows
        /// the walker what they are already holding.
        case stampAward(taskID: String)
        /// `1:4586` ("Transition") — the sealed scroll between the story and the walk. It closes
        /// the reveal and opens the checkpoint's own screens, so it sits after `storyReveal` and
        /// `placeNotice`, immediately before the checkpoint's first task — never after the task
        /// menu.
        case transition
        case atCheckpoint
        case finished
    }

    /// The gate's own states, which now live on `ArrivalSampling` — the sidequest flow waits at the
    /// same gate (`FR-SIDE-02`), and one rule with two implementations is two rules.
    typealias ArrivalStatus = ArrivalSampling.Status

    // MARK: Inputs

    private let engine: RunEngine
    private let repository: any ContentRepository
    private let preferences: any AppPreferencesStore
    /// Where a photo task's photograph is written (`1:4827`). Optional because a Run does not need
    /// one to be walked: with no store the camera is simply not offered, and every photo task is
    /// still resolvable by skipping (`AD-2`).
    private let photoStore: (any PhotoStore)?
    /// Whether this device has a camera at all. Injected rather than read here so the rule is a value
    /// a test can set — the Simulator has none, and a screen that offers a control the hardware
    /// cannot honour is worse on a walk than one that says so.
    private let hasCameraHardware: Bool
    /// `FR-ARR-01`…`FR-ARR-05`, `FR-START-10`, `NFR-BAT-04`, extracted so this view model and
    /// `SideQuestFlowViewModel` cannot drift apart about what arrival means.
    let sampling: ArrivalSampling
    /// Set when the user chose "start over" in preview. The draft is not deleted then and there —
    /// it is deleted when the replacement walk actually begins, so backing out of the arrival
    /// screen leaves the old walk exactly where it was.
    private let discardingExistingDraft: Bool

    let quest: Quest
    let language: ContentLanguage

    // MARK: Observable state

    private(set) var run: Run?
    private(set) var stage: Stage = .awaitingArrival
    /// The gate's state, forwarded. `@Observable` reads through the nested object, so a view
    /// watching `model.arrival` still redraws when the sampler moves.
    var arrival: ArrivalStatus { sampling.status }
    var manualOverrideAvailable: Bool { sampling.manualOverrideAvailable }
    var manualOverrideRemainingSeconds: Int? { sampling.manualOverrideRemainingSeconds }
    var manualOverrideProgress: Double { sampling.manualOverrideProgress }
    var searchingElapsedSeconds: Int { sampling.searchingElapsedSeconds }
    var isPresentingManualOverride: Bool { sampling.isPresentingManualOverride }
    /// The cutscene is shown once per walk, not once per checkpoint.
    private var hasShownCutscene = false
    /// What `locationVerified`'s Continue hands over to. Decided at arrival, while `currentIndex`
    /// still names the checkpoint just reached, rather than re-derived when the walker taps — the
    /// walk moves on between those two moments only if something else advances it, and a stored
    /// answer cannot disagree with the one the arrival took.
    private var stageAfterArrivalConfirmed: Stage = .storyReveal
    /// `FR-START-09` — the named presence confirmation, shown only at the start checkpoint.
    private(set) var isConfirmingPresence = false
    private(set) var isConfirmingAbandon = false
    private(set) var message: String?
    private(set) var checkpoint: CheckpointPresentation?
    /// Task answers being typed, keyed by task id. Not persisted until saved — `FR-RUN-01` is about
    /// completed actions, and a half-typed sentence is not one.
    var taskDrafts: [String: String] = [:]
    /// Photographs taken but not yet submitted, keyed by task id — the same argument as `taskDrafts`
    /// one type up. Held in memory rather than written on capture: `1:4852`'s cross discards the
    /// shot, and a file written at the shutter and discarded a second later is an orphan in the
    /// walker's Documents directory that nothing would ever collect. `PhotoStore` is called from
    /// `saveTask`, once.
    private var photoDrafts: [String: UIImage] = [:]
    /// Whether `1:4681` is over the task sheet. A cover rather than a stage, for the same reason the
    /// site plan is one: the camera is opened and dismissed back to the same task, and putting it in
    /// `Stage` would make backing out of it ambiguous with backing out of the task.
    private(set) var isPresentingCamera = false

    /// The authored walking line (`FR-MAP-02`). Read once at construction: it is content, so it
    /// cannot change under a walk in progress, and a nil here means the quest ships no geometry
    /// rather than that the map failed to load.
    private let routeGeometry: RouteGeometry?
    /// `FR-MAP-02` asks for the walker's position *relative to* the next checkpoint — a direction,
    /// which a scalar distance cannot express.
    var lastKnownCoordinate: Coordinate? { sampling.lastKnownCoordinate }

    // MARK: Init

    init?(
        engine: RunEngine,
        repository: any ContentRepository,
        preferences: any AppPreferencesStore,
        locationProvider: any LocationProviding,
        questID: String,
        language: ContentLanguage,
        existingRun: Run? = nil,
        discardingExistingDraft: Bool = false,
        manualOverrideDelay: Duration = .seconds(60),
        photoStore: (any PhotoStore)? = nil,
        // `AVCaptureDevice`, not `UIImagePickerController.isSourceTypeAvailable(.camera)`, and the
        // difference is visible: the Simulator answers `true` to the picker's question and has no
        // capture device, so the sheet offered a camera and the camera screen then had to explain
        // there was none. This is the same question `CameraSession.start()` asks, so the two screens
        // cannot disagree about whether a photograph is possible.
        hasCameraHardware: Bool = AVCaptureDevice.default(for: .video) != nil
    ) {
        guard let quest = (try? repository.quest(id: questID)) ?? nil else { return nil }
        self.engine = engine
        self.repository = repository
        self.preferences = preferences
        self.photoStore = photoStore
        self.hasCameraHardware = hasCameraHardware
        self.sampling = ArrivalSampling(
            locationProvider: locationProvider,
            language: language,
            manualOverrideDelay: manualOverrideDelay)
        self.quest = quest
        self.language = language
        self.run = existingRun
        self.discardingExistingDraft = discardingExistingDraft
        // A quest whose geometry is missing or unreadable still walks; it walks without a drawn
        // route. V18 is what stops that reaching a release.
        self.routeGeometry = (try? repository.routeGeometry(questID: questID)) ?? nil

        stage = Self.initialStage(run: existingRun)
        if stage == .atCheckpoint || stage == .finished {
            checkpoint = presentation(forOrderIndex: currentIndex)
        }

        sampling.onArrival = { [weak self] method, accuracyM in
            self?.record(method: method, accuracyM: accuracyM)
        }
        sampling.onAuthorizationDecided = { [weak self] _ in
            guard let self, self.isAwaitingFirstAuthorizationDecision else { return }
            self.isAwaitingFirstAuthorizationDecision = false
            self.finishBeginningArrival()
        }
    }

    private static func initialStage(run: Run?) -> Stage {
        if let run {
            // A walk already under way is past the hook. A resumed one never sees it again — it
            // is an opening, not a gate.
            switch run.state {
            case .completed, .abandoned: return .finished
            default: return run.hasArrivedAtCurrentCheckpoint ? .atCheckpoint : .awaitingArrival
            }
        }
        // A fresh walk opens on the hook, as the board does. A resumed one never sees it again —
        // it is an opening, not a gate.
        return .storyPreview
    }

    /// Leaving the hook straight for the arrival gate. Both notices that used to sit here —
    /// `FR-START-04`'s safety notice and `FR-START-02`'s location rationale — are gone by request;
    /// nothing precedes the system permission prompt any more.
    func advanceFromStoryPreview() {
        beginArrival()
    }

    // MARK: Derived

    var currentIndex: Int { run?.currentCheckpointIndex ?? 0 }

    var orderedCheckpoints: [Checkpoint] { quest.orderedCheckpoints }

    var currentCheckpoint: Checkpoint? {
        orderedCheckpoints.first { $0.orderIndex == currentIndex }
    }

    var reachedCount: Int { run?.reachedCount ?? 0 }

    var totalCheckpoints: Int { quest.checkpointCount }

    /// `FR-CP-08` — checkpoints reached out of total. Never a distance.
    var progressText: String {
        String(format: UIStrings.string(.checkpointProgress, language),
               reachedCount, totalCheckpoints)
    }

    var stepText: String {
        String(format: UIStrings.string(.arrivalStep, language),
               currentIndex + 1, totalCheckpoints)
    }

    var headingText: String {
        let name = placeName(for: currentCheckpoint)
        return String(format: UIStrings.string(.arrivalHeading, language), name)
    }

    /// `FR-CP-03` — the clue from the checkpoint just left, re-readable for as long as the walk to
    /// the next one lasts, without re-triggering anything.
    var clueToCurrentCheckpoint: String? {
        guard currentIndex > 0, let run else { return nil }
        return run.result(forOrderIndex: currentIndex - 1)?.snapshotClueToNext
    }

    var isAtStartCheckpoint: Bool { currentIndex == 0 && run == nil }

    /// `FR-MAP-02` — the ordered sequence, the walker's position relative to the next stop, and the
    /// straight-line distance remaining. Nil when the quest ships no readable geometry, in which
    /// case the arrival screen simply has no map rather than an empty frame where one should be.
    var routeMap: RunRoutePresentation? {
        guard let geometry = routeGeometry else { return nil }

        let stops = orderedCheckpoints.compactMap { checkpoint -> RunRouteStop? in
            guard let place = place(for: checkpoint) else { return nil }
            return RunRouteStop(
                orderIndex: checkpoint.orderIndex,
                coordinate: place.coordinate,
                isReached: run?.result(forOrderIndex: checkpoint.orderIndex) != nil,
                isTarget: checkpoint.orderIndex == currentIndex)
        }

        let targetPlace = place(for: currentCheckpoint)
        let distanceText = zip2(lastKnownCoordinate, targetPlace?.coordinate).map { user, target in
            ContentFormatter(language: language)
                .distance(metres: Int(Geo.distanceM(user, target).rounded()))
        }

        return RunRoutePresentation(
            // The stops are taken from the Places, not from the geometry file's own Point
            // features: the Place coordinate is what the arrival rule measures against, and a map
            // that disagrees with the gate is a map that sends someone to the wrong side of a wall.
            line: geometry.line,
            stops: stops,
            target: targetPlace?.coordinate,
            targetRadiusM: Double(targetPlace?.arrivalRadiusM ?? 0),
            userPosition: lastKnownCoordinate,
            distanceRemainingText: distanceText,
            targetName: placeName(for: currentCheckpoint))
    }

    private func zip2<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
        guard let a, let b else { return nil }
        return (a, b)
    }

    var presenceConfirmationTitle: String {
        String(format: UIStrings.string(.runStartConfirmTitle, language),
               placeName(for: currentCheckpoint))
    }

    // MARK: Preflight

    /// Set only while the very first system permission prompt is up, so
    /// `sampling.onAuthorizationDecided` knows this particular decision is the one it is waiting
    /// on and not, say, the walker later revoking access from Settings mid-walk.
    private var isAwaitingFirstAuthorizationDecision = false

    /// `FR-ONB-04` — permission is asked only once, in context. The screen stays put — whatever it
    /// already was — while the system prompt is up, rather than jumping to the arrival screen
    /// underneath it; `finishBeginningArrival()` is what actually moves on, either at once (below)
    /// or once `sampling.onAuthorizationDecided` reports the walker answered.
    private func beginArrival() {
        guard sampling.authorization == .notRequested else {
            finishBeginningArrival()
            return
        }
        isAwaitingFirstAuthorizationDecision = true
        sampling.requestWhenInUseAuthorization()
    }

    private func finishBeginningArrival() {
        stage = .awaitingArrival
        beginSampling()
    }

    // MARK: Sampling lifecycle — FR-ARR-02, NFR-BAT-04

    func screenAppeared() {
        guard stage == .awaitingArrival else { return }
        beginSampling()
    }

    /// Sampling stops when the arrival screen goes away — not when the app backgrounds, not when a
    /// timer decides. `NFR-BAT-04` is a hard requirement and `ArrivalSampling.stop` is the only
    /// place it is met.
    func screenDisappeared() {
        sampling.stop()
    }

    private func beginSampling() {
        guard let checkpoint = currentCheckpoint,
              let place = place(for: checkpoint) else { return }
        sampling.start(target: place.coordinate, radiusM: place.arrivalRadiusM)
    }

    // MARK: Arrival — FR-ARR-01

    /// `FR-ARR-03/04`, `FR-START-09/10`. At the start checkpoint this routes through the named
    /// confirmation first; everywhere else it is one tap and costs nothing.
    func useManualOverride() {
        if isAtStartCheckpoint {
            isConfirmingPresence = true
            return
        }
        sampling.arriveManually()
    }

    // MARK: The override sheet — FR-START-10, FR-ARR-04

    func presentManualOverride() { sampling.presentManualOverride() }

    func dismissManualOverride() { sampling.dismissManualOverride() }

    /// Confirming from inside the sheet. At the start checkpoint the named presence confirmation is
    /// still a separate step (`FR-START-09`) — the two are not collapsed into one, and the sheet
    /// does not become a second way to start a Run from outside the radius (`FR-START-08`), because
    /// it routes through exactly the same `useManualOverride` path everything else does.
    func confirmManualOverrideFromSheet() {
        sampling.dismissManualOverride()
        guard isAtStartCheckpoint else {
            sampling.arriveManually()
            return
        }
        // Presenting the confirmation in the same run loop as the sheet's dismissal loses it, so it
        // waits for the sheet to finish leaving.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            self?.isConfirmingPresence = true
        }
    }

    var manualOverrideCountdownText: String? { sampling.manualOverrideCountdownText }

    var searchingElapsedText: String { sampling.searchingElapsedText }

    func confirmPresence() {
        isConfirmingPresence = false
        sampling.arriveManually()
    }

    func cancelPresenceConfirmation() {
        isConfirmingPresence = false
    }


    private func record(method: ArrivalMethod, accuracyM: Double?) {
        guard let checkpoint = currentCheckpoint else { return }
        do {
            if let existing = run {
                run = try engine.recordArrival(
                    runID: existing.id, checkpointID: checkpoint.id,
                    method: method, accuracyM: accuracyM)
            } else if discardingExistingDraft {
                run = try engine.restart(
                    questID: quest.id, language: language,
                    method: method, accuracyM: accuracyM)
            } else {
                run = try engine.start(
                    questID: quest.id, language: language,
                    method: method, accuracyM: accuracyM)
            }
            arriveAtCurrentCheckpoint()
        } catch let error as RunEngineError {
            message = describe(error)
        } catch {
            message = String(describing: error)
        }
    }

    private func arriveAtCurrentCheckpoint() {
        sampling.finish()
        checkpoint = presentation(forOrderIndex: currentIndex)

        // The cutscene runs once per walk, at the first arrival — a repeat walker, and anyone
        // resuming a draft, goes straight to the story. After it comes the paged reveal, then the
        // transition, then the checkpoint itself.
        if !hasShownCutscene && currentIndex == 0 {
            hasShownCutscene = true
            stageAfterArrivalConfirmed = .cutsceneIntro
        } else {
            stageAfterArrivalConfirmed = .storyReveal
        }
        // `1:4458` — arrival is confirmed on its own screen before any of that.
        stage = .locationVerified

        if let run, let checkpoint {
            self.run = (try? engine.markLoreOpened(
                runID: run.id, checkpointID: checkpoint.id)) ?? run
        }
    }

    // MARK: The Hisplora story stages

    /// `1:4458`'s Continue — into the cutscene on the walk's first arrival, into the story reveal
    /// at every other checkpoint.
    func advanceFromLocationVerified() { stage = stageAfterArrivalConfirmed }

    func advanceFromCutsceneIntro() { stage = .cutscenePortrait }

    /// `187:866`'s "Start the Journey" — into `187:1103`, the map with the beating dot, rather
    /// than straight into the reveal. The cutscene names the story; this says where it starts.
    func advanceFromCutscenePortrait() { stage = .approachTransition }

    /// `187:1103` leaves on its own after `approachTransitionDuration`, and the screen is what runs
    /// the clock — a timer here would keep counting through a back-out and land the walker on the
    /// reveal from a screen they had already left.
    func advanceFromApproachTransition() {
        guard stage == .approachTransition else { return }
        stage = .storyReveal
    }

    /// How long `187:1103` holds before it moves itself on. Named rather than written at the call
    /// site so the screen and the guard that pins it read the same number.
    static let approachTransitionDuration: Duration = .seconds(5)

    /// A sacred Place explains itself before any task is offered (`FR-TASK-05`), straight off the
    /// story reveal; every other checkpoint goes straight to the sealed-scroll transition.
    /// Reordered ahead of `transition` at request — the New Hisplora board drew `1:4592` after
    /// `1:4586`.
    func advanceFromStoryReveal() {
        stage = (checkpoint?.isSacred ?? false) ? .placeNotice : .transition
    }

    /// `1:4592` → `1:4586`. The notice hands over to the sealed scroll, not to the first task
    /// directly — the scroll is what closes the story and opens the walk.
    func advanceFromPlaceNotice() { stage = .transition }

    /// The sealed scroll closes the story and opens the walk — `1:4856` → `1:4586` → `1:4711` on
    /// the New Hisplora board (place notice, when the Place is sacred, has already been shown).
    /// The transition is the seam between the two halves of a checkpoint, so it hands straight to
    /// the checkpoint's first task rather than the task menu.
    func advanceFromTransition() {
        stage = firstTaskStage(from: .transition)
    }

    /// The checkpoint's first task, in the order the content authors it — what the board reaches
    /// straight from `1:4586`, the sealed-scroll transition. A checkpoint whose task list is empty
    /// after `FR-TASK-06`'s filter has nothing to open, so the menu is what it shows.
    var firstTask: ContentTask? { checkpoint?.tasks.first }

    private func firstTaskStage(from origin: Stage) -> Stage {
        guard let first = firstTask else { return .checkpointDetail }
        stageBeforeTaskDetail = origin
        return .taskDetail(taskID: first.id)
    }

    func advanceFromCheckpointDetail() { stage = .atCheckpoint }

    /// Where `taskDetail` was entered from — `transition` for the checkpoint's first task,
    /// `checkpointDetail` for every task opened from the menu. Stored rather than derived:
    /// once the first task is resolved it is indistinguishable from any other row, so "which task
    /// is this" cannot answer "where did the walker come from".
    private var stageBeforeTaskDetail: Stage = .checkpointDetail

    /// Opening one task's own sheet from the menu (`1:4904` → `1:4711`).
    ///
    /// Guarded on the task actually being at this checkpoint. Not defensiveness: the presentation's
    /// task list is filtered by `FR-TASK-06`, and a stage holding an id nothing resolves would draw
    /// an empty sheet with a back button and no way to tell what went wrong.
    func openTaskDetail(taskID: String) {
        guard checkpoint?.tasks.contains(where: { $0.id == taskID }) == true else { return }
        stageBeforeTaskDetail = .checkpointDetail
        stage = .taskDetail(taskID: taskID)
    }

    /// Leaving the sheet forwards without resolving anything — an already-answered task being
    /// re-read. It lands on the menu, which is the checkpoint's hub:
    /// `checkpointDetailContinueToNext` is the one way out of it.
    func advanceFromTaskDetail() { stage = .checkpointDetail }

    /// Saving an answer from the sheet, then into the story behind it.
    ///
    /// `saveTask` falls back to a skip on an empty draft, so the walk never stalls on a sheet whose
    /// field was left blank — `AD-2` means a task gates nothing, and that has to stay true of the
    /// screen the walk now opens on.
    func saveTaskFromDetail(_ task: ContentTask) {
        saveTask(task)
        stage = .questExplanation(taskID: task.id)
    }

    /// `FR-TASK-02`'s skip, from the sheet. Same weight as saving and the same destination — the
    /// story follows a skip too, because withholding it would make the skip a penalty.
    func skipTaskFromDetail(_ task: ContentTask) {
        skipTask(task)
        stage = .questExplanation(taskID: task.id)
    }

    // MARK: The story behind a task — `1:4609` — and the stamp — `1:4641`

    /// `1:4613`'s tap.
    func advanceFromQuestExplanation() {
        guard case .questExplanation(let taskID) = stage else { return }
        stage = .stampAward(taskID: taskID)
    }

    /// `1:4654` — back to this checkpoint's task menu.
    func stampAwardMoreQuests() { stage = .checkpointDetail }

    /// `15:2798` — on towards the next place. The same exit `checkpointDetailContinueToNext` takes,
    /// so there is one way off a checkpoint and two controls that reach it.
    func stampAwardNextLocation() { stage = .atCheckpoint }

    /// The claims `1:4609` prints — the Place's own `loreStandalone`, with the accuracy label and the
    /// citations `FR-CP-05` asks for. Empty when the Place authors none, which the screen renders as
    /// the lead alone rather than as an error.
    var explanationClaims: [LoreClaimPresentation] { checkpoint?.standaloneClaims ?? [] }

    /// Which of this walk's stamps the checkpoint just reached franked, counting from one.
    ///
    /// From `orderIndex` rather than from `run.awards.count`: the awards array also holds the badge
    /// at the final checkpoint (`FR-DONE-02`), and counting it would print "5 of 5" one stop early.
    var stampNumber: Int { (checkpoint?.orderIndex ?? 0) + 1 }

    var stampTotal: Int { totalCheckpoints }

    /// `1:4654`'s count — how many tasks at this checkpoint are still unresolved. Zero hides the
    /// control rather than offering nothing.
    var unresolvedTaskCount: Int { taskCount - resolvedTaskCount }

    /// The drawing franked into `1:4647`, tiered by how many quests through this place the walker has
    /// *finished* (`HisploraStampArtwork`). A walk in progress has not finished, so a first-time
    /// walker sees the first drawing here and the same one in the Journal afterwards.
    ///
    /// **This walk is passed in alongside the finished ones, and it has to be.** The resolver builds
    /// its stamp → place table from the quests of the runs it is given, and counts visits only from
    /// the ones that are `.completed`. Handing it the finished runs alone means a first-time walker's
    /// quest is in no table at all, and the window comes back empty — which is the honest fallback for
    /// a place the design never drew, and the wrong answer for a place it did. Adding the active run
    /// contributes the mapping and no visits, and `HisploraStampArtwork.tier` floors at 1.
    var stampArtworkName: String? {
        guard let run, let stampID = orderedCheckpoints
            .first(where: { $0.orderIndex == currentIndex })?.stampId
        else { return nil }
        let finished = (try? engine.completedRuns()) ?? []
        return StampArtworkResolver(runs: finished + [run], repository: repository)
            .artworkName(questID: run.questID, stampSourceID: stampID)
    }

    // MARK: The camera — `1:4681`

    /// Whether the camera can be offered at all: a device with one, and somewhere to write what it
    /// takes. False turns `1:4827`'s pill into the note that says why (`AD-2` — the task is still
    /// resolvable either way).
    var isCameraAvailable: Bool { hasCameraHardware && photoStore != nil }

    func presentCamera() {
        guard isCameraAvailable, case .taskDetail = stage else { return }
        isPresentingCamera = true
    }

    func dismissCamera() { isPresentingCamera = false }

    /// The shutter's result. Held as a draft rather than written — `1:4852`'s cross discards it, and
    /// `saveTask` is the one place a file is ever created.
    func capturedPhoto(_ image: UIImage) {
        guard case .taskDetail(let taskID) = stage else { return }
        photoDrafts[taskID] = image
        isPresentingCamera = false
    }

    /// `1:4852` — discard the shot and re-offer the camera.
    func removePhotoDraft(_ task: ContentTask) { photoDrafts[task.id] = nil }

    /// The photograph waiting on this task's sheet. A `UIImage` rather than a SwiftUI `Image`
    /// because a view model in this target does not import SwiftUI; the view wraps it.
    func photoDraft(for task: ContentTask) -> UIImage? { photoDrafts[task.id] }

    /// The task the `taskDetail` stage is showing, or nil on every other stage.
    var detailTask: ContentTask? {
        guard case .taskDetail(let taskID) = stage else { return nil }
        return checkpoint?.tasks.first { $0.id == taskID }
    }

    /// How many of this checkpoint's tasks have been resolved — answered or skipped, since
    /// `FR-TASK-02` makes those the same kind of outcome and `AD-2` means neither gates anything.
    /// This is what fills the segmented bar on `452:3138`.
    var resolvedTaskCount: Int {
        (checkpoint?.tasks ?? []).count { resolution(for: $0) != nil }
    }

    var taskCount: Int { checkpoint?.tasks.count ?? 0 }

    var taskProgressLabel: String {
        String(format: UIStrings.string(.checkpointDetailProgressLabel, language),
               resolvedTaskCount, taskCount)
    }

    // MARK: The site plan — `452:3028`

    /// Whether the plan is over the task sheet. A cover rather than a stage, because the plan is
    /// something the walker glances at and dismisses back to the same task — it is not a step in the
    /// walk, and putting it in `Stage` would make backing out of it ambiguous.
    private(set) var isPresentingSiteMap = false

    func presentSiteMap() {
        guard checkpoint?.siteMap != nil else { return }
        isPresentingSiteMap = true
    }

    func dismissSiteMap() { isPresentingSiteMap = false }

    /// Backing out of a story stage returns to the one before it rather than leaving the walk.
    func retreatFromStoryStage() {
        switch stage {
        // `1:4458` is the screen the cutscene was reached from, and it is a pure display stage —
        // `advanceFromLocationVerified` still hands over to the stored `stageAfterArrivalConfirmed`,
        // so going back there and forward again lands on this same screen. Without this case the
        // chevron on `98:1588` fell to `default: break` and did nothing at all.
        case .cutsceneIntro: stage = .locationVerified
        case .cutscenePortrait: stage = .cutsceneIntro
        case .approachTransition: stage = .cutscenePortrait
        // The map now stands between the cutscene and the reveal, so on the walk's first
        // checkpoint that is what backing out of the reveal returns to. Every later checkpoint
        // never passed through either, and has nowhere above it to go.
        case .storyReveal: stage = hasShownCutscene && currentIndex == 0 ? .approachTransition : .storyReveal
        case .transition: stage = (checkpoint?.isSacred ?? false) ? .placeNotice : .storyReveal
        case .placeNotice: stage = .storyReveal
        // The menu now sits *after* the first task, so backing out of it returns to that task
        // rather than to the transition the walk passed through before it.
        case .checkpointDetail:
            if let first = firstTask {
                stageBeforeTaskDetail = .transition
                stage = .taskDetail(taskID: first.id)
            } else {
                stage = .transition
            }
        case .taskDetail: stage = stageBeforeTaskDetail
        // Backing out of the story returns to the task it belongs to, which by then is resolved —
        // so the sheet draws its saved answer and a plain Continue rather than the field again
        // (`FR-TASK-07`: the walker may want to re-read what they wrote).
        case .questExplanation(let taskID): stage = .taskDetail(taskID: taskID)
        case .stampAward(let taskID): stage = .questExplanation(taskID: taskID)
        default: break
        }
    }

    /// Every `LoreBlock` at this checkpoint, joined into the one passage the story reveal shows —
    /// the same join `hookText` uses, so a multi-block checkpoint reads as paragraphs rather than a
    /// pager (`46:120` restyle).
    var storyRevealText: String {
        (checkpoint?.claims.map(\.block.text) ?? []).joined(separator: "\n\n")
    }

    /// The quest's hook, joined into one passage for the typewriter. Content, not a literal.
    var hookText: String {
        quest.hookLore.map { $0.text.value(for: language) }.joined(separator: "\n\n")
    }

    var questTitle: String { quest.title.value(for: language) }

    var routeDistanceText: String {
        ContentFormatter(language: language).distance(metres: quest.route.totalDistanceM)
    }

    var routeDurationText: String {
        ContentFormatter(language: language).duration(minutes: quest.route.totalDurationMin)
    }

    /// The image the cutscene frames. The quest's hero image when it ships one — content with
    /// provenance behind it — never a generated likeness introduced here.
    var cutsceneImageURL: URL? {
        guard let asset = quest.heroImageAsset else { return nil }
        return (try? repository.assetURL(asset)) ?? nil
    }

    var currentPlaceName: String { placeName(for: currentCheckpoint) }

    /// `FR-MAP-04` — where "Navigate There" on `223:2004` goes.
    ///
    /// The checkpoint's own coordinate, not the walker's: this is a handoff to the place the quest
    /// is waiting at. `nil` when the place cannot be resolved, so the arrival screen hides the
    /// control rather than offering one that opens nothing. Nothing else on that screen depends on
    /// it (`AD-3`).
    var externalMapsURL: URL? {
        guard let place = place(for: currentCheckpoint) else { return nil }
        return ExternalMapsLink.appleMapsWalkingURL(
            to: place.coordinate,
            name: place.nameOfficial.value(for: language))
    }

    /// Which of the Hisplora location frames the arrival screen is showing. The mapping is the
    /// arrival rule's own and lives on `ArrivalSampling`, so the sidequest gate draws the same
    /// three states from the same decision.
    var locationState: LocationState { sampling.locationState }

    // MARK: Progression — FR-CP-01

    var canAdvance: Bool {
        guard let run, run.state == .active else { return false }
        return run.hasArrivedAtCurrentCheckpoint
            && currentIndex + 1 < totalCheckpoints
    }

    func advance() {
        guard let run else { return }
        do {
            self.run = try engine.advanceToNextCheckpoint(runID: run.id)
            checkpoint = nil
            stage = .awaitingArrival
            beginSampling()
        } catch let error as RunEngineError {
            message = describe(error)
        } catch {
            message = String(describing: error)
        }
    }

    func openSummary() {
        stage = .finished
    }

    var isCompleted: Bool { run?.state == .completed }

    // MARK: Tasks — AD-2, FR-TASK-01/02/07

    /// Saving a task, whichever kind it is.
    ///
    /// A photo task saves the photograph and a written one saves the words; either way an *empty*
    /// answer is recorded as a skip rather than as an answer to nothing, which is what keeps a
    /// blank sheet from stalling a walk (`AD-2`).
    ///
    /// The photograph reaches disk here and nowhere else. `PhotoStore.save` downscales it and
    /// returns a path relative to the app container — never absolute, because an absolute path
    /// resolves to nothing after a restore from backup and the walker's photographs appear to have
    /// vanished (`NFR-REL-05`). A store that throws leaves the draft where it is and says so, rather
    /// than recording a result that points at a file that was never written.
    func saveTask(_ task: ContentTask) {
        if task.type == .photo {
            guard let image = photoDrafts[task.id], let photoStore else { return skipTask(task) }
            do {
                let path = try photoStore.save(image, recordID: UUID())
                write(task: task, skipped: false, text: nil, photoRelativePath: path)
                photoDrafts[task.id] = nil
            } catch {
                message = String(describing: error)
            }
            return
        }
        let text = taskDrafts[task.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return skipTask(task) }
        write(task: task, skipped: false, text: text)
    }

    func skipTask(_ task: ContentTask) {
        photoDrafts[task.id] = nil
        write(task: task, skipped: true, text: nil)
    }

    private func write(
        task: ContentTask,
        skipped: Bool,
        text: String?,
        photoRelativePath: String? = nil
    ) {
        guard let run, let checkpoint else { return }
        do {
            self.run = try engine.recordTaskResult(
                runID: run.id, checkpointID: checkpoint.id,
                taskID: task.id, skipped: skipped, text: text,
                photoRelativePath: photoRelativePath)
        } catch let error as RunEngineError {
            message = describe(error)
        } catch {
            message = String(describing: error)
        }
    }

    func resolution(for task: ContentTask) -> TaskResult? {
        guard let run, let checkpoint else { return nil }
        return run.result(forCheckpointID: checkpoint.id)?
            .taskResults.first { $0.taskID == task.id }
    }

    // MARK: Abandoning — FR-RUN-04

    func requestAbandon() { isConfirmingAbandon = true }

    func cancelAbandon() { isConfirmingAbandon = false }

    func confirmAbandon() {
        isConfirmingAbandon = false
        guard let run else { return }
        self.run = (try? engine.abandon(runID: run.id, reason: .userChoice)) ?? run
        screenDisappeared()
        stage = .finished
    }

    // MARK: Message

    func dismissMessage() { message = nil }

    private func describe(_ error: RunEngineError) -> String {
        switch error {
        case .outOfSequence(let checkpointID, _):
            let name = orderedCheckpoints.first { $0.id == checkpointID }
                .map { placeName(for: $0) } ?? checkpointID
            return String(format: UIStrings.string(.arrivalOutOfSequence, language), name)
        default:
            return error.description
        }
    }

    // MARK: Content lookups

    private func place(for checkpoint: Checkpoint?) -> Place? {
        guard let checkpoint else { return nil }
        return (try? repository.place(id: checkpoint.placeId)) ?? nil
    }

    private func placeName(for checkpoint: Checkpoint?) -> String {
        place(for: checkpoint)?.nameOfficial.value(for: language)
            ?? checkpoint?.placeId ?? ""
    }

    private func presentation(forOrderIndex index: Int) -> CheckpointPresentation? {
        guard let checkpoint = orderedCheckpoints.first(where: { $0.orderIndex == index })
        else { return nil }
        let place = place(for: checkpoint)
        let formatter = ContentFormatter(language: language)

        func presentedClaims(from blocks: [LoreBlock]) -> [LoreClaimPresentation] {
            blocks.enumerated().map { offset, block in
                LoreClaimPresentation(
                    id: offset,
                    block: LoreBlockPresentation(
                        id: offset,
                        text: block.text.value(for: language),
                        accuracyLabel: formatter.accuracyLabel(block.accuracy),
                        appearance: block.accuracy == .documented ? .documented : .oral,
                        ink: block.accuracy == .documented ? .documented : .oral),
                    citations: block.sourceRefs.compactMap { ref in
                        guard let place, place.sources.indices.contains(ref) else { return nil }
                        return place.sources[ref].citation
                    })
            }
        }
        let claims = presentedClaims(from: checkpoint.loreSegment)

        // `FR-TASK-06` — a photo task at a Place where photography is prohibited is not offered at
        // all. The validator rejects such content (V9); this is the runtime half of the same rule,
        // because content can be corrected after a build and this screen must not be the thing
        // that carries the mistake to a temple gate.
        let tasks = checkpoint.tasks.filter { task in
            !(task.type == .photo && place?.photoPolicy.level == .prohibited)
        }

        return CheckpointPresentation(
            id: checkpoint.id,
            orderIndex: checkpoint.orderIndex,
            placeName: place?.nameOfficial.value(for: language) ?? checkpoint.placeId,
            placeDescription: (place?.loreStandalone ?? [])
                .map { $0.text.value(for: language) }.joined(separator: "\n\n"),
            isSacred: place?.isSacred ?? false,
            dressCodeText: place?.dressCode.value(for: language) ?? "",
            photoPolicyText: place.map { formatter.photoPolicy($0.photoPolicy.level) } ?? "",
            claims: claims,
            standaloneClaims: presentedClaims(from: place?.loreStandalone ?? []),
            clueToNext: checkpoint.clueToNext?.value(for: language),
            tasks: tasks,
            taskPrompts: Dictionary(
                uniqueKeysWithValues: tasks.map { ($0.id, $0.prompt.value(for: language)) }),
            coordinate: place?.coordinate ?? Coordinate(lat: 0, lon: 0),
            arrivalRadiusM: place?.arrivalRadiusM ?? 75,
            isFinal: checkpoint.orderIndex == (orderedCheckpoints.last?.orderIndex ?? 0),
            siteMap: place.flatMap(siteMap(for:)),
            approachMap: place.flatMap(approachMap(for:)))
    }

    /// The Place's drawn plan, with its citation resolved (`452:3028`).
    ///
    /// Returns nil rather than a plan with an empty citation when the `sourceRef` does not resolve.
    /// V3 rejects such content at build time, but content can be corrected after a build and this is
    /// the one screen that must not be the thing carrying an unsourced claim about a real place's
    /// layout to a temple gate — the same runtime-half-of-a-validator-rule argument `FR-TASK-06`'s
    /// photo filter above makes.
    private func siteMap(for place: Place) -> SiteMapPresentation? {
        guard let authored = place.siteMap,
              place.sources.indices.contains(authored.sourceRef)
        else { return nil }
        return SiteMapPresentation(
            imageURL: (try? repository.assetURL(authored.asset)) ?? nil,
            aspectRatio: authored.aspectRatio,
            citation: place.sources[authored.sourceRef].citation,
            // `452:3032`–`3034` draw three dots on the plan. They are not authored anywhere in the
            // content tree, and inventing coordinates for them here would be this file asserting
            // where three things stand inside a real puri — which is precisely the claim the
            // citation above exists to qualify. Empty until content carries them.
            markers: [])
    }

    /// The Place's drawn approach map (`1:4458`).
    ///
    /// The `sourceRef` still has to resolve even though the screen no longer prints what it resolves
    /// to — the same runtime half of V3 that `siteMap(for:)` above applies. A map whose provenance
    /// has gone missing from the content is a different thing from one whose provenance is merely
    /// not on screen, and this is the check that keeps the first case off the parchment.
    private func approachMap(for place: Place) -> ApproachMapPresentation? {
        guard let authored = place.approachMap,
              place.sources.indices.contains(authored.sourceRef)
        else { return nil }
        return ApproachMapPresentation(
            imageURL: (try? repository.assetURL(authored.asset)) ?? nil,
            aspectRatio: authored.aspectRatio,
            marker: authored.marker)
    }
}
