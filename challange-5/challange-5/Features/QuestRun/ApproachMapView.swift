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
    /// Whether the authored marker pulses over the drawing — `187:1103`'s beating dot.
    ///
    /// Off by default, so `1:4458` keeps the still map it was drawn with. The pulse says *walk to
    /// here*, which is the transition screen's whole sentence and would be a second instruction on
    /// a screen whose own sentence is that the fix has landed.
    var pulsesAtMarker: Bool = false

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
                // Attached to the *fitted* view rather than after the `maxWidth` frame below: the
                // aspect ratio makes this box the drawing's own drawn rect, and the marker's
                // fractions are fractions of the drawing. Reading the wider frame instead would
                // slide the dot sideways by half the slack.
                .overlay { marker }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.xs))
                .accessibilityLabel(String(format: UIStrings.string(mapLabelKey, language),
                                           placeName))
        } else {
            RoundedRectangle(cornerRadius: KultaraMetrics.xs)
                .fill(palette.inkDusty.color.opacity(0.15))
                .aspectRatio(approachMap.aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
    }

    /// Whether the dot is actually on the paper — asked in one place, because the accessibility
    /// label and the overlay must not disagree about it. A screen that asked for the dot over a map
    /// whose content carries no point still draws the plain map, and must still be described as one.
    private var drawsMarker: Bool { pulsesAtMarker && approachMap.marker != nil }

    /// The dot is the difference between this map and `1:4458`'s, so it is named rather than left
    /// to colour and motion (`NFR-A11Y-05`).
    private var mapLabelKey: UIStringKey {
        drawsMarker ? .approachTransitionMapAccessibility : .locationVerifiedMapAccessibility
    }

    /// The beating dot over the authored point. Nothing is drawn when the screen did not ask for
    /// it, or when the content carries no point — the second case is the honest one, not a
    /// fallback to the middle of the paper.
    @ViewBuilder private var marker: some View {
        if drawsMarker, let point = approachMap.marker {
            GeometryReader { proxy in
                HisploraPulsingMapMarker()
                    .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
            }
        }
    }
}
