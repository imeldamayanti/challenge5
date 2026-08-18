import SwiftUI

/// The wax seals: the one that closes the Journal envelope (Figma `511:1430`) and the four the
/// Explorer's Card lays out as badges (`547:2954`).
///
/// **Provenance.** All five are photographic exports from the design file, and they are chrome in
/// the sense `PortraitFrame.swift` sets out — a seal depicts nothing and claims nothing, so it is a
/// licence question rather than an editorial one, recorded here so it stays answerable. What is
/// *written under* a seal is a different matter, and this view takes it as a parameter.
public enum HisploraWaxSealMetrics {

    /// The colours the design casts the badges in. Four, cycled by position, because the frames
    /// draw four and a fifth badge has to look like something. The order is the frame's reading
    /// order, so the first badge earned is the crimson one the envelope is also closed with.
    public enum Wax: String, Sendable, CaseIterable {
        case crimson, green, gold, magenta

        var resourceName: String { "badge-seal-\(rawValue)" }

        /// The seal for a badge at `index` in the reader's list. Deterministic, so a badge does not
        /// change colour between launches — colour here is decoration and never the only signal
        /// carrying meaning (`NFR-A11Y-05`); every seal is captioned with its name.
        public static func forIndex(_ index: Int) -> Wax {
            allCases[((index % allCases.count) + allCases.count) % allCases.count]
        }
    }

    /// The envelope's closing seal, cast in the same crimson as the first badge.
    public static let envelopeSeal: Image? = image(named: "wax-seal")

    /// Loaded once from the package bundle, for the reason given on `PortraitFrameMetrics`: a
    /// dropped resource becomes a value the fallback branches on rather than a blank screen.
    public static func image(named name: String) -> Image? {
        #if canImport(UIKit)
        guard let url = url(named: name),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }

    static func url(named name: String) -> URL? {
        Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Images")
    }

    /// Every seal this module ships, so a test fails when one stops shipping rather than the app
    /// quietly falling back to a drawn disc.
    public static var allResourceNames: [String] {
        ["wax-seal"] + Wax.allCases.map(\.resourceName)
    }

    public static var allAreAvailable: Bool {
        allResourceNames.allSatisfy { url(named: $0) != nil }
    }
}

/// A wax seal, on its own. Decoration: it is never the only thing naming what it stands for.
public struct HisploraWaxSeal: View {
    @Environment(\.hisploraPalette) private var palette

    private let wax: HisploraWaxSealMetrics.Wax?

    /// `nil` casts the envelope's own crimson seal rather than one of the badge four.
    public init(wax: HisploraWaxSealMetrics.Wax? = nil) {
        self.wax = wax
    }

    public var body: some View {
        Group {
            if let image = loaded {
                image.resizable().aspectRatio(contentMode: .fit)
            } else {
                // A ruled disc, for the same reason the portrait frame falls back to a ruled oval:
                // a missing decoration must not take the layout with it.
                Circle()
                    .fill(palette.brownDeep.color)
                    .overlay(Circle().stroke(palette.buttonRing.color,
                                             lineWidth: KultaraMetrics.hairline))
            }
        }
        .accessibilityHidden(true)
    }

    private var loaded: Image? {
        guard let wax else { return HisploraWaxSealMetrics.envelopeSeal }
        return HisploraWaxSealMetrics.image(named: wax.resourceName)
    }
}

/// One badge on the Explorer's Card: a seal with its name set beneath it (`547:2955`).
public struct HisploraSealBadge: View {
    @Environment(\.hisploraPalette) private var palette

    private let name: String
    private let wax: HisploraWaxSealMetrics.Wax

    public init(name: String, wax: HisploraWaxSealMetrics.Wax) {
        self.name = name
        self.wax = wax
    }

    public var body: some View {
        VStack(spacing: KultaraMetrics.sm) {
            HisploraWaxSeal(wax: wax)
                .frame(maxWidth: .infinity)
            Text(name)
                .kultaraFont(.editorialLabel)
                .foregroundStyle(palette.inkCream.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
