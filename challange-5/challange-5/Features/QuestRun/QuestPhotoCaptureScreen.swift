import AVFoundation
import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The camera — Figma `1:4681` ("Camera").
///
/// **Reached only from a photo task.** Four of the five shipped checkpoints carry a written
/// reflection or a question; `badung-catur-muka` is the one with a `photo` task, and `FR-TASK-06`
/// drops even that one at a Place where photography is prohibited. So this screen exists behind a
/// single control on `TaskDetailScreen` and is never part of a written task's path.
///
/// **It is on the museum theme's opposite: no theme at all.** The frame is a full-bleed preview under
/// a translucent black bar, which is the system camera's own language rather than either of this
/// app's two visual directions. Reproduced as drawn — a `HisploraStage` behind a live preview would
/// be brown nobody ever sees.
///
/// **Nothing here gates the task.** No capture device, a refused permission and a failed shot all
/// land on a legible state with a way out, and the task behind this screen is still resolvable by
/// skipping (`AD-2`, `FR-TASK-02`). That is why the two failure states carry the skip rather than
/// only a cross.
struct QuestPhotoCaptureScreen: View {
    let language: ContentLanguage
    /// Handed the captured image. Writing it is the view model's job — this screen owns the device,
    /// not the walker's records.
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    /// `FR-TASK-02`, offered from the two states where no photograph is possible. A screen that can
    /// only be left backwards would make a hardware failure feel like a locked door.
    let onSkip: () -> Void

    @State private var camera = CameraSession()
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            preview
            unavailableNotice
            VStack(spacing: 0) {
                navigationBar
                Spacer(minLength: 0)
                controls
            }
        }
        .preferredColorScheme(.dark)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    // MARK: The preview

    @ViewBuilder private var preview: some View {
        if case .running = camera.state {
            CameraPreviewLayer(session: camera.session)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }

    /// The two states with no picture behind them: no device, and access refused. Both are ordinary
    /// outcomes rather than errors, so both are sentences and a skip rather than an alert.
    @ViewBuilder private var unavailableNotice: some View {
        switch camera.state {
        case .unavailable, .denied, .failed:
            VStack(spacing: KultaraMetrics.lg) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityHidden(true)
                Text(noticeText)
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(UIStrings.string(.taskSkipAction, language), action: onSkip)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, KultaraMetrics.xl)
                    .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    .background(.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.7),
                                              lineWidth: KultaraMetrics.hairline))
            }
            .padding(.horizontal, 40)
        case .idle, .running:
            EmptyView()
        }
    }

    private var noticeText: String {
        switch camera.state {
        case .denied: UIStrings.string(.cameraDenied, language)
        case .failed(let reason): reason
        default: UIStrings.string(.cameraUnavailable, language)
        }
    }

    // MARK: `1:4684` — the bar

    /// The frame's 128-point bar: a 70%-black blur under the status bar, the title centred at 19
    /// points, and the cross in the trailing corner.
    ///
    /// The title is an overlay on the row rather than its middle column, for the same reason
    /// `TaskDetailScreen`'s is: with a 44-point control on one side and nothing on the other, a
    /// three-column row centres the title on the space between them rather than on the screen.
    private var navigationBar: some View {
        HStack {
            Spacer(minLength: 0)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: KultaraMetrics.minimumTapTarget,
                           height: KultaraMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(UIStrings.string(.cameraClose, language))
        }
        .overlay {
            Text(UIStrings.string(.cameraTitle, language))
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, KultaraMetrics.minimumTapTarget)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(alignment: .top) {
            // The frame paints the bar up under the status bar, so the material has to reach past
            // the safe area the row itself respects.
            Color.black.opacity(0.7)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(height: KultaraMetrics.hairline)
                }
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: `1:4695` — the shutter row

    /// The 2× badge, the shutter and the flash, 366 points apart as `1:4696` sets them.
    ///
    /// Drawn rather than exported. Figma ships the shutter and the flash as SVGs, but the shutter is
    /// two concentric circles and the flash is a bolt in a translucent disc — both are geometry with
    /// a state, not glyphs: the flash has to change appearance when it is on, and a flat export
    /// cannot. `HisploraStampShape` records the same argument for the perforation. The cross above
    /// and the bolt here are SF Symbols, which is what Figma itself emits for the equivalent marks on
    /// the sibling frames (`1:4832`, `1:4853`).
    @ViewBuilder private var controls: some View {
        if case .running = camera.state {
            HStack {
                zoomBadge
                Spacer(minLength: 0)
                shutter
                Spacer(minLength: 0)
                flashBadge
            }
            .frame(maxWidth: 366)
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }

    private var zoomBadge: some View {
        Button { camera.toggleZoom() } label: {
            Text(camera.isZoomedIn ? "1x" : "2x")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(camera.isZoomedIn ? 1 : 0.7))
                .frame(width: 49, height: 49)
                .background(.black.opacity(0.7), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(UIStrings.string(
            camera.isZoomedIn ? .cameraZoomOut : .cameraZoomIn, language))
    }

    /// `1:4699` — a 73.6-point ring with a filled disc inside it.
    private var shutter: some View {
        Button {
            guard !isCapturing else { return }
            isCapturing = true
            Task {
                defer { isCapturing = false }
                if let image = await camera.capture() { onCapture(image) }
            }
        } label: {
            ZStack {
                Circle().stroke(.white, lineWidth: 4).frame(width: 73.65, height: 73.65)
                Circle().fill(.white).frame(width: 59, height: 59)
                    .opacity(isCapturing ? 0.4 : 1)
            }
            .frame(width: 73.65, height: 73.65)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isCapturing)
        .accessibilityLabel(UIStrings.string(.cameraShutter, language))
    }

    @ViewBuilder private var flashBadge: some View {
        if camera.isFlashAvailable {
            let isOn = camera.flashMode == .on
            Button { camera.toggleFlash() } label: {
                Image(systemName: isOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isOn ? .black : .white)
                    .frame(width: 49, height: 49)
                    .background(isOn ? AnyShapeStyle(.yellow)
                                     : AnyShapeStyle(.black.opacity(0.7)), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(UIStrings.string(isOn ? .cameraFlashOff : .cameraFlashOn, language))
        } else {
            // The frame's own box, so the shutter stays centred on a device with no flash.
            Color.clear.frame(width: 49, height: 49)
        }
    }
}

/// `AVCaptureVideoPreviewLayer` in a SwiftUI view. There is no SwiftUI-native camera preview as of
/// iOS 18, which is the same gap `CameraCaptureView` records for the picker.
private struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        // Fill: the preview is what the walker frames the shot in, and letterboxing it would show
        // them less than the photograph will contain.
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.previewLayer.session !== session { uiView.previewLayer.session = session }
    }

    /// A `UIView` whose backing layer *is* the preview layer, so the layer resizes with the view
    /// instead of needing a frame set in `layoutSubviews`.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
