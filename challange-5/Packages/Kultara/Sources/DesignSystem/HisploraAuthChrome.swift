import SwiftUI

/// The controls the three entry frames are built out of — `791:5145` ("Sign Up"), `791:5109`
/// ("Sign In") and `822:2235` ("Guest").
///
/// They live here rather than in the app target for the reason every other Hisplora component does:
/// the frames draw one capsule field, one seal-red pill and one provider row, and three screens
/// assemble them in three orders. Every string is passed in — `DesignSystem` has no localisation
/// table (`NFR-I18N-01`).
///
/// The frames' own metrics, in their own 402-point terms: 314-point controls inside a 44-point page
/// margin, 17 points of horizontal padding and 11 of vertical inside a fully rounded capsule, and a
/// 10-point gap between an icon and its label. Vertical padding is expressed as a `minHeight` floor
/// rather than a fixed height everywhere below, so a label that has grown at an accessibility size
/// makes its control taller instead of being clipped (`NFR-A11Y-01`).

/// One outlined capsule field: a leading symbol, then the text.
///
/// **The placeholder is drawn rather than handed to `TextField`.** SwiftUI's own placeholder takes
/// the platform's tertiary grey, and this screen has a measured ink for quiet type; drawing it is
/// the only way the colour is the palette's. It is `accessibilityHidden` because the field itself
/// carries the same words as its label, and VoiceOver announcing them twice is how a form starts
/// reading as a stutter.
public struct HisploraFieldRow: View {
    @Environment(\.hisploraPalette) private var palette

    /// What kind of entry this is, which is the whole difference between the three fields the
    /// frames draw. Bundled as one value rather than as five parameters at the call site: a field
    /// whose keyboard, autocapitalisation and secure-entry settings can be set independently is a
    /// field somebody will eventually configure into an email box that capitalises.
    public enum Kind: Sendable {
        case name
        case email
        case password

        var symbol: String {
            switch self {
            case .name: "person.crop.circle"
            case .email: "envelope.fill"
            case .password: "lock.fill"
            }
        }

    }

    private let kind: Kind
    private let placeholder: String
    private let accessibilityLabel: String
    @Binding private var text: String

    public init(
        kind: Kind,
        placeholder: String,
        accessibilityLabel: String,
        text: Binding<String>
    ) {
        self.kind = kind
        self.placeholder = placeholder
        self.accessibilityLabel = accessibilityLabel
        _text = text
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.symbol)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(palette.inkMuted.color)
                .accessibilityHidden(true)
            field
                .font(.system(size: 17, weight: .medium))
                .tracking(-0.34)
                .foregroundStyle(palette.inkDark.color)
                .tint(palette.brownSeal.color)
                .accessibilityLabel(accessibilityLabel)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 11)
        .frame(minHeight: KultaraMetrics.minimumTapTarget)
        .overlay {
            Capsule().stroke(palette.fieldRing.color, lineWidth: KultaraMetrics.hairline)
        }
        .contentShape(Capsule())
    }

    @ViewBuilder
    private var field: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(palette.inkMuted.color)
                    .accessibilityHidden(true)
            }
            // The keyboard, the capitalisation and the content type are iOS-only and the package
            // builds for macOS under `swift test`, so the *settings* are conditional rather than
            // the fields — the same shape `KultaraSearchField` uses for the same reason.
            switch kind {
            case .name:
                nameField.autocorrectionDisabled()
            case .email:
                emailField.autocorrectionDisabled()
            case .password:
                passwordField.autocorrectionDisabled()
            }
        }
    }

    @ViewBuilder private var nameField: some View {
        #if os(iOS)
        TextField("", text: $text)
            .textContentType(.name)
            .textInputAutocapitalization(.words)
        #else
        TextField("", text: $text)
        #endif
    }

    @ViewBuilder private var emailField: some View {
        #if os(iOS)
        TextField("", text: $text)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
        #else
        TextField("", text: $text)
        #endif
    }

    @ViewBuilder private var passwordField: some View {
        #if os(iOS)
        SecureField("", text: $text)
            .textContentType(.password)
            .textInputAutocapitalization(.never)
        #else
        SecureField("", text: $text)
        #endif
    }
}

/// The entry screens' one primary action: a seal-red capsule with a white label (`791:5152`,
/// `791:5116`, `822:2241`).
///
/// It needs no hairline. The fill measures 8.77:1 on the cream it stands on, so it is its own
/// boundary — the same argument `hisploraPillOnPaper` makes about the near-black pill, and the
/// reason neither of them carries `buttonRing`.
public struct HisploraSealPillButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .tracking(-0.34)
            .foregroundStyle(palette.inkOnButton.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, KultaraMetrics.lg)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.brownSeal.color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

public extension ButtonStyle where Self == HisploraSealPillButtonStyle {
    static var hisploraSealPill: HisploraSealPillButtonStyle { HisploraSealPillButtonStyle() }
}

/// One identity-provider row: a mark, then a label, on a filled capsule (`791:5170`, `791:5173`,
/// `791:5180`).
///
/// The fill and the ink are keypaths because the frames draw two of these on the same screen in
/// opposite polarities — near-black with white type for Apple, white with grey type for the rest —
/// and both pairs are measured in `HisploraPalette.contrastPairs`. A row with a literal colour at
/// the call site would be the one thing on the screen nobody measured.
public struct HisploraProviderButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    private let fill: KeyPath<HisploraPalette, SRGBColor>
    private let ink: KeyPath<HisploraPalette, SRGBColor>
    private let dimsWhenDisabled: Bool

    /// - Parameter dimsWhenDisabled: whether a disabled row is faded.
    ///
    ///   It is on by default and off for the two provider rows, which is the opposite of what a
    ///   style usually wants and is deliberate. Fading these composites the fill into the cream —
    ///   near-black turns to mud and the white row all but disappears — so a screen that is
    ///   *reproducing a frame* would be drawing two colours nobody sampled, and the measured pairs
    ///   would stop describing what is on it. The rows keep their fills; `.disabled` still stops
    ///   the tap and still makes VoiceOver announce them as dimmed, and the line under them says
    ///   why in words (`NFR-A11Y-05`).
    public init(
        fill: KeyPath<HisploraPalette, SRGBColor>,
        ink: KeyPath<HisploraPalette, SRGBColor>,
        dimsWhenDisabled: Bool = true
    ) {
        self.fill = fill
        self.ink = ink
        self.dimsWhenDisabled = dimsWhenDisabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .tracking(-0.34)
            .foregroundStyle(palette[keyPath: ink].color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, KultaraMetrics.lg)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette[keyPath: fill].color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .opacity(isEnabled || !dimsWhenDisabled ? 1 : 0.4)
    }
}

public extension ButtonStyle where Self == HisploraProviderButtonStyle {
    /// `791:5170` — near-black carrying white type. Never dimmed; see `dimsWhenDisabled`.
    static var hisploraProviderDark: HisploraProviderButtonStyle {
        HisploraProviderButtonStyle(
            fill: \.buttonFill, ink: \.inkOnButton, dimsWhenDisabled: false)
    }

    /// `791:5173` — the stamp's white paper carrying the quiet ink, which is the one pair on this
    /// screen already measured for a caption on white. Never dimmed, for the same reason.
    static var hisploraProviderLight: HisploraProviderButtonStyle {
        HisploraProviderButtonStyle(
            fill: \.paperStamp, ink: \.inkMuted, dimsWhenDisabled: false)
    }

    /// `791:5180` — the same white row, for the one control here that is not disabled.
    static var hisploraProviderGuest: HisploraProviderButtonStyle {
        HisploraProviderButtonStyle(fill: \.paperStamp, ink: \.inkMuted)
    }
}

/// The ruled `OR` between the credential block and the provider block (`791:5164`, `791:5128`).
///
/// One accessibility element rather than three, and it is a *heading*: to a reader who cannot see
/// the two rules, "OR" alone in the middle of a form says nothing about what it divides.
public struct HisploraRuleDivider: View {
    @Environment(\.hisploraPalette) private var palette

    private let label: String
    private let accessibilityLabel: String

    public init(label: String, accessibilityLabel: String) {
        self.label = label
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: KultaraMetrics.sm) {
            rule
            Text(label)
                .font(.system(size: 17, weight: .bold))
                .tracking(1.7)
                .foregroundStyle(palette.inkMuted.color)
            rule
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isHeader)
    }

    private var rule: some View {
        Rectangle()
            .fill(palette.fieldRing.color)
            .frame(height: KultaraMetrics.hairline)
            .frame(maxWidth: .infinity)
    }
}

/// The Google mark on `791:5174`, exported from the frame at 4× rather than drawn.
///
/// **Never hand-authored.** It is a trademark with a published geometry, and an approximation of
/// one is worse than none — the same rule that keeps `HisploraOnboardingArt` an export. It ships as
/// PNG because `Package.swift` copies `Resources/Images` wholesale into the app bundle and
/// everything in there is read through `UIImage(data:)`, which does not decode SVG.
///
/// **This mark is a pre-public blocker, not a settled asset.** Google's brand terms allow the "G"
/// on a real Google Sign-In control and nowhere else, and this build has no identity provider
/// behind the button — see `docs/hisplora-tokens.md`, beside the consent-log blockers. It is drawn
/// here so the screen is the frame's; whether it ships is a decision with an owner.
public enum HisploraGoogleMark {

    static let resourceName = "google-mark"

    /// The export's own proportions, width over height — `791:5174` draws it 21.57 × 22.
    public static let aspectRatio: CGFloat = 21.57 / 22.0

    /// Whether the artwork shipped, so a dropped PNG is a value a test can see rather than a blank
    /// gap in a row of buttons.
    public static var isAvailable: Bool { url != nil }

    static var url: URL? {
        Bundle.module.url(forResource: resourceName, withExtension: "png", subdirectory: "Images")
    }

    public static let image: Image? = {
        #if canImport(UIKit)
        guard let url, let data = try? Data(contentsOf: url), let image = UIImage(data: data)
        else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }()
}

/// The mark inside a provider row, at the height the frames set it.
///
/// Decoration: the button's own label names the provider, so a missing file costs the row its
/// picture and nothing else (`NFR-A11Y-04`).
public struct HisploraProviderMark: View {

    /// Which mark a row carries. Apple's is an SF Symbol — the platform ships it, and it is the one
    /// place a system glyph is the *correct* asset rather than a stand-in for an export.
    public enum Provider: Sendable {
        case apple
        case google
        case guest
    }

    private let provider: Provider

    public init(provider: Provider) {
        self.provider = provider
    }

    public var body: some View {
        Group {
            switch provider {
            case .apple:
                // 20 tall on `791:5171`, and set a hair above the baseline the way Apple's own
                // lockups draw it.
                Image(systemName: "applelogo")
                    .font(.system(size: 18, weight: .regular))
                    .symbolRenderingMode(.monochrome)
            case .google:
                if let image = HisploraGoogleMark.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22 * HisploraGoogleMark.aspectRatio, height: 22)
                }
            case .guest:
                // Monochrome, or SF Symbols draws this one in its own two colours and it becomes
                // the brightest object on a page of browns.
                Image(systemName: "theatermasks.fill")
                    .font(.system(size: 17, weight: .regular))
                    .symbolRenderingMode(.monochrome)
            }
        }
        .accessibilityHidden(true)
    }
}
