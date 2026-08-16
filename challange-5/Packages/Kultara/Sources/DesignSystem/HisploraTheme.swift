import Foundation

/// The Hisplora story-flow palette, sampled from the Figma frames rather than from the file's
/// colour variables.
///
/// The file's Colors page (`1:632`) is an untouched template — Blond, Light Hot Pink, Maximum Blue
/// Purple, Android Green — and describes none of the screens it sits beside. The screens are drawn
/// in browns, cream and sepia as raw fills, so every value below was read off the frames and named
/// here. Measured, as always: `NFR-A11Y-03` is a number, and two pairs had to move (see below).
///
/// **Why this is a separate palette rather than new values in `KultaraPalette`.** The story flow is
/// a fixed editorial pairing — deep brown carrying cream type — not a surface that flips with the
/// system appearance. It is the same argument `photoScrim` already makes: a photograph does not get
/// lighter in light mode, and neither does a cutscene. The quest list, region map, settings and
/// summary stay on the museum theme until frames exist for them, so the seam falls at a screen
/// boundary rather than through the middle of one.
public struct HisploraPalette: Sendable, Equatable {

    // Grounds — the browns the frames alternate between.
    /// The deepest ground: story reveal, location screens, transition.
    public let brownDeep: SRGBColor
    /// A step lighter, used as the frame fill behind the cutscene and as the fill of the circular
    /// pager control.
    public let brownMid: SRGBColor
    /// The greyed brown the story-flow frames actually lay over themselves — a full-bleed
    /// `#58453E` rectangle on `81:588`, `98:1588` and `187:866`. It reads as smoke rather than as
    /// earth, and it is what the typewriter and the gilded frame are photographed against.
    public let brownStone: SRGBColor

    // Papers — the cream grounds the narrative screens are printed on.
    /// Story preview, the typewriter screen.
    public let paperCream: SRGBColor
    /// The sketch pages of Story Reveal.
    public let paperWarm: SRGBColor
    /// Location Checking, the lightest of the three.
    public let paperLight: SRGBColor

    // Inks on the brown grounds.
    public let inkCream: SRGBColor
    public let inkDusty: SRGBColor

    // Inks on the paper grounds.
    public let inkDark: SRGBColor
    public let inkBody: SRGBColor
    public let inkMuted: SRGBColor

    // The one filled control: a near-black pill with a white label.
    public let buttonFill: SRGBColor
    public let inkOnButton: SRGBColor
    /// The pill's boundary. The design draws none, and a near-black pill on mid-brown measures
    /// 2.04:1 — below the 3:1 WCAG 1.4.11 asks of a control's visual boundary. Rather than move
    /// the ground or the fill, the control gains a hairline. Deviation recorded in
    /// `docs/hisplora-tokens.md`.
    public let buttonRing: SRGBColor

    /// The hand-drawn annotation on the Story Reveal pages. Decoration only: it fails contrast
    /// against the paper by a wide margin and therefore never carries meaning by itself
    /// (`NFR-A11Y-05`). The phrase it marks carries a weight change as well, which is the signal
    /// that actually does the work.
    public let highlight: SRGBColor

    public init(
        brownDeep: SRGBColor,
        brownMid: SRGBColor,
        brownStone: SRGBColor,
        paperCream: SRGBColor,
        paperWarm: SRGBColor,
        paperLight: SRGBColor,
        inkCream: SRGBColor,
        inkDusty: SRGBColor,
        inkDark: SRGBColor,
        inkBody: SRGBColor,
        inkMuted: SRGBColor,
        buttonFill: SRGBColor,
        inkOnButton: SRGBColor,
        buttonRing: SRGBColor,
        highlight: SRGBColor
    ) {
        self.brownDeep = brownDeep
        self.brownMid = brownMid
        self.brownStone = brownStone
        self.paperCream = paperCream
        self.paperWarm = paperWarm
        self.paperLight = paperLight
        self.inkCream = inkCream
        self.inkDusty = inkDusty
        self.inkDark = inkDark
        self.inkBody = inkBody
        self.inkMuted = inkMuted
        self.buttonFill = buttonFill
        self.inkOnButton = inkOnButton
        self.buttonRing = buttonRing
        self.highlight = highlight
    }

    /// Sampled 2026-08-13, re-read 2026-08-14 from frames `81:588`, `81:617`, `89:1402`,
    /// `223:2004`, `98:1588`, `187:866`, `105:1699`, `187:954`, `187:1053`, `187:1103`.
    ///
    /// Two values are not the design's. `inkDusty` is drawn `#AA9B8E` and measures 3.34:1 on
    /// `brownStone` — a lead paragraph, so it is held to body text, and the theme yields to the
    /// threshold rather than the other way round (`NFR-A11Y-03`). It is lightened to the nearest
    /// passing value. `buttonRing` does not exist in the design at all and is added for the reason
    /// given on the property. Everything else is as drawn.
    public static let standard = HisploraPalette(
        brownDeep: SRGBColor(hex: "#6E2717"),
        brownMid: SRGBColor(hex: "#6E3B26"),
        brownStone: SRGBColor(hex: "#58453E"),
        paperCream: SRGBColor(hex: "#EEE7D2"),
        paperWarm: SRGBColor(hex: "#EADBC7"),
        paperLight: SRGBColor(hex: "#F4EADD"),
        inkCream: SRGBColor(hex: "#FDF2DE"),      // 9.63:1 on brownDeep, 8.11:1 on brownStone
        inkDusty: SRGBColor(hex: "#D0B5AE"),      // moved from the drawn #AA9B8E; 4.67:1 on brownStone
        inkDark: SRGBColor(hex: "#1D1D1D"),       // 14.18:1 on paperLight
        inkBody: SRGBColor(hex: "#444444"),       // 7.17:1 on paperWarm
        inkMuted: SRGBColor(hex: "#5E5A5A"),      // 5.72:1 on paperLight
        buttonFill: SRGBColor(hex: "#151311"),
        inkOnButton: SRGBColor(hex: "#FFFFFF"),   // 18.53:1 on the fill
        buttonRing: SRGBColor(hex: "#B69682"),    // 3.31:1 on brownMid — the boundary, added
        highlight: SRGBColor(hex: "#E0B341"))     // decoration, deliberately unmeasured as text

    public var allTokens: [(name: String, value: SRGBColor)] {
        [("brownDeep", brownDeep), ("brownMid", brownMid), ("brownStone", brownStone),
         ("paperCream", paperCream), ("paperWarm", paperWarm), ("paperLight", paperLight),
         ("inkCream", inkCream), ("inkDusty", inkDusty),
         ("inkDark", inkDark), ("inkBody", inkBody), ("inkMuted", inkMuted),
         ("buttonFill", buttonFill), ("inkOnButton", inkOnButton), ("buttonRing", buttonRing),
         ("highlight", highlight)]
    }

    /// Every legibility claim this palette makes, enumerated so the suite measures the palette
    /// rather than a hand-picked list.
    ///
    /// `highlight` is deliberately absent: it is a drawn annotation over text that is already
    /// measured, and enumerating it as a text pair would assert something it does not claim.
    public var contrastPairs: [ContrastPair] {
        var pairs: [ContrastPair] = []

        // Cream type on the two brown grounds. The headings are 40 pt serif — large text by any
        // reading — but the subtitles beside them are 15 pt, so the muted ink is held to body.
        for (name, ground) in [("brownDeep", brownDeep), ("brownMid", brownMid),
                               ("brownStone", brownStone)] {
            pairs.append(ContrastPair(label: "inkCream on \(name)",
                                      foreground: inkCream, background: ground,
                                      requirement: .largeText))
            pairs.append(ContrastPair(label: "inkDusty on \(name)",
                                      foreground: inkDusty, background: ground,
                                      requirement: .bodyText))
        }

        // Type on the three papers.
        for (name, paper) in [("paperCream", paperCream), ("paperWarm", paperWarm),
                              ("paperLight", paperLight)] {
            pairs.append(ContrastPair(label: "inkDark on \(name)",
                                      foreground: inkDark, background: paper,
                                      requirement: .bodyText))
            pairs.append(ContrastPair(label: "inkBody on \(name)",
                                      foreground: inkBody, background: paper,
                                      requirement: .bodyText))
            pairs.append(ContrastPair(label: "inkMuted on \(name)",
                                      foreground: inkMuted, background: paper,
                                      requirement: .bodyText))
        }

        // The filled control: its label, and its boundary against the ground it sits on.
        pairs.append(ContrastPair(label: "inkOnButton on buttonFill",
                                  foreground: inkOnButton, background: buttonFill,
                                  requirement: .bodyText))
        // `223:2004` inverts it — a white capsule with near-black type. Both halves are measured
        // rather than assumed symmetrical, and the white fill's own boundary against the ground is
        // what lets `HisploraLightPillButtonStyle` do without the ring the dark pill needs.
        pairs.append(ContrastPair(label: "buttonFill on inkOnButton",
                                  foreground: buttonFill, background: inkOnButton,
                                  requirement: .bodyText))
        pairs.append(ContrastPair(label: "inkOnButton on brownStone",
                                  foreground: inkOnButton, background: brownStone,
                                  requirement: .bodyText))
        pairs.append(ContrastPair(label: "buttonRing on brownMid",
                                  foreground: buttonRing, background: brownMid,
                                  requirement: .nonTextEssential))
        pairs.append(ContrastPair(label: "buttonRing on brownDeep",
                                  foreground: buttonRing, background: brownDeep,
                                  requirement: .nonTextEssential))
        pairs.append(ContrastPair(label: "buttonRing on brownStone",
                                  foreground: buttonRing, background: brownStone,
                                  requirement: .nonTextEssential))

        return pairs
    }
}
