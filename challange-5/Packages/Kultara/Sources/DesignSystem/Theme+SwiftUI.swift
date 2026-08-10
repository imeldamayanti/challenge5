import SwiftUI

public extension SRGBColor {
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

public extension KultaraTheme {
    static func palette(for colorScheme: ColorScheme) -> KultaraPalette {
        colorScheme == .dark ? dark : light
    }
}

private struct KultaraPaletteKey: EnvironmentKey {
    static let defaultValue = KultaraTheme.light
}

public extension EnvironmentValues {
    var kultaraPalette: KultaraPalette {
        get { self[KultaraPaletteKey.self] }
        set { self[KultaraPaletteKey.self] = newValue }
    }
}

/// Resolves the palette from the current appearance and publishes it downwards, so no view reads
/// `colorScheme` to pick a colour by hand — that is how a dark-mode token gets missed
/// (`NFR-PLAT-04`).
public struct KultaraThemeProvider<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let palette = KultaraTheme.palette(for: colorScheme)
        content
            .environment(\.kultaraPalette, palette)
            .background(palette.paper.color.ignoresSafeArea())
            .tint(palette.seal.color)
    }
}

public extension View {
    /// Applies a role's font and its line spacing together. Splitting them is how lore ends up
    /// with body type and caption leading.
    func kultaraFont(_ role: KultaraTypography.Role) -> some View {
        font(KultaraTypography.font(role))
            .lineSpacing(role.lineSpacing)
    }

    /// `NFR-A11Y-06`. Applied to the hit region, not the glyph, so a small icon still has a
    /// 44-point target around it.
    func kultaraTapTarget() -> some View {
        frame(minWidth: KultaraMetrics.minimumTapTarget,
              minHeight: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
    }
}

/// A sheet laid on the page. Uses `paperRaised`, which the theme measures body ink against.
public struct KultaraCard<Content: View>: View {
    @Environment(\.kultaraPalette) private var palette
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(KultaraMetrics.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.paperRaised.color)
            .overlay(
                RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius)
                    .stroke(palette.rule.color, lineWidth: KultaraMetrics.hairline))
            .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius))
    }
}

/// A ruled hairline. `rule` is measured at 3:1 because it carries structure, not decoration.
public struct KultaraRule: View {
    @Environment(\.kultaraPalette) private var palette

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(palette.rule.color)
            .frame(height: KultaraMetrics.hairline)
            .accessibilityHidden(true)
    }
}

/// The accuracy label from `FR-CP-05`, rendered as text plus a border treatment plus a symbol.
/// The caller supplies the already-localised text, so this stays content-agnostic — `DesignSystem`
/// does not know what a `LoreBlock` is.
public struct AccuracyChip: View {
    @Environment(\.kultaraPalette) private var palette

    private let text: String
    private let appearance: ChipAppearance
    private let ink: KeyPath<KultaraPalette, SRGBColor>

    public init(text: String, appearance: ChipAppearance, ink: KeyPath<KultaraPalette, SRGBColor>) {
        self.text = text
        self.appearance = appearance
        self.ink = ink
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.xs) {
            Image(systemName: appearance.symbolName)
                .imageScale(.small)
            Text(text)
        }
        .kultaraFont(.chipLabel)
        .foregroundStyle(palette[keyPath: ink].color)
        .padding(.horizontal, KultaraMetrics.sm)
        .padding(.vertical, KultaraMetrics.xs)
        .background(palette.paperSunken.color)
        .overlay(border)
        // One label, read out whole. The symbol is decoration for VoiceOver's purposes; the text
        // already says which kind of claim this is.
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var border: some View {
        let shape = RoundedRectangle(cornerRadius: KultaraMetrics.xs)
        switch appearance.border {
        case .solid:
            shape.stroke(palette[keyPath: ink].color, lineWidth: appearance.borderWidth)
        case .dashed:
            shape.stroke(palette[keyPath: ink].color,
                         style: StrokeStyle(lineWidth: appearance.borderWidth, dash: [3, 2]))
        }
    }
}
