//
//  SideQuestLongLookView.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit

/// `s9` Phase B / `s14` Phase 1, `FR-WATCH-05` — the custom long-look card a sidequest-nearby
/// notification expands into. Takes already-resolved values, not a `UNNotification`, so it stays
/// previewable in isolation from `SideQuestNotificationController`.
///
/// Renders Figma `91:176` ("Example/Notifications kiri"): a cream ground, a brown radar disc with a
/// faint crosshair and two concentric rings, and the synopsis under it.
///
/// **The watch app's own screen is a different design and stays different.** That one is `91:182`'s
/// gold frame, in `SideQuestWatchCardView`. A notification you glanced at and a screen you navigated
/// to are different places (`s14` D1/D2); the earlier `s12` plan assumed they should look identical
/// and the user overturned it. The two views share only the `(synopsis, heroImage)` pair they both
/// take — do not factor their chrome into a common component "for consistency".
struct SideQuestLongLookView: View {
    let synopsis: String
    let heroImage: UIImage?

    /// Sampled from the Figma render of `91:176` (a 205×251 frame) on 2026-08-19, not carried over
    /// from `s10`/`s11`/`s13` — every figure those recorded for the *previous* design was measured
    /// against a file that does not exist. See `s14`'s Context section.
    private enum Metrics {
        /// Fraction of the card's width. A fraction rather than a point value because watch case
        /// widths differ: `s13` specified a fixed 128pt slot, which is ~70% of the content width on
        /// a 46 mm watch against this frame's 55%, so a fixed number can be right on one size only.
        static let discWidthFraction: CGFloat = 0.55
        /// The two concentric rings, as fractions of the disc's diameter — found as the two peaks in
        /// the render's radial lightness profile, at 0.525 and 0.75 of the radius.
        static let ringFractions: [CGFloat] = [0.525, 0.75]
        /// The crosshair and the rings are one hairline wide at the frame's own scale (1 unit of
        /// 112.6), so it is expressed relative to the disc.
        static let graticuleWidthFraction: CGFloat = 1.0 / 112.6
        /// The centre symbol's *visible* circle, as a fraction of the disc diameter. Measured off
        /// the render (28px of 116). Figma's icon frame is 31% — larger, because that is the glyph's
        /// em box rather than the circle drawn inside it, and `.resizable().scaledToFit()` sizes the
        /// drawn bounds, not the em box.
        static let symbolCircleFraction: CGFloat = 0.24
        /// The graticule measures 4% cream over the brown in the render. Drawn a shade stronger,
        /// because a 4% hairline all but disappears once the card is on a real display — but only a
        /// shade: 0.09 was tried first and measured 2.3× the frame's contrast on a 46 mm simulator,
        /// which turns subordinate detail into the loudest thing on the card. This is the one
        /// deliberate deviation from the sampled values here.
        static let graticuleOpacity: CGFloat = 0.05
    }

    /// The card's own width, read once. `containerRelativeFrame(.horizontal)` — which `s14`
    /// specifies — sets a width but cannot set the matching height, so the square has to come from
    /// `.aspectRatio(1, .fit)`, and a VStack short on vertical space then shrinks the disc below the
    /// 55% the frame calls for: measured at 44.5% of the screen width on a 46 mm simulator. Reading
    /// the width and setting an explicit square frame is what actually holds the sampled proportion.
    /// The fraction is still a fraction — the constraint `s14` cared about — just an enforced one.
    @State private var cardWidth: CGFloat = 0

    private static let ground = Color(hex: 0xFCF5E8)
    private static let disc = Color(hex: 0x804A34)
    private static let ink = Color(hex: 0x151311)

    /// Figma node `91:180` is a text node whose content is the single character U+10077D — an SF
    /// Symbol as a private-use glyph, which carries the picture but not the name.
    ///
    /// Resolved by measurement, not by eye: U+10077D is glyph 13796 (`uni10077D.medium`) in
    /// `SFSymbolsFallback.otf`, and that glyph shape-matches `figure.wave.circle.fill` at 0.9957
    /// correlation against all 8,302 names in CoreGlyphs' `symbol_order.plist` — the runner-up scores
    /// 0.8979, and every near-miss is a different `.circle.fill` sharing only the disc.
    ///
    /// The cream circle is *part of this glyph*, not a separate shape behind it: a `.circle.fill`
    /// variant composites as a filled disc with the figure knocked out, which is why one tinted
    /// `Image` replaces `s13`'s planned stack of a cream `Circle()` plus a figure on top.
    private static let centreSymbol = "figure.wave.circle.fill"

    var body: some View {
        VStack(spacing: 16) {
            imageSlot
                .frame(width: discDiameter, height: discDiameter)
            Text(synopsis)
                .font(.footnote)
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(.center)
            // No `lineLimit`: watchOS inherits the paired iPhone's text size and real walkers sit at
            // accessibility sizes. A limit here truncates the only content this card carries.
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Self.ground)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { cardWidth = $0 }
    }

    private var discDiameter: CGFloat { cardWidth * Metrics.discWidthFraction }

    /// One slot in two states, not a graphic bolted beside a photo well. A sidequest that ships a
    /// real, sourced `heroImageAsset` fills the disc with that photo; every sidequest today has none
    /// and gets the radar graphic instead (`FR-WATCH-06` — never a likeness this app invented). This
    /// is also the fallback for an attachment that fails to load, which on watchOS is common enough
    /// to be the expected case; see `loadHeroImage` in `SideQuestNotificationController.swift`.
    @ViewBuilder
    private var imageSlot: some View {
        if let heroImage {
            Image(uiImage: heroImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .accessibilityLabel("Photo of the place this sidequest is about")
        } else {
            radarDisc
        }
    }

    private var radarDisc: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(Self.disc)
                graticule(diameter: diameter)
                Image(systemName: Self.centreSymbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: diameter * Metrics.symbolCircleFraction)
                    .foregroundStyle(Self.ground)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        // Decoration standing in for an absent picture. Announcing it tells a VoiceOver user nothing;
        // without this the slot is read out by asset name, which tells them less than nothing. The
        // synopsis below is this card's real content and reads normally.
        .accessibilityHidden(true)
    }

    private func graticule(diameter: CGFloat) -> some View {
        let hairline = diameter * Metrics.graticuleWidthFraction
        return ZStack {
            ForEach(Metrics.ringFractions, id: \.self) { fraction in
                Circle()
                    .stroke(lineWidth: hairline)
                    .frame(width: diameter * fraction, height: diameter * fraction)
            }
            Rectangle().frame(width: diameter, height: hairline)
            Rectangle().frame(width: hairline, height: diameter)
        }
        .foregroundStyle(Self.ground.opacity(Metrics.graticuleOpacity))
        .clipShape(Circle())
    }
}

extension Color {
    /// `0xRRGGBB`, opaque. A local equivalent of `DesignSystem`'s palette tokens — not a link to that
    /// package, which does not build for watchOS (see the design spec's Architecture section for why).
    /// `SideQuestWatchCardView` uses this too; it lives here because this file came first.
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview("Placeholder — no heroImageAsset") {
    SideQuestLongLookView(
        synopsis: "This exact spot has a real history moment.",
        heroImage: nil)
}

#Preview("With image") {
    SideQuestLongLookView(
        synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
        heroImage: UIImage(systemName: "photo.fill"))
}
