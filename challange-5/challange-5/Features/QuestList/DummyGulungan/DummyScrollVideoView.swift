import AVFoundation
import SwiftUI

/// DUMMY / TRY-OUT ONLY — not wired into the real quest run flow. Plays `gulungan.mov` once and
/// freezes on its last frame, so the scroll "unrolls" and stays open rather than looping back to
/// rolled-up. Exists to preview the video asset in place of `StoryTransitionScreen`'s static PNG
/// before deciding whether to bring it into the real flow.
struct DummyScrollVideoView: UIViewRepresentable {
    final class PlayerContainerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        // Full-bleed background, not a framed clip — the other elements sit on top of it.
        view.playerLayer.videoGravity = .resizeAspectFill
        guard let url = Bundle.main.url(forResource: "gulungan", withExtension: "mov") else {
            return view
        }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        view.playerLayer.player = player
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}
}
