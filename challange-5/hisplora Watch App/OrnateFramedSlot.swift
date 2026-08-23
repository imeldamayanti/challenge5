//
//  OrnateFramedSlot.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit

/// The gold frame with a picture set into it, as `91:182` and `670:1832` both draw it.
///
/// **This is one drawing's geometry, not shared chrome.** `s14` D2 is still in force and still
/// worth reading: the notification long look and the watch app's own screen are different places
/// and get different designs — different grounds, different type, different closing lines. What
/// the two now have in common is the *frame*, because the new board (`670:1832`) puts the same
/// export on the long look that `91:182` already had on the screen. Two copies of nine measured
/// fractions is two places for the next re-export to be applied in half; the ground and the words
/// stay where they belong, with each screen.
struct OrnateFramedSlot: View {

    /// The photograph a sidequest ships, or `nil` for the flat fill.
    let heroImage: UIImage?

    /// From Figma `91:182` / `670:1834` — the two frames place the group identically.
    enum Metrics {
        /// `Group 103` is 99 wide in a 205-wide card, with aspect 99/116.
        static let widthFraction: CGFloat = 99.0 / 205.0
        static let aspectRatio: CGFloat = 99.0 / 116.0
        /// `image 22`, the slot the photo fills, is 71.69 × 91.45 inside the 99 × 116 group and
        /// centred at (15.5 + 71.69/2, 13.275 + 91.45/2).
        static let slotWidthFraction: CGFloat = 71.68751525878906 / 99.0
        static let slotHeightFraction: CGFloat = 91.44999694824219 / 116.0
        static let slotCentre = UnitPoint(x: 0.5191, y: 0.5087)
    }

    private static let slotFill = Color(hex: 0x804A34)

    /// The slot is drawn *behind* the frame and deliberately overshoots the frame's visible
    /// aperture: `image 22` is 0.724 × 0.788 of the group, while the PNG's transparent oval
    /// measures 0.640 × 0.679 of the file. That gap is the bevel, and a photo sized to the
    /// aperture instead of the slot would leave a hairline of ground showing around its edge.
    var body: some View {
        GeometryReader { proxy in
            let box = proxy.size
            ZStack {
                slot
                    .frame(width: box.width * Metrics.slotWidthFraction,
                           height: box.height * Metrics.slotHeightFraction)
                    .clipShape(Ellipse())
                    .position(x: box.width * Metrics.slotCentre.x,
                              y: box.height * Metrics.slotCentre.y)
                // `.scaledToFill()` plus `.clipped()` reproduces what Figma does with this fill:
                // the PNG's own aspect is 447/558 = 0.801 against the 0.853 box it is placed in,
                // and the file is cropped top and bottom rather than stretched — measured, not
                // assumed.
                Image("OrnateFrame")
                    .resizable()
                    .scaledToFill()
                    .frame(width: box.width, height: box.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
        }
    }

    /// `FR-WATCH-06` — a flat brand-palette fill, never a likeness this app invented, unless a
    /// future content update ships a real, sourced, cited `heroImageAsset`. Every sidequest today
    /// has none, which is why both frames' painted portrait is **not** packaged: it is the same
    /// unsourced likeness `docs/hisplora-tokens.md` already carries as a blocker on the History
    /// page, and shipping it here would spread the problem rather than draw a picture.
    @ViewBuilder
    private var slot: some View {
        if let heroImage {
            Image(uiImage: heroImage)
                .resizable()
                .scaledToFill()
                .accessibilityLabel("Photo of the place this sidequest is about")
        } else {
            Self.slotFill.accessibilityHidden(true)
        }
    }
}

/// `670:1841` — four concentric rings bleeding off the card's top-right corner.
///
/// Drawn rather than packaged: the export is four annuli of one colour on one centre, and a PNG of
/// that is bytes in every watch build for something four `Circle().stroke`s describe exactly. The
/// stroke thins outward, which is the whole of the ornament's character.
struct NotificationRingPattern: View {

    /// Mid-radius and stroke width of each ring, as fractions of the 107-unit box `670:1841` draws
    /// it in — read off the export's own inner and outer radii.
    private static let rings: [(radius: CGFloat, width: CGFloat)] = [
        (21.357 / 107, 2.990 / 107),
        (32.036 / 107, 2.136 / 107),
        (42.715 / 107, 1.281 / 107),
        (53.393 / 107, 0.214 / 107),
    ]

    /// `#B44934` at 5%. The same red `DesignSystem.HisploraPalette.mapMarker` carries — restated
    /// here because this target links neither that package nor any other (`SideQuestLongLookView`
    /// says why).
    private static let ink = Color(hex: 0xB44934)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(Array(Self.rings.enumerated()), id: \.offset) { _, ring in
                    Circle()
                        .stroke(Self.ink, lineWidth: ring.width * side)
                        .frame(width: ring.radius * 2 * side, height: ring.radius * 2 * side)
                }
            }
            .frame(width: side, height: side)
            .opacity(0.05)
        }
        .accessibilityHidden(true)
    }
}
