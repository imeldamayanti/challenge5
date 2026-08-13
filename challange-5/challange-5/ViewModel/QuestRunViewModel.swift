import ContentKit
import DesignSystem
import Foundation
import RunEngine

@MainActor
@Observable
final class QuestRunViewModel {

    enum Stage: Equatable {
        /// `FR-START-04` — acknowledged before the first Run of this quest.
        case safetyNotice
        /// `FR-START-02` — the plain-language explanation that precedes the system prompt.
        case locationNotice
        case awaitingArrival
        case atCheckpoint
        case finished
    }

    enum ArrivalStatus: Equatable {
        case idle
        case searching
        case approaching(distanceText: String, accuracyText: String)
        /// Inside the radius, but by a fix too vague to prove it (`FR-ARR-01`).
        case accuracyInsufficient(distanceText: String, accuracyText: String)
        case permissionDenied
    }

    // MARK: Inputs

    private let engine: RunEngine
    private let repository: any ContentRepository
    private let preferences: any AppPreferencesStore
    private let locationProvider: any LocationProviding
    private let manualOverrideDelay: Duration
    /// Set when the user chose "start over" in preview. The draft is not deleted then and there —
    /// it is deleted when the replacement walk actually begins, so backing out of the arrival
    /// screen leaves the old walk exactly where it was.
    private let discardingExistingDraft: Bool

    let quest: Quest
    let language: ContentLanguage

    // MARK: Observable state

    private(set) var run: Run?
    private(set) var stage: Stage = .awaitingArrival
    private(set) var arrival: ArrivalStatus = .idle
    /// `FR-ARR-03` — revealed after 60 s of unsuccessful detection, or immediately when permission
    /// is refused, since waiting a minute for a fix that cannot arrive is a minute of nothing.
    private(set) var manualOverrideAvailable = false
    /// `FR-START-09` — the named presence confirmation, shown only at the start checkpoint.
    private(set) var isConfirmingPresence = false
    private(set) var isConfirmingAbandon = false
    private(set) var message: String?
    private(set) var checkpoint: CheckpointPresentation?
    /// Task answers being typed, keyed by task id. Not persisted until saved — `FR-RUN-01` is about
    /// completed actions, and a half-typed sentence is not one.
    var taskDrafts: [String: String] = [:]

    private var overrideTimer: Task<Void, Never>?
    /// `FR-ARR-03` — a manual arrival records the last known accuracy, because that number is what
    /// later explains *why* the override was needed at this particular gate.
    private var lastKnownAccuracyM: Double?

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
        self.locationProvider = locationProvider
        self.quest = quest
        self.language = language
        self.run = existingRun
        self.discardingExistingDraft = discardingExistingDraft
        self.manualOverrideDelay = manualOverrideDelay

        stage = Self.initialStage(
            run: existingRun,
            quest: quest,
            preferences: preferences,
            authorization: locationProvider.authorization)
        if stage == .atCheckpoint || stage == .finished {
            checkpoint = presentation(forOrderIndex: currentIndex)
        }

        self.locationProvider.onFix = { [weak self] fix in self?.handle(fix: fix) }
        self.locationProvider.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorizationChange(status)
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
        if !preferences.safetyNoticeAckedQuestIDs.contains(quest.id) { return .safetyNotice }
        if authorization == .notRequested { return .locationNotice }
        return .awaitingArrival
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

    var safetyNotes: String { quest.safetyNotes.value(for: language) }

    var presenceConfirmationTitle: String {
        String(format: UIStrings.string(.runStartConfirmTitle, language),
               placeName(for: currentCheckpoint))
    }

    // MARK: Preflight — FR-START-02/04

    func acknowledgeSafetyNotice() {
        preferences.safetyNoticeAckedQuestIDs.insert(quest.id)
        stage = locationProvider.authorization == .notRequested ? .locationNotice : .awaitingArrival
        if stage == .awaitingArrival { beginSampling() }
    }

    func acknowledgeLocationNoticeAndRequestPermission() {
        stage = .awaitingArrival
        locationProvider.requestWhenInUseAuthorization()
        beginSampling()
    }

    // MARK: Sampling lifecycle — FR-ARR-02, NFR-BAT-04

    func screenAppeared() {
        guard stage == .awaitingArrival else { return }
        beginSampling()
    }

    /// Sampling stops when the arrival screen goes away — not when the app backgrounds, not when a
    /// timer decides. `NFR-BAT-04` is a hard requirement and this is the only place it is met.
    func screenDisappeared() {
        locationProvider.stop()
        overrideTimer?.cancel()
        overrideTimer = nil
    }

    private func beginSampling() {
        guard let checkpoint = currentCheckpoint,
              let place = place(for: checkpoint) else { return }

        arrival = locationProvider.authorization == .denied
            || locationProvider.authorization == .restricted
            ? .permissionDenied
            : .searching

        // `FR-ERR-02` — a refused permission must not destroy the Run, so the override that keeps
        // it walkable appears at once rather than after a minute of pretending to look.
        manualOverrideAvailable = arrival == .permissionDenied

        locationProvider.start(target: place.coordinate)
        startOverrideTimer()
    }

    private func startOverrideTimer() {
        overrideTimer?.cancel()
        guard !manualOverrideAvailable else { return }
        let delay = manualOverrideDelay
        overrideTimer = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.manualOverrideAvailable = true
        }
    }

    private func handleAuthorizationChange(_ status: LocationAuthorizationSnapshot) {
        guard stage == .awaitingArrival else { return }
        if status == .denied || status == .restricted {
            arrival = .permissionDenied
            manualOverrideAvailable = true
        } else if arrival == .permissionDenied {
            arrival = .searching
            beginSampling()
        }
    }

    // MARK: Arrival — FR-ARR-01

    private func handle(fix: LocationFix) {
        guard stage == .awaitingArrival,
              let checkpoint = currentCheckpoint,
              let place = place(for: checkpoint) else { return }

        let decision = ArrivalEvaluator.decide(
            fix: fix, target: place.coordinate, radiusM: place.arrivalRadiusM)
        lastKnownAccuracyM = fix.horizontalAccuracyM
        let formatter = ContentFormatter(language: language)
        let distanceText = formatter.distance(metres: Int(decision.distanceM.rounded()))
        let accuracyText = formatter.distance(metres: Int(decision.accuracyM.rounded()))

        switch decision {
        case .arrived(_, let accuracy):
            record(method: .gps, accuracyM: accuracy)
        case .outsideRadius:
            // `FR-ARR-05` — a number that moves, never an indefinite spinner.
            arrival = .approaching(distanceText: distanceText, accuracyText: accuracyText)
        case .accuracyInsufficient:
            arrival = .accuracyInsufficient(
                distanceText: distanceText, accuracyText: accuracyText)
        }
    }

    /// `FR-ARR-03/04`, `FR-START-09/10`. At the start checkpoint this routes through the named
    /// confirmation first; everywhere else it is one tap and costs nothing.
    func useManualOverride() {
        if isAtStartCheckpoint {
            isConfirmingPresence = true
            return
        }
        record(method: .manual, accuracyM: lastKnownAccuracyM)
    }

    func confirmPresence() {
        isConfirmingPresence = false
        record(method: .manual, accuracyM: lastKnownAccuracyM)
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
        locationProvider.stop()
        overrideTimer?.cancel()
        overrideTimer = nil
        manualOverrideAvailable = false
        arrival = .idle
        checkpoint = presentation(forOrderIndex: currentIndex)
        stage = .atCheckpoint

        if let run, let checkpoint {
            self.run = (try? engine.markLoreOpened(
                runID: run.id, checkpointID: checkpoint.id)) ?? run
        }
    }

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
