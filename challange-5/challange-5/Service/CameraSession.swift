import AVFoundation
import Foundation
import UIKit

/// The capture device behind `1:4681`, and the reason it is not `UIImagePickerController`.
///
/// The frame draws its own chrome — a titled dark bar with a cross, a 2× badge, a ringed shutter and
/// a flash toggle — over a full-bleed preview. `UIImagePickerController` draws Apple's chrome and
/// will not let a caller replace it, so reproducing the frame means owning the session. The sidequest
/// challenge still uses the picker (`SideQuestChallengeView`); that flow has no frame of its own and
/// the picker is the smaller thing there.
///
/// **Nothing here gates anything.** A device with no camera, a refused permission and a capture that
/// fails all land on a state the screen can explain, and the task behind it is still skippable —
/// `AD-2` means a task never blocks a walk, and that has to stay true of the one screen that depends
/// on hardware.
///
/// The session runs off the main actor because `AVCaptureSession.startRunning` blocks; the published
/// state does not, which is why the class is `@MainActor` and only the session work hops off it.
@MainActor
@Observable
final class CameraSession {

    /// What the screen has to draw. One enum rather than three booleans, because the states are
    /// exclusive and a screen showing two of them at once is a bug that compiles.
    enum State: Equatable {
        /// Before `start()` — and while the system prompt is on screen.
        case idle
        case running
        /// No capture device at all: the Simulator, or an iPad with the camera restricted.
        case unavailable
        /// `AVAuthorizationStatus.denied` or `.restricted`. iOS shows its prompt once, so the screen
        /// points at Settings rather than asking again.
        case denied
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Whether the 2× badge is on. The frame draws a single badge rather than a scale, so this is a
    /// toggle rather than a factor — and the factor it toggles to is clamped to what the device
    /// actually offers.
    private(set) var isZoomedIn = false
    private(set) var flashMode: AVCaptureDevice.FlashMode = .off

    /// Exposed so the preview layer can be attached. `nonisolated(unsafe)` is not needed: the layer
    /// is only ever read on the main actor, and `AVCaptureSession` is documented as safe to attach
    /// to a layer from there.
    let session = AVCaptureSession()

    private var device: AVCaptureDevice?
    private let output = AVCapturePhotoOutput()
    private var captureDelegate: PhotoCaptureDelegate?
    /// Everything that touches the session is serialized here; `startRunning` blocks for long enough
    /// to drop frames on the main thread.
    private let queue = DispatchQueue(label: "kultara.camera.session")

    var isFlashAvailable: Bool { device?.isFlashAvailable ?? false }

    /// The factor the badge switches to, clamped to the device. A wide-angle iPhone tops out well
    /// past 2, but a device that does not reach it must not be asked for it.
    private var zoomedFactor: CGFloat {
        min(2, device?.activeFormat.videoMaxZoomFactor ?? 1)
    }

    // MARK: Lifecycle

    /// Asks for access if it has not been asked for, configures the session, and starts it.
    ///
    /// Safe to call more than once — the screen calls it from `task`, which re-runs on every
    /// appearance.
    func start() async {
        guard AVCaptureDevice.default(for: .video) != nil else {
            state = .unavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                state = .denied
                return
            }
        case .denied, .restricted:
            state = .denied
            return
        @unknown default:
            state = .denied
            return
        }
        configureIfNeeded()
        guard state != .failed("") else { return }
        let session = session
        await withCheckedContinuation { continuation in
            queue.async {
                if !session.isRunning { session.startRunning() }
                continuation.resume()
            }
        }
        if case .failed = state { return }
        state = .running
    }

    func stop() {
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    private func configureIfNeeded() {
        guard device == nil else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            state = .failed("No capture input")
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        self.device = device
    }

    // MARK: The frame's two controls

    /// `1:4697` — the 2× badge.
    func toggleZoom() {
        guard let device else { return }
        let target = isZoomedIn ? 1 : zoomedFactor
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = target
            device.unlockForConfiguration()
            isZoomedIn.toggle()
        } catch {
            // A zoom that will not take is not worth interrupting a walk for: the picture is still
            // takeable at 1×.
        }
    }

    /// `1:4702` — the flash. Held here rather than on the device because it is a per-shot setting on
    /// `AVCapturePhotoSettings`, not device state.
    func toggleFlash() {
        flashMode = flashMode == .on ? .off : .on
    }

    // MARK: Capture

    /// `1:4699` — the shutter. Returns `nil` when the capture fails, which the screen treats the
    /// same way it treats a cancel: nothing is written and the task is still open.
    func capture() async -> UIImage? {
        guard case .running = state else { return nil }
        let settings = AVCapturePhotoSettings()
        if output.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        }
        return await withCheckedContinuation { continuation in
            let delegate = PhotoCaptureDelegate { image in
                continuation.resume(returning: image)
            }
            // Held on `self`: `capturePhoto(with:delegate:)` does not retain its delegate, and a
            // delegate released between the shutter and the callback is a capture that never
            // returns — which here would be an `await` that never resumes.
            captureDelegate = delegate
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }
}

/// One shot, one delegate. `AVCapturePhotoCaptureDelegate` is a callback protocol with no completion
/// handler form, so this is the adapter that turns it into one.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (UIImage?) -> Void
    /// `photoOutput(_:didFinishProcessingPhoto:error:)` fires once per shot, but a delegate that
    /// resumed a continuation twice would trap, so the guarantee is held here rather than assumed.
    private var hasFinished = false

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        guard !hasFinished else { return }
        hasFinished = true
        guard error == nil, let data = photo.fileDataRepresentation() else {
            return completion(nil)
        }
        completion(UIImage(data: data))
    }
}
