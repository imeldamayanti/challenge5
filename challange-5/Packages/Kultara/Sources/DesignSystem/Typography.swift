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
            }
        }

        public var weight: Font.Weight {
            switch self {
            // The display serif ships in one weight, and asking SwiftUI to synthesise a bolder one
            // smears the modulation that is the reason for using it.
            case .questTitleLarge, .questTitle, .sectionHeading: .regular
            case .eyebrow, .buttonLabel: .semibold
            case .chipLabel: .medium
            case .body, .lore, .metadata, .caption: .regular
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
            case .questTitleLarge, .questTitle, .sectionHeading, .body, .lore: 0
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
            case .questTitleLarge, .questTitle: true
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
    public static let floatingTabBarClearance: CGFloat = 88

    public static let cardCornerRadius: CGFloat = 4
    /// The photo cards on Home are rounded far more than a sheet of paper is — they are
    /// photographs, not documents, and the design draws them that way.
    public static let photoCardCornerRadius: CGFloat = 16
    public static let hairline: CGFloat = 1
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
