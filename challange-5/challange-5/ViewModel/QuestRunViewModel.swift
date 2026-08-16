import ContentKit
import DesignSystem
import Foundation
import RunEngine
import UIStringsKit

@MainActor
@Observable
final class QuestRunViewModel {

    enum Stage: Equatable {
        /// `81:588` — the hook, typed out, with the walk's distance and duration under it. The
        /// board opens the flow here, before the notices.
        case storyPreview
        /// `FR-START-04` — acknowledged before the first Run of this quest.
        case safetyNotice
        /// `FR-START-02` — the plain-language explanation that precedes the system prompt.
        case locationNotice
        case awaitingArrival
        /// The Hisplora cutscene — the quest's hook and a framed image, shown once at the first
        /// arrival of a walk. A presentation of `hookLore`, not a new content type: see
        /// `CutsceneScreens.swift`.
        case cutsceneIntro
        case cutscenePortrait
        /// The lore reveal — one passage, joined from every `LoreBlock` at the checkpoint.
        case storyReveal
        /// `50:137` — the sacred-Place notice, before the task menu. Only reached when
        /// `checkpoint.isSacred`; every other checkpoint's story goes straight to `checkpointDetail`.
        case placeNotice
        /// `51:201` — what is waiting at this checkpoint, named before it is answered.
        case checkpointDetail
        /// The place name, before the checkpoint proper.
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
    /// `FR-START-09` — the named presence confirmation, shown only at the start checkpoint.
    private(set) var isConfirmingPresence = false
    private(set) var isConfirmingAbandon = false
    private(set) var message: String?
    private(set) var checkpoint: CheckpointPresentation?
    /// Task answers being typed, keyed by task id. Not persisted until saved — `FR-RUN-01` is about
    /// completed actions, and a half-typed sentence is not one.
    var taskDrafts: [String: String] = [:]

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
        manualOverrideDelay: Duration = .seconds(60)
    ) {
        guard let quest = (try? repository.quest(id: questID)) ?? nil else { return nil }
        self.engine = engine
        self.repository = repository
        self.preferences = preferences
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

        stage = Self.initialStage(
            run: existingRun,
            quest: quest,
            preferences: preferences,
            authorization: sampling.authorization)
        if stage == .atCheckpoint || stage == .finished {
            checkpoint = presentation(forOrderIndex: currentIndex)
        }

        sampling.onArrival = { [weak self] method, accuracyM in
            self?.record(method: method, accuracyM: accuracyM)
        }
    }

    private static func initialStage(
        run: Run?,
        quest: Quest,
        preferences: any AppPreferencesStore,
        authorization: LocationAuthorizationSnapshot
    ) -> Stage {
        if let run {
            // A walk already under way has been through both notices. Showing them again on every
            // resume would turn a safety notice into a dialog people learn to dismiss.
            switch run.state {
            case .completed, .abandoned: return .finished
            default: return run.hasArrivedAtCurrentCheckpoint ? .atCheckpoint : .awaitingArrival
            }
        }
        // A fresh walk opens on the hook, as the board does. A resumed one never sees it again —
        // it is an opening, not a gate.
        return .storyPreview
    }

    /// Leaving the hook for the notices. The order after it is unchanged: `FR-START-04` before
    /// `FR-START-02` before any sampling.
    func advanceFromStoryPreview() {
        if !preferences.safetyNoticeAckedQuestIDs.contains(quest.id) {
            stage = .safetyNotice
        } else if sampling.authorization == .notRequested {
            stage = .locationNotice
        } else {
            stage = .awaitingArrival
            beginSampling()
        }
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

    var safetyNotes: String { quest.safetyNotes.value(for: language) }

    var presenceConfirmationTitle: String {
        String(format: UIStrings.string(.runStartConfirmTitle, language),
               placeName(for: currentCheckpoint))
    }

    // MARK: Preflight — FR-START-02/04

    func acknowledgeSafetyNotice() {
        preferences.safetyNoticeAckedQuestIDs.insert(quest.id)
        stage = sampling.authorization == .notRequested ? .locationNotice : .awaitingArrival
        if stage == .awaitingArrival { beginSampling() }
    }

    func acknowledgeLocationNoticeAndRequestPermission() {
        stage = .awaitingArrival
        sampling.requestWhenInUseAuthorization()
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
            stage = .cutsceneIntro
        } else {
            stage = .storyReveal
        }

        if let run, let checkpoint {
            self.run = (try? engine.markLoreOpened(
                runID: run.id, checkpointID: checkpoint.id)) ?? run
        }
    }

    // MARK: The Hisplora story stages

    func advanceFromCutsceneIntro() { stage = .cutscenePortrait }

    func advanceFromCutscenePortrait() { stage = .storyReveal }

    /// A sacred Place explains itself before the task menu (`FR-TASK-05`'s rule, moved one screen
    /// earlier); every other checkpoint goes straight to the menu.
    func advanceFromStoryReveal() {
        stage = (checkpoint?.isSacred ?? false) ? .placeNotice : .checkpointDetail
    }

    func advanceFromPlaceNotice() { stage = .checkpointDetail }

    func advanceFromCheckpointDetail() { stage = .transition }

    func advanceFromTransition() { stage = .atCheckpoint }

    /// Backing out of a story stage returns to the one before it rather than leaving the walk.
    func retreatFromStoryStage() {
        switch stage {
        case .cutscenePortrait: stage = .cutsceneIntro
        case .storyReveal: stage = hasShownCutscene && currentIndex == 0 ? .cutscenePortrait : .storyReveal
        case .placeNotice: stage = .storyReveal
        case .checkpointDetail: stage = (checkpoint?.isSacred ?? false) ? .placeNotice : .storyReveal
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

    func saveTask(_ task: ContentTask) {
        let text = taskDrafts[task.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return skipTask(task) }
        write(task: task, skipped: false, text: text)
    }

    func skipTask(_ task: ContentTask) {
        write(task: task, skipped: true, text: nil)
    }

    private func write(task: ContentTask, skipped: Bool, text: String?) {
        guard let run, let checkpoint else { return }
        do {
            self.run = try engine.recordTaskResult(
                runID: run.id, checkpointID: checkpoint.id,
                taskID: task.id, skipped: skipped, text: text)
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

        let claims = checkpoint.loreSegment.enumerated().map { offset, block in
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
            clueToNext: checkpoint.clueToNext?.value(for: language),
            tasks: tasks,
            taskPrompts: Dictionary(
                uniqueKeysWithValues: tasks.map { ($0.id, $0.prompt.value(for: language)) }),
            coordinate: place?.coordinate ?? Coordinate(lat: 0, lon: 0),
            arrivalRadiusM: place?.arrivalRadiusM ?? 75,
            isFinal: checkpoint.orderIndex == (orderedCheckpoints.last?.orderIndex ?? 0))
    }
}
