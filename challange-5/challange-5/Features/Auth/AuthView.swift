import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The entry screens, on the Hisplora direction — Figma `791:5145` (Sign Up), `791:5109` (Sign In)
/// and `822:2235` (Guest).
///
/// They replace `AuthWireframeView`, which was a drawing of this flow with a "Skip for now" on it,
/// and they are reached where it was: splash → onboarding → **here** → Home. Onboarding is the
/// first Hisplora surface the app shows and these are the second, third and fourth, so the museum
/// catalogue is still not seen until Home — the seam between the two directions stays a screen
/// boundary.
///
/// **What is behind them is a local profile, not an account.** `AuthViewModel` has the whole
/// account of that, including why the two provider rows are drawn and disabled.
struct AuthView: View {

    private let language: ContentLanguage
    @State private var model: AuthViewModel
    private let onFinish: () -> Void

    init(store: any AppPreferencesStore, language: ContentLanguage, onFinish: @escaping () -> Void) {
        self.language = language
        self.onFinish = onFinish
        _model = State(initialValue: AuthViewModel(store: store))
    }

    var body: some View {
        HisploraStage(ground: \.paperSheet) {
            Group {
                switch model.stage {
                case .signUp:
                    AuthCredentialScreen(
                        configuration: .signUp, model: model, language: language)
                case .signIn:
                    AuthCredentialScreen(
                        configuration: .signIn, model: model, language: language)
                case .guestName:
                    GuestNameScreen(model: model, language: language)
                }
            }
            // The three frames are one page redrawn, so they cross-fade rather than push: a
            // navigation transition here would slide 314-point controls out from under 314-point
            // controls in the same place.
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: model.stage)
        }
        .onChange(of: model.isFinished) { _, finished in
            if finished { onFinish() }
        }
    }
}

// MARK: - The page these three frames share

/// The entry frames' own margins, in their own 402-point terms: a 314-point control inside a
/// 44-point page margin. Not on `KultaraMetrics`' spacing scale, for the reason `OnboardingView`
/// gives about its own 20 — this is the board's page margin, not a step of the museum's rhythm.
enum AuthMetrics {
    static let margin: CGFloat = 44
    /// 233 − 127 − 41: the air the frames leave under the masthead before the form starts.
    static let titleBand: CGFloat = 65
    /// 127 on the frame, under a 62-point status bar.
    static let titleTop: CGFloat = 65
    /// The 10 between two stacked controls, and the 30 between the form's three blocks.
    static let controlGap: CGFloat = 10
    static let blockGap: CGFloat = 30
    /// 184 − 158 on `791:5145`, 126 − 102 on `791:5109`: the step between the last field and the
    /// action under it. The two frames differ by two points, which is a rounding of the fields'
    /// own heights rather than a decision.
    static let actionGap: CGFloat = 25
    /// 173 − 158 and 117 − 102: the step between the last provider row and the closing line.
    static let footerGap: CGFloat = 15
}

/// The message a submission left under one of the fields.
///
/// Set in `brownSeal` — the screen's own seal red, measured on this cream — rather than in a system
/// red this palette does not have. It is announced as an alert so a walker using VoiceOver hears it
/// without hunting for it, and the field it belongs to says the same words in its own hint, because
/// colour and position never carry a message alone here (`NFR-A11Y-05`).
struct AuthFieldMessage: View {
    @Environment(\.hisploraPalette) private var palette

    let key: UIStringKey
    let language: ContentLanguage

    var body: some View {
        Text(UIStrings.string(key, language))
            .kultaraFont(.caption)
            .foregroundStyle(palette.brownSeal.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 17)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// A field with whatever the last submission said about it printed underneath.
struct AuthField: View {
    let kind: HisploraFieldRow.Kind
    let placeholder: UIStringKey
    let field: AuthViewModel.Field
    @Bindable var model: AuthViewModel
    let language: ContentLanguage
    @Binding var text: String

    private var problem: AuthViewModel.Problem? {
        model.problem?.field == field ? model.problem : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            HisploraFieldRow(
                kind: kind,
                placeholder: UIStrings.string(placeholder, language),
                accessibilityLabel: UIStrings.string(placeholder, language),
                text: $text)
            if let problem {
                AuthFieldMessage(key: problem.message, language: language)
            }
        }
        // The message is the field's own hint as well as a line under it: a reader who has moved
        // focus to the box hears what is wrong with it there, rather than only where it is drawn.
        .accessibilityHint(problem.map { UIStrings.string($0.message, language) } ?? "")
        .onChange(of: text) { _, _ in model.clearProblem() }
    }
}

/// The two provider rows, the guest row on the sign-up frame, and the line that says why the first
/// two cannot be used.
///
/// `791:5170`, `791:5173` and `791:5180`. Apple and Google are `disabled` — see `AuthViewModel` for
/// why a control labelled "Continue with Apple" that does not call `AuthenticationServices` is not
/// something this app is willing to draw as working. "Continue as a guest" is the one row here that
/// does what it says.
struct AuthProviderBlock: View {
    @Environment(\.hisploraPalette) private var palette

    let showsGuestRow: Bool
    let language: ContentLanguage
    let onGuest: () -> Void

    var body: some View {
        VStack(spacing: AuthMetrics.controlGap) {
            Button {
                // Unreachable: the control is disabled. Left empty rather than given a stand-in
                // action, so wiring Sign in with Apple later is a change in one place.
            } label: {
                providerLabel(.apple, .authContinueWithApple)
            }
            .buttonStyle(.hisploraProviderDark)
            .disabled(true)

            Button {} label: {
                providerLabel(.google, .authContinueWithGoogle)
            }
            .buttonStyle(.hisploraProviderLight)
            .disabled(true)

            if showsGuestRow {
                Button(action: onGuest) {
                    providerLabel(.guest, .authContinueAsGuest)
                }
                .buttonStyle(.hisploraProviderGuest)
            }

            Text(UIStrings.string(.authProvidersUnavailable, language))
                .kultaraFont(.caption)
                .foregroundStyle(palette.inkMuted.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, KultaraMetrics.xs)
        }
    }

    private func providerLabel(
        _ provider: HisploraProviderMark.Provider,
        _ key: UIStringKey
    ) -> some View {
        HStack(spacing: AuthMetrics.controlGap) {
            HisploraProviderMark(provider: provider)
            Text(UIStrings.string(key, language))
        }
    }
}

/// The closing line: a question in the quiet ink and the other screen's name in the seal red
/// (`791:5183`, `791:5144`).
///
/// The whole line is one `Button` rather than a `Text` with a tappable run. A tap target inside a
/// paragraph is not something VoiceOver announces or activates, and the words either side of it are
/// what say where it goes — so the control is the sentence, labelled with the sentence.
struct AuthSwitchLine: View {
    @Environment(\.hisploraPalette) private var palette

    let question: UIStringKey
    let action: UIStringKey
    let language: ContentLanguage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: KultaraMetrics.xs) {
                Text(UIStrings.string(question, language))
                    .foregroundStyle(palette.inkMuted.color)
                Text(UIStrings.string(action, language))
                    .fontWeight(.bold)
                    .foregroundStyle(palette.brownSeal.color)
            }
            .font(.system(size: 15))
            .tracking(-0.23)
            .frame(maxWidth: .infinity)
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(UIStrings.string(action, language))
        .accessibilityHint(UIStrings.string(question, language))
    }
}
