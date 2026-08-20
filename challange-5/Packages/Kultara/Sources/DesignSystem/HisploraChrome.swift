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
    private let grain: Bool
    private let content: Content

    /// - Parameter grain: whether to print `KultaraGround`'s sheet over the ground. Opt-in rather
    ///   than automatic: the story-flow frames draw their brown flat, and printing the sheet
    ///   everywhere would be redrawing screens nobody sampled it from. It is on where the design
    ///   shows a printed ground, which is the Journal and the Explorer's Card — and since the sheet
    ///   is cream, those callers pass a cream `ground` to match it.
    public init(
        ground: KeyPath<HisploraPalette, SRGBColor> = \.brownDeep,
        grain: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.ground = ground
        self.grain = grain
        self.content = content()
    }

    public var body: some View {
        let palette = HisploraPalette.standard
        _ = KultaraFonts.isAvailable
        return content
            .environment(\.hisploraPalette, palette)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Token first, speckle over it — `Speckle.swift` explains why that ordering is what
            // keeps `HisploraThemeTests`' measured pairs describing what is actually on screen.
            .kultaraSpeckledGround(palette[keyPath: ground])
    }
}

/// The design's one action: a full-width near-black pill with a white label.
///
/// The ring is not in the frame. A near-black pill on mid-brown measures 2.04:1, and WCAG 1.4.11
/// wants 3:1 for a control's visual boundary — so the control gains a hairline rather than the
/// ground being lightened. `HisploraThemeTests` holds both halves of that.
///
/// **On a cream ground the ring is wrong rather than merely unnecessary.** The same near-black on
/// `paperSheet` measures 16.71:1, so the fill is its own boundary; drawing `buttonRing`'s tan
/// hairline there would add an outline the design does not draw *and* that measures 2.47:1 on
/// the ground — under the 3:1 the edge it is outlining clears twenty times over. `ring: nil` is that case, and it is a decision the caller makes because
/// only the caller knows which ground the pill is standing on.
public struct HisploraPillButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    private let ring: KeyPath<HisploraPalette, SRGBColor>?

    public init(ring: KeyPath<HisploraPalette, SRGBColor>? = \.buttonRing) {
        self.ring = ring
    }

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
            .overlay {
                if let ring {
                    Capsule().stroke(palette[keyPath: ring].color,
                                     lineWidth: KultaraMetrics.hairline)
                }
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

/// The quiet escape hatch the redesigned onboarding frames set at the top right — underlined text,
/// not a pill (`737:4731`, `737:4734`, `737:4741`).
///
/// It is a `ButtonStyle` rather than a styled `Text` with a gesture for the reason the Journal's
/// sealed card is a `Button`: a picture or a label with a tap gesture is not something VoiceOver
/// announces or activates. The underline is what carries "this is a link" for a reader who cannot
/// separate `inkQuiet` from the body ink, so it is drawn rather than left to colour alone
/// (`NFR-A11Y-05`), and the label is padded out to the 44-point target the 17-point type does not
/// reach on its own (`NFR-A11Y-06`).
public struct HisploraTextLinkButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette

    private let ink: KeyPath<HisploraPalette, SRGBColor>

    public init(ink: KeyPath<HisploraPalette, SRGBColor> = \.inkQuiet) {
        self.ink = ink
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .tracking(-0.34)
            .underline()
            .foregroundStyle(palette[keyPath: ink].color)
            .kultaraTapTarget()
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// The inverse pill, as `223:2004` draws it: a white capsule with near-black type.
///
/// The dark pill above and this one are the same control in two frames, and the difference is not
/// decoration — `223:2004` is on `brownStone`, where a white fill is the higher-contrast of the
/// two. It needs no ring: white on `brownStone` measures far past the 3:1 WCAG 1.4.11 wants for a
/// control's boundary, which is the whole reason the dark pill needs one and this does not.
///
/// The metrics are the frame's: 17 points of vertical padding around a 17-point label at 1.4 line
/// height, which is what makes the drawn 58-point height, and −0.51 tracking as SF Pro is set
/// there.
public struct HisploraLightPillButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .tracking(-0.51)
            .foregroundStyle(palette.buttonFill.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity)
            // 58 as drawn. A floor rather than a fixed height: SwiftUI's line box for a 17-point
            // label is a little shorter than the 1.4 leading Figma sets, and at accessibility sizes
            // the label has to be allowed to make the capsule taller instead of being clipped.
            .frame(minHeight: 58)
            .background(palette.inkOnButton.color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

/// The quieter second action — "Back to Homepage" on `223:2004`, which the design draws as bare
/// text under the pill.
///
/// `ink` exists because that frame sets the label pure white while the rest of the story flow sets
/// it `inkCream`. Both are measured against the brown grounds; the caller picks which frame it is
/// reproducing rather than the two quietly drifting apart.
public struct HisploraPlainButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette

    private let ink: KeyPath<HisploraPalette, SRGBColor>

    public init(ink: KeyPath<HisploraPalette, SRGBColor> = \.inkCream) {
        self.ink = ink
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .tracking(-0.51)
            .foregroundStyle(palette[keyPath: ink].color)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

public extension ButtonStyle where Self == HisploraPillButtonStyle {
    static var hisploraPill: HisploraPillButtonStyle { HisploraPillButtonStyle() }

    /// The same pill with no hairline — see the type's note on why a cream ground drops it.
    static var hisploraPillOnPaper: HisploraPillButtonStyle { HisploraPillButtonStyle(ring: nil) }
}

public extension ButtonStyle where Self == HisploraTextLinkButtonStyle {
    static var hisploraTextLink: HisploraTextLinkButtonStyle { HisploraTextLinkButtonStyle() }
}

public extension ButtonStyle where Self == HisploraLightPillButtonStyle {
    static var hisploraLightPill: HisploraLightPillButtonStyle { HisploraLightPillButtonStyle() }
}

public extension ButtonStyle where Self == HisploraPlainButtonStyle {
    static var hisploraPlain: HisploraPlainButtonStyle { HisploraPlainButtonStyle() }

    /// `223:2004`'s "Back to Homepage" — pure white rather than the flow's cream.
    static func hisploraPlain(
        ink: KeyPath<HisploraPalette, SRGBColor>
    ) -> HisploraPlainButtonStyle {
        HisploraPlainButtonStyle(ink: ink)
    }
}

/// The back chevron every frame carries at the top left. The caller supplies the label, because
/// `DesignSystem` has no localisation table (`NFR-I18N-01`).
public struct HisploraBackButton: View {
    @Environment(\.hisploraPalette) private var palette

    private let accessibilityLabel: String
    private let ink: KeyPath<HisploraPalette, SRGBColor>
    private let size: CGFloat
    private let action: () -> Void

    /// `size` is the glyph, not the control: the tap target stays 44 either way
    /// (`NFR-A11Y-06`). `223:2004` draws it at 24; the earlier story frames draw it smaller, which
    /// is why 20 remains the default rather than being changed under them.
    public init(
        accessibilityLabel: String,
        ink: KeyPath<HisploraPalette, SRGBColor> = \.inkCream,
        size: CGFloat = 20,
        action: @escaping () -> Void
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.ink = ink
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.backward")
                .font(.system(size: size, weight: .regular))
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
