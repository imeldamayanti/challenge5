import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The drawn plan of a Place's grounds — `452:3028` ("Site Map"), opened from the hint at the foot of
/// `TaskDetailScreen`.
///
/// **This is the one story-flow screen on paper rather than on brown**, and the frame is right about
/// that: a plan is a document, so `mapGround` is its own token and the seam still falls at a screen
/// boundary the way `HisploraPalette` requires.
///
/// **The plan is content and it carries a citation, which the frame does not draw.** `452:3031` is a
/// generated illustration annotating a real puri with real distances — "171 meters", "158 meters",
/// an entrance gate and an exit gate. Those are claims about a real place, so `FR-CP-05` applies to
/// them exactly as it applies to a sentence of lore: the drawing comes from `Place.siteMap` with a
/// `sourceRef` behind it, and the citation is printed under it. Today's citation begins
/// `BELUM DIVERIFIKASI` and says in as many words that the drawing is generated and unsurveyed, which
/// is the whole point of putting it on the screen instead of leaving it in a JSON file.
///
/// **This is not a map (`FR-MAP-01`).** No tiles, no `MKMapView`, nothing fetched — a bundled image
/// with a pinch and a drag, which works in airplane mode like every other core flow (`AD-3`,
/// `FR-OFF-03`). The route between checkpoints is still `RunRouteMapView`'s job; this is the inside of
/// one stop.
struct PlaceSiteMapScreen: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let language: ContentLanguage
    let placeName: String
    let siteMap: SiteMapPresentation?
    let onClose: () -> Void

    private static let margin: CGFloat = 20

    /// The pinch-and-drag state the frame's own hint promises. Held here rather than in the view model
    /// because it is a gesture on a picture and survives nothing — not a stage change, not a
    /// relaunch, and it should not.
    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var committedPan: CGSize = .zero

    private static let zoomRange: ClosedRange<CGFloat> = 1...4

    var body: some View {
        HisploraStage(ground: \.mapGround) {
            VStack(spacing: 0) {
                titleBar
                Spacer(minLength: 0)
                plan
                Spacer(minLength: 0)
                gestureHint
            }
            .padding(.horizontal, Self.margin)
        }
    }

    /// `452:3050` sets the place name leading, not centred — this screen's bar is a document's head,
    /// not a step in a walk — with the close control opposite it.
    private var titleBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(placeName)
                .font(.system(size: 19, weight: .semibold))
                .tracking(-0.38)
                .foregroundStyle(palette.buttonFill.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: KultaraMetrics.md)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(palette.buttonFill.color)
                    .kultaraTapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(UIStrings.string(.siteMapClose, language))
        }
        .padding(.top, 13)
    }

    @ViewBuilder private var plan: some View {
        if let siteMap {
            VStack(spacing: KultaraMetrics.md) {
                drawing(siteMap)
                // The frame prints no citation. `FR-CP-05` is why one is here, and why it is at body
                // weight under the drawing rather than tucked behind a tap.
                citation(siteMap)
            }
        } else {
            Text(UIStrings.string(.siteMapUnavailable, language))
                .font(.system(size: 15))
                .foregroundStyle(palette.inkBody.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    /// The plan itself, zoomable and pannable, clipped to the frame's own 362 × 320 window.
    ///
    /// Clipped rather than allowed to grow: without the clip a zoomed plan draws over the title and
    /// the hint, and the close control stops being reachable — which on this screen is the only way
    /// out.
    @ViewBuilder private func drawing(_ siteMap: SiteMapPresentation) -> some View {
        let markerCount = siteMap.markers.count
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                if let url = siteMap.imageURL, let image = BundledImage.load(url) {
                    image.resizable().scaledToFit()
                } else {
                    // A plan the bundle cannot read is a content fault, not a blank screen: it says
                    // so, in the same words the no-plan case uses.
                    Text(UIStrings.string(.siteMapUnavailable, language))
                        .font(.system(size: 15))
                        .foregroundStyle(palette.inkBody.color)
                        .multilineTextAlignment(.center)
                }
                ForEach(siteMap.markers) { marker in
                    Circle()
                        .fill(palette.mapMarker.color)
                        .frame(width: 8, height: 8)
                        // A cream ring so the dot reads as a placed object on any part of the
                        // drawing, rather than relying on the marker's colour alone
                        // (`NFR-A11Y-05`).
                        .overlay(Circle().stroke(palette.paperCream.color, lineWidth: 1))
                        .position(x: size.width * marker.x, y: size.height * marker.y)
                }
            }
            .frame(width: size.width, height: size.height)
            .scaleEffect(zoom)
            .offset(pan)
        }
        .aspectRatio(siteMap.aspectRatio, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
        .gesture(zoomGesture.simultaneously(with: panGesture))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: UIStrings.string(.siteMapAccessibility, language),
                                   placeName, markerCount))
    }

    private func citation(_ siteMap: SiteMapPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(UIStrings.string(.siteMapSourceHeading, language))
                .font(.system(size: 13, weight: .semibold))
                // `inkDark` and not `inkMuted`: the muted ink measures 4.39:1 on `mapGround`, just
                // under body text, so this screen does not use it (`HisploraPalette.contrastPairs`).
                .foregroundStyle(palette.inkDark.color)
            Text(siteMap.citation)
                .font(.system(size: 13))
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `452:3036` — the hand glyph and the gesture hint. Not a control: the gestures are on the plan
    /// above, and this says what they are.
    private var gestureHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 24))
                .foregroundStyle(palette.buttonFill.color)
                .accessibilityHidden(true)
            Text(UIStrings.string(.siteMapGestureHint, language))
                .font(.system(size: 17))
                .tracking(-0.34)
                .foregroundStyle(palette.inkDark.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 30)
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = clampedZoom(committedZoom * value.magnification)
            }
            .onEnded { _ in
                committedZoom = zoom
                // Zooming back out has to bring the drawing back with it, or a plan panned to a
                // corner at 4× and then zoomed out sits off-screen with no way to recover it.
                if committedZoom == Self.zoomRange.lowerBound {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        pan = .zero
                    }
                    committedPan = .zero
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                pan = CGSize(width: committedPan.width + value.translation.width,
                             height: committedPan.height + value.translation.height)
            }
            .onEnded { _ in committedPan = pan }
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    }
}
