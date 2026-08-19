import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The drawn plan of a Place's grounds — `452:2651` ("Site Map"), opened from the hint at the foot of
/// `TaskDetailScreen`.
///
/// **The plan runs full — filled, cropped and dragged, not fitted.** `452:2651` draws the image 673.9
/// points wide inside a 402-point frame: it starts flush with the window's leading edge, bleeds off
/// the trailing one, and the frame's own hint says what to do about that ("Pinch to zoom, drag to
/// explore"). An earlier pass fitted the whole drawing into a 362 × 320 window, which is legible and
/// is not the design — at fit scale a plan annotated with building outlines and gate labels is a
/// thumbnail. Filling by height and cropping the width is what makes it a plan you read.
///
/// **This is the one story-flow screen on paper rather than on brown**, and the frame is right about
/// that: a plan is a document, so `mapGround` is its own token and the seam still falls at a screen
/// boundary the way `HisploraPalette` requires.
///
/// **The plan is content and it carries a citation, which the frame does not draw.** `452:2654` is a
/// generated illustration annotating a real puri with real distances — "171 meters", "158 meters",
/// an entrance gate and an exit gate. Those are claims about a real place, so `FR-CP-05` applies to
/// them exactly as it applies to a sentence of lore: the drawing comes from `Place.siteMap` with a
/// `sourceRef` behind it, and the citation is printed under it. Today's citation begins
/// `BELUM DIVERIFIKASI` and says in as many words that the drawing is generated and unsurveyed, which
/// is the whole point of putting it on the screen instead of leaving it in a JSON file. It is also
/// the reason the plan gets the *remaining* height rather than the frame's literal 594.6: the
/// citation is not scrolled off, not put behind a tap, and not truncated, so it takes its space first
/// and the drawing takes the rest (deviation 12 in `docs/hisplora-tokens.md`).
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

    /// `452:3053` sets the title at 20 and `452:2654` sets the plan at 16 — the drawing is wider than
    /// the words on purpose, and the two insets are not the same number.
    private static let textMargin: CGFloat = 20
    private static let planLeading: CGFloat = 16

    /// The pinch-and-drag state the frame's own hint promises. Held here rather than in the view model
    /// because it is a gesture on a picture and survives nothing — not a stage change, not a
    /// relaunch, and it should not.
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var drag: CGSize = .zero

    /// The window and the size the plan is drawn at, recorded because a gesture callback has no
    /// `GeometryProxy` and the pan it stores has to be clamped against both.
    @State private var viewport: CGSize = .zero
    @State private var content: CGSize = .zero

    private static let maximumZoom: CGFloat = 4

    var body: some View {
        HisploraStage(ground: \.mapGround) {
            VStack(spacing: 0) {
                titleBar
                    .padding(.horizontal, Self.textMargin)
                plan
                    // Leading inset only. The trailing edge is where the drawing runs off the screen,
                    // and a margin there would turn the design's crop into a framed picture.
                    .padding(.leading, Self.planLeading)
                    .padding(.top, 26)
                    .frame(maxHeight: .infinity)
                footer
                    .padding(.horizontal, Self.textMargin)
                    .padding(.top, 24)
            }
        }
    }

    /// `452:3053` sets the place name leading, not centred — this screen's bar is a document's head,
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
        if let siteMap, let url = siteMap.imageURL, let image = BundledImage.load(url) {
            drawing(siteMap, image: image)
        } else {
            // No plan, or a plan the bundle cannot read: both are content faults and both say so,
            // rather than leaving a reader looking at an empty rectangle.
            Text(UIStrings.string(.siteMapUnavailable, language))
                .font(.system(size: 15))
                .foregroundStyle(palette.inkBody.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.trailing, Self.textMargin)
        }
    }

    /// The plan, filled into whatever height is left and clipped to it.
    ///
    /// Clipped rather than allowed to grow: without the clip a zoomed plan draws over the title and
    /// the hint, and the close control stops being reachable — which on this screen is the only way
    /// out.
    private func drawing(_ siteMap: SiteMapPresentation, image: Image) -> some View {
        GeometryReader { proxy in
            let window = proxy.size
            let scale = clampedZoom
            let size = ArtworkViewport.filledSize(aspectRatio: siteMap.aspectRatio, in: window)
            let offset = drawnPan(content: size, scale: scale, in: window)

            ZStack(alignment: .topLeading) {
                image
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(width: window.width, height: window.height)

                // Markers are drawn in window space, outside the `scaleEffect`, so a dot keeps its
                // size while the plan under it grows.
                ForEach(siteMap.markers) { marker in
                    let point = ArtworkViewport.position(
                        of: CGPoint(x: marker.x, y: marker.y),
                        drawnAt: size, in: window, scale: scale, offset: offset)
                    Circle()
                        .fill(palette.mapMarker.color)
                        .frame(width: 12, height: 12)
                        // A cream ring so the dot reads as a placed object on any part of the
                        // drawing, rather than relying on the marker's colour alone
                        // (`NFR-A11Y-05`).
                        .overlay(Circle().stroke(palette.paperCream.color, lineWidth: 1.5))
                        .position(x: point.x, y: point.y)
                }
            }
            .frame(width: window.width, height: window.height)
            .clipped()
            .contentShape(Rectangle())
            // One combined gesture, not `.gesture` plus `.simultaneousGesture`. Attached separately,
            // the drag claims the touch sequence the moment a finger moves and the magnify gesture
            // never receives the second one — pinch-to-zoom silently does nothing.
            .gesture(SimultaneousGesture(panGesture, zoomGesture))
            .onAppear { openOnTheLeadingEdge(content: size, in: window) }
            .onChange(of: window) { _, newWindow in
                let refilled = ArtworkViewport.filledSize(aspectRatio: siteMap.aspectRatio,
                                                          in: newWindow)
                viewport = newWindow
                content = refilled
                pan = ArtworkViewport.clampedPan(pan, content: refilled, scale: zoom, in: newWindow)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(format: UIStrings.string(.siteMapAccessibility, language),
                                       placeName, siteMap.markers.count))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// `452:2659` — the hand glyph and the gesture hint, with the plan's citation under them.
    ///
    /// Not a control: the gestures are on the plan above, and this says what they are.
    private var footer: some View {
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
            if let siteMap {
                // The frame prints no citation. `FR-CP-05` is why one is here, and why it is under
                // the drawing in full rather than tucked behind a tap.
                citation(siteMap)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 24)
    }

    private func citation(_ siteMap: SiteMapPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(UIStrings.string(.siteMapSourceHeading, language))
                .font(.system(size: 13, weight: .semibold))
                // `inkDark` and not `inkMuted`: the muted ink measures 4.39:1 on `mapGround`, just
                // under body text, so this screen does not use it (`HisploraPalette.contrastPairs`).
                .foregroundStyle(palette.inkDark.color)
            Text(siteMap.citation)
                .font(.system(size: 12))
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, KultaraMetrics.xs)
    }

    private var clampedZoom: CGFloat {
        min(max(zoom * pinch, 1), Self.maximumZoom)
    }

    /// The offset the plan is drawn at this frame: the stored pan, grown by the live pinch and moved
    /// by the live drag, then clamped so no edge of the drawing comes inside the window.
    private func drawnPan(content: CGSize, scale: CGFloat, in window: CGSize) -> CGSize {
        // The stored pan was measured at the stored zoom, so it grows with the live pinch. Without
        // this the plan slides under the fingers during a pinch and snaps back the moment the
        // gesture ends.
        let ratio = scale / max(zoom, 0.0001)
        let proposed = CGSize(width: pan.width * ratio + drag.width,
                              height: pan.height * ratio + drag.height)
        return ArtworkViewport.clampedPan(proposed, content: content, scale: scale, in: window)
    }

    /// The plan opens on its leading edge, as `452:2651` draws it — the drawing flush with the
    /// window's left and running off the right, rather than centred with both edges cropped.
    private func openOnTheLeadingEdge(content: CGSize, in window: CGSize) {
        viewport = window
        self.content = content
        pan = ArtworkViewport.leadingPan(content: content, scale: 1, in: window)
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in state = value.translation }
            .onEnded { value in
                commitPan(CGSize(width: pan.width + value.translation.width,
                                 height: pan.height + value.translation.height),
                          at: zoom)
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                let target = min(max(zoom * value.magnification, 1), Self.maximumZoom)
                let ratio = target / max(zoom, 0.0001)
                zoom = target
                if target == 1 {
                    // Zooming back out has to bring the plan back with it, or a plan panned to a
                    // corner at 4× and then zoomed out sits off-screen with no way to recover it.
                    // Back to the leading edge, which is where it opened.
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        pan = ArtworkViewport.leadingPan(content: content, scale: 1, in: viewport)
                    }
                } else {
                    commitPan(CGSize(width: pan.width * ratio, height: pan.height * ratio), at: target)
                }
            }
    }

    private func commitPan(_ proposed: CGSize, at scale: CGFloat) {
        pan = ArtworkViewport.clampedPan(proposed, content: content, scale: scale, in: viewport)
    }
}
