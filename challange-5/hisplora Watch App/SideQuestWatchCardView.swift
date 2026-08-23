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

    // The gold frame's own measured fractions live in `OrnateFramedSlot` — `670:1832` put the
    // same drawing on the notification long look, and two copies of nine fractions is two places
    // for the next re-export to be applied in half.

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

    var body: some View {
        VStack(spacing: 12) {
            OrnateFramedSlot(heroImage: heroImage)
                .frame(width: frameWidth,
                       height: frameWidth / OrnateFramedSlot.Metrics.aspectRatio)
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

    private var frameWidth: CGFloat { cardWidth * OrnateFramedSlot.Metrics.widthFraction }

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
        // The icon sits to the left of the text, leveled against the *whole* wrapped block rather
        // than its first line — `alignment: .center` on the `HStack` does that automatically once
        // the text is left-aligned instead of centred; a centred multi-line text block next to a
        // left-hand icon is what read as lopsided before. Sized up a step from the text
        // (`.body` against `.footnote`) so it reads as a label, not an afterthought.
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "iphone")
                .font(.body)
            Text("The full story is on your iPhone")
                .font(.footnote)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Self.captionInk)
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
