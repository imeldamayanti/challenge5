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
    /// Read but not used directly: it is what makes `body` re-run when the reader changes their
    /// text size, which is what keeps the navigation bar's font in step with everything else.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        let palette = KultaraTheme.palette(for: colorScheme)
        // Registers the packaged serif on first use. Touched here as well as from `kultaraFont` so
        // the UIKit chrome below, which resolves its font by name, cannot run before the name
        // exists.
        _ = KultaraFonts.isAvailable
        #if canImport(UIKit)
        KultaraNavigationChrome.apply(palette)
        #endif
        return content
            .environment(\.kultaraPalette, palette)
            // The grain sits over the token, never in place of it — `PaperTexture.swift` explains
            // why that ordering is what keeps the measured contrast pairs honest. Screens that
            // paint their own opaque ground (every `HisploraStage`) cover it, which is how the
            // museum sheet stays out of the story flow without either side knowing about the other.
            .background {
                ZStack {
                    palette.paper.color
                    KultaraPaperTexture.paperGrain(for: colorScheme)?
                        .resizable()
                        .scaledToFill()
                        .opacity(KultaraPaperTexture.grainOpacity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .ignoresSafeArea()
            }
            .tint(palette.seal.color)
    }
}

public extension View {
    /// Applies a role's font with everything that belongs to it — leading, tracking, and case.
    /// Splitting them is how lore ends up with body type and caption leading, or how one heading
    /// keeps its tracking while the next one loses it.
    func kultaraFont(_ role: KultaraTypography.Role) -> some View {
        font(KultaraTypography.font(role))
            .lineSpacing(role.lineSpacing)
            .tracking(role.tracking)
            .textCase(role.isUppercased ? .uppercase : nil)
    }

    /// Reserves room at the foot of a scrolling screen for the floating tab bar, scaled to the
    /// reader's text size (`NFR-A11Y-02`, `NFR-A11Y-06`).
    ///
    /// A modifier rather than `.padding(.bottom, KultaraMetrics.floatingTabBarClearance)` at each
    /// call site, because the scale can only be read from the environment and eleven screens reading
    /// it independently is eleven chances to read it wrong — or to keep using the fixed 88 and put
    /// the last control back under the bar.
    func kultaraFloatingTabBarClearance() -> some View {
        modifier(FloatingTabBarClearance())
    }

    /// Keeps the system from setting a screen's name a second time, in its own face, above a page
    /// that already carries a typed heading. Platform-conditional because the modifier does not
    /// exist off iOS, and the package builds for macOS in test.
    func kultaraInlineNavigationTitle() -> some View {
        #if os(iOS)
        return navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }

    /// Hides the navigation bar on screens that carry their own heading. Platform-conditional
    /// because `.navigationBar` does not exist off iOS, and the package builds for macOS in test.
    func kultaraHiddenNavigationBar() -> some View {
        #if os(iOS)
        return toolbar(.hidden, for: .navigationBar)
        #else
        return self
        #endif
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
            // The catalogue's second rule, inset — the same double-line the plates carry, so a card
            // and a framed photograph read as the same kind of object.
            .overlay(
                RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius)
                    .inset(by: 3)
                    .stroke(palette.rule.color.opacity(0.4), lineWidth: KultaraMetrics.hairline))
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

/// The scaled foot clearance, as a modifier so the label scale is read once.
///
/// `@ScaledMetric` against `.footnote` because that is the text style `KultaraTabBar` sets its labels
/// in (`chipLabel`), and the bar's height is what is being cleared. A base of 100 makes the ratio
/// fall straight out: the framework scales the number, so the quotient is the scale.
private struct FloatingTabBarClearance: ViewModifier {
    @ScaledMetric(relativeTo: .footnote) private var scaledUnit: CGFloat = 100

    func body(content: Content) -> some View {
        content.padding(
            .bottom,
            KultaraMetrics.floatingTabBarClearance(labelScale: scaledUnit / 100))
    }
}
