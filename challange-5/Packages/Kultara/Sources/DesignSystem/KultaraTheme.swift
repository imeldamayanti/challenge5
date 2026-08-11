import Foundation

/// The typed-page theme — cream sheet, typewriter ink, one sage accent — in measured form. Every
/// colour the app renders text on or
/// in is declared here and enumerated in `contrastPairs`, so `NFR-A11Y-03` is a property the test
/// suite checks rather than a claim someone made once.
public struct KultaraPalette: Sendable, Equatable {

    // Surfaces — three, because text lands on all three and a token measured only against the
    // page background passes while being unreadable on a card.
    public let paper: SRGBColor
    public let paperRaised: SRGBColor
    public let paperSunken: SRGBColor

    // Inks
    public let ink: SRGBColor
    public let inkMuted: SRGBColor
    public let inkOnSeal: SRGBColor

    // Over a photograph. `NFR-A11Y-03` cannot be satisfied against an arbitrary image, so the
    // text block sits on an opaque scrim and the gradient above it is decoration.
    public let photoScrim: SRGBColor
    public let inkOnPhoto: SRGBColor
    public let inkMutedOnPhoto: SRGBColor

    // Accents
    public let seal: SRGBColor
    public let sealFill: SRGBColor
    public let rule: SRGBColor
    public let documentedInk: SRGBColor
    public let oralInk: SRGBColor
    public let warning: SRGBColor

    public init(
        paper: SRGBColor,
        paperRaised: SRGBColor,
        paperSunken: SRGBColor,
        ink: SRGBColor,
        inkMuted: SRGBColor,
        inkOnSeal: SRGBColor,
        photoScrim: SRGBColor,
        inkOnPhoto: SRGBColor,
        inkMutedOnPhoto: SRGBColor,
        seal: SRGBColor,
        sealFill: SRGBColor,
        rule: SRGBColor,
        documentedInk: SRGBColor,
        oralInk: SRGBColor,
        warning: SRGBColor
    ) {
        self.paper = paper
        self.paperRaised = paperRaised
        self.paperSunken = paperSunken
        self.ink = ink
        self.inkMuted = inkMuted
        self.inkOnSeal = inkOnSeal
        self.photoScrim = photoScrim
        self.inkOnPhoto = inkOnPhoto
        self.inkMutedOnPhoto = inkMutedOnPhoto
        self.seal = seal
        self.sealFill = sealFill
        self.rule = rule
        self.documentedInk = documentedInk
        self.oralInk = oralInk
        self.warning = warning
    }

    public var allTokens: [(name: String, value: SRGBColor)] {
        [("paper", paper), ("paperRaised", paperRaised), ("paperSunken", paperSunken),
         ("ink", ink), ("inkMuted", inkMuted), ("inkOnSeal", inkOnSeal),
         ("photoScrim", photoScrim), ("inkOnPhoto", inkOnPhoto), ("inkMutedOnPhoto", inkMutedOnPhoto),
         ("seal", seal), ("sealFill", sealFill), ("rule", rule),
         ("documentedInk", documentedInk), ("oralInk", oralInk), ("warning", warning)]
    }

    /// Every claim the palette makes about legibility, enumerated. The list is the contract.
    public var contrastPairs: [ContrastPair] {
        let surfaces: [(String, SRGBColor)] = [
            ("paper", paper), ("paperRaised", paperRaised), ("paperSunken", paperSunken),
        ]
        var pairs: [ContrastPair] = []

        for (surfaceName, surface) in surfaces {
            pairs.append(ContrastPair(label: "ink on \(surfaceName)",
                                      foreground: ink, background: surface, requirement: .bodyText))
            pairs.append(ContrastPair(label: "inkMuted on \(surfaceName)",
                                      foreground: inkMuted, background: surface, requirement: .bodyText))
            pairs.append(ContrastPair(label: "seal on \(surfaceName)",
                                      foreground: seal, background: surface, requirement: .bodyText))
            pairs.append(ContrastPair(label: "warning on \(surfaceName)",
                                      foreground: warning, background: surface, requirement: .bodyText))
        }

        // The accuracy chips sit on the sunken surface (FR-CP-05).
        pairs.append(ContrastPair(label: "documentedInk on paperSunken",
                                  foreground: documentedInk, background: paperSunken, requirement: .bodyText))
        pairs.append(ContrastPair(label: "oralInk on paperSunken",
                                  foreground: oralInk, background: paperSunken, requirement: .bodyText))

        // Over a photograph, against the scrim the text actually lands on.
        pairs.append(ContrastPair(label: "inkOnPhoto on photoScrim",
                                  foreground: inkOnPhoto, background: photoScrim, requirement: .bodyText))
        pairs.append(ContrastPair(label: "inkMutedOnPhoto on photoScrim",
                                  foreground: inkMutedOnPhoto, background: photoScrim, requirement: .bodyText))

        // Filled controls.
        pairs.append(ContrastPair(label: "inkOnSeal on sealFill",
                                  foreground: inkOnSeal, background: sealFill, requirement: .bodyText))

        // Hairlines, chip borders, focus rings: essential non-text, 3:1.
        pairs.append(ContrastPair(label: "rule on paper",
                                  foreground: rule, background: paper, requirement: .nonTextEssential))
        pairs.append(ContrastPair(label: "rule on paperRaised",
                                  foreground: rule, background: paperRaised, requirement: .nonTextEssential))
        pairs.append(ContrastPair(label: "sealFill on paper",
                                  foreground: sealFill, background: paper, requirement: .nonTextEssential))

        return pairs
    }
}

public enum KultaraTheme {

    public enum Appearance: String, Sendable, CaseIterable, CustomStringConvertible {
        case light, dark
        public var description: String { rawValue }
    }

    public static let allAppearances = Appearance.allCases

    public static func palette(for appearance: Appearance) -> KultaraPalette {
        switch appearance {
        case .light: light
        case .dark: dark
        }
    }

    // MARK: - Measured palettes
    //
    // The direction is a typed page: an undyed cream sheet, typewriter ink, and one sage accent —
    // the green of the machine itself. It replaces the earlier parchment-and-oxblood palette, which
    // read as costume rather than as a document.
    //
    // Sampled from the reference: sheet #F9F3E5, ambient card stock #F1EBDD, ink #362627, and the
    // machine's sage across #8E9574–#A8AB8C. Only one sample survived unchanged. The sage as
    // sampled reaches 2.4:1 on cream — fine for a painted steel body, not for text or for a filled
    // control — so the accent is the same hue carried down to #3D5138, and the *light* sage returns
    // in dark mode where it is the readable end. Ink moved off the sampled #362627 (a red-brown)
    // toward neutral, because on a cream sheet a warm ink at body size reads as faded.
    //
    // Every number below is produced by `KultaraThemeTests.reportMeasuredContrastRatios`.

    /// Light: a sheet in the platen. Lowest measured ratio is 3.84:1 on a hairline (needs 3:1);
    /// lowest text ratio is 5.58:1 (needs 4.5:1).
    public static let light = KultaraPalette(
        paper: SRGBColor(hex: "#F7F1E2"),           // the sheet
        paperRaised: SRGBColor(hex: "#FCF8EE"),     // card, a sheet laid on the page
        paperSunken: SRGBColor(hex: "#EAE2CF"),     // inset: chips, breakdown rows
        ink: SRGBColor(hex: "#26231C"),             // 13.91:1 on paper
        inkMuted: SRGBColor(hex: "#55503F"),        // 7.15:1 — dark enough to read, not just to imply
        inkOnSeal: SRGBColor(hex: "#FCF8EE"),       // 8.14:1 on the seal fill
        photoScrim: SRGBColor(hex: "#16170F"),      // opaque; the gradient's endpoint
        inkOnPhoto: SRGBColor(hex: "#F7F1E4"),
        inkMutedOnPhoto: SRGBColor(hex: "#CFC2AC"),
        seal: SRGBColor(hex: "#3D5138"),            // the machine's sage, carried down; 7.66:1
        sealFill: SRGBColor(hex: "#3D5138"),
        rule: SRGBColor(hex: "#7E7A63"),            // 3.84:1 — structural, not decorative
        documentedInk: SRGBColor(hex: "#26231C"),   // 12.15:1 on the chip surface
        oralInk: SRGBColor(hex: "#5A4326"),         // 7.18:1, and a different hue from documented
        warning: SRGBColor(hex: "#8A4410"))         // burnt ochre; 5.58:1 at worst

    /// Dark: the same page under a desk lamp (`NFR-PLAT-04`). Lowest measured ratio is 4.01:1 on a
    /// hairline; lowest text ratio is 7.99:1.
    public static let dark = KultaraPalette(
        paper: SRGBColor(hex: "#15160F"),
        paperRaised: SRGBColor(hex: "#20221A"),
        paperSunken: SRGBColor(hex: "#0E0F09"),
        ink: SRGBColor(hex: "#F1EDDD"),             // 15.52:1 on paper
        inkMuted: SRGBColor(hex: "#BCB7A2"),        // 9.04:1
        inkOnSeal: SRGBColor(hex: "#15160F"),       // 9.24:1 on the seal fill
        // A photograph does not get lighter in light mode, so the scrim does not flip.
        photoScrim: SRGBColor(hex: "#16170F"),
        inkOnPhoto: SRGBColor(hex: "#F7F1E4"),
        inkMutedOnPhoto: SRGBColor(hex: "#CFC2AC"),
        seal: SRGBColor(hex: "#A9C094"),            // the sampled sage, readable here; 9.24:1
        sealFill: SRGBColor(hex: "#A9C094"),
        rule: SRGBColor(hex: "#857F69"),            // 4.01:1
        documentedInk: SRGBColor(hex: "#F1EDDD"),   // 16.41:1
        oralInk: SRGBColor(hex: "#DCC7A2"),         // 11.67:1
        warning: SRGBColor(hex: "#E8B25C"))         // 8.39:1
}
