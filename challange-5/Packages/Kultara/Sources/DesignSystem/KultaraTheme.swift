import Foundation

/// The museum-catalogue theme — cream sheet, near-black ink, one brick-red seal — in measured form.
/// Every colour the app renders text on or
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
    // The direction is a museum catalogue: an uncoated cream stock, near-black ink, and one deep
    // brick red used for the things a visitor acts on — the section names, the ticket button, the
    // seal. It replaces the typed-page palette, whose sage accent belonged to the machine rather
    // than to the subject.
    //
    // Sampled from the reference spreads: stock #E9E5D9–#F9F5E9, the red across #6C2A1A–#8B3324,
    // and the dark spread's charcoal at #1F1F1F. The red survived close to as sampled, which is
    // unusual — a brick red that dark is already 7.33:1 on cream, so it can carry text *and* fill a
    // control without being pushed around. What moved is the dark appearance's accent: the same red
    // on charcoal is 2.1:1, so dark mode uses the light end of the same hue.
    //
    // Every number below is produced by `KultaraThemeTests.reportMeasuredContrastRatios`.

    /// Light: the catalogue page. Lowest measured ratio is 4.06:1 on a hairline (needs 3:1); lowest
    /// text ratio is 5.52:1 (needs 4.5:1).
    public static let light = KultaraPalette(
        paper: SRGBColor(hex: "#F6F1E4"),           // the stock
        paperRaised: SRGBColor(hex: "#FCF9F1"),     // plate mat, a sheet laid on the page
        paperSunken: SRGBColor(hex: "#E9E1D0"),     // inset: chips, breakdown rows
        ink: SRGBColor(hex: "#201C18"),             // 15.01:1 on paper
        inkMuted: SRGBColor(hex: "#585042"),        // 7.05:1 — dark enough to read, not just to imply
        inkOnSeal: SRGBColor(hex: "#FCF9F1"),       // 7.86:1 on the seal fill
        photoScrim: SRGBColor(hex: "#17130F"),      // opaque; the gradient's endpoint
        inkOnPhoto: SRGBColor(hex: "#F7F1E4"),
        inkMutedOnPhoto: SRGBColor(hex: "#CFC2AC"),
        seal: SRGBColor(hex: "#8C2F1E"),            // the reference's brick red; 7.33:1
        sealFill: SRGBColor(hex: "#8C2F1E"),
        rule: SRGBColor(hex: "#7C7563"),            // 4.06:1 — structural, not decorative
        documentedInk: SRGBColor(hex: "#201C18"),   // 13.01:1 on the chip surface
        oralInk: SRGBColor(hex: "#5A4326"),         // 7.13:1, and a different hue from documented
        // Ochre, not a second red: a warning beside the seal red has to be a different hue or the
        // page has two accents that mean different things and look the same. 5.52:1 at worst.
        warning: SRGBColor(hex: "#7A4E0C"))

    /// Dark: the reference's charcoal spread (`NFR-PLAT-04`). Lowest measured ratio is 3.78:1 on a
    /// hairline; lowest text ratio is 6.33:1.
    public static let dark = KultaraPalette(
        paper: SRGBColor(hex: "#1B1A18"),
        paperRaised: SRGBColor(hex: "#26241F"),
        paperSunken: SRGBColor(hex: "#121110"),
        ink: SRGBColor(hex: "#F2ECDD"),             // 14.76:1 on paper
        inkMuted: SRGBColor(hex: "#BEB6A3"),        // 8.62:1
        inkOnSeal: SRGBColor(hex: "#1B1A18"),       // 7.10:1 on the seal fill
        // A photograph does not get lighter in light mode, so the scrim does not flip.
        photoScrim: SRGBColor(hex: "#17130F"),
        inkOnPhoto: SRGBColor(hex: "#F7F1E4"),
        inkMutedOnPhoto: SRGBColor(hex: "#CFC2AC"),
        seal: SRGBColor(hex: "#E4907B"),            // the same red at the readable end; 7.10:1
        sealFill: SRGBColor(hex: "#E4907B"),
        rule: SRGBColor(hex: "#847D6B"),            // 3.78:1
        documentedInk: SRGBColor(hex: "#F2ECDD"),   // 16.00:1
        oralInk: SRGBColor(hex: "#DCC7A2"),         // 11.44:1
        warning: SRGBColor(hex: "#E8B25C"))         // 8.09:1 at worst
}
