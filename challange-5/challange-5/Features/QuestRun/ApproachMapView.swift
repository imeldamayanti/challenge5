import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The drawn map of the streets around a checkpoint, printed on the parchment of `1:4458`
/// ("Location Verified").
///
/// **This is not a map (`FR-MAP-01`, `FR-OFF-03`).** No tiles, no `MKMapView`, nothing fetched — a
/// bundled image out of the content tree, which renders in airplane mode like every other core flow
/// (`AD-3`). The frame pastes a live street-map screenshot into this slot; what ships instead is the
/// same picture authored as content, which is the only form of it this app is allowed to hold.
///
/// **The citation is authored but deliberately not drawn, and that is an open `FR-CP-05` gap.** The
/// drawing names real Denpasar streets and asserts how they meet, which is a claim of the kind the
/// rule covers — the content still carries a `sourceRef` (V3 and V14 hold it, and
/// `QuestRunViewModel.approachMap(for:)` still refuses a map whose ref does not resolve), so the
/// provenance exists and is enforced; it simply is not on this screen. That was a product decision
/// on 2026-08-20, made the same way the Story Reveal's omission was, and like that one it has no PRD
/// amendment and no named owner yet. Both need signing off together rather than by inference.
///
/// When the image is missing a reserved box draws in its place, so the parchment does not silently
/// collapse to nothing.
struct ApproachMapView: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let placeName: String
    let approachMap: ApproachMapPresentation

    var body: some View {
        drawing
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var drawing: some View {
        if let url = approachMap.imageURL, let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                // Fit rather than fill: this is a drawing with labels at its edges — "PURI AGUNG
                // PEMECUTAN" sits in the bottom-left corner of the shipped one — and cropping to
                // fill a slot cuts the names off the places the map exists to point at.
                .aspectRatio(approachMap.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.xs))
                .accessibilityLabel(
                    String(format: UIStrings.string(.locationVerifiedMapAccessibility, language),
                           placeName))
        } else {
            RoundedRectangle(cornerRadius: KultaraMetrics.xs)
                .fill(palette.inkDusty.color.opacity(0.15))
                .aspectRatio(approachMap.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }
}
