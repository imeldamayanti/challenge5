import SwiftUI

/// Type roles, each defined by a `Font.TextStyle` rather than a point size, because a fixed size
/// does not scale however carefully the layout is written (`NFR-A11Y-01`). There is deliberately no
/// API here that takes a size.
public enum KultaraTypography {

    public enum Role: String, Sendable, CaseIterable {
        /// Quest title on the preview screen — the masthead of the page.
        case questTitleLarge
        /// Quest title on a list card.
        case questTitle
        /// A section's name, set in the display serif's italic, as on the reference spread.
        case sectionHeading
        /// The small ruled kicker above a heading or beside a plate: `EXHIBIT // 03`. Sans, caps,
        /// widely tracked — the museum label, not the label copy.
        case eyebrow
        case body
        /// Long-form lore. The same style as body, named separately so it cannot be shrunk on its
        /// own by someone tidying a layout.
        case lore
        /// Distance, duration, cost — read in the street, so not below footnote.
        case metadata
        /// A plate's caption: the exhibit's name in brackets over its date. Sans, so a caption
        /// under a serif title reads as apparatus rather than as more title.
        case caption
        case chipLabel
        case buttonLabel

        // MARK: The Hisplora story flow
        //
        // The roles that exist only on the story screens, in the faces those frames are drawn with.
        // They live in the same table as everything else so there is still exactly one place that
        // decides what a piece of type is — which is why `452:3132` and `447:1880`'s four New York
        // sizes are four roles here and not four `.system(size:)` calls in two views.

        /// The heading on a story-flow screen — "The Last Traces of Badung", "A Legend Will Guide
        /// Your Journey". Set in the system serif, as the frames set it.
        case storyDisplay
        /// A section's name on a story-flow screen: "All Quest" on `452:3174`. New York Medium at
        /// 25 as drawn — a third the size of `storyDisplay`, so it is its own role rather than that
        /// one shrunk at a call site.
        case storySection
        /// The task's own name on the parchment sheet (`447:1896`). Same size as `storySection` and
        /// a weight above it, because on that screen it is the masthead and there is nothing over
        /// it.
        case storyTaskTitle
        /// The place name printed at the head of the sheet, over the ornament (`447:1906`). New York
        /// Bold at 17 — the smallest and heaviest of the four, which is what makes it read as a
        /// standfirst rather than as a second title.
        case storyPlaceMark
        /// The onboarding screens' title (`523:1951`, `523:1978`, `523:2006`). New York Regular at
        /// 30 — between `storyDisplay` and `storySection`, and its own role rather than either of
        /// those bent at a call site, because it is the masthead of a screen that has no other
        /// serif on it.
        case onboardingDisplay
        /// The place name a story-flow screen carries in its top bar (`452:3136`), where the frame
        /// sets the serif rather than the sans the other bars use.
        case storyBarTitle
        /// The hook typed onto the sheet in the typewriter (`81:588`).
        case typedSheet
        /// The two figures ruled beneath it: the distance and the duration.
        case typedFigure
        /// A short serif label set at reading size — a badge's name under its wax seal, an
        /// envelope's title on its pocket (`547:2955`, `511:1428`).
        ///
        /// It exists because the frames name these objects in the serif at body size, and the
        /// table had no such role: every serif role above is a title cut at 22 points or more, and
        /// `sectionHeading` is italic. Setting a badge name in `questTitle` would print a 24-point
        /// title in a two-column grid; setting it in `body` would drop the face the frames name
        /// things in. One role, one decision, as the rest of this table works.
        case editorialLabel

        public var textStyle: Font.TextStyle {
            switch self {
            case .questTitleLarge: .largeTitle
            case .questTitle: .title2
            case .sectionHeading: .title3
            case .eyebrow: .caption
            case .body: .body
            case .lore: .body
            case .metadata: .subheadline
            case .caption: .footnote
            case .chipLabel: .footnote
            case .buttonLabel: .body
            case .storyDisplay: .largeTitle
            // 25 and 17 as drawn; `.title2` and `.title3` are the two system styles those sit
            // between, and a text style is what makes them scale at all (`NFR-A11Y-01`).
            case .storySection, .storyTaskTitle: .title2
            case .onboardingDisplay: .title
            case .storyPlaceMark, .storyBarTitle: .title3
            case .typedSheet: .footnote
            case .typedFigure: .title3
            case .editorialLabel: .body
            }
        }

        public var weight: Font.Weight {
            switch self {
            // The display serif ships in one weight, and asking SwiftUI to synthesise a bolder one
            // smears the modulation that is the reason for using it.
            case .questTitleLarge, .questTitle, .sectionHeading, .editorialLabel: .regular
            case .eyebrow, .buttonLabel: .semibold
            case .chipLabel: .medium
            case .body, .lore, .metadata, .caption: .regular
            // Special Elite ships in one weight, and New York's display cut is drawn light on
            // purpose — the frames set both regular.
            case .storyDisplay, .typedSheet, .typedFigure, .storyBarTitle,
                 .onboardingDisplay: .regular
            // The three weights `452:3174`, `447:1896` and `447:1906` are drawn in. New York is
            // the system's own serif and ships every weight, so unlike Instrument Serif these are
            // real cuts rather than a synthesised smear.
            case .storySection: .medium
            case .storyTaskTitle: .semibold
            case .storyPlaceMark: .bold
            }
        }

        /// Display roles are set in Instrument Serif; everything a reader has to read or operate is
        /// set in SF Pro. The split is the reference spread's, and it is doing work: the serif names
        /// things, the sans carries information.
        ///
        /// `body` and `lore` are sans for the same reason they were never monospaced — Instrument
        /// Serif is a display cut, and lore is where a display face at the largest accessibility
        /// sizes turns into extra wrapping, which is precisely what `NFR-A11Y-01` is about.
        public var face: KultaraFace {
            switch self {
            case .questTitleLarge, .questTitle, .sectionHeading: .serif
            case .storyDisplay, .storySection, .storyTaskTitle, .storyPlaceMark,
                 .storyBarTitle, .onboardingDisplay: .displaySerif
            case .typedSheet, .typedFigure: .typewriter
            default: .sans
            }
        }

        /// Section names are set in italic, as on the reference: `the collection`, `welcome`. The
        /// masthead is upright.
        public var isItalic: Bool {
            switch self {
            case .sectionHeading: true
            default: false
            }
        }

        /// The size the serif is cut at before Dynamic Type scales it, roughly a tenth above the
        /// system's own size for the style — Instrument Serif has a small x-height, so matched by
        /// point size it reads smaller than the sans beside it. Ignored by the sans roles, which
        /// take the system's size for their style unchanged.
        var basePointSize: CGFloat {
            switch self {
            case .questTitleLarge: 40
            case .questTitle: 24
            case .sectionHeading: 22
            case .storyDisplay: 38
            case .onboardingDisplay: 30
            case .storySection, .storyTaskTitle: 25
            case .storyPlaceMark, .storyBarTitle: 17
            // The frame types the sheet at 8.5 pt, because on the frame the sheet is a small
            // object inside a photograph. Reproduced literally it is unreadable, so the sheet is
            // set at a size a person can read and scales from there (`NFR-A11Y-01`). Deviation
            // recorded in `docs/hisplora-tokens.md`.
            //
            // 12 pt is the floor of that deviation, not a new value pulled from the frame: the
            // page is now a fixed window over a machine that does not move, so the passage has to
            // fit one sheet. `TypewriterTests.theSheetIsSetLargerThanTheFrameDrawsIt` holds the
            // floor; going under it re-opens the readability failure the deviation exists to
            // prevent.
            case .typedSheet: 12
            case .typedFigure: 17
            default: 17
            }
        }

        /// Letter-spacing, on the small sans roles only. The serif's own fit is what a display face
        /// is drawn for, and tracking a paragraph is how a wall of text stops being one.
        public var tracking: CGFloat {
            switch self {
            case .eyebrow: 2
            case .chipLabel, .caption: 0.5
            case .buttonLabel, .metadata: 0.3
            case .questTitleLarge, .questTitle, .sectionHeading, .editorialLabel, .body, .lore: 0
            // The frames track the display down (-0.76 at 38 pt) and the typed sheet in slightly.
            case .storyDisplay: -0.76
            // The onboarding frames set the 30-point title untracked, unlike the 38-point display.
            case .onboardingDisplay: 0
            case .storySection, .storyTaskTitle: -0.5
            case .storyPlaceMark: -0.34
            case .storyBarTitle: -0.38
            case .typedSheet, .typedFigure: -0.34
            }
        }

        /// Caps are for the eyebrow and nothing else. A capitalised sentence is slower to read; a
        /// capitalised quest title would flatten the proper nouns the content is made of; and an
        /// all-caps chip label risks VoiceOver taking a short word for an initialism and spelling
        /// it out, which `FR-CP-05` cannot afford.
        public var isUppercased: Bool {
            switch self {
            case .eyebrow: true
            default: false
            }
        }

        /// Whether WCAG's large-text allowance genuinely applies: ≥ 24 pt regular or ≥ 19 pt bold
        /// at the default content size. Only the two title roles qualify.
        public var isLargeText: Bool {
            switch self {
            // `typedFigure` is deliberately absent. It is `.title3` — 20 pt regular — which is
            // under WCAG's 24 pt, so claiming the allowance here would quietly lower the bar the
            // palette is measured against. It is inkDark on paper anyway, at 13.64:1.
            case .questTitleLarge, .questTitle, .storyDisplay, .onboardingDisplay: true
            default: false
            }
        }

        public var contrastRequirement: ContrastRequirement {
            isLargeText ? .largeText : .bodyText
        }

        /// Long-form roles get a looser line so a wall of lore is readable; short roles do not,
        /// because extra leading on a one-line label reads as a layout bug. The display serif is
        /// the other exception, and in the other direction — set at the reference's size it wants a
        /// line tighter than the default, which SwiftUI expresses as negative spacing.
        public var lineSpacing: CGFloat {
            switch self {
            case .lore, .body: 4
            case .questTitleLarge: -4
            case .questTitle, .sectionHeading: -2
            case .storyDisplay: -3
            case .onboardingDisplay: -2
            case .storySection, .storyTaskTitle, .storyPlaceMark, .storyBarTitle: -1
            // 1.4 line height on the frame's sheet, which at this size is a few points of air.
            case .typedSheet: 3
            default: 0
            }
        }
    }

    public static func font(_ role: Role) -> Font {
        KultaraFonts.font(role)
    }
}

public enum KultaraMetrics {
    /// `NFR-A11Y-06`.
    public static let minimumTapTarget: CGFloat = 44

    public static let spacingScale: [CGFloat] = [4, 8, 12, 16, 24, 32, 48]

    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32

    /// How much room a scrolling screen leaves at its foot for the floating tab bar.
    ///
    /// `KultaraTabBar` is published as a `safeAreaInset`, which reserves space for the two root
    /// tabs but is not reaching content pushed inside the navigation stack — the last card of a
    /// preview ends up underneath the pill. Until that is understood rather than guessed at, the
    /// screens that scroll pad their own foot by this much, because a control the walker cannot
    /// reach is worse than a gap at the end of a scroll.
    ///
    /// 64 for the pill, 8 for the padding under it, and 16 of air so the last line is not flush
    /// against it.
    ///
    /// **This value is the clearance at the default text size only.** `floatingTabBarClearance(labelScale:)`
    /// is what a screen should actually reserve; this stays public because it is the design's own
    /// number and the scaled form is defined in terms of it.
    public static let floatingTabBarClearance: CGFloat = 88

    /// The bar's own content height at the default text size — `KultaraTabBar`'s `minHeight`.
    ///
    /// A minimum rather than a height, which is the whole reason the clearance has to scale: the bar
    /// grows with its labels and a fixed 88 does not.
    public static let floatingTabBarContentHeight: CGFloat = 64

    /// The room a scrolling screen has to leave for the floating tab bar at a given label scale
    /// (`NFR-A11Y-02`, `NFR-A11Y-06`).
    ///
    /// The bug this exists for: the clearance was a fixed 88 while `KultaraTabBar` is a `minHeight`
    /// that grows with its labels. At the largest accessibility size the bar stands roughly 210
    /// points tall, the last control on a scrolling screen came to rest underneath it, and a tap on
    /// that control's centre belonged to the bar — so tapping "Settings" switched tab instead of
    /// opening Settings. `FloatingTabBarClearanceTests` holds every part of the contract below.
    ///
    /// Never *less* than the design's 88, however small the text: the bar has a minimum height, so
    /// shrinking the labels does not shrink the thing being cleared.
    public static func floatingTabBarClearance(labelScale: CGFloat) -> CGFloat {
        // The 24 is the 8 of padding under the pill plus the 16 of air above the last line — both
        // fixed, because neither is type.
        max(floatingTabBarClearance, floatingTabBarContentHeight * labelScale + sm + lg)
    }

    public static let cardCornerRadius: CGFloat = 4
    /// The photo cards on Home are rounded far more than a sheet of paper is — they are
    /// photographs, not documents, and the design draws them that way. 12 is the Ngalcer Home
    /// frame's own radius (`28:77`).
    public static let photoCardCornerRadius: CGFloat = 12
    public static let hairline: CGFloat = 1

    /// The round icon button the Home masthead carries beside the title (`28:173`). 48, not the
    /// 44-point minimum: the frame draws it larger, and a tap target may exceed `NFR-A11Y-06`
    /// but never fall under it.
    public static let circleButtonSize: CGFloat = 48

    /// The photograph's own height on a Home card at the default content size (`28:76`: 354×208).
    /// A minimum rather than a height — the caption decides how tall the card actually ends up,
    /// so the words are never clipped at an accessibility size (`NFR-A11Y-01`).
    public static let photoCardMinimumHeight: CGFloat = 208

    /// The caption block's own height on that card (`275:2183`: 354×89), and, like the card's, a
    /// minimum rather than a height.
    public static let photoCardCaptionHeight: CGFloat = 89

    /// The caption's horizontal inset (`275:2183`, `padding(.horizontal, 15)`). Not `lg`: 15 is the
    /// frame's number and the spacing scale has no 15 in it, so borrowing 16 would be a silent
    /// point of drift between the drawing and the screen.
    public static let photoCardCaptionInset: CGFloat = 15

    /// The gap between the card's title and its row of facts (`275:2183`, `spacing: 10`).
    public static let photoCardCaptionSpacing: CGFloat = 10
}

// MARK: - Accuracy chip appearance

/// How an accuracy label is drawn. Three differentiators, not one: the text itself, a border
/// treatment, and a symbol. Colour is the fourth and is never load-bearing (`NFR-A11Y-05`).
public struct ChipAppearance: Sendable, Equatable {

    public enum Border: String, Sendable, Equatable {
        /// A ruled box — a record.
        case solid
        /// A broken box — something told rather than filed.
        case dashed
    }

    public let border: Border
    public let borderWidth: CGFloat
    public let symbolName: String
    /// Always false: `FR-CP-05` forbids hiding the label behind a tap, and a chip that looks
    /// tappable invites exactly that reading.
    public let isInteractive: Bool

    public init(border: Border, borderWidth: CGFloat, symbolName: String, isInteractive: Bool = false) {
        self.border = border
        self.borderWidth = borderWidth
        self.symbolName = symbolName
        self.isInteractive = isInteractive
    }

    public static let documented = ChipAppearance(
        border: .solid, borderWidth: 1, symbolName: "doc.text")

    public static let oral = ChipAppearance(
        border: .dashed, borderWidth: 1, symbolName: "quote.bubble")
}
