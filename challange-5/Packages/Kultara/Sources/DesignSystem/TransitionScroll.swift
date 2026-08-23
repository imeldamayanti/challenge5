import SwiftUI

/// The sealed scroll the transition screen offers — Figma `293:1595`, layer `293:1599`.
///
/// Packaged with the design system rather than authored as content, on the same argument the
/// typewriter's machine and the portrait frame's ornament are: it is one object drawn for every
/// quest, it depicts a thing rather than a person or a place, and it makes no claim that
/// `FR-CP-05` would want a source for.
///
/// **The picture is the raw source, and the turn is applied in code.** `293:1599` draws the scroll
/// turned 41.6°, and Figma will happily export that node pre-turned — but its export bakes the
/// board's grey ground into the PNG's alpha, which lands on this screen as a grey rectangle around
/// the scroll. The uploaded source image is the one with a real cut-out, so that is what ships and
/// `rotationDegrees` does the rest.
///
/// **Provenance.** A generated image exported from the design file. Like its two siblings, that is
/// a licence question to answer rather than an editorial one, recorded here so it stays answerable.
public enum TransitionScrollMetrics {

    /// The picture's own proportions before the turn, `264.247 × 252.026` as `293:1599` places it.
    public static let aspectRatio: CGFloat = 264.247 / 252.026

    /// How wide the untuned picture is against the screen: 264.247 of a 402-point frame.
    public static let widthFraction: CGFloat = 264.247 / 402.0

    /// `293:1599`'s `rotate-[41.6deg]`.
    public static let rotationDegrees: Double = 41.6

    /// The box the turned picture occupies, `364.93 × 363.905` — very nearly square, and held as
    /// the frame's real ratio rather than rounded to 1. `rotationEffect` does not resize the view
    /// it turns, so the layout needs this separately from the picture's own size.
    public static let boxWidthFraction: CGFloat = 364.93 / 402.0
    public static let boxAspectRatio: CGFloat = 364.93 / 363.905

    /// The width to give the *untumed* picture so the level roll it draws is `turned` points long.
    ///
    /// **This is the difference between the frame you set and the object the reader sees, and
    /// getting it wrong is a 38% error.** The asset draws its roll on a diagonal across a
    /// 264.247 × 252.026 canvas and `rotationDegrees` stands it level, so the roll's *length* is the
    /// canvas's diagonal extent — 364.93 — not the canvas's width. Framing the canvas at the task
    /// sheet's 362 therefore drew a roll about 500 points long on a 402-point screen: the transition
    /// grew the scroll far past the sheet it was about to become, which is what "kebesaran" was.
    ///
    /// At rest the two happen to agree — the frame draws the canvas at 264.247, which presents a
    /// 364.93-long roll, and the sheet is 362 wide — so the honest consequence of this correction is
    /// that `widening` barely changes the roll's size at all. That is right: what that beat is
    /// actually for is the roll leaving the screen's centre line and settling into the sheet's box.
    public static func canvasWidth(forTurnedWidth turned: CGFloat) -> CGFloat {
        turned * (widthFraction / boxWidthFraction)
    }

    public static let image: Image? = {
        #if canImport(UIKit)
        guard let url = imageURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }()

    static var imageURL: URL? {
        Bundle.module.url(
            forResource: "transition-scroll", withExtension: "png", subdirectory: "Images")
    }

    /// Whether the packaged scroll resolved. Exposed for the same reason
    /// `PortraitFrameMetrics.ornamentIsAvailable` and `StoryIllustrationMetrics.isAvailable` are: a
    /// dropped resource should fail a test, not ship a blank screen.
    public static var isAvailable: Bool { imageURL != nil }
}
