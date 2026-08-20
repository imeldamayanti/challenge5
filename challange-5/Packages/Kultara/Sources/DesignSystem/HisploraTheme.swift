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
    /// The printed sheet's own stock — `275:2179`'s `#FDF2DE`, the colour `KultaraGround` renders
    /// over. The Journal and the Explorer's Card stand on it as of 2026-08-19, so it is a ground
    /// here and not only in the museum palette, and it is measured as one.
    public let paperSheet: SRGBColor

    // Inks on the brown grounds.
    public let inkCream: SRGBColor
    public let inkDusty: SRGBColor

    /// The quest-row card on `452:3132` — a shade warmer and lighter than `paperCream`, drawn as a
    /// ticket rather than as a sheet. Kept as its own token instead of rounded into `paperCream`
    /// because the two sit on the same screen: the stamp's cream and the rows' cream differ, and
    /// collapsing them loses the layering the frame builds.
    public let paperTicket: SRGBColor
    /// The row title on that card. Not `inkDark`: the frame sets the titles a touch warmer than
    /// the near-black it uses on the story papers.
    public let inkTicket: SRGBColor
    /// The well of the segmented task progress bar (`452:3138`), which the filled segments are
    /// stamped into.
    public let trackWell: SRGBColor
    /// The unfilled segment of the onboarding progress bar (`702:2081`, `702:2082`), which the
    /// frames draw as 25% `buttonFill` over `paperSheet`.
    ///
    /// Flattened to an opaque value rather than left as an alpha, for the reason `KultaraPaperTexture`
    /// gives about the grain: `HisploraThemeTests` measures token pairs, and a pair one half of which
    /// is a translucency over "whatever is behind it" is not a pair anyone measured. The flattened
    /// value is exactly what the frame composites to on this screen's one ground.
    ///
    /// **Re-sampled 2026-08-20.** The onboarding redesign (`702:2068`, `702:1999`, `702:1980`)
    /// moved the whole screen off `brownMid` and onto the cream `paperSheet`, so the wash the bar
    /// is drawn as composites over a different ground and the flattened value moved with it —
    /// `#926954` became `#C3BAAB`. The token is repointed rather than duplicated: the onboarding
    /// bar is its only caller, and a second token for the ground nobody draws it on any more would
    /// be a colour with no screen behind it.
    public let trackDim: SRGBColor
    /// The underlined "Skip" the redesigned onboarding frames set at the top right
    /// (`737:4731`, `737:4734`, `737:4741`): 75% `buttonFill` over `paperSheet`, flattened for the
    /// same reason `trackDim` is.
    public let inkQuiet: SRGBColor
    /// The stock the Journal's two paper cards are printed on (`791:5568`, `791:5814`) — the sheets
    /// that come out of the envelope and are read in the modal.
    ///
    /// Its own token rather than `paperLight` rounded to: the card is a torn sheet photographed
    /// over a dark scrim, and the two creams sit on the same screen the moment a card is drawn
    /// over the shelf. `#F5F1E5` is the frame's fill and this is where it is written down.
    public let paperCard: SRGBColor
    /// The site-map screen's ground (`452:3028`). The only screen in the story flow that is not on
    /// a brown: the plan is a document, and the frame lays it on paper rather than on earth.
    public let mapGround: SRGBColor
    /// The marker dots on the site plan (`452:3032`–`3034`). Drawn on the plan itself, so it is
    /// measured against the papers rather than against "whatever the drawing happens to be" — and
    /// it never carries meaning alone (`NFR-A11Y-05`): the markers are also named in the plan's
    /// accessibility label, and each one carries a cream ring so it reads as a placed object.
    public let mapMarker: SRGBColor

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
        paperSheet: SRGBColor,
        paperTicket: SRGBColor,
        inkTicket: SRGBColor,
        trackWell: SRGBColor,
        trackDim: SRGBColor,
        inkQuiet: SRGBColor,
        paperCard: SRGBColor,
        mapGround: SRGBColor,
        mapMarker: SRGBColor,
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
        self.paperSheet = paperSheet
        self.paperTicket = paperTicket
        self.inkTicket = inkTicket
        self.trackWell = trackWell
        self.trackDim = trackDim
        self.inkQuiet = inkQuiet
        self.paperCard = paperCard
        self.mapGround = mapGround
        self.mapMarker = mapMarker
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
    /// `223:2004`, `98:1588`, `187:866`, `105:1699`, `187:954`, `187:1053`, `187:1103`. Extended
    /// 2026-08-17 from `452:3132` ("Quest 1/3"), `447:1880` ("Quest_Filled") and `452:3028`
    /// ("Site Map").
    ///
    /// Two values are not the design's. `inkDusty` is drawn `#AA9B8E` and measures 3.34:1 on
    /// `brownStone` — a lead paragraph, so it is held to body text, and the theme yields to the
    /// threshold rather than the other way round (`NFR-A11Y-03`). It is lightened to the nearest
    /// passing value. `buttonRing` does not exist in the design at all and is added for the reason
    /// given on the property. Everything else is as drawn.
    ///
    /// The 2026-08-17 additions are all as drawn; what moved on those three screens is *usage*, not
    /// values, and all three moves are recorded in `docs/hisplora-tokens.md`: `452:3138`'s unfilled
    /// segments lose their 29% cream wash, that bar's `#9F8E88` outline is replaced by the already
    /// measured `buttonRing`, and `447:1900`'s `#CAB7B0` pill outline is replaced by `brownMid`.
    public static let standard = HisploraPalette(
        brownDeep: SRGBColor(hex: "#6E2717"),
        brownMid: SRGBColor(hex: "#6E3B26"),
        brownStone: SRGBColor(hex: "#58453E"),
        paperCream: SRGBColor(hex: "#EEE7D2"),
        paperWarm: SRGBColor(hex: "#EADBC7"),
        paperLight: SRGBColor(hex: "#F4EADD"),
        paperSheet: SRGBColor(hex: "#FDF2DE"),    // 15.26:1 under inkDark
        paperTicket: SRGBColor(hex: "#EFEBD7"),   // 10.79:1 under inkTicket
        inkTicket: SRGBColor(hex: "#34312E"),
        trackWell: SRGBColor(hex: "#8D7870"),     // 3.36:1 against a filled segment
        trackDim: SRGBColor(hex: "#C3BAAB"),      // 9.65:1 against a filled segment
        inkQuiet: SRGBColor(hex: "#4F4B44"),      // 7.82:1 on paperSheet
        paperCard: SRGBColor(hex: "#F5F1E5"),     // 15.02:1 under inkDark, 8.02:1 under brownMid
        mapGround: SRGBColor(hex: "#DFCDB5"),     // 11.95:1 under buttonFill
        mapMarker: SRGBColor(hex: "#B44934"),     // 4.31:1 on paperCream, 3.43:1 on mapGround
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
         ("paperTicket", paperTicket), ("inkTicket", inkTicket),
         ("trackWell", trackWell), ("trackDim", trackDim), ("inkQuiet", inkQuiet),
         ("paperSheet", paperSheet), ("paperCard", paperCard),
         ("mapGround", mapGround), ("mapMarker", mapMarker),
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

        // Type on the four papers.
        for (name, paper) in [("paperCream", paperCream), ("paperWarm", paperWarm),
                              ("paperLight", paperLight), ("paperSheet", paperSheet),
                              ("paperCard", paperCard)] {
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

        // The quest-row ticket on `452:3132`. Its own ink plus the two the row's subtitle and any
        // resolved-state note are set in, because a card is only as legible as the least legible
        // thing printed on it.
        for (name, ink) in [("inkTicket", inkTicket), ("inkBody", inkBody), ("inkMuted", inkMuted)] {
            pairs.append(ContrastPair(label: "\(name) on paperTicket",
                                      foreground: ink, background: paperTicket,
                                      requirement: .bodyText))
        }

        // The segmented task progress bar (`452:3138`). This pair *is* the bar's state: a filled
        // segment is `paperCream`, an unfilled one is the bare well, and if the two are not
        // distinguishable the bar says nothing. It is why the frame's 29% cream wash on the
        // unfilled segments is gone — washed, they measure 2.25:1 against a filled one.
        pairs.append(ContrastPair(label: "paperCream on trackWell",
                                  foreground: paperCream, background: trackWell,
                                  requirement: .nonTextEssential))

        // The onboarding progress bar (`702:2079`). Same argument as the task bar above: the pair
        // *is* the bar's state. A walker who cannot tell a walked segment from an unwalked one is
        // being shown nothing, and the position is also spoken — the bar carries an "screen 2 of 4"
        // label, so the shape never carries the count alone (`NFR-A11Y-05`).
        pairs.append(ContrastPair(label: "buttonFill on trackDim",
                                  foreground: buttonFill, background: trackDim,
                                  requirement: .nonTextEssential))
        // The same screens' underlined Skip, which is the one piece of type on them that is not set
        // in the full-strength ink.
        pairs.append(ContrastPair(label: "inkQuiet on paperSheet",
                                  foreground: inkQuiet, background: paperSheet,
                                  requirement: .bodyText))
        // ...and their one action, a near-black pill printed on the same cream.
        pairs.append(ContrastPair(label: "buttonFill on paperSheet",
                                  foreground: buttonFill, background: paperSheet,
                                  requirement: .bodyText))

        // The site-map screen (`452:3028`) — the one paper ground in the story flow.
        //
        // `inkMuted` is deliberately absent: it measures 4.39:1 here, just under body text, so the
        // plan's citation line is set in `inkBody` instead. Enumerating the pair would assert
        // something this screen does not do.
        for (name, ink) in [("buttonFill", buttonFill), ("inkDark", inkDark), ("inkBody", inkBody)] {
            pairs.append(ContrastPair(label: "\(name) on mapGround",
                                      foreground: ink, background: mapGround,
                                      requirement: .bodyText))
        }
        // The marker dots. Measured against the plan's own cream, which is where they are actually
        // drawn — never against `mapGround`, which is the screen behind the plan and not a ground
        // any marker lands on.
        pairs.append(ContrastPair(label: "mapMarker on paperCream",
                                  foreground: mapMarker, background: paperCream,
                                  requirement: .nonTextEssential))

        // `447:1880`'s parchment sheet does two jobs in `brownMid`: the place name printed at its
        // head, and — after the deviation — the outline of the "Take Photo" control. The sheet's
        // lightest sampled interior is `#F3F1E5`; `paperCream` stands in for it here as the
        // packaged art's own darker end, which is the conservative direction for both.
        pairs.append(ContrastPair(label: "brownMid on paperCream",
                                  foreground: brownMid, background: paperCream,
                                  requirement: .bodyText))

        // The Journal's paper card (`791:5568`): the eyebrow over its title is set in `brownMid`,
        // and the card's one control is the near-black pill printed on the same sheet.
        pairs.append(ContrastPair(label: "brownMid on paperCard",
                                  foreground: brownMid, background: paperCard,
                                  requirement: .bodyText))
        pairs.append(ContrastPair(label: "buttonFill on paperCard",
                                  foreground: buttonFill, background: paperCard,
                                  requirement: .bodyText))

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
