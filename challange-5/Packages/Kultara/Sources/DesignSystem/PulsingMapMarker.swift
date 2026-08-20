import SwiftUI

/// The beating dot the transition screen puts over the place it is sending the walker to
/// (`187:1103`).
///
/// **It marks; it does not claim.** The dot is laid over a drawing at a point the *content*
/// authored — the same discipline `Place.mapPoint` follows — so this component takes a position and
/// knows nothing about where anything is. Give it no position and there is nothing to draw.
///
/// Three things it does that the frame does not draw, all of them requirements:
///
/// - **Under Reduce Motion the ring stops rather than the dot going away** (`NFR-A11Y-04`). A pulse
///   collapsed to nothing would take the marker with it, and the marker is the point of the screen.
///   What is left is the still dot with its ring at rest, which says the same thing without moving.
/// - **The dot never carries meaning by colour alone** (`NFR-A11Y-05`): it wears the cream ring the
///   site plan's markers wear, so it reads as a placed object over any part of a drawing, and the
///   caller names it in the map's accessibility label.
/// - **`mapMarker` is the token**, the one already measured against `paperCream` — the ground these
///   drawings are printed on — rather than a new colour that would need its own pair.
public struct HisploraPulsingMapMarker: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The still dot's diameter. The halo grows to `haloScale` times this.
    private let diameter: CGFloat

    @State private var isPulsing = false

    public init(diameter: CGFloat = 14) {
        self.diameter = diameter
    }

    /// How far the ring travels before it has faded out. Held here rather than inlined because the
    /// halo's reserved frame is sized from it — a ring that grew past its own frame would be
    /// clipped by whatever the marker is positioned inside.
    private static let haloScale: CGFloat = 2.6

    public var body: some View {
        ZStack {
            halo
            Circle()
                .fill(palette.mapMarker.color)
                .frame(width: diameter, height: diameter)
                .overlay(Circle().stroke(palette.paperCream.color, lineWidth: 2))
        }
        // The halo is drawn at its largest, so the marker occupies the room it needs whatever the
        // ring is doing. Sizing to the dot would let the ring be clipped at the moment it is widest.
        .frame(width: diameter * Self.haloScale, height: diameter * Self.haloScale)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }

    /// The ring that leaves the dot and fades. Under Reduce Motion it is drawn once, at rest and at
    /// its smallest — a static outline around the dot rather than a frozen mid-flight ring, which
    /// would read as a second object.
    private var halo: some View {
        Circle()
            .stroke(palette.mapMarker.color, lineWidth: 2)
            .frame(width: diameter, height: diameter)
            .scaleEffect(isPulsing ? Self.haloScale : 1)
            .opacity(isPulsing ? 0 : 0.7)
    }
}
