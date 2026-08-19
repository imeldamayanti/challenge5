import SwiftUI

/// The three onboarding illustrations, exported whole from Figma `523:1946`, `523:1973` and
/// `523:1999` (art groups `670:1692`, `670:1694`, `670:1749`).
///
/// **Exported as flat pictures rather than rebuilt.** Each is a composite the frames assemble out
/// of a photographed object plus a dozen rotated, shadowed, overlapping layers — three scrolls at
/// ±10°, five wax-sealed stamps at ±15° under a seal, and, on the scrolls, text set in a lorem face.
/// Reproducing that in SwiftUI would mean re-deriving geometry that is already decided, and every
/// re-derivation would be a place for the drawing to drift from the design. The exports carry the
/// shadows the frames draw, which is why the boxes below are a little larger than the art groups'
/// own bounds.
///
/// **These three files are 1× and want replacing.** They are contents-only renders, which is the
/// only form the export came back in with a transparent background — the ordinary export composites
/// the *frame's* fill behind the art, which on these frames is a cream sheet, so each picture
/// arrived sitting on a cream card that does not exist in the design. A 3× export made from Figma's
/// own export panel is a drop-in: same three names, same three boxes, and the fractions below are
/// in points and do not move. Until then the art is soft on a 3× screen.
///
/// **This is chrome, not content.** These pictures belong to the onboarding screens the way
/// `KultaraTypewriter`'s machine belongs to the story preview: they illustrate what the app is,
/// they are not authored material about a place, and they are replaced by a redesign rather than by
/// a content update. That is the line `Package.swift` draws between `Resources/Images` here and the
/// assets in `ContentKit`.
///
/// Note for whoever reads `onboarding-quest.png` closely: the scrolls in it are drawn carrying task
/// names ("Find The Iron Statue", "Ancient Script Meaning", "Find The Whip Bearer") that exist
/// nowhere in the content tree. They are the frame's illustration of a task sheet, printed at a
/// size no one reads, and nothing in the app renders from them (`AD-4`, `FR-RUN-06`).
public enum HisploraOnboardingArt: String, Sendable, CaseIterable {
    /// `670:1692` — the dancers before the temple gates.
    case explore
    /// `670:1694` — three task scrolls, fanned.
    case quest
    /// `670:1749` — five stamps under a wax seal.
    case collection

    /// The packaged file's name. Kept apart from the case name so the app target can name a picture
    /// (`"explore"`) without naming a file — a rename of the asset is then this line and nothing
    /// else.
    var resourceName: String { "onboarding-\(rawValue)" }

    /// How wide the exported picture is drawn, as a fraction of the 402-point frame.
    ///
    /// Taken from the export's own box, not from the art group's: the shadow bleed is part of the
    /// picture once it is a PNG, so measuring the group would draw every illustration slightly
    /// large and shift it up. `explore` is wider than the screen's 362-point text column, which is
    /// why the art is laid out outside the page's horizontal padding rather than inside it.
    public var widthFraction: CGFloat {
        switch self {
        case .explore: 378.0 / 402.0
        case .quest: 353.0 / 402.0
        case .collection: 321.0 / 402.0
        }
    }

    /// The export's own proportions, width over height.
    public var aspectRatio: CGFloat {
        switch self {
        case .explore: 1134.0 / 831.0
        case .quest: 1059.0 / 801.0
        case .collection: 963.0 / 900.0
        }
    }

    /// Loaded eagerly from the package bundle, the same way `StoryIllustrationMetrics` and
    /// `KultaraPaperTexture` load theirs: `Image(_:bundle:)` resolves lazily and draws nothing at
    /// all if the resource is ever dropped from `Package.swift`, whereas this way the miss is a
    /// value a test can see.
    public var image: Image? {
        Self.loaded[self] ?? nil
    }

    /// Whether the artwork shipped. `OnboardingArtTests` asserts it for every case, so removing a
    /// PNG fails the suite instead of quietly leaving a blank half-screen.
    public var isAvailable: Bool { Self.url(for: self) != nil }

    static func url(for art: HisploraOnboardingArt) -> URL? {
        Bundle.module.url(
            forResource: art.resourceName, withExtension: "png", subdirectory: "Images")
    }

    private static let loaded: [HisploraOnboardingArt: Image?] = {
        var table: [HisploraOnboardingArt: Image?] = [:]
        for art in HisploraOnboardingArt.allCases {
            #if canImport(UIKit)
            if let url = url(for: art),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                table[art] = Image(uiImage: image)
            } else {
                table[art] = Image?.none
            }
            #else
            table[art] = Image?.none
            #endif
        }
        return table
    }()
}

/// The segmented bar the onboarding frames carry under the status bar (`523:2053`–`2056`): one
/// 4-point rounded segment per screen, the reached ones in cream, the rest in `trackDim`.
///
/// Two things the frame does not do. The segments are drawn equal-width and flexible rather than at
/// the frame's fixed 115 points, so a fourth screen — see `OnboardingViewModel` on why there is one
/// — fits the same 362-point row without the bar running off the edge. And the whole row is one
/// accessibility element carrying a spoken position, because a count of filled boxes is exactly the
/// kind of meaning `NFR-A11Y-05` says shape must not carry alone. The caller supplies that string:
/// this module has no localisation table (`NFR-I18N-01`).
public struct HisploraProgressBar: View {
    @Environment(\.hisploraPalette) private var palette

    private let current: Int
    private let total: Int
    private let accessibilityLabel: String

    public init(current: Int, total: Int, accessibilityLabel: String) {
        self.current = current
        self.total = total
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.sm) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    // The current segment alone, not everything up to it. `523:1985`–`1987` dim the
                    // first *and* third segment on screen two, so the bar is a position indicator
                    // rather than a fill gauge, and it is reproduced as drawn.
                    .fill(index == current ? palette.inkCream.color : palette.trackDim.color)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
