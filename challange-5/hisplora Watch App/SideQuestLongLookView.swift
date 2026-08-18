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
struct SideQuestLongLookView: View {
    let synopsis: String
    let heroImage: UIImage?

    let imageSlotSize: CGFloat = 64

    var body: some View {
        VStack(spacing: 8) {
            imageSlot
            Text(synopsis)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private var imageSlot: some View {
        if let heroImage {
            Image(uiImage: heroImage)
                .resizable()
                .scaledToFill()
                .frame(width: imageSlotSize, height: imageSlotSize)
                .clipShape(Circle())
        } else {
            // `FR-WATCH-06` — a flat brand-palette fill, never a photo or a likeness. This is the
            // state every sidequest renders today (none carry `heroImageAsset` yet), and it is also
            // the fallback for any attachment-loading failure (see `loadHeroImage` in
            // `SideQuestNotificationController.swift`).
            Circle()
                .fill(Color(hex: 0x804A34))
                .frame(width: imageSlotSize, height: imageSlotSize)
        }
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
