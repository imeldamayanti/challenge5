import SwiftUI

/// The three onboarding illustrations, exported whole from Figma `702:2068`, `702:1999` and
/// `702:1980` (art groups `737:4729`, `737:4674`, `737:4649`).
///
/// **Exported as flat pictures rather than rebuilt.** Each is a composite the frames assemble out
/// of a photographed object plus a dozen rotated, shadowed, overlapping layers — three scrolls at
/// ±10°, five wax-sealed stamps at ±15° under a seal, and, on the scrolls, text set in a lorem face.
/// Reproducing that in SwiftUI would mean re-deriving geometry that is already decided, and every
/// re-derivation would be a place for the drawing to drift from the design. The exports carry the
/// shadows the frames draw, which is why the boxes below are a little larger than the art groups'
/// own bounds.
///
/// **These three files are 3×, and their transparency is recovered rather than exported.** Figma
/// returns exactly two things and neither is what is wanted on its own: an ordinary export at any
/// scale composites the *frame's* cream fill behind the art, and a contents-only render is
/// transparent but will not upscale past 1× whatever `maxDimension` asks for. So each picture is
/// built from both — the 3× export supplies the colour, the 1× contents-only render supplies the
/// alpha (resampled up), and the ground is divided back out of the colour
/// (`art = (composite − (1 − α)·cream) / α`). The result is the design's own pixels at 3× with a
/// real alpha channel, which matters because the shadows these frames draw are soft: keying the
/// cream out by colour would have left a hard halo everywhere a shadow fades.
///
/// Quantised to a 256-colour palette afterwards (600 KB for the three, against 2.9 MB unquantised).
/// That is a size decision on chrome, not on content: nothing here is a photograph of a real place
/// that a walker is asked to recognise.
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
    /// `737:4729` — the dancers before the temple gates.
    case explore
    /// `737:4674` — three task scrolls, fanned.
    case quest
    /// `737:4649` — five stamps under a wax seal.
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
        case .quest: 340.0 / 402.0
        // `737:4649` is drawn 46 from the left and 31.67 from the right rather than centred. The
        // 7-point offset is not reproduced: it reads as a mistake on a 402-point frame and as a
        // worse one on any other width, and centring is what every other picture here does.
        case .collection: 324.333 / 402.0
        }
    }

    /// The export's own proportions, width over height.
    public var aspectRatio: CGFloat {
        switch self {
        case .explore: 1134.0 / 831.0
        case .quest: 1020.0 / 771.0
        case .collection: 973.0 / 822.0
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

/// The segmented bar the onboarding frames carry under the status bar (`702:2079`–`2082`): one
/// 4-point rounded segment per screen, the reached one in `buttonFill`, the rest in `trackDim`.
///
/// Two things the frame does not do. The segments are drawn equal-width and flexible rather than at
/// the frame's fixed 115 points, so the bar takes whatever `total` it is given without running off
/// the 362-point row — onboarding is three screens again as of 2026-08-20, and was four before it.
/// And the whole row is one accessibility element carrying a spoken position, because a count of
/// filled boxes is exactly the kind of meaning `NFR-A11Y-05` says shape must not carry alone. The
/// caller supplies that string: this module has no localisation table (`NFR-I18N-01`).
public struct HisploraProgressBar: View {
    @Environment(\.hisploraPalette) private var palette

    private let current: Int
    private let total: Int
    private let ink: KeyPath<HisploraPalette, SRGBColor>
    private let track: KeyPath<HisploraPalette, SRGBColor>
    private let accessibilityLabel: String

    /// - Parameters:
    ///   - ink: the reached segment. Defaults to the near-black the redesigned frames set on cream.
    ///   - track: the unreached ones. `trackDim` is that ink at 25% over `paperSheet`, flattened,
    ///     and the pair is measured in `HisploraThemeTests` — a caller that overrides one of these
    ///     is claiming a pair nobody measured, so both are named together or neither is.
    public init(
        current: Int,
        total: Int,
        ink: KeyPath<HisploraPalette, SRGBColor> = \.buttonFill,
        track: KeyPath<HisploraPalette, SRGBColor> = \.trackDim,
        accessibilityLabel: String
    ) {
        self.current = current
        self.total = total
        self.ink = ink
        self.track = track
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.sm) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    // The current segment alone, not everything up to it. `702:2080`–`2082` dim the
                    // second *and* third segment on every screen the board draws, so the bar is a
                    // position indicator rather than a fill gauge, and it is reproduced as drawn.
                    .fill(index == current
                          ? palette[keyPath: ink].color
                          : palette[keyPath: track].color)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
