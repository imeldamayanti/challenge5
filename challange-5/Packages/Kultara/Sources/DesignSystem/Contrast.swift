import Foundation

/// A colour in the sRGB space, held as component values rather than as a platform colour type so
/// contrast can be *measured* rather than eyeballed. `NFR-A11Y-03` is a numeric requirement, and
/// the "royal letter" aged-paper direction is called out in the PRD as being at direct risk of
/// failing it — so the theme is adapted to the measurement, never the other way round.
public struct SRGBColor: Sendable, Equatable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public init(hex: String) {
        var digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if digits.count == 3 {
            digits = digits.map { "\($0)\($0)" }.joined()
        }
        let value = UInt32(digits, radix: 16) ?? 0
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    public var hex: String {
        String(format: "#%02X%02X%02X",
               Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    /// WCAG 2.1 relative luminance. The per-channel gamma expansion is the part that gets
    /// dropped by mistake, and dropping it flatters a palette by a wide margin.
    public var relativeLuminance: Double {
        func expand(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * expand(red) + 0.7152 * expand(green) + 0.0722 * expand(blue)
    }
}

/// WCAG 2.1 contrast ratio, 1.0 … 21.0.
public func contrastRatio(_ a: SRGBColor, _ b: SRGBColor) -> Double {
    let first = a.relativeLuminance
    let second = b.relativeLuminance
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)
}

public struct ContrastRequirement: Sendable, Equatable, Hashable {
    public let name: String
    public let minimumRatio: Double

    /// `NFR-A11Y-03` — body text at 4.5:1. Lore is long-form reading, so this is the common case
    /// rather than the exception.
    public static let bodyText = ContrastRequirement(name: "body text", minimumRatio: 4.5)
    /// Large text — 3:1 by WCAG AA, meaning ≥ 24 pt regular or ≥ 19 pt bold at default sizes.
    public static let largeText = ContrastRequirement(name: "large text", minimumRatio: 3.0)
    /// Essential non-text: focus rings, icon strokes, the accuracy chip's border.
    public static let nonTextEssential = ContrastRequirement(name: "non-text essential", minimumRatio: 3.0)
}

/// One measurable claim the theme makes about itself: this foreground, on that background, at
/// this level. The theme exposes these so the test suite enumerates the theme rather than a
/// hand-picked list — a token added later without measuring fails the suite instead of shipping.
public struct ContrastPair: Sendable, Equatable {
    public let label: String
    public let foreground: SRGBColor
    public let background: SRGBColor
    public let requirement: ContrastRequirement

    public init(
        label: String,
        foreground: SRGBColor,
        background: SRGBColor,
        requirement: ContrastRequirement
    ) {
        self.label = label
        self.foreground = foreground
        self.background = background
        self.requirement = requirement
    }

    public var measuredRatio: Double { contrastRatio(foreground, background) }
    public var passes: Bool { measuredRatio >= requirement.minimumRatio }

    /// `NFR-A11Y-03` acceptance criterion 6 asks for a measurement on the final theme. This is
    /// the line that gets reported.
    public var measurementLine: String {
        String(format: "%@  %@ on %@  %.2f:1  (needs %.1f:1)  %@",
               label.padding(toLength: max(label.count, 34), withPad: " ", startingAt: 0),
               foreground.hex, background.hex,
               measuredRatio, requirement.minimumRatio,
               passes ? "PASS" : "FAIL")
    }
}
