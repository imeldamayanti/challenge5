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

    @FocusState private var experienceFocused: Bool
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
        // The board's cream screens stand on `#F3EEE1` — a grayer cream than `paperSheet`, the
        // same ground the Journey Saved frame draws.
        HisploraStage(groundColor: SRGBColor(hex: "#F3EEE1"), grain: true) {
            VStack(spacing: 0) {
                TripPageBar(
                    title: UIStrings.string(.writeJournalTitle, language),
                    backLabel: UIStrings.string(.tripPageBack, language),
                    shareState: .hidden,
                    onBack: { dismiss() })

                ScrollView {
                    VStack(spacing: KultaraMetrics.lg) {
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
        .toolbar {
            // The keyboard's own Done — the field is the only text input on the screen, and a
            // walker who wants their photo slots back before saving has no other way to put the
            // keyboard away.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(UIStrings.string(.writeJournalKeyboardDone, language)) {
                    experienceFocused = false
                }
            }
        }
        .onChange(of: placePickerItem) { _, item in load(item) { placePhoto = $0 } }
        .onChange(of: selfiePickerItem) { _, item in load(item) { selfiePhoto = $0 } }
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - The card (`921-2256`)

    private var card: some View {
        VStack(alignment: .leading, spacing: 48) {
            Text(UIStrings.string(.writeJournalHeading, language))
                .font(.system(size: 35, weight: .bold, design: .serif))
                .tracking(-0.7)
                .foregroundStyle(SRGBColor(hex: "#58453E").color)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(UIStrings.string(.writeJournalExperienceLabel, language))
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.34)
                        .foregroundStyle(SRGBColor(hex: "#444444").color)
                    VStack(spacing: 4) {
                        experienceField
                        Text("\(text.count)/\(Self.characterLimit)")
                            .font(.system(size: 15))
                            .tracking(-0.45)
                            .foregroundStyle(SRGBColor(hex: "#999999").color)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(UIStrings.string(.writeJournalMemoriesLabel, language))
                        .font(.system(size: 17, weight: .medium))
                        .tracking(-0.34)
                        .foregroundStyle(SRGBColor(hex: "#444444").color)
                    HStack(spacing: 8) {
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
        }
        // The frame insets its content 29 from each paper edge and 56 off the top (the die
        // itself overhangs 13 past the node's sides), leaving 79 below the last row.
        .padding(.top, 56)
        .padding(.horizontal, 29)
        .padding(.bottom, 79)
        .frame(maxWidth: .infinity)
        .background(palette.paperStamp.color)
        // The mockup's scalloped edge is `HisploraStampShape`'s die at the frame's own two
        // pitches — 14 bites across (touching, 25.85 points on this paper's 362-point width) and
        // 13 down the sides (pitch 41.8, spaced), which is what `teethDown:` exists for. The old
        // `teethAcross: 28` cut every scallop at half the drawn size.
        .clipShape(
            HisploraStampShape(teethAcross: 14, teethDown: 13),
            style: HisploraStampShape.fillStyle)
    }

    private var experienceField: some View {
        TextField(
            UIStrings.string(.writeJournalExperiencePlaceholder, language),
            text: $text,
            // The frame draws the untouched field's hint in `#878080`, fainter than typed ink.
            prompt: Text(UIStrings.string(.writeJournalExperiencePlaceholder, language))
                .foregroundColor(SRGBColor(hex: "#878080").color),
            axis: .vertical)
            .font(.system(size: 15))
            .tracking(-0.3)
            .foregroundStyle(palette.inkDark.color)
            .lineLimit(4...8)
            // The frame's empty field is a fixed 117-point pane; typing past four lines grows it.
            .frame(minHeight: 117, alignment: .topLeading)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SRGBColor(hex: "#D8D8D8").color, lineWidth: KultaraMetrics.hairline)
            }
            .focused($experienceFocused)
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
        let labelInk = palette.brownSeal.color
        let ring = SRGBColor(hex: "#D8D8D8").color
        return PhotosPicker(selection: selection, matching: .images) {
            VStack(spacing: 8) {
                if let image {
                    // `Color.clear` + overlay, not a bare `frame(height:)`: a filled image sized
                    // by height alone takes its own aspect-derived width, which overruns the slot
                    // and prints past the card. The clear pane holds the slot's own width; the
                    // photo fills it and is clipped to it — the frame's filled state.
                    Color.clear
                        .frame(height: 64)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ink)
                }
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(labelInk)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.45))
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
