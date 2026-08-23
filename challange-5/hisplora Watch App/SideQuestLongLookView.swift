//
//  SideQuestLongLookView.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit

/// `FR-WATCH-05` — the custom long-look card a sidequest-nearby notification expands into.
/// Takes already-resolved values, not a `UNNotification`, so it stays previewable in isolation from
/// `SideQuestNotificationController`.
///
/// Renders Figma **`670:1832`**: a tan-to-cream ground, the gold frame around the sidequest's image
/// slot, the synopsis under it, and four faint rings bleeding off the top-right corner.
///
/// > **This replaced `91:176`'s radar disc, and that reverses `s14` D1/D2.** Those decisions said
/// > the long look and the watch app's own screen are different places and get different designs —
/// > the radar for the notification, `91:182`'s gold frame for the screen — and the user had
/// > overturned an earlier plan to make them identical. The new board puts the gold frame on the
/// > notification too, so the radar is gone. The *principle* survives and is why the two files are
/// > still two files: the grounds, the type and the closing line differ, and only the frame's
/// > geometry is shared (`OrnateFramedSlot`). Do not merge them.
///
/// **The X and the "Open in App" bar the frame draws are not in here**, deliberately. watchOS draws
/// the dismiss control itself and renders the category's own actions below this content — and
/// `SideQuestNotificationCategory`'s "Open in App" action already exists on the phone side and is
/// registered here by `WatchSideQuestNotificationCategory`. Drawing either would put a second,
/// dead copy under the real one.
struct SideQuestLongLookView: View {
    let synopsis: String
    let heroImage: UIImage?

    /// `670:1832`'s ground, sampled down the centre column of the 205 × 251 frame.
    ///
    /// Darker at the top than `91:182`'s (`#D0B28D`), which is the board's change and not a
    /// resample error: the notification's ground carries the ornament, and the rings only read
    /// against something with some weight in it.
    private static let ground = LinearGradient(
        colors: [Color(hex: 0x9C692E), Color(hex: 0xFDF2DE)],
        startPoint: .top, endPoint: .bottom)

    private static let ink = Color(hex: 0x151311)

    /// Fractions of the card's width, from `670:1834`/`670:1837`/`670:1841`. Fractions rather than
    /// points because watch case widths differ — a figure that is right on a 41 mm is wrong on a
    /// 49 mm.
    private enum Metrics {
        /// The frame group sits 24 units below the card's top edge in a 205-wide frame. Measured
        /// against the *width* rather than the height: this view is laid out inside a scroll view,
        /// where reading the height back would make the padding depend on the content it pads.
        static let frameTopFraction: CGFloat = 24.0 / 205.0
        /// `670:1837` opens 140 units down, 12 of which is its own top padding.
        static let textTopFraction: CGFloat = 12.0 / 205.0
        /// `670:1841` is 107 wide and hangs 43 off the right edge and 50 above the top.
        static let patternSideFraction: CGFloat = 107.0 / 205.0
        static let patternRightFraction: CGFloat = -43.0 / 205.0
        static let patternTopFraction: CGFloat = -50.0 / 205.0
    }

    /// The card's own width, read once. Every figure above is a fraction of it, and nothing in
    /// SwiftUI hands that over for free.
    @State private var cardWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            OrnateFramedSlot(heroImage: heroImage)
                .frame(width: frameWidth, height: frameWidth / OrnateFramedSlot.Metrics.aspectRatio)
                .padding(.top, cardWidth * Metrics.frameTopFraction)
            Text(synopsis)
                .font(.footnote)
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(.center)
                .padding(.top, cardWidth * Metrics.textTopFraction)
            // No `lineLimit`: watchOS inherits the paired iPhone's text size and real walkers sit
            // at accessibility sizes. A limit here truncates the only content this card carries.
        }
        .padding(.horizontal)
        .padding(.bottom)
        .frame(maxWidth: .infinity)
        .background(alignment: .topTrailing) { pattern }
        .background(Self.ground)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
    }

    private var frameWidth: CGFloat { cardWidth * OrnateFramedSlot.Metrics.widthFraction }

    /// Drawn inside a `.background`, not a `.overlay`: `670:1841` sits under the card's content in
    /// the frame's z-order, and at 5% over a gradient the difference is visible the moment the
    /// synopsis wraps up beside it.
    ///
    /// It is clipped by the card, which is what makes it bleed off the corner rather than float.
    private var pattern: some View {
        NotificationRingPattern()
            .frame(width: cardWidth * Metrics.patternSideFraction,
                   height: cardWidth * Metrics.patternSideFraction)
            .offset(x: cardWidth * -Metrics.patternRightFraction,
                    y: cardWidth * Metrics.patternTopFraction)
    }
}

extension Color {
    /// `0xRRGGBB`, opaque. A local equivalent of `DesignSystem`'s palette tokens — not a link to
    /// that package, which does not build for watchOS (see the design spec's Architecture section
    /// for why). `SideQuestWatchCardView` and `OrnateFramedSlot` use this too; it lives here
    /// because this file came first.
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview("Placeholder — no heroImageAsset") {
    SideQuestLongLookView(
        synopsis: "You're on a battlefield. The last tale of Badung.",
        heroImage: nil)
}

#Preview("With image") {
    SideQuestLongLookView(
        synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
        heroImage: UIImage(systemName: "photo.fill"))
}
