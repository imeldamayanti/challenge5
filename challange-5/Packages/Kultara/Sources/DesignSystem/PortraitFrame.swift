import SwiftUI

/// The gilded oval frame the cutscene presents a portrait in (Figma `223:1987`, "Group 104").
///
/// The frame is a single PNG with a transparent oval interior, laid *over* the portrait rather than
/// around it, so the carved inner bevel overlaps the picture's edge the way a real frame does. The
/// portrait is clipped to an ellipse behind it; without the clip, a photograph whose aspect ratio
/// differs from the opening shows its corners through the transparent centre.
///
/// **Provenance.** The ornament is a generated image, exported from the design file where it is
/// named `ChatGPT Image Aug 13, 2026 at 09_35_01 AM`. As chrome — a decorative frame that depicts
/// nothing and claims nothing — that is a licence question rather than an editorial one, and it is
/// recorded here so the question is answerable later. **The portrait placed inside it is a different
/// matter**: this view deliberately takes the picture as a parameter and does not caption it, because
/// a likeness of a named person is a claim, and `FR-CP-05` requires every claim to carry its
/// epistemic status and its source. The caller supplies both the image and the words about it.
public struct KultaraPortraitFrame<Portrait: View>: View {
    @Environment(\.kultaraPalette) private var palette

    private let accessibilityLabel: String
    private let portrait: Portrait

    public init(accessibilityLabel: String, @ViewBuilder portrait: () -> Portrait) {
        self.accessibilityLabel = accessibilityLabel
        self.portrait = portrait()
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                portrait
                    .frame(width: size.width * PortraitFrameMetrics.openingSize.width,
                           height: size.height * PortraitFrameMetrics.openingSize.height)
                    .clipShape(Ellipse())
                    .offset(x: size.width * PortraitFrameMetrics.openingOrigin.x,
                            y: size.height * PortraitFrameMetrics.openingOrigin.y)
                ornament(size: size)
            }
            .frame(width: size.width, height: size.height)
        }
        // The frame keeps its proportions at every text size and on every device: it is a picture
        // frame, and a stretched one reads as a mistake rather than as a layout.
        .aspectRatio(PortraitFrameMetrics.aspectRatio, contentMode: .fit)
        // One element, named by the caller. The ornament is decoration and the portrait cannot name
        // itself, so a VoiceOver reader gets the sitter rather than "image, image".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// The carved frame, or a ruled oval when the asset cannot be loaded. The fallback exists for the
    /// same reason the map's does: a missing decoration must not take the portrait with it.
    @ViewBuilder private func ornament(size: CGSize) -> some View {
        if let image = PortraitFrameMetrics.ornamentImage {
            image
                .resizable()
                .frame(width: size.width, height: size.height)
                .accessibilityHidden(true)
        } else {
            Ellipse()
                .stroke(palette.seal.color, lineWidth: 2)
                .frame(width: size.width * PortraitFrameMetrics.openingSize.width,
                       height: size.height * PortraitFrameMetrics.openingSize.height)
                .offset(x: size.width * PortraitFrameMetrics.openingOrigin.x,
                        y: size.height * PortraitFrameMetrics.openingOrigin.y)
                .accessibilityHidden(true)
        }
    }
}

/// The frame's measurements and its packaged ornament, kept out of the view because a generic type
/// cannot hold stored statics — and because proportions are values worth testing without building
/// a view to read them.
public enum PortraitFrameMetrics {

    /// The frame's own proportions, 360 × 450 in the design.
    public static let aspectRatio: CGFloat = 360.0 / 450.0

    /// Where the opening sits inside the frame, as a fraction of the frame's size. Measured from two
    /// instances that draw the group at different scales — 360 × 450 in `98:1588` and 320 × 400 in
    /// `187:866` — which agree to four decimal places, so these are the design's real ratios and not
    /// one screen's rounding.
    public static let openingOrigin = CGPoint(x: 50.0 / 320.0, y: 52.5 / 400.0)
    public static let openingSize = CGSize(width: 231.25 / 320.0, height: 295.0 / 400.0)

    /// Loaded once from the package bundle. `Image(_:bundle:)` would resolve lazily and silently draw
    /// nothing if the resource were ever dropped from `Package.swift`; this way the miss is a value
    /// the fallback can branch on, and `ornamentIsAvailable` makes it testable.
    static let ornamentImage: Image? = {
        #if canImport(UIKit)
        guard let url = ornamentURL,
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }()

    static var ornamentURL: URL? {
        Bundle.module.url(
            forResource: "portrait-frame", withExtension: "png", subdirectory: "Images")
    }

    /// Whether the packaged ornament resolved. Exposed so a test can fail when the resource stops
    /// shipping, rather than the app quietly falling back to a plain oval.
    public static var ornamentIsAvailable: Bool { ornamentURL != nil }
}
