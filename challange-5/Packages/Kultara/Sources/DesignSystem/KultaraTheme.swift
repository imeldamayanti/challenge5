import Foundation

/// The aged-paper "royal letter" theme, in measured form. Every colour the app renders text on or
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
    // The visual direction taken literally — sepia ink #6B5436 on sepia parchment #E8DCC0, a warm
    // wax-seal red #A6512F, a soft tan hairline #C4B48E — was measured first and failed 15 of 30
    // pairs. The worst were not subtle: secondary text 2.90:1 against a card, the amber warning
    // 2.76:1, hairlines 1.50:1 where 3:1 is required. Exactly the failure `NFR-A11Y-03` names.
    //
    // What changed, and what did not. The *parchment* stayed: it is the identity, so it moved
    // lighter (#E8DCC0 → #F4EAD5) rather than away. What went was the sepia *ink* — brown text on
    // brown paper is where the ratios die. Body ink is now near-black warm brown, secondary text
    // is dark enough to read rather than merely to suggest, the wax seal deepened from orange-red
    // to oxblood, and the amber warning became burnt ochre. Hairlines had the largest change,
    // because a 1.5:1 rule is decoration pretending to be structure.
    //
    // Every number below is produced by `KultaraThemeTests.reportMeasuredContrastRatios`.

    /// Light: aged paper. Lowest measured ratio is 3.71:1 on a hairline (needs 3:1); lowest text
    /// ratio is 5.21:1 (needs 4.5:1).
    public static let light = KultaraPalette(
        paper: SRGBColor(hex: "#F4EAD5"),           // parchment
        paperRaised: SRGBColor(hex: "#FBF5E8"),     // card, a sheet laid on the page
        paperSunken: SRGBColor(hex: "#E7DAC0"),     // inset: chips, breakdown rows
        ink: SRGBColor(hex: "#2A2118"),             // 13.22:1 on paper
        inkMuted: SRGBColor(hex: "#57462F"),        // 7.57:1 — dark enough to read, not just to imply
        inkOnSeal: SRGBColor(hex: "#FBF5E8"),       // 9.13:1 on the seal fill
        seal: SRGBColor(hex: "#7A2617"),            // oxblood wax; 8.30:1 on paper
        sealFill: SRGBColor(hex: "#7A2617"),
        rule: SRGBColor(hex: "#8A7550"),            // 3.71:1 — structural, not decorative
        documentedInk: SRGBColor(hex: "#2A2118"),   // 11.43:1 on the chip surface
        oralInk: SRGBColor(hex: "#3A4433"),         // 7.39:1, and a different hue from documented
        warning: SRGBColor(hex: "#8A4410"))         // burnt ochre; 5.21:1 at worst

    /// Dark: the same letter read by lamplight (`NFR-PLAT-04`). Lowest measured ratio is 3.87:1 on
    /// a hairline; lowest text ratio is 6.68:1.
    public static let dark = KultaraPalette(
        paper: SRGBColor(hex: "#1B1610"),
        paperRaised: SRGBColor(hex: "#262019"),
        paperSunken: SRGBColor(hex: "#120E0A"),
        ink: SRGBColor(hex: "#F0E6D4"),             // 14.52:1 on paper
        inkMuted: SRGBColor(hex: "#C0B198"),        // 8.54:1
        inkOnSeal: SRGBColor(hex: "#1B1610"),       // 6.68:1 on the seal fill
        seal: SRGBColor(hex: "#E8A08C"),            // 8.42:1
        sealFill: SRGBColor(hex: "#E0866F"),
        rule: SRGBColor(hex: "#8A7A62"),            // 4.31:1
        documentedInk: SRGBColor(hex: "#F0E6D4"),   // 15.53:1
        oralInk: SRGBColor(hex: "#BFCBB2"),         // 11.35:1
        warning: SRGBColor(hex: "#E8B25C"))         // 9.37:1
}
