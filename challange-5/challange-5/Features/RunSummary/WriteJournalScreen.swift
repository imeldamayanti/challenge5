import ContentKit
import DesignSystem
import Foundation
import PhotosUI
import RunEngine
import SwiftUI
import UIKit
import UIStringsKit

/// `921-2256` — the walk's closing reflection, written from the Summary screen. Replaces the
/// `createJournal` wireframe: free text plus up to two keepsake photographs, saved onto the Run
/// itself (`RunEngine.saveJournalEntry`, reached through `QuestRunViewModel.saveJournalEntry`)
/// rather than staying a drawing of empty boxes.
///
/// Hisplora, not museum, even though it is pushed from the museum-styled Summary screen — the same
/// whole-screen boundary `QuestRunView.isOnStoryFlow` draws everywhere else in this codebase.
struct WriteJournalScreen: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    let language: ContentLanguage
    /// Writes the entry to the Run and hands back the updated one, or `nil` on failure — the same
    /// shape `QuestRunViewModel.saveJournalEntry` returns.
    let onSave: (_ text: String, _ placePhoto: UIImage?, _ selfiePhoto: UIImage?) -> Run?
    let onOpenRecap: (Run) -> Void

    @State private var text = ""
    @State private var placePhoto: UIImage?
    @State private var selfiePhoto: UIImage?
    @State private var placePickerItem: PhotosPickerItem?
    @State private var selfiePickerItem: PhotosPickerItem?
    /// Set once `onSave` succeeds, which is also what the `navigationDestination(isPresented:)`
    /// below pushes `JourneySavedScreen` on.
    @State private var savedRun: Run?

    private static let characterLimit = 250

    var body: some View {
        HisploraStage(ground: \.paperSheet, grain: true) {
            VStack(spacing: 0) {
                TripPageBar(
                    title: UIStrings.string(.writeJournalTitle, language),
                    backLabel: UIStrings.string(.tripPageBack, language),
                    shareText: nil,
                    onBack: { dismiss() })

                ScrollView {
                    VStack(spacing: KultaraMetrics.xl) {
                        card
                        Button(UIStrings.string(.writeJournalSaveAction, language)) { save() }
                            .buttonStyle(.hisploraPillOnPaper)
                            .disabled(trimmedText.isEmpty)
                    }
                    .padding(KultaraMetrics.lg)
                    .padding(.top, KultaraMetrics.md)
                }
            }
        }
        .navigationBarBackButtonHidden()
        // `Run` carries no `Hashable` conformance — nothing else in this codebase has needed one —
        // so the push is driven by presence rather than by `navigationDestination(item:)`.
        .navigationDestination(isPresented: Binding(
            get: { savedRun != nil },
            set: { if !$0 { savedRun = nil } })
        ) {
            if let savedRun {
                JourneySavedScreen(
                    language: language,
                    text: trimmedText,
                    placePhoto: placePhoto,
                    selfiePhoto: selfiePhoto,
                    onSeeRecap: { onOpenRecap(savedRun) })
            }
        }
        .onChange(of: placePickerItem) { _, item in load(item) { placePhoto = $0 } }
        .onChange(of: selfiePickerItem) { _, item in load(item) { selfiePhoto = $0 } }
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - The card (`921-2256`)

    private var card: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
            Text(UIStrings.string(.writeJournalHeading, language))
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(palette.inkDark.color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                Text(UIStrings.string(.writeJournalExperienceLabel, language))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.inkDark.color)
                experienceField
                Text("\(text.count)/\(Self.characterLimit)")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.inkMuted.color)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                Text(UIStrings.string(.writeJournalMemoriesLabel, language))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.inkDark.color)
                HStack(spacing: KultaraMetrics.md) {
                    photoSlot(
                        image: placePhoto,
                        label: UIStrings.string(.writeJournalAddPlacePhoto, language),
                        selection: $placePickerItem)
                    photoSlot(
                        image: selfiePhoto,
                        label: UIStrings.string(.writeJournalAddSelfie, language),
                        selection: $selfiePickerItem)
                }
            }
        }
        .padding(KultaraMetrics.xl)
        .frame(maxWidth: .infinity)
        .background(palette.paperStamp.color)
        // The mockup's scalloped edge is `HisploraStampCard`'s own die, reused at a coarser pitch —
        // a *count* of bites, not a fixed size, is exactly what lets one shape serve a 26-point
        // envelope stamp and this much larger card at a matching perforation (`HisploraStampShape`).
        .clipShape(HisploraStampShape(teethAcross: 28), style: HisploraStampShape.fillStyle)
    }

    private var experienceField: some View {
        TextField(
            UIStrings.string(.writeJournalExperiencePlaceholder, language),
            text: $text, axis: .vertical)
            .font(.system(size: 15))
            .foregroundStyle(palette.inkDark.color)
            .lineLimit(4...8)
            .padding(KultaraMetrics.md)
            .background(palette.paperSheet.color, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(palette.buttonRing.color, lineWidth: KultaraMetrics.hairline)
            }
            .onChange(of: text) { _, newValue in
                if newValue.count > Self.characterLimit {
                    text = String(newValue.prefix(Self.characterLimit))
                }
            }
    }

    private func photoSlot(
        image: UIImage?, label: String, selection: Binding<PhotosPickerItem?>
    ) -> some View {
        // `PhotosPicker`'s label builder is not MainActor-isolated, so `palette` — itself
        // MainActor-isolated — is read into local, `Sendable` `Color` values first rather than
        // read from inside the closure.
        let ink = palette.inkDark.color
        let buttonInk = palette.buttonFill.color
        let ring = palette.buttonRing.color
        return PhotosPicker(selection: selection, matching: .images) {
            VStack(spacing: KultaraMetrics.sm) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ink)
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(buttonInk)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KultaraMetrics.lg)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ring, lineWidth: KultaraMetrics.hairline)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func load(_ item: PhotosPickerItem?, into assign: @escaping (UIImage?) -> Void) {
        guard let item else { return }
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            assign(data.flatMap { UIImage(data: $0) })
        }
    }

    private func save() {
        guard !trimmedText.isEmpty else { return }
        savedRun = onSave(trimmedText, placePhoto, selfiePhoto)
    }
}
