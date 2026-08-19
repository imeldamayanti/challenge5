//
//  SideQuestLongLookView.swift
//  hisplora Watch App
//

import SwiftUI
import UIKit

/// `s9` Phase B, `FR-WATCH-05` — the custom long-look card a sidequest-nearby notification expands
/// into. Takes already-resolved values, not a `UNNotification`, so it stays previewable and testable
/// in isolation from `SideQuestNotificationController` (see
/// `.claude/plans/sidequest/s10-long-look-card-design.md`).
///
/// Matches Figma `91:182` ("Example/Notifications kanan"). That frame's own image layer is named
/// `ChatGPT Image Aug 13, 2026 at 09_35_01 AM 1` — an AI-generated asset. Inspecting the downloaded
/// PNG (`OrnateFrame.png`) confirmed it is *only* the decorative gold border with a fully transparent
/// oval cutout — no portrait is baked in, so it carries none of the `FR-CP-05`/`FR-WATCH-06`
/// unsourced-likeness risk `docs/hisplora-tokens.md` flags for a *different* frame. The oval still
/// renders the same flat brand-palette fill as before when there's no `heroImage` — this frame is
/// decoration around that placeholder, not a replacement for the no-likeness rule.
struct SideQuestLongLookView: View {
    let synopsis: String
    let heroImage: UIImage?

    /// `OrnateFrame.png` is 447×558 — lock the displayed frame to that ratio so the hole-fraction
    /// math below (measured directly off the asset's alpha channel) stays correct at any size.
    private let frameWidth: CGFloat = 92
    private let frameAspectRatio: CGFloat = 447.0 / 558.0
    private var frameHeight: CGFloat { frameWidth / frameAspectRatio }
    /// The frame's transparent oval, as a fraction of the asset's own bounds — measured by scanning
    /// `OrnateFrame.png`'s alpha channel outward from center, not eyeballed off the screenshot.
    private let holeWidthFraction: CGFloat = 0.6465
    private let holeHeightFraction: CGFloat = 0.6846

    var body: some View {
        VStack(spacing: 10) {
            imageSlot
            Text(synopsis)
                .font(.footnote)
                .foregroundStyle(Color(hex: 0x151311))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: 0xFDF2DE), Color(hex: 0x9C692E)],
                startPoint: .top, endPoint: .bottom)
        )
    }

    @ViewBuilder
    private var imageSlot: some View {
        ZStack {
            // `FR-WATCH-06` — a flat brand-palette fill, never a photo or a likeness, unless a
            // future content update sets a real (sourced, cited) `heroImageAsset`. This is the
            // state every sidequest renders today, and the fallback for any attachment-load
            // failure (see `loadHeroImage` in `SideQuestNotificationController.swift`).
            Group {
                if let heroImage {
                    Image(uiImage: heroImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(hex: 0x804A34)
                }
            }
            .frame(width: frameWidth * holeWidthFraction, height: frameHeight * holeHeightFraction)
            .clipShape(Ellipse())

            Image("OrnateFrame")
                .resizable()
                .frame(width: frameWidth, height: frameHeight)
        }
        .frame(width: frameWidth, height: frameHeight)
    }
}

extension Color {
    /// `0xRRGGBB`, opaque. A local equivalent of `DesignSystem`'s palette tokens — not a link to that
    /// package, which does not build for watchOS (see the design spec's Architecture section for why).
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview("Placeholder — no heroImageAsset") {
    SideQuestLongLookView(
        synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
        heroImage: nil)
}

#Preview("With image") {
    SideQuestLongLookView(
        synopsis: "Puri Agung Pemecutan menyimpan jejak salah satu dari empat wajah Badung.",
        heroImage: UIImage(systemName: "photo.fill"))
}
