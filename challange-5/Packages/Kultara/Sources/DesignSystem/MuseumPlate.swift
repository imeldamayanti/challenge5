import SwiftUI

/// The catalogue apparatus: the pieces the reference spread uses to present an object — a kicker
/// above a heading, a framed plate, the bracketed caption under it, and the one filled control on
/// the page.
///
/// They live here rather than in a screen because the whole point of the reference is that every
/// object on every page is presented the same way. A caption invented locally is how that stops
/// being true.

// MARK: - Eyebrow

/// `SECTION // 03` — the small ruled kicker. The number is optional and is set as the catalogue
/// sets it, after a double slash.
public struct KultaraEyebrow: View {
    @Environment(\.kultaraPalette) private var palette

    private let text: String
    private let index: Int?
    private let ink: KeyPath<KultaraPalette, SRGBColor>

    public init(_ text: String, index: Int? = nil, ink: KeyPath<KultaraPalette, SRGBColor> = \.inkMuted) {
        self.text = text
        self.index = index
        self.ink = ink
    }

    public var body: some View {
        // Two short strings, but "short" is a default-size claim: at AccessibilityXXXL a region
        // name and its number laid side by side run several hundred points past the window, and
        // every ancestor inherits that width. So the row wraps, and each string wraps within it.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: KultaraMetrics.sm) { label; number }
            VStack(alignment: .leading, spacing: 2) { label; number }
        }
        .kultaraFont(.eyebrow)
        .foregroundStyle(palette[keyPath: ink].color)
        // Read as one phrase; "slash slash zero three" is not what the number means.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(index.map { "\(text), \($0)" } ?? text)
    }

    private var label: some View {
        Text(text)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var number: some View {
        if let index {
            // Not uppercased with the label — it is a number, and `textCase` on the whole row
            // would be a no-op that looks like intent.
            Text(String(format: "// %02d", index))
                .foregroundStyle(palette.seal.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Plate

/// A framed object: a hairline, a mat of raised stock, and the image inside it. The reference frames
/// every exhibit this way, and the frame is what makes a photograph read as something on display
/// rather than as a banner.
public struct KultaraPlate<Content: View>: View {
    @Environment(\.kultaraPalette) private var palette

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(KultaraMetrics.xs)
            .background(palette.paperRaised.color)
            .overlay(
                Rectangle()
                    .stroke(palette.rule.color, lineWidth: KultaraMetrics.hairline))
            .overlay(
                Rectangle()
                    .inset(by: 3)
                    .stroke(palette.rule.color.opacity(0.5), lineWidth: KultaraMetrics.hairline))
    }
}

/// The caption under a plate: the object's name in brackets, then its date or place after a double
/// slash. Both lines are sans — apparatus, not more title — and both are real text, so VoiceOver
/// reads a name and a date rather than punctuation.
public struct KultaraPlateCaption: View {
    @Environment(\.kultaraPalette) private var palette

    private let title: String
    private let detail: String?
    private let alignment: HorizontalAlignment

    public init(title: String, detail: String? = nil, alignment: HorizontalAlignment = .leading) {
        self.title = title
        self.detail = detail
        self.alignment = alignment
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text("[ \(title) ]")
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text("// \(detail)")
                    .foregroundStyle(palette.inkMuted.color)
            }
        }
        .kultaraFont(.caption)
        .frame(maxWidth: .infinity,
               alignment: alignment == .center ? .center : .leading)
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel([title, detail].compactMap { $0 }.joined(separator: ", "))
    }
}

/// One fact in a catalogue entry: a symbol and a value, on paper rather than on a photograph.
///
/// The on-photo sibling is `PhotoCardFact`, and the two exist separately because their inks are
/// measured against different backgrounds — the same view with a colour parameter is how a token
/// measured against the scrim ends up on cream.
public struct KultaraFact: View {
    @Environment(\.kultaraPalette) private var palette

    private let symbolName: String
    private let label: String
    private let value: String
    private let emphasised: Bool

    public init(symbolName: String, label: String, value: String, emphasised: Bool = false) {
        self.symbolName = symbolName
        self.label = label
        self.value = value
        self.emphasised = emphasised
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.xs) {
            Image(systemName: symbolName)
                .imageScale(.small)
                .foregroundStyle(palette.inkMuted.color)
            Text(value)
                .fontWeight(emphasised ? .semibold : .regular)
                .foregroundStyle(emphasised ? palette.seal.color : palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .kultaraFont(.metadata)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - The one filled control

/// The ticket button: filled seal red, square-cornered, its label measured against the fill. There
/// is exactly one of these on a page in the reference, and treating it as *the* action rather than
/// as a button style is deliberate — a page with three red buttons has no primary action.
public struct SealButtonStyle: ButtonStyle {
    @Environment(\.kultaraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .kultaraFont(.buttonLabel)
            .foregroundStyle(palette.inkOnSeal.color)
            .padding(.horizontal, KultaraMetrics.xl)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.sealFill.color)
            .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius))
            // Pressed state as a dimming of the whole control rather than a second red: the fill is
            // already the darkest thing on the page.
            .opacity(configuration.isPressed ? 0.82 : 1)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

/// The quieter sibling: ruled outline, seal ink, no fill. For the second action on a page, so the
/// filled one keeps meaning what it means.
public struct RuledButtonStyle: ButtonStyle {
    @Environment(\.kultaraPalette) private var palette

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .kultaraFont(.buttonLabel)
            .foregroundStyle(palette.seal.color)
            .padding(.horizontal, KultaraMetrics.lg)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .overlay(
                RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius)
                    .stroke(palette.seal.color, lineWidth: KultaraMetrics.hairline))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

public extension ButtonStyle where Self == SealButtonStyle {
    static var seal: SealButtonStyle { SealButtonStyle() }
}

public extension ButtonStyle where Self == RuledButtonStyle {
    static var ruled: RuledButtonStyle { RuledButtonStyle() }
}

// MARK: - Section heading

/// A section's name, set as the reference sets it: the italic serif, with a rule running out from
/// it to the edge of the measure. The rule is decoration and is hidden from VoiceOver; the heading
/// carries the header trait so rotor navigation still works.
public struct KultaraSectionHeading: View {
    @Environment(\.kultaraPalette) private var palette

    private let text: String
    private let eyebrow: String?

    public init(_ text: String, eyebrow: String? = nil) {
        self.text = text
        self.eyebrow = eyebrow
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            if let eyebrow {
                KultaraEyebrow(eyebrow)
            }
            HStack(alignment: .center, spacing: KultaraMetrics.md) {
                Text(text)
                    .kultaraFont(.sectionHeading)
                    .foregroundStyle(palette.seal.color)
                    .fixedSize(horizontal: false, vertical: true)
                    // The rule yields first. Without this the heading is the flexible one and a
                    // long section name at an accessibility size gets squeezed to a column of
                    // single letters rather than the rule simply running out of room.
                    .layoutPriority(1)
                    .accessibilityAddTraits(.isHeader)
                KultaraRule()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
