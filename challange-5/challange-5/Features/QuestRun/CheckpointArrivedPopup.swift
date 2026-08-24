import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The arrival card over `5:1608`'s map — what a walk says when the fix lands at every checkpoint
/// after the first, in place of `1:4458`'s whole screen.
///
/// It is `1108:2780`'s object (`NewDiscoveryPopup`) rather than a new one: a dimming wash and a
/// centred card carrying what happened and one control out of it. The two are the same kind of
/// event — something happened *at* the walker — and drawing them differently would make one of
/// them mean less.
///
/// **The scrim is not a control here.** `NewDiscoveryPopup`'s is a `Button` because tapping outside
/// that card dismisses it, and a bare rectangle with a gesture is not something VoiceOver can
/// announce or activate (`NFR-A11Y-05`). This card has nothing to dismiss *to* — the arrival is
/// already recorded (`FR-RUN-01`) and its one control carries the walk into the story — so the wash
/// is decoration and is hidden from VoiceOver rather than being a control that leads nowhere.
struct CheckpointArrivedPopup: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    /// The place arrived at. Content, never a literal (`AD-4`, `FR-RUN-06`).
    let placeName: String
    let onContinue: () -> Void

    /// `1108:2780`'s own figures, so the two cards are one object at two moments.
    private enum Metrics {
        static let cardWidth: CGFloat = 300
        static let cornerRadius: CGFloat = 19
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 20
        static let stackSpacing: CGFloat = 10
        static let textSpacing: CGFloat = 6
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .accessibilityHidden(true)
            card
        }
        .ignoresSafeArea()
    }

    private var card: some View {
        VStack(spacing: Metrics.stackSpacing) {
            seal
            text
            continueAction
        }
        .padding(.horizontal, Metrics.horizontalPadding)
        .padding(.vertical, Metrics.verticalPadding)
        .frame(width: Metrics.cardWidth)
        .background(palette.paperTrip.color,
                    in: RoundedRectangle(cornerRadius: Metrics.cornerRadius, style: .continuous))
        // One announcement — heading, body, control — so VoiceOver does not reach the map
        // underneath before the reader has heard what happened.
        .accessibilityElement(children: .contain)
    }

    /// The arrival mark — the same `mapMarker` dot in its cream ring that every map on this flow
    /// places over a place, at rest.
    ///
    /// **Deliberately not `HisploraPulsingMapMarker`.** That component's ring repeats forever,
    /// which is what a map's *destination* wants and what a card does not: an animation with
    /// nowhere to arrive is the leading suspect behind the XCUITest that never sees the app go
    /// idle, and a card that is on screen for one tap has no reason to add a second one.
    private var seal: some View {
        Circle()
            .fill(palette.mapMarker.color)
            .frame(width: 44, height: 44)
            .overlay(Circle().stroke(palette.paperCream.color, lineWidth: 3))
            .accessibilityHidden(true)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: Metrics.textSpacing) {
            // `.checkpointArrivedHeading` rather than `1:4458`'s "Location Verified": that screen
            // was explaining a *fix*, which is what a walker needs told once. What this card says
            // is what happened — they arrived.
            Text(UIStrings.string(.checkpointArrivedHeading, language))
                .font(.system(size: 20, weight: .semibold))
                .tracking(-0.45)
                .foregroundStyle(palette.inkDark.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // The place is what makes this arrival *this* arrival; `1:4458` had a whole screen to
            // establish it and this card has a line.
            Text(placeName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
            Text(UIStrings.string(.locationVerifiedBody, language))
                .font(.system(size: 15))
                .tracking(-0.23)
                .foregroundStyle(palette.inkMuted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `1108:2785`'s near-black pill — hugging its label rather than filling the card, so the card
    /// reads as an announcement rather than as a form.
    private var continueAction: some View {
        Button(action: onContinue) {
            Text(UIStrings.string(.locationVerifiedContinue, language))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(palette.inkOnButton.color)
                .padding(.horizontal, 48)
                .padding(.vertical, 8)
                .frame(minHeight: KultaraMetrics.minimumTapTarget)
                .background(palette.buttonFill.color, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Checkpoint Arrived") {
    HisploraStage(ground: \.brownStone) {
        CheckpointArrivedPopup(
            language: .en,
            placeName: "Pura Maospahit",
            onContinue: {})
    }
}
