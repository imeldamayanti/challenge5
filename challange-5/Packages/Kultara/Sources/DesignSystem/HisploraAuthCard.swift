import SwiftUI

/// The login and register frames — Figma `1429:2829` ("Login") and `1429:3260` ("Register").
///
/// **A second entry design, and it replaces the first at the screen boundary rather than inside
/// one.** `791:5145`/`791:5109` drew the entry as a cream page in the story flow's own language:
/// a serif masthead, capsule fields, a ruled `OR`. These two frames draw it as a deep-brown
/// masthead over a white card — a form, not a page of the book. The seam rule the two visual
/// directions already follow applies here too, so the whole screen moved rather than half of it.
///
/// Everything in this file is measured off the frames in their own 402-point terms, and the
/// numbers are named rather than inlined so the two screens cannot drift apart:
///
/// | What | Frame | Value |
/// |---|---|---|
/// | masthead height | `1429:2830` | 397 |
/// | card | `1429:3241` | inset 20, top 257, radius 10, padding 24, block gap 24 |
/// | field | `I1429:3243;3:6011` | height 46, radius 10, padding 14, gap 16 |
/// | action | `1429:3250` | fully rounded, 17 vertical padding |
/// | provider row | `1429:3256` | radius 40, 18 vertical padding, 8 between mark and label |
///
/// **Type is set at the frames' own point sizes and does not scale with Dynamic Type.** That is the
/// same deliberate bend `TripSummaryScreen`, `TripHistoryScreen` and `PhotoQuestCard`'s caption
/// make, for the same reason and at the owner's instruction of 2026-08-26: a role that scales
/// cannot hold a 12-point label beside a 32-point masthead at the ratio the frames draw. Every box
/// below is a floor rather than a fixed height, so a label that has grown makes its control taller
/// instead of being clipped (`NFR-A11Y-01`), and the strings are still passed in — `DesignSystem`
/// has no localisation table (`NFR-I18N-01`).
///
/// The frames name Inter, Roboto and SF Pro Display in three places between them. Only the last
/// ships with iOS; the other two are drawn in the system face at the frames' sizes and weights
/// rather than packaged, which is a substitution and is recorded in `docs/hisplora-tokens.md`.
public enum AuthCardMetrics {
    /// The frame's own status bar. Every vertical number below is the frame's figure *less* this,
    /// so the band and the card keep their relationship on a phone whose status bar is not 44.
    static let frameStatusBar: CGFloat = 44

    /// `1429:2830` — the masthead is 397 tall on the frame; this is the part of it below the
    /// status bar. The band grows by whatever the device puts above.
    public static let headHeight: CGFloat = 397 - frameStatusBar
    /// `1429:3234` — the shield's top, 68 on the frame.
    public static let headlineTop: CGFloat = 68 - frameStatusBar
    /// The 24 between the shield and the text block, and the 12 inside it.
    public static let headlineGap: CGFloat = 24
    public static let headlineTextGap: CGFloat = 12
    /// `1429:3235` — the shield mark.
    public static let shieldSize: CGFloat = 28
    /// `1429:3236` — how wide the masthead's title sets, which is what wraps it onto two lines.
    public static let headlineWidth: CGFloat = 235
    /// The line under it runs to the card's own width instead: the frames set it inside 235 in
    /// Inter, and the system face at the same size needs more room for the same sentence.
    public static let headlineSubtitleWidth: CGFloat = 402 - 2 * 20

    /// `1429:3241` — the card's own box.
    public static let cardInset: CGFloat = 20
    /// `1429:3241` starts at 257 on the frame.
    public static let cardTop: CGFloat = 257 - frameStatusBar
    public static let cardRadius: CGFloat = 10
    public static let cardPadding: CGFloat = 24
    /// The step between the card's five blocks: fields, action, rule, provider, closing line.
    public static let blockGap: CGFloat = 24

    /// `I1429:3243;3:6011` — one field.
    public static let fieldHeight: CGFloat = 46
    public static let fieldRadius: CGFloat = 10
    public static let fieldPadding: CGFloat = 14
    /// The 16 between two stacked fields, which is also the step down to the Remember row.
    public static let fieldGap: CGFloat = 16
    /// `I1429:3244;3:6015` — the eye toggle.
    public static let eyeSize: CGFloat = 16

    /// `1429:3250` — the action's vertical padding inside its capsule.
    public static let actionPadding: CGFloat = 17
    /// `1429:3256` — the provider row's.
    public static let providerPadding: CGFloat = 18
    public static let providerRadius: CGFloat = 40
    public static let providerMarkGap: CGFloat = 8
    public static let providerMarkSize: CGFloat = 20

    /// `1429:3252` — the gap either side of "Or login with".
    public static let ruleGap: CGFloat = 16
    /// `1429:3247` — the checkbox's own 19-point box, and the 11.08 square drawn inside it.
    public static let checkboxBox: CGFloat = 19
    public static let checkboxSquare: CGFloat = 11.083
    public static let checkboxRadius: CGFloat = 1.583
    public static let checkboxStroke: CGFloat = 1.5
    /// `1429:3246` — the gap between the box and its label.
    public static let checkboxGap: CGFloat = 5
    /// `1429:3257` — the gap inside the closing line.
    public static let closingGap: CGFloat = 6
}

// MARK: - The two packaged pictures

/// The masthead's ground and the shield standing on it.
///
/// **The masthead is a photograph of itself, not a colour plus a drawing.** `1429:2831` is a
/// diamond gradient masked into a starfield with a 10 % ruled grid over it — about a hundred and
/// forty layers in the file. Reproducing that in SwiftUI would mean re-deriving a mask, a gradient
/// and forty-six rules, and every re-derivation is a place for the drawing to drift. The export
/// carries the frame's own brown, so it is drawn over `brownDeep` and the two agree exactly; the
/// device-corner rounding Figma baked into the export's corners is filled back to the same brown,
/// or a full-bleed masthead would print two pale notches under the status bar.
///
/// Loaded eagerly, for the reason `HisploraOnboardingArt` gives: `Image(_:bundle:)` resolves lazily
/// and draws nothing at all if the resource is dropped from `Package.swift`, whereas this way the
/// miss is a value a test can see.
public enum HisploraAuthArt: String, Sendable, CaseIterable {
    /// `1429:2831` — the masthead's ground, at 3× of the frame's 402 × 397.
    case headTexture
    /// `1429:3235` — the shield mark, white, at 3× of 28.
    case shield

    var resourceName: String {
        switch self {
        case .headTexture: "auth-head-texture"
        case .shield: "auth-shield"
        }
    }

    /// The export's own proportions, width over height.
    public var aspectRatio: CGFloat {
        switch self {
        case .headTexture: 1206.0 / 1191.0
        case .shield: 1
        }
    }

    public var image: Image? { Self.loaded[self] ?? nil }

    /// Whether the artwork shipped. `HisploraAuthCardTests` asserts it for both cases, so removing
    /// a PNG fails the suite instead of quietly leaving a blank masthead.
    public var isAvailable: Bool { Self.url(for: self) != nil }

    static func url(for art: HisploraAuthArt) -> URL? {
        Bundle.module.url(
            forResource: art.resourceName, withExtension: "png", subdirectory: "Images")
    }

    private static let loaded: [HisploraAuthArt: Image?] = {
        var table: [HisploraAuthArt: Image?] = [:]
        for art in HisploraAuthArt.allCases {
            #if canImport(UIKit)
            if let url = url(for: art),
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                table[art] = Image(uiImage: image)
            } else {
                table[art] = Image?.none
            }
            #else
            table[art] = Image?.none
            #endif
        }
        return table
    }()
}

// MARK: - The masthead

/// `1429:2830` — the brown band the two frames open on: the shield, the title, and one line under
/// it saying what the form below asks for.
///
/// It bleeds under the status bar, so its height is the frame's 397 *plus* whatever the device puts
/// above it — a masthead that stopped at 397 measured from the safe area would leave a strip of the
/// page's near-white above the brown on every phone with a notch.
public struct HisploraAuthHead: View {
    @Environment(\.hisploraPalette) private var palette

    private let title: String
    private let subtitle: String
    private let topInset: CGFloat

    /// - Parameter topInset: the safe-area inset above the frame, which the band grows by.
    public init(title: String, subtitle: String, topInset: CGFloat) {
        self.title = title
        self.subtitle = subtitle
        self.topInset = topInset
    }

    public var body: some View {
        VStack(spacing: AuthCardMetrics.headlineGap) {
            shield
            VStack(spacing: AuthCardMetrics.headlineTextGap) {
                Text(title)
                    // SF Pro Display Bold 32 (`1429:3237`). The frame's 1.2 line height is what the
                    // system face already sets at this size, so nothing is added: `lineSpacing` is
                    // *extra* leading on top of the font's own, and adding 20 % again opened the
                    // two lines to about 47 points against the drawing's 38.
                    .font(.system(size: 32, weight: .bold))
                    // The frames set the title block 235 points wide, which is what wraps both
                    // mastheads onto two lines. Wider and "Sign in to your Account" sets on one and
                    // stops matching the drawing.
                    .frame(width: AuthCardMetrics.headlineWidth)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    // 12, tracking −0.12 (`1429:3238`). One line on the frame — it is *not* held to
                    // the title's 235, which is narrower than this sentence sets in the system face
                    // and wrapped it onto two.
                    .font(.system(size: 12, weight: .medium))
                    .tracking(-0.12)
                    .frame(maxWidth: AuthCardMetrics.headlineSubtitleWidth)
            }
            .foregroundStyle(palette.authHeadInk.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, AuthCardMetrics.headlineTop)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: AuthCardMetrics.headHeight, alignment: .top)
        .padding(.top, topInset)
        .background(alignment: .top) { ground }
        .clipped()
    }

    private var shield: some View {
        Group {
            if let image = HisploraAuthArt.shield.image {
                image.resizable().scaledToFit()
            } else {
                // Decoration: the title under it says what the screen is, so a missing file costs
                // the masthead its mark and nothing else (`NFR-A11Y-04`).
                Color.clear
            }
        }
        .frame(width: AuthCardMetrics.shieldSize, height: AuthCardMetrics.shieldSize)
        .accessibilityHidden(true)
    }

    /// The export over the brown it was exported on, so a band taller than the picture — a phone
    /// with a deep notch, or a title that grew — extends in the same colour rather than in nothing.
    private var ground: some View {
        palette.brownDeep.color
            .overlay(alignment: .top) {
                HisploraAuthArt.headTexture.image?
                    .resizable()
                    .aspectRatio(HisploraAuthArt.headTexture.aspectRatio, contentMode: .fill)
            }
            .clipped()
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)
    }
}

// MARK: - The card

/// `1429:3241` — the white card the form is printed on: 20 in from either edge, 24 of padding, and
/// 24 between each of its blocks.
public struct HisploraAuthCard<Content: View>: View {
    @Environment(\.hisploraPalette) private var palette

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: AuthCardMetrics.blockGap) { content }
            .padding(AuthCardMetrics.cardPadding)
            .frame(maxWidth: .infinity)
            .background(
                palette.paperStamp.color,
                in: RoundedRectangle(cornerRadius: AuthCardMetrics.cardRadius, style: .continuous))
    }
}

// MARK: - One field

/// `I1429:3243;3:6011` — a 46-point box with a 10-point radius, a hairline, and a shadow so faint
/// it is barely a shadow.
///
/// **The placeholder is drawn rather than handed to `TextField`**, for the reason
/// `HisploraFieldRow` gives: SwiftUI's own takes the platform's tertiary grey and this design has a
/// measured ink for quiet type. It is `accessibilityHidden` because the field carries the same
/// words as its label.
///
/// **The eye is a real toggle.** The frames draw only the crossed-out state, which is what a hidden
/// password looks like — but a crossed eye beside a row of dots is the one control on this card a
/// walker will try to press, and a drawn one that does not respond is worse than none. It is
/// labelled and it announces which state it will move to.
public struct HisploraAuthField: View {
    @Environment(\.hisploraPalette) private var palette

    /// What kind of entry this is. One value rather than four parameters, for the reason
    /// `HisploraFieldRow.Kind` gives: a field whose keyboard, capitalisation and secure-entry
    /// settings can be set independently is one somebody eventually configures into an email box
    /// that capitalises.
    public enum Kind: Sendable {
        case name
        case email
        case password

        var isSecure: Bool { self == .password }
    }

    private let kind: Kind
    private let placeholder: String
    private let accessibilityLabel: String
    private let revealLabel: String
    private let hideLabel: String
    @Binding private var text: String
    @State private var isRevealed = false

    public init(
        kind: Kind,
        placeholder: String,
        accessibilityLabel: String,
        revealLabel: String,
        hideLabel: String,
        text: Binding<String>
    ) {
        self.kind = kind
        self.placeholder = placeholder
        self.accessibilityLabel = accessibilityLabel
        self.revealLabel = revealLabel
        self.hideLabel = hideLabel
        _text = text
    }

    public var body: some View {
        HStack(spacing: 10) {
            field
                // SF Pro Display Medium 14, tracking −0.14 (`I1429:3243;3:6014`).
                .font(.system(size: 14, weight: .medium))
                .tracking(-0.14)
                .foregroundStyle(palette.authFieldInk.color)
                .tint(palette.brownDeep.color)
                .accessibilityLabel(accessibilityLabel)
            if kind.isSecure { eye }
        }
        .padding(.horizontal, AuthCardMetrics.fieldPadding)
        // A floor rather than a height: a walker at an accessibility text size gets a taller box,
        // never a clipped one (`NFR-A11Y-01`).
        .frame(minHeight: AuthCardMetrics.fieldHeight)
        .background(
            palette.paperStamp.color,
            in: RoundedRectangle(cornerRadius: AuthCardMetrics.fieldRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuthCardMetrics.fieldRadius, style: .continuous)
                .stroke(palette.authRule.color, lineWidth: 1)
        }
        // `0px 1px 2px rgba(228,229,231,0.24)` on the frame.
        .shadow(color: Color(red: 228 / 255, green: 229 / 255, blue: 231 / 255).opacity(0.24),
                radius: 1, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: AuthCardMetrics.fieldRadius, style: .continuous))
    }

    private var eye: some View {
        Button {
            isRevealed.toggle()
        } label: {
            Image(systemName: isRevealed ? "eye" : "eye.slash")
                .font(.system(size: AuthCardMetrics.eyeSize - 3, weight: .regular))
                .foregroundStyle(palette.authQuiet.color)
                .frame(width: AuthCardMetrics.eyeSize, height: AuthCardMetrics.eyeSize)
                // The glyph is 16 points, which is under the 44 a tap target wants — the box around
                // it is what the finger gets, drawn inside the field's own padding.
                .frame(width: KultaraMetrics.minimumTapTarget,
                       height: KultaraMetrics.minimumTapTarget,
                       alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRevealed ? hideLabel : revealLabel)
    }

    @ViewBuilder
    private var field: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(palette.authQuiet.color)
                    .accessibilityHidden(true)
            }
            // The keyboard, the capitalisation and the content type are iOS-only and the package
            // builds for macOS under `swift test`, so the *settings* are conditional rather than
            // the fields — the shape `HisploraFieldRow` already uses for the same reason.
            switch kind {
            case .name: nameField.autocorrectionDisabled()
            case .email: emailField.autocorrectionDisabled()
            case .password: passwordField.autocorrectionDisabled()
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
        Group {
            if isRevealed {
                TextField("", text: $text).textContentType(.password)
            } else {
                SecureField("", text: $text).textContentType(.password)
            }
        }
        .textInputAutocapitalization(.never)
        #else
        Group {
            if isRevealed { TextField("", text: $text) } else { SecureField("", text: $text) }
        }
        #endif
    }
}

// MARK: - The row under the fields

/// `1429:3245` — "Remember me" beside an empty box, with "Forgot Password ?" opposite.
///
/// **Drawn, and nothing behind either half**, at the owner's instruction of 2026-08-26. There is no
/// account backend in front of these screens — `AuthViewModel` has the whole account of that — so a
/// checkbox that stored something would be storing it about nothing, and a "Forgot Password ?"
/// control would open a flow this build does not have.
///
/// So neither is a control. The row is one static accessibility element that says as much, rather
/// than two `Button`s VoiceOver would offer to activate: a drawn control announced as a control is
/// the failure `NFR-A11Y-05` is about, and it is the reason the guest route is a real row below
/// rather than a third drawing here.
public struct HisploraAuthRememberRow: View {
    @Environment(\.hisploraPalette) private var palette

    private let rememberLabel: String
    private let forgotLabel: String
    private let spokenLabel: String

    public init(rememberLabel: String, forgotLabel: String, spokenLabel: String) {
        self.rememberLabel = rememberLabel
        self.forgotLabel = forgotLabel
        self.spokenLabel = spokenLabel
    }

    public var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: AuthCardMetrics.checkboxGap) {
                checkbox
                Text(rememberLabel)
                    // 12, tracking −0.12 (`1429:3248`).
                    .font(.system(size: 12, weight: .medium))
                    .tracking(-0.12)
                    .foregroundStyle(palette.authQuiet.color)
            }
            Spacer(minLength: AuthCardMetrics.checkboxGap)
            Text(forgotLabel)
                .font(.system(size: 12, weight: .semibold))
                .tracking(-0.12)
                .foregroundStyle(palette.authEmphasis.color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(.isStaticText)
    }

    /// `1429:3247` — an 11.08-point square with a 1.583 radius, stroked 1.5, centred in a
    /// 19-point box.
    private var checkbox: some View {
        RoundedRectangle(cornerRadius: AuthCardMetrics.checkboxRadius, style: .continuous)
            .stroke(palette.authQuiet.color, lineWidth: AuthCardMetrics.checkboxStroke)
            .frame(width: AuthCardMetrics.checkboxSquare, height: AuthCardMetrics.checkboxSquare)
            .frame(width: AuthCardMetrics.checkboxBox, height: AuthCardMetrics.checkboxBox)
    }
}

// MARK: - The action

/// `1429:3250` — the card's one filled control: a near-black capsule carrying white type.
public struct HisploraAuthActionButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // SF Pro Medium 17, tracking −0.51 (`1429:3251`).
            .font(.system(size: 17, weight: .medium))
            .tracking(-0.51)
            .foregroundStyle(palette.inkOnButton.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, KultaraMetrics.sm)
            .padding(.vertical, AuthCardMetrics.actionPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.buttonFill.color, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

public extension ButtonStyle where Self == HisploraAuthActionButtonStyle {
    static var hisploraAuthAction: HisploraAuthActionButtonStyle {
        HisploraAuthActionButtonStyle()
    }
}

/// `1429:3256` — a provider row: white, outlined, fully rounded, with the mark set against the
/// label rather than against the edge.
public struct HisploraAuthProviderButtonStyle: ButtonStyle {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Roboto Medium 14 on the frame; the system face at the same size and weight, because
            // Roboto does not ship with iOS and packaging a font for one label is not a trade this
            // design asks for.
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(palette.authProviderInk.color)
            .multilineTextAlignment(.center)
            .padding(.horizontal, KultaraMetrics.md)
            .padding(.vertical, AuthCardMetrics.providerPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .background(palette.paperStamp.color,
                        in: RoundedRectangle(cornerRadius: AuthCardMetrics.providerRadius,
                                             style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AuthCardMetrics.providerRadius, style: .continuous)
                    .stroke(palette.authProviderRing.color, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.85 : 1)
            .opacity(isEnabled ? 1 : 0.4)
    }
}

public extension ButtonStyle where Self == HisploraAuthProviderButtonStyle {
    static var hisploraAuthProvider: HisploraAuthProviderButtonStyle {
        HisploraAuthProviderButtonStyle()
    }
}

// MARK: - The rule and the closing line

/// `1429:3252` — "Or login with" between two hairlines.
///
/// One accessibility element rather than three, and a heading, for the reason
/// `HisploraRuleDivider` gives: the phrase alone in the middle of a form says nothing about what it
/// divides to a reader who cannot see the two rules.
public struct HisploraAuthRuleDivider: View {
    @Environment(\.hisploraPalette) private var palette

    private let label: String

    public init(label: String) {
        self.label = label
    }

    public var body: some View {
        HStack(spacing: AuthCardMetrics.ruleGap) {
            rule
            Text(label)
                // 12, tracking −0.12 (`1429:3254`).
                .font(.system(size: 12))
                .tracking(-0.12)
                .foregroundStyle(palette.authQuiet.color)
            rule
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isHeader)
    }

    private var rule: some View {
        Rectangle()
            .fill(palette.authRule.color)
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

/// `1429:3257` — the closing line: a question in the quiet grey, and the other screen's name in the
/// masthead's brown.
///
/// The whole line is one `Button` rather than a `Text` with a tappable run, for the reason
/// `AuthSwitchLine` already gives: a tap target inside a paragraph is not something VoiceOver
/// announces or activates, and the words either side of it are what say where it goes.
public struct HisploraAuthSwitchLine: View {
    @Environment(\.hisploraPalette) private var palette

    private let question: String
    private let action: String
    private let onTap: () -> Void

    public init(question: String, action: String, onTap: @escaping () -> Void) {
        self.question = question
        self.action = action
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: AuthCardMetrics.closingGap) {
                Text(question)
                    // 15, tracking −0.15 (`1429:3258`).
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.authQuiet.color)
                Text(action)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.brownDeep.color)
            }
            .tracking(-0.15)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action)
        .accessibilityHint(question)
    }
}
