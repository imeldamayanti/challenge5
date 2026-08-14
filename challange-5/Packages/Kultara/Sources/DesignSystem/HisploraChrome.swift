import SwiftUI

public extension SRGBColor {
    /// The palette is measured in sRGB components; this is the only place it becomes a `Color`.
    var hisploraColor: Color { color }
}

private struct HisploraPaletteKey: EnvironmentKey {
    static let defaultValue = HisploraPalette.standard
}

public extension EnvironmentValues {
    var hisploraPalette: HisploraPalette {
        get { self[HisploraPaletteKey.self] }
        set { self[HisploraPaletteKey.self] = newValue }
    }
}

/// Publishes the story-flow palette and paints the ground.
///
/// It does not read `colorScheme`, and that is the decision rather than an omission: this flow is a
/// fixed editorial pairing, the way a printed page is. See `HisploraPalette` for the argument.
public struct HisploraStage<Content: View>: View {
    private let ground: KeyPath<HisploraPalette, SRGBColor>
    private let content: Content

    public init(
        ground: KeyPath<HisploraPalette, SRGBColor> = \.brownDeep,
        @ViewBuilder content: () -> Content
    ) {
        self.ground = ground
        self.content = content()
    }

    public var body: some View {
        let palette = HisploraPalette.standard
        _ = KultaraFonts.isAvailable
        return content
            .environment(\.hisploraPalette, palette)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette[keyPath: ground].color.ignoresSafeArea())
    }
}

/// The design's one action: a full-width near-black pill with a white label.
///
/// The ring is not in the frame. A near-black pill on mid-brown measures 2.04:1, and WCAG 1.4.11
/// wants 3:1 for a control's visual boundary — so the control gains a hairline rather than the
/// ground being lightened. `HisploraThemeTests` holds both halves of that.
public struct HisploraPillButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(palette.inkOnButton.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, KultaraMetrics.lg)
            .padding(.vertical, KultaraMetrics.lg)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.buttonFill.color, in: Capsule())
            .overlay(Capsule().stroke(palette.buttonRing.color, lineWidth: KultaraMetrics.hairline))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

/// The quieter second action — "Back to Homepage" on `223:2004`, which the design draws as bare
/// text under the pill.
public struct HisploraPlainButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(palette.inkCream.color)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

public extension ButtonStyle where Self == HisploraPillButtonStyle {
    static var hisploraPill: HisploraPillButtonStyle { HisploraPillButtonStyle() }
}

public extension ButtonStyle where Self == HisploraPlainButtonStyle {
    static var hisploraPlain: HisploraPlainButtonStyle { HisploraPlainButtonStyle() }
}

/// The back chevron every frame carries at the top left. The caller supplies the label, because
/// `DesignSystem` has no localisation table (`NFR-I18N-01`).
public struct HisploraBackButton: View {
    @Environment(\.hisploraPalette) private var palette

    private let accessibilityLabel: String
    private let ink: KeyPath<HisploraPalette, SRGBColor>
    private let action: () -> Void

    public init(
        accessibilityLabel: String,
        ink: KeyPath<HisploraPalette, SRGBColor> = \.inkCream,
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.ink = ink
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.backward")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(palette[keyPath: ink].color)
                .kultaraTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The 48-point circular next control on the Story Reveal pages (`187:1053`).
public struct HisploraNextButton: View {
    @Environment(\.hisploraPalette) private var palette

    private let accessibilityLabel: String
    private let action: () -> Void

    public init(accessibilityLabel: String, action: @escaping () -> Void) {
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.forward")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(palette.inkCream.color)
                // 48 points as drawn, which already clears the 44-point minimum.
                .frame(width: 48, height: 48)
                .background(palette.brownMid.color, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// The `1/3` pager the reveal pages carry, top right. The current page is set bold — the weight is
/// the signal, not the colour (`NFR-A11Y-05`).
public struct HisploraPager: View {
    @Environment(\.hisploraPalette) private var palette

    private let current: Int
    private let total: Int
    private let accessibilityLabel: String

    public init(current: Int, total: Int, accessibilityLabel: String) {
        self.current = current
        self.total = total
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: 0) {
            Text("\(current)").font(.system(size: 15, weight: .bold))
            Text("/\(total)").font(.system(size: 15, weight: .regular))
        }
        .foregroundStyle(palette.inkBody.color)
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
