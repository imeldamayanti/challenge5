import ContentKit
import DesignSystem
import SwiftUI
import UIKit
import UIStringsKit

/// Which ground a shared story card is cut on. The picker's own vocabulary, kept out of the card
/// because the card does not care which of them it renders.
enum ShareStoryVariantKind: String, CaseIterable, Sendable, Identifiable {
    case photo
    case brown

    var id: String { rawValue }

    /// The offer is built from what the walk actually produced (`921:2543`'s two thumbnails):
    /// the brown card always exists, the photo card only when the walk has a photograph to put on
    /// it. One item means no choice to make and no row to make it with.
    static func availableVariants(hasPhoto: Bool) -> [ShareStoryVariantKind] {
        hasPhoto ? [.photo, .brown] : [.brown]
    }
}

/// The variant picker the completion carousel's Share button opens — **the header of Figma
/// `921:2543`/`921:2598`, and nothing more**: preview, two thumbnail choices, and a Share action.
/// The rest of those frames is the OS's own share sheet, which this hands over to rather than
/// rebuilds (`AD-4`'s cousin rule: never re-draw the platform).
///
/// Both variants are rendered *here*, when the sheet opens — never eagerly on page appearance,
/// where every swipe through the carousel would burn two 1080 px renders for nothing. Sharing is
/// fully offline (`AD-3`) and gates nothing (`AD-2`): Close Summary behaves identically whether or
/// not anybody ever taps Share.
struct ShareStoryPickerSheet: View {

    let language: ContentLanguage
    /// The card input the carousel assembled, carrying whichever ground it decided on — photo
    /// when the walk has a photograph, brown otherwise. Every variant derives from this one value.
    let input: ShareStoryCard.Input
    /// What the share sheet is handed when a render somehow comes back nil, so Share can never
    /// dead-end. See the action below.
    let fallbackText: String

    @Environment(\.dismiss) private var dismiss
    @State private var selection: ShareStoryVariantKind?
    @State private var rendered: [ShareStoryVariantKind: UIImage] = [:]
    @State private var presentsNativeShare = false

    private var hasPhoto: Bool { input.ground.photograph != nil }
    private var variants: [ShareStoryVariantKind] {
        ShareStoryVariantKind.availableVariants(hasPhoto: hasPhoto)
    }
    private var selected: ShareStoryVariantKind? {
        let available = variants
        return selection.flatMap { available.contains($0) ? $0 : nil } ?? available.first
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .accessibilityHidden(true)

            header

            Spacer(minLength: 8)

            preview

            if variants.count > 1 {
                thumbnailRow
            }

            Spacer(minLength: 8)

            shareButton
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .task { renderVariantsOnce() }
        .sheet(isPresented: $presentsNativeShare) {
            ActivityShareSheet(
                items: [shareItem],
                onFinish: {
                    presentsNativeShare = false
                    // The activity sheet closing ends the whole gesture: back to the postcard,
                    // not to a picker whose job is already done.
                    dismiss()
                })
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(UIStrings.string(.shareStorySheetTitle, language))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            HStack {
                Spacer()
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color(uiColor: .secondarySystemFill)))
                        // The visible circle is small; the target is what a close control owes.
                        .contentShape(Circle().inset(by: -7))
                }
                .accessibilityLabel(Text(UIStrings.string(.tripRecapCloseAction, language)))
            }
            .padding(.trailing, 16)
        }
    }

    // MARK: - Preview

    private var preview: some View {
        Group {
            if let image = selected.flatMap({ rendered[$0] }) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 176, height: 313)
            } else if let selected {
                // Rendering is synchronous and quick, so this branch is the moment before the
                // first frame lands — and the honest answer if a render ever fails outright.
                ShareStoryCard(input: cardInput(for: selected))
                    .frame(width: 176, height: 313)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: UIStrings.string(.shareStoryPreviewLabel, language),
            selected.map(variantName) ?? ""))
    }

    // MARK: - Variant thumbnails

    private var thumbnailRow: some View {
        HStack(spacing: 24) {
            ForEach(variants) { kind in
                thumbnail(kind)
            }
        }
    }

    private func thumbnail(_ kind: ShareStoryVariantKind) -> some View {
        let isSelected = selected == kind
        return Button {
            selection = kind
        } label: {
            ZStack {
                swatch(kind)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                Circle()
                    .stroke(
                        isSelected ? SRGBColor(hex: "#F3C029").color
                            : SRGBColor(hex: "#C3C3C3").color,
                        lineWidth: 2)
            }
        }
        .accessibilityLabel(Text(variantName(kind)))
        // The selected trait is how the announcement happens: VoiceOver reads "selected" on the
        // focused thumbnail, so a change of choice is heard rather than only seen.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// A thumbnail is the *ground*, drawn as itself — a 48-point circle cannot show a whole 9:16
    /// card, and a shrunken render of everything behind it would read as noise. What the reader
    /// is choosing between is exactly what these two circles show.
    @ViewBuilder private func swatch(_ kind: ShareStoryVariantKind) -> some View {
        switch kind {
        case .photo:
            if let photo = input.ground.photograph {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray
            }
        case .brown:
            LinearGradient(
                stops: [
                    .init(color: SRGBColor(hex: "#1C0F0B").color, location: 0),
                    .init(color: SRGBColor(hex: "#86361D").color, location: 0.86),
                ],
                startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Actions

    private var shareButton: some View {
        Button {
            presentsNativeShare = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.fill")
                Text(UIStrings.string(.tripRecapShareAction, language))
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
        }
        // Solid black where the carousel's twin is 50% black: that wash stood on a dark stage,
        // where translucency is the look — on a white sheet it would only read grey.
        .background(Color.black, in: Capsule())
        .overlay {
            Capsule().stroke(SRGBColor(hex: "#1A1A1A").color, lineWidth: 1)
        }
    }

    /// The rendered card if there is one, the walker's words otherwise — **the last-resort
    /// fallback that keeps Share from dead-ending** if ImageRenderer returns nil for both
    /// variants, which nothing above this line can rule out.
    private var shareItem: Any {
        selected.flatMap { rendered[$0] } ?? fallbackText
    }

    // MARK: - Helpers

    private func variantName(_ kind: ShareStoryVariantKind) -> String {
        UIStrings.string(
            kind == .photo ? .shareStoryVariantPhoto : .shareStoryVariantBrown, language)
    }

    private func cardInput(for kind: ShareStoryVariantKind) -> ShareStoryCard.Input {
        switch kind {
        case .photo:
            if let photo = input.ground.photograph {
                return input.withGround(.photo(photo))
            }
            return input.withGround(.brown)
        case .brown:
            return input.withGround(.brown)
        }
    }

    /// Both variants, once, when the sheet opens — the lazy point at which rendering is worth its
    /// cost. Re-entry (a second Share in one session) finds the dictionary filled and skips.
    private func renderVariantsOnce() {
        guard rendered.isEmpty else { return }
        for kind in variants {
            rendered[kind] = ShareStoryCard(input: cardInput(for: kind)).render()
        }
    }
}

/// The native share sheet, wrapped rather than rebuilt. `completionWithItemsHandler` fires whether
/// the walker completed, cancelled or failed, which is what makes it the single hook for dismissing
/// our picker afterwards.
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in onFinish() }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
