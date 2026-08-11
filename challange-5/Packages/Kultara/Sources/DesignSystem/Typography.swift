import SwiftUI

/// Type roles, each defined by a `Font.TextStyle` rather than a point size, because a fixed size
/// does not scale however carefully the layout is written (`NFR-A11Y-01`). There is deliberately no
/// API here that takes a size.
public enum KultaraTypography {

    public enum Role: String, Sendable, CaseIterable {
        /// Quest title on the preview screen.
        case questTitleLarge
        /// Quest title on a list card.
        case questTitle
        case sectionHeading
        case body
        /// Long-form lore. The same style as body, named separately so it cannot be shrunk on its
        /// own by someone tidying a layout.
        case lore
        /// Distance, duration, cost — read in the street, so not below footnote.
        case metadata
        case chipLabel
        case buttonLabel

        public var textStyle: Font.TextStyle {
            switch self {
            case .questTitleLarge: .largeTitle
            case .questTitle: .title2
            case .sectionHeading: .headline
            case .body: .body
            case .lore: .body
            case .metadata: .subheadline
            case .chipLabel: .footnote
            case .buttonLabel: .body
            }
        }

        public var weight: Font.Weight {
            switch self {
            case .questTitleLarge, .questTitle: .semibold
            case .sectionHeading, .buttonLabel: .semibold
            case .chipLabel: .medium
            case .body, .lore, .metadata: .regular
            }
        }

        /// Typed roles use a monospaced face — the theme's whole identity is a page that came out
        /// of a machine, and a proportional label next to a monospaced heading reads as a mistake.
        ///
        /// Long-form reading is the exception. `body` and `lore` stay proportional: monospace sets
        /// roughly 20% wider per character, and lore is the one place where that turns into extra
        /// wrapping at the largest accessibility sizes — precisely what `NFR-A11Y-01` is about.
        /// Charm loses to reading a paragraph.
        public var design: Font.Design {
            switch self {
            case .body, .lore: .default
            default: .monospaced
            }
        }

        /// Letter-spacing on the typed roles, taken from the reference's headings. Applied only
        /// where the string is short; tracking a paragraph is how a wall of text stops being one.
        public var tracking: CGFloat {
            switch self {
            case .questTitleLarge: 2
            case .sectionHeading, .chipLabel: 1.5
            case .questTitle, .buttonLabel, .metadata: 0.5
            case .body, .lore: 0
            }
        }

        /// Headings are set in caps, as on the reference sheet — and only headings. A capitalised
        /// sentence is slower to read; a capitalised quest title would flatten the proper nouns the
        /// content is made of; and an all-caps chip label risks VoiceOver taking a short word for
        /// an initialism and spelling it out, which `FR-CP-05` cannot afford.
        public var isUppercased: Bool {
            switch self {
            case .sectionHeading: true
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
        /// because extra leading on a one-line label reads as a layout bug.
        public var lineSpacing: CGFloat {
            switch self {
            case .lore, .body: 4
            default: 0
            }
        }
    }

    public static func font(_ role: Role) -> Font {
        .system(role.textStyle, design: role.design, weight: role.weight)
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

    public static let cardCornerRadius: CGFloat = 4
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
