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
    @Environment(\.hisploraPalette) private var palette
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
        HisploraStage(ground: \.paperSheet, grain: true) {
            VStack(spacing: 0) {
                TripPageBar(
                    title: "",
                    backLabel: UIStrings.string(.tripPageBack, language),
                    shareState: .hidden,
                    onBack: { dismiss() })

                ScrollView {
                    VStack(spacing: KultaraMetrics.xl) {
                        Text(UIStrings.string(.journeySavedTitle, language))
                            .font(.system(size: 32, weight: .semibold, design: .serif))
                            .foregroundStyle(palette.inkDark.color)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)

                        photoCollage

                        if !text.isEmpty {
                            Text(text)
                                .font(.system(size: 15))
                                .foregroundStyle(palette.inkDark.color)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(KultaraMetrics.lg)
                                .background(
                                    palette.paperCard.color, in: RoundedRectangle(cornerRadius: 16))
                        }

                        Button(UIStrings.string(.journeySavedRecapAction, language)) {
                            onSeeRecap()
                        }
                        .buttonStyle(.hisploraPillOnPaper)
                    }
                    .padding(KultaraMetrics.lg)
                    .padding(.top, KultaraMetrics.md)
                }
            }
        }
        .navigationBarBackButtonHidden()
    }

    // MARK: - The photographs and the seal

    @ViewBuilder private var photoCollage: some View {
        if placePhoto != nil || selfiePhoto != nil {
            ZStack {
                if let placePhoto {
                    polaroid(placePhoto)
                        .rotationEffect(.degrees(-6))
                        .offset(x: -34)
                }
                if let selfiePhoto {
                    polaroid(selfiePhoto)
                        .rotationEffect(.degrees(6))
                        .offset(x: 34, y: 14)
                }
                sealArtwork
                    .offset(y: 58)
            }
            .frame(height: 190)
            .accessibilityHidden(true)
        } else {
            sealArtwork.accessibilityHidden(true)
        }
    }

    private func polaroid(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 118, height: 138)
            .clipped()
            .padding(8)
            .padding(.bottom, 18)
            .background(Color.white)
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }

    /// The stamp franked on `247:1880`'s arrival, reused here rather than a new export — a seal is
    /// decoration, and the same one already shipped for the checkpoint stamp says the same thing.
    @ViewBuilder private var sealArtwork: some View {
        if let seal = HisploraWaxSealMetrics.questSeal {
            seal
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: HisploraWaxSealMetrics.questSealSize.width,
                    height: HisploraWaxSealMetrics.questSealSize.height)
        } else {
            Circle()
                .fill(palette.mapMarker.color)
                .frame(
                    width: HisploraWaxSealMetrics.questSealSize.width,
                    height: HisploraWaxSealMetrics.questSealSize.width)
        }
    }
}
