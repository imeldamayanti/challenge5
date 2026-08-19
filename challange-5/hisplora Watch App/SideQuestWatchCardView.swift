//
//  SideQuestWatchCardView.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit

/// `s14` Phase 2 — the card the **watch app's own screen** shows once a walker taps "Open in App"
/// on a sidequest notification. Renders Figma `91:182` ("Example/Notifications kanan"): a tan-to-cream
/// ground, the ornate gold frame around the sidequest's image slot, the synopsis, and a line saying
/// where the rest of it is.
///
/// Deliberately **not** `SideQuestLongLookView`. That one is `91:176`'s radar and stays the
/// notification long-look; this one is the screen you arrive at. `s12` planned to reuse the long-look
/// here "so the notification and the in-app card look identical" and the user reversed it (`s14` D2):
/// a card you glanced at and a screen you navigated to are different places. The two share only the
/// `(synopsis, heroImage)` pair — same initialiser shape so `ContentView` can hold either, no shared
/// chrome. Keep it that way.
struct SideQuestWatchCardView: View {
    let synopsis: String
    let heroImage: UIImage?

    /// Read once, for the same reason `SideQuestLongLookView` reads it: fractions of the card are the
    /// unit every figure below is expressed in, and nothing in SwiftUI hands them over for free.
    @State private var cardWidth: CGFloat = 0

    /// From Figma `91:182` — node metadata for geometry, pixel sampling of the render for colour,
    /// metadata winning where they disagree (`s14` Global Constraints).
    private enum Metrics {
        /// `Group 103` is 99 wide in a 205-wide frame, with aspect 99/116.
        static let frameWidthFraction: CGFloat = 99.0 / 205.0
        static let frameAspectRatio: CGFloat = 99.0 / 116.0
        /// The frame sits 24 units below the card's top edge. Figma measures that against the card's
        /// *height*, but this view is laid out inside a scroll view, where reading the height back
        /// would make the padding depend on the content it pads — so it is expressed against the
        /// width instead, off the same 205-unit frame. Same distance, no layout loop.
        static let frameTopInsetFraction: CGFloat = 24.0 / 205.0
        /// `image 22`, the slot the photo fills, is 71.69 × 91.45 inside the 99 × 116 group and
        /// centred at (15.5 + 71.69/2, 13.275 + 91.45/2).
        static let slotWidthFraction: CGFloat = 71.68751525878906 / 99.0
        static let slotHeightFraction: CGFloat = 91.44999694824219 / 116.0
        static let slotCentre = UnitPoint(x: 0.5191, y: 0.5087)
    }

    /// `91:182`'s ground, sampled down the centre column. Exposed rather than applied here: see
    /// `sideQuestCardGround()` below for why the screen paints it and this view does not.
    static let ground = LinearGradient(
        colors: [Color(hex: 0xD0B28D), Color(hex: 0xFCF2DE)],
        startPoint: .top, endPoint: .bottom)

    private static let ink = Color(hex: 0x151311)
    /// The caption's ink. Subordinate to the synopsis, which is what `s14` asked `.secondary` for —
    /// but `.secondary` on watchOS resolves against the platform's dark default, and measured on a
    /// 46 mm simulator it rendered at **1.05:1** on this cream ground: present in the layout,
    /// invisible to read. At 0.65 the same ink measures 5.5:1 against `#FCF2DE`, the end of the
    /// gradient the caption actually sits over. `NFR-A11Y-03` — contrast is measured here, not
    /// reviewed, and this ground is exactly the one CLAUDE.md records shipping a real contrast bug on.
    private static let captionInk = Color(hex: 0x151311).opacity(0.65)
    private static let slotFill = Color(hex: 0x804A34)

    var body: some View {
        VStack(spacing: 12) {
            framedSlot
                .frame(width: frameWidth, height: frameWidth / Metrics.frameAspectRatio)
                .padding(.top, cardWidth * Metrics.frameTopInsetFraction)
            Text(synopsis)
                .font(.footnote)
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(.center)
            handoffCaption
        }
        .padding(.horizontal)
        .padding(.bottom)
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
    }

    private var frameWidth: CGFloat { cardWidth * Metrics.frameWidthFraction }

    /// The slot is drawn *behind* the frame and deliberately overshoots the frame's visible aperture:
    /// `image 22` is 0.724 × 0.788 of the group, while the PNG's transparent oval measures 0.640 ×
    /// 0.679 of the file. That gap is the bevel, and a photo sized to the aperture instead of the
    /// slot would leave a hairline of ground showing around its edge.
    private var framedSlot: some View {
        GeometryReader { proxy in
            let box = proxy.size
            ZStack {
                slot
                    .frame(width: box.width * Metrics.slotWidthFraction,
                           height: box.height * Metrics.slotHeightFraction)
                    .clipShape(Ellipse())
                    .position(x: box.width * Metrics.slotCentre.x,
                              y: box.height * Metrics.slotCentre.y)
                // `.scaledToFill()` plus `.clipped()` reproduces what Figma does with this fill: the
                // PNG's own aspect is 447/558 = 0.801 against the 0.853 box it is placed in, and the
                // file is cropped top and bottom rather than stretched — measured, not assumed.
                Image("OrnateFrame")
                    .resizable()
                    .scaledToFill()
                    .frame(width: box.width, height: box.height)
                    .clipped()
                    .accessibilityHidden(true)
            }
        }
    }

    /// `FR-WATCH-06` — a flat brand-palette fill, never a likeness this app invented, unless a future
    /// content update ships a real, sourced, cited `heroImageAsset`. Every sidequest today has none.
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

    /// `91:182` draws this as a filled dark-brown ground pinned to the bottom edge with centred text,
    /// which on watchOS is the platform's own signature for the primary action button. Anything
    /// wearing that shape gets tapped, whatever it says — and there is nothing here to tap: the
    /// notification-tap path that would hand off to the iPhone does not exist (`s12`'s finding, and
    /// why `FR-WATCH-07` is still open). So the ground, the edge-pinning and the centring are all
    /// dropped and what remains is a caption (`s14` D3).
    ///
    /// It is a plain `Text`, and that is load-bearing. A `Button` would be tappable; a
    /// `.disabled(true)` one would still be announced as "dimmed button", which is worse than saying
    /// nothing; a capsule or a `.background` would put the button shape back. Plain text is skipped
    /// by the AssistiveTouch cursor on its own, which is exactly the intent.
    ///
    /// The wording is a statement, not `91:182`'s literal "Open in Iphone App" (`s14` D4). An
    /// imperative verb reads as an instruction to act *here*, and there is nothing here to act on;
    /// saying where the thing is makes no promise this screen cannot keep.
    ///
    /// **Do not restore the bar.** If you are here because it looks unfinished against the Figma
    /// frame, that is the deviation working as intended.
    private var handoffCaption: some View {
        HStack(spacing: 4) {
            Image(systemName: "iphone")
            Text("The full story is on your iPhone")
        }
        .font(.footnote)
        .foregroundStyle(Self.captionInk)
        .multilineTextAlignment(.center)
    }
}

extension View {
    /// Paints `91:182`'s ground behind a whole screen. It goes here rather than inside
    /// `SideQuestWatchCardView` because the card scrolls: a `ScrollView` clips its content's
    /// background to the content, so `.ignoresSafeArea()` applied in there cannot reach past the
    /// inset watchOS reserves for the always-visible clock, and a black band sits across the top of
    /// an otherwise edge-to-edge design. Painting behind the scroll view instead also holds the
    /// gradient still while the card moves over it, which is the behaviour you want anyway.
    func sideQuestCardGround() -> some View {
        background { SideQuestWatchCardView.ground.ignoresSafeArea() }
    }
}

#Preview("Placeholder — no heroImageAsset") {
    ScrollView {
        SideQuestWatchCardView(
            synopsis: "You're on a battlefield. The last tale of Badung.",
            heroImage: nil)
    }
    .sideQuestCardGround()
}

#Preview("With image") {
    ScrollView {
        SideQuestWatchCardView(
            synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
            heroImage: UIImage(systemName: "photo.fill"))
    }
    .sideQuestCardGround()
}
