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
/// **The citation is printed under the drawing and is not optional.** A street map names real roads
/// and asserts how they meet, so `FR-CP-05` treats it as a claim exactly as it treats a sentence of
/// lore — the same argument `PlaceSiteMapScreen` makes for the site plan, and the same reason
/// `ApproachMapPresentation` carries the citation rather than leaving the view to look it up. Today's
/// citation begins `BELUM DIVERIFIKASI` and says in as many words that the map is an illustration
/// rather than a survey.
///
/// When the image is missing the citation still draws. A missing asset must not take the words about
/// it with it — that would leave the drawing's absence looking like a screen with nothing to say
/// rather than a screen whose picture failed to load.
struct ApproachMapView: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let placeName: String
    let approachMap: ApproachMapPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            drawing
            citation
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            // The reserved box rather than nothing, so the sheet does not silently collapse to the
            // height of two lines of citation when an asset goes missing.
            RoundedRectangle(cornerRadius: KultaraMetrics.xs)
                .fill(palette.inkDusty.color.opacity(0.15))
                .aspectRatio(approachMap.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }

    private var citation: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(UIStrings.string(.locationVerifiedMapSourceHeading, language))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.inkDark.color)
            Text(approachMap.citation)
                .font(.system(size: 12))
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
