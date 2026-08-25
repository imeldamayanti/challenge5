import ContentKit
import DesignSystem
import SwiftUI
import UIKit
import UIStringsKit

/// `921-2932` — the confirmation `WriteJournalScreen`'s Save lands on.
///
/// **"See Journey Recap" opens the walk's real Trip Summary, not a second screen built to hold the
/// same job.** `Letters.TripSummaryScreen` already renders exactly this — a walk's places, lore,
/// written answers, stamps and photographs, all from the Run's own snapshots — reached today
/// through the Journal's sealed envelope. `onSeeRecap` is a closure precisely so this screen does
/// not have to know *how* that screen is reached (switching tabs and opening the journal-letter
/// overlay is `KultaraRootView`'s concern, not this one's).
struct JourneySavedScreen: View {
    @Environment(\.dismiss) private var dismiss

    let language: ContentLanguage
    /// The entry `WriteJournalScreen` just saved, held rather than re-read off the Run: a Run
    /// carries only the photos' relative paths, and re-reading them back through `PhotoStore` here
    /// would be the one round trip this screen does not need to make.
    let text: String
    let placePhoto: UIImage?
    let selfiePhoto: UIImage?
    let onSeeRecap: () -> Void

    var body: some View {
        // The frame's own ground: `#F3EEE1`, a grayer cream than `paperSheet`.
        HisploraStage(groundColor: SRGBColor(hex: "#F3EEE1"), grain: true) {
            VStack(spacing: 0) {
                TripPageBar(
                    title: "",
                    backLabel: UIStrings.string(.tripPageBack, language),
                    shareState: .hidden,
                    onBack: { dismiss() })

                ScrollView {
                    VStack(spacing: 40) {
                        // New York Medium 31, the frame's own title weight — one step lighter
                        // than the carousel headlines.
                        Text(UIStrings.string(.journeySavedTitle, language))
                            .font(.system(size: 31, weight: .medium, design: .serif))
                            .tracking(-0.93)
                            .foregroundStyle(SRGBColor(hex: "#1A1A1A").color)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        photoCollage

                        if !text.isEmpty {
                            Text(text)
                                .font(.system(size: 15))
                                .tracking(-0.3)
                                .foregroundStyle(SRGBColor(hex: "#403838").color)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 10)
                                .background(
                                    Color.white.opacity(0.45),
                                    in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, KultaraMetrics.md)
                    .padding(.bottom, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Pinned above the home indicator rather than left at the end of the scroll, the
                // way `WriteJournalScreen`'s Save sits: the collage is short enough that the page
                // does not scroll, so a trailing button floats mid-screen with the rest of the
                // page empty below it.
                .safeAreaInset(edge: .bottom) { recapAction }
            }
        }
        .navigationBarBackButtonHidden()
    }

    /// The one control on the page, held at the foot.
    private var recapAction: some View {
        Button(UIStrings.string(.journeySavedRecapAction, language)) {
            onSeeRecap()
        }
        .buttonStyle(.hisploraPillOnPaper)
        .padding(.horizontal, 20)
        .padding(.bottom, KultaraMetrics.lg)
    }

    // MARK: - The photographs and the medallion (`921:2937`/`2943`/`2946`)

    /// The frame's collage, re-expressed as offsets from its own centre: the portrait die
    /// (121 × 164.2) sits up-left at −8.17°, the landscape one (the same die's 142 × 192.8 box
    /// turned on its side) up-right at +5.41°, and the bronze emblem — 101 points, the same
    /// `trip-emblem` artwork the carousel's headline page carries — overlaps both from below.
    @ViewBuilder private var photoCollage: some View {
        ZStack {
            if let placePhoto {
                photoStamp(placePhoto, dieWidth: 121, dieHeight: 164.227)
                    .rotationEffect(.degrees(-8.17))
                    .offset(x: -74, y: -16)
            }
            if let selfiePhoto {
                photoStamp(selfiePhoto, dieWidth: 192.824, dieHeight: 142.07)
                    .rotationEffect(.degrees(5.41))
                    .offset(x: 56, y: -22)
            }
            HisploraTripArtworkImage(HisploraTripArtwork.emblem, contentMode: .fill)
                .frame(width: 101, height: 101)
                .clipShape(Circle())
                .offset(x: -12.5, y: 62)
        }
        .frame(height: 230)
        .accessibilityHidden(true)
    }

    /// A photograph set into the frame's own photo die: white paper, the picture inset ~6% all
    /// round, and the perforation the die's vector cuts — 9 bites across and 13 down, spaced
    /// (a 0.71 bite span), which is what `biteSpan:` exists for.
    private func photoStamp(_ image: UIImage, dieWidth: CGFloat, dieHeight: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: dieWidth * 0.873, height: dieHeight * 0.877)
            .clipped()
            .frame(width: dieWidth, height: dieHeight)
            .background(Color.white)
            .clipShape(
                HisploraStampShape(teethAcross: 9, teethDown: 13, biteSpan: 0.71),
                style: HisploraStampShape.fillStyle)
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
    }
}
