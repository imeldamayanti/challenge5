import AVFoundation
import Foundation

/// Plays the spoken reading of a checkpoint's passage — `Checkpoint.narration`, resolved to a file
/// URL by the content repository and handed here as a URL and nothing else.
///
/// **A local file and no network, by construction.** The recording ships in the content bundle, so
/// this is `AVAudioPlayer` over a file URL rather than `AVPlayer` over an asset that could be
/// streamed. That is not an optimisation: `AD-3` says every core flow works in airplane mode, and a
/// player that could reach the network is a player that will eventually be pointed at something
/// that does.
///
/// **Nothing here gates anything.** A file that will not decode, a session that will not activate
/// and a URL that resolves to nothing all land on `.unavailable`, which draws no control — the walk
/// continues exactly as it does at a checkpoint with no recording at all. The narration is a way of
/// hearing the passage that is already on screen, never the only way to receive it
/// (`NFR-A11Y-05`).
///
/// **It starts on its own when the passage starts, and that is why there are two audio-session
/// categories.** A reading nobody asked for must be silenceable by the switch on the side of the
/// phone — two of the five shipped places are `isSacred`, and a walker who silenced their phone at
/// a temple gate has already said what they want. A reading the walker *tapped* must not be, because
/// a play button that honours the switch reads as broken rather than as respectful. So `.ambient`
/// for the first and `.playback` for the second, decided per call rather than once at construction.
/// Under VoiceOver nothing starts by itself at all: the screen withholds `autoplay()`, because a
/// narrator over a screen reader is two voices at once.
@MainActor
@Observable
final class NarrationPlayer {

    /// What the screen has to draw. One enum rather than a pair of booleans, because a control that
    /// can be both playing and unavailable is a bug that compiles.
    enum State: Equatable {
        /// No recording for this checkpoint in this language, or one that would not open.
        case unavailable
        case ready
        case playing
    }

    private(set) var state: State = .unavailable
    /// 0…1 through the current recording, for the button's ring. Zero when nothing is loaded.
    private(set) var progress: Double = 0

    // Everything below is machinery, not state a view reads, so none of it is observed — and the
    // `lazy` one *cannot* be: `@Observable` rewrites a tracked property into an init accessor,
    // which a lazy stored property has no way to be.
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var loadedURL: URL?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// Set when `AVAudioSession` was activated by this object, so it is deactivated once and only
    /// by whoever turned it on.
    @ObservationIgnored private var holdsSession = false
    /// Whether the current recording has already been started without being asked. One shot per
    /// recording: a walker who pauses an autoplayed reading has said something, and the next
    /// `reveal` step must not talk over them by starting it again.
    @ObservationIgnored private var autoplayed = false
    /// Set when `autoplay()` arrives before `load(_:)` has a player to start. SwiftUI does not
    /// promise that the body's `onAppear` runs before a child's `task`, so the intent is remembered
    /// rather than dropped — which is the difference between the narration working and it working
    /// on most launches.
    @ObservationIgnored private var autoplayPending = false

    /// The delegate is a separate object because `AVAudioPlayerDelegate` is an `NSObjectProtocol`
    /// and this type is a `@MainActor` `@Observable` class, not an `NSObject`.
    @ObservationIgnored private lazy var completion = CompletionObserver { [weak self] in
        self?.finish()
    }

    deinit { ticker?.cancel() }

    // MARK: Loading

    /// Points the player at a recording, or at nothing.
    ///
    /// Idempotent on the same URL: the Story Reveal re-renders on every reveal step, and reloading
    /// there would restart the reading under the walker each time. A *different* URL — the next
    /// checkpoint — stops whatever is playing first, because two narrators is never a state this
    /// app should be able to reach.
    func load(_ url: URL?) {
        guard url != loadedURL else { return }
        stop()
        loadedURL = url
        player = nil
        progress = 0
        // `autoplayed` is per recording, so a new one may start itself. `autoplayPending` is
        // deliberately *not* cleared: it is the screen's intent for the page being loaded, and the
        // whole reason it exists is that it can arrive before this method does.
        autoplayed = false
        guard let url else {
            state = .unavailable
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = completion
            player.prepareToPlay()
            self.player = player
            state = .ready
            if autoplayPending { autoplay() }
        } catch {
            // A recording that will not decode is a content defect the validator cannot catch —
            // V14 proves the file is there, not that it is audio. It is not a reason to interrupt
            // a walk.
            self.player = nil
            state = .unavailable
        }
    }

    // MARK: Transport

    func toggle() {
        switch state {
        case .unavailable: break
        case .ready: play()
        case .playing: pause()
        }
    }

    /// Starts the reading because the page did, not because anybody asked — called when the
    /// passage begins revealing.
    ///
    /// Idempotent per recording, and safe to call before there is anything to play: an `.unavailable`
    /// player has either not loaded yet, in which case the intent is held for `load(_:)`, or has
    /// nothing to load, in which case holding it costs nothing.
    func autoplay() {
        guard !autoplayed else { return }
        switch state {
        case .unavailable:
            autoplayPending = true
        case .ready:
            autoplayed = true
            autoplayPending = false
            play(unprompted: true)
        case .playing:
            autoplayed = true
            autoplayPending = false
        }
    }

    /// - Parameter unprompted: true when the page started this rather than the walker, which is what
    ///   decides whether the ring/silent switch is honoured. See `activateSession(unprompted:)`.
    func play(unprompted: Bool = false) {
        guard let player, state != .unavailable else { return }
        activateSession(unprompted: unprompted)
        guard player.play() else { return }
        state = .playing
        startTicking()
    }

    func pause() {
        guard state == .playing, let player else { return }
        player.pause()
        state = .ready
        stopTicking()
    }

    /// Stops and rewinds. Called when the stage changes, when the app leaves the foreground, and
    /// before loading a different recording.
    ///
    /// It rewinds rather than pausing because the next thing that happens after a stage change is
    /// a different passage on screen; resuming a reading of the previous one from the middle would
    /// be the narration and the page disagreeing about where the walker is.
    func stop() {
        ticker?.cancel()
        ticker = nil
        player?.stop()
        player?.currentTime = 0
        progress = 0
        if state == .playing { state = .ready }
        releaseSession()
    }

    // MARK: Session

    /// Two categories, chosen by who started the reading.
    ///
    /// `.ambient` for a reading that began on its own: it is silenced by the ring/silent switch and
    /// it mixes rather than ducking, which is what unrequested speech in a temple courtyard has to
    /// do. `.playback` for a reading the walker tapped: it ignores the switch, because somebody who
    /// presses play and hears nothing concludes the app is broken, and it ducks other audio so a
    /// walker's music drops under the reading and comes back after it.
    ///
    /// Set on every activation rather than once, because the same recording can change hands — an
    /// autoplayed reading the walker pauses and restarts is a reading they have now asked for.
    private func activateSession(unprompted: Bool) {
        let session = AVAudioSession.sharedInstance()
        // A session that will not configure is not a reason to refuse to play: the player may well
        // still be audible under whatever category is already active.
        if unprompted {
            try? session.setCategory(.ambient, mode: .spokenAudio)
        } else {
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        try? session.setActive(true)
        holdsSession = true
    }

    private func releaseSession() {
        guard holdsSession else { return }
        holdsSession = false
        try? AVAudioSession.sharedInstance().setActive(
            false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: Progress

    /// Ten ticks a second, which is finer than a 48-point ring can show and coarse enough to cost
    /// nothing. It is a poll rather than a `CADisplayLink` because the ring is the only thing
    /// reading it and it does not have to be frame-accurate.
    private func startTicking() {
        stopTicking()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, self.state == .playing, let player = self.player else { return }
                let duration = player.duration
                self.progress = duration > 0 ? min(player.currentTime / duration, 1) : 0
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    /// The recording reached its end on its own: rewind so the same control plays it again rather
    /// than resuming a finished file.
    private func finish() {
        stopTicking()
        player?.currentTime = 0
        progress = 0
        state = player == nil ? .unavailable : .ready
        releaseSession()
    }

    /// `AVAudioPlayerDelegate` needs an `NSObject`; this is the smallest one that will do.
    private final class CompletionObserver: NSObject, AVAudioPlayerDelegate {
        private let onFinish: @MainActor () -> Void

        init(onFinish: @escaping @MainActor () -> Void) {
            self.onFinish = onFinish
        }

        nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully: Bool) {
            Task { @MainActor in self.onFinish() }
        }

        nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
            Task { @MainActor in self.onFinish() }
        }
    }
}
