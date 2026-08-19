import ContentKit
import Foundation
import RunEngine
import UIStringsKit

/// The arrival gate, owned by whichever screen is waiting at one.
///
/// Five behaviours were private to `QuestRunViewModel` until `s4` needed the same gate for a
/// sidequest (`FR-SIDE-02`, `s0` D3): the sampling lifecycle, the bounded 60-second wait, the
/// `ArrivalDecision` → status mapping, the refused-permission shortcut, and the override sheet.
/// They are extracted rather than copied — copying is how two screens end up disagreeing about what
/// arrival means, and the whole reason `FR-ARR-01` is one rule is that it is one rule.
///
/// What it does **not** decide is what arrival then does. That is the owning view model's: a
/// checkpoint records against a Run, a sidequest discovers itself and snapshots its story, and
/// neither may reach into the other (`FR-SIDE-01`). Arrival leaves here as a decided fact — a
/// method and an accuracy — exactly as it reaches `RunEngine`.
@MainActor
@Observable
final class ArrivalSampling {

    /// What the screen is currently able to say about where the walker is.
    enum Status: Equatable {
        case idle
        case searching
        case approaching(distanceText: String, accuracyText: String)
        /// Inside the radius, but by a fix too vague to prove it (`FR-ARR-01`).
        case accuracyInsufficient(distanceText: String, accuracyText: String)
        case permissionDenied
    }

    // MARK: Inputs

    private let locationProvider: any LocationProviding
    private let language: ContentLanguage
    private let manualOverrideDelay: Duration

    /// Called once the gate opens, by GPS or by the walker saying so. Set by the owner; nothing
    /// here knows what happens next.
    var onArrival: ((ArrivalMethod, Double?) -> Void)?

    // MARK: Observable state

    private(set) var status: Status = .idle
    /// `FR-ARR-03` — revealed after 60 s of unsuccessful detection, or immediately when permission
    /// is refused, since waiting a minute for a fix that cannot arrive is a minute of nothing.
    private(set) var manualOverrideAvailable = false
    /// Whole seconds until the override appears, or `nil` when there is nothing to count down to.
    /// `FR-ARR-05`: a number that moves, never an indefinite spinner.
    private(set) var manualOverrideRemainingSeconds: Int?
    /// `0…1` for a determinate progress indicator over that same wait.
    private(set) var manualOverrideProgress: Double = 0
    private(set) var searchingElapsedSeconds: Int = 0
    /// `FR-START-10`, `FR-ARR-04` — the override lives in a sheet, because a control the walker
    /// needs when GPS has failed cannot be the quietest line on a scrolling screen.
    private(set) var isPresentingManualOverride = false
    /// `FR-ARR-03` — a manual arrival records the last known accuracy, because that number is what
    /// later explains *why* the override was needed at this particular gate.
    private(set) var lastKnownAccuracyM: Double?
    /// Kept alongside it, because `FR-MAP-02` asks for the walker's position *relative to* the
    /// target — a direction, which a scalar distance cannot express.
    private(set) var lastKnownCoordinate: Coordinate?

    // MARK: Private

    private var target: Coordinate?
    private var radiusM: Int = 0
    /// Guards the callbacks. The provider is stopped on arrival, but a fix already in flight can
    /// still land afterwards, and a second arrival from it would be a second record.
    private var isSampling = false
    private var overrideTimer: Task<Void, Never>?
    private var overrideSchedule: ManualOverrideSchedule?

    init(
        locationProvider: any LocationProviding,
        language: ContentLanguage,
        manualOverrideDelay: Duration = .seconds(60)
    ) {
        self.locationProvider = locationProvider
        self.language = language
        self.manualOverrideDelay = manualOverrideDelay
        self.locationProvider.onFix = { [weak self] fix in self?.handle(fix: fix) }
        self.locationProvider.onAuthorizationChange = { [weak self] status in
            self?.handleAuthorizationChange(status)
        }
    }

    var authorization: LocationAuthorizationSnapshot { locationProvider.authorization }

    /// `FR-ONB-04`, `FR-START-02` — asked in context, after the app has explained itself.
    func requestWhenInUseAuthorization() {
        locationProvider.requestWhenInUseAuthorization()
    }

    // MARK: Lifecycle — FR-ARR-02, NFR-BAT-04

    func start(target: Coordinate, radiusM: Int) {
        self.target = target
        self.radiusM = radiusM
        isSampling = true

        status = authorization == .denied || authorization == .restricted
            ? .permissionDenied
            : .searching

        // `FR-ERR-02` — a refused permission must not destroy the walk, so the override that keeps
        // it walkable appears at once rather than after a minute of pretending to look.
        manualOverrideAvailable = status == .permissionDenied

        locationProvider.start(target: target)
        startOverrideTimer()
    }

    /// Sampling stops when the screen goes away — not when the app backgrounds, not when a timer
    /// decides. `NFR-BAT-04` is a hard requirement and this is the only place it is met.
    func stop() {
        isSampling = false
        locationProvider.stop()
        overrideTimer?.cancel()
        overrideTimer = nil
    }

    /// Everything `stop()` does, plus clearing the wait — used once the gate has opened and there
    /// is nothing left to count down to.
    func finish() {
        stop()
        overrideSchedule = nil
        manualOverrideAvailable = false
        manualOverrideRemainingSeconds = nil
        isPresentingManualOverride = false
        status = .idle
    }

    // MARK: The bounded wait — FR-ARR-03, FR-ARR-05

    /// One timer for both jobs. It publishes the countdown *and* flips availability from the same
    /// schedule, so the number on screen and the control appearing cannot disagree — a countdown
    /// that reaches zero beside a control that is still hidden is worse than no countdown.
    private func startOverrideTimer() {
        overrideTimer?.cancel()
        overrideSchedule = ManualOverrideSchedule(
            startedAt: Date(),
            delay: manualOverrideDelay,
            isImmediate: manualOverrideAvailable)
        refreshOverrideCountdown()
        guard !manualOverrideAvailable else { return }
        overrideTimer = Task { [weak self] in
            // Twice a second: the display is in whole seconds, and this is a foreground screen the
            // walker is looking at, not the location sampler `NFR-BAT-04` governs.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled, let self else { return }
                self.refreshOverrideCountdown()
                if self.manualOverrideAvailable { return }
            }
        }
    }

    private func refreshOverrideCountdown() {
        guard let schedule = overrideSchedule else {
            manualOverrideRemainingSeconds = nil
            return
        }
        let now = Date()
        manualOverrideRemainingSeconds = schedule.remainingSeconds(at: now)
        manualOverrideProgress = schedule.progress(at: now)
        searchingElapsedSeconds = Int(schedule.elapsedSeconds(at: now))
        if schedule.isAvailable(at: now) {
            manualOverrideAvailable = true
            manualOverrideRemainingSeconds = nil
        }
    }

    private func handleAuthorizationChange(_ snapshot: LocationAuthorizationSnapshot) {
        guard isSampling else { return }
        if snapshot == .denied || snapshot == .restricted {
            status = .permissionDenied
            manualOverrideAvailable = true
            // `FR-ERR-02` — nothing left to wait for, so nothing left to count down.
            overrideTimer?.cancel()
            overrideTimer = nil
            overrideSchedule = nil
            manualOverrideRemainingSeconds = nil
            manualOverrideProgress = 1
        } else if status == .permissionDenied, let target {
            start(target: target, radiusM: radiusM)
        }
    }

    // MARK: The gate — FR-ARR-01

    private func handle(fix: LocationFix) {
        guard isSampling, let target else { return }

        let decision = ArrivalEvaluator.decide(fix: fix, target: target, radiusM: radiusM)
        lastKnownAccuracyM = fix.horizontalAccuracyM
        lastKnownCoordinate = fix.coordinate
        let formatter = ContentFormatter(language: language)
        let distanceText = formatter.distance(metres: Int(decision.distanceM.rounded()))
        let accuracyText = formatter.distance(metres: Int(decision.accuracyM.rounded()))

        switch decision {
        case .arrived(_, let accuracy):
            onArrival?(.gps, accuracy)
        case .outsideRadius:
            // `FR-ARR-05` — a number that moves, never an indefinite spinner.
            status = .approaching(distanceText: distanceText, accuracyText: accuracyText)
        case .accuracyInsufficient:
            status = .accuracyInsufficient(distanceText: distanceText, accuracyText: accuracyText)
        }
    }

    /// `FR-ARR-03/04` — one tap, and it costs nothing. Whether a further confirmation is required
    /// before it is the owner's rule, not this one's: a quest start needs `FR-START-09`'s named
    /// confirmation and a sidequest does not (`s0` D3).
    func arriveManually() {
        onArrival?(.manual, lastKnownAccuracyM)
    }

    // MARK: The override sheet — FR-START-10, FR-ARR-04

    func presentManualOverride() { isPresentingManualOverride = true }

    func dismissManualOverride() { isPresentingManualOverride = false }

    // MARK: Derived

    /// `0:47`. Digits and a colon, so it is not a translated string — but it is only ever shown
    /// inside one that is.
    var manualOverrideCountdownText: String? {
        guard let remaining = manualOverrideRemainingSeconds else { return nil }
        return String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var searchingElapsedText: String {
        String(format: "%d:%02d", searchingElapsedSeconds / 60, searchingElapsedSeconds % 60)
    }

    /// Which of the Hisplora location frames the screen is showing. The mapping is the arrival
    /// rule's own: `FR-ARR-01` is two conditions, and "close but the fix is too coarse" is *not*
    /// arrival — so it draws "Not Quite There" rather than "Verified".
    var locationState: LocationState {
        switch status {
        case .idle, .searching: .checking
        case .approaching, .accuracyInsufficient: .notThere
        case .permissionDenied: .denied
        }
    }
}
