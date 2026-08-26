import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The entry screens — Figma `1429:2829` ("Login"), `1429:3260` ("Register") and `822:2235`
/// (Guest).
///
/// **The first two were redrawn on 2026-08-26.** They were `791:5145` and `791:5109`: a cream page
/// in the story flow's own language, with a serif masthead and capsule fields. The board now draws
/// the entry as a deep-brown masthead over a white card, which is a form rather than a page of the
/// book, and the whole screen moved rather than half of it — the two visual directions are separated
/// at a screen boundary and that has not changed. The guest screen is still `822:2235` and is still
/// on the cream, because the board did not redraw it.
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

    init(
        store: any AppPreferencesStore,
        credentials: any CredentialLinking = NoCredentialLinking(),
        language: ContentLanguage,
        onFinish: @escaping () -> Void
    ) {
        self.language = language
        self.onFinish = onFinish
        _model = State(initialValue: AuthViewModel(store: store, credentials: credentials))
    }

    var body: some View {
        HisploraStage(ground: model.stage == .guestName ? \.paperSheet : \.authGround) {
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

// MARK: - The guest page

/// `822:2235`'s own margins, in its own 402-point terms: a 314-point control inside a 44-point page
/// margin. Not on `KultaraMetrics`' spacing scale, for the reason `OnboardingView` gives about its
/// own 20 — this is the board's page margin, not a step of the museum's rhythm.
///
/// Only the guest screen reads these now. The login and register screens moved to
/// `AuthCardMetrics`, which carries `1429:2829`'s and `1429:3260`'s numbers instead.
enum AuthMetrics {
    static let margin: CGFloat = 44
    /// The 10 between two stacked controls on that screen.
    static let controlGap: CGFloat = 10
    /// 372 − 312 − 46: the step the guest frame puts between its field and its action.
    static let actionGap: CGFloat = 25
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
            // The masthead's own brown. `brownSeal` is the cream page's red and reads as a
            // different colour beside a `#6E2717` band, which is the one place on these two screens
            // where two nearly-identical browns would sit within 300 points of each other.
            .foregroundStyle(palette.brownDeep.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AuthCardMetrics.fieldPadding)
            .accessibilityAddTraits(.isStaticText)
    }
}

/// A boxed field on the card, with whatever the last submission said about it printed underneath
/// (`I1429:3243;3:6011`).
///
/// Its own type beside `AuthField` rather than a style flag on it: the guest screen is still
/// `822:2235`, still on cream, and still draws the capsule. One field type that could be either
/// would be a field somebody eventually puts on the wrong ground.
struct AuthCardField: View {
    let kind: HisploraAuthField.Kind
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
            HisploraAuthField(
                kind: kind,
                placeholder: UIStrings.string(placeholder, language),
                accessibilityLabel: UIStrings.string(placeholder, language),
                revealLabel: UIStrings.string(.authRevealPassword, language),
                hideLabel: UIStrings.string(.authHidePassword, language),
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

/// The Apple row (`1429:3256`), the guest row under it on the register frame, and a line under both.
///
/// **Apple is wired to `c2` phase 6's `CredentialLinking`.** Google's row was removed rather than
/// left drawn-and-disabled: with no `[auth.external.google]` block and no OAuth client behind it, a
/// "Continue with Google" pill is a promise the app cannot keep — and Google's brand terms allow
/// their mark only on a working Google Sign-In control, which made the shipped mark itself a
/// pre-public blocker (`docs/hisplora-tokens.md`). A failed sign-in says so under the block rather
/// than leaving a walker looking at a button that did nothing.
///
/// **The guest row is not in the frames.** It is added at the owner's instruction of 2026-08-26, at
/// Apple's own size and in Apple's own style, and it is the one entry this build can honestly
/// complete — see `AuthCredentialScreen`. The two rows are 16 apart rather than the card's own 24,
/// so they read as one block with two ways through it rather than as two of the card's five blocks.
struct AuthProviderBlock: View {
    @Environment(\.hisploraPalette) private var palette

    let showsGuestRow: Bool
    let language: ContentLanguage
    @Bindable var model: AuthViewModel
    let onGuest: () -> Void

    /// Owns one `ASAuthorizationController` per screen, not per tap — a fresh coordinator per tap
    /// would leak the delegate of whichever attempt the walker abandoned mid-sheet.
    @State private var appleSignIn = AppleSignInCoordinator()

    var body: some View {
        VStack(spacing: AuthCardMetrics.fieldGap) {
            Button {
                Task { await startAppleSignIn() }
            } label: {
                providerLabel(.apple, .authContinueWithApple)
            }
            .buttonStyle(.hisploraAuthProvider)
            .disabled(model.isSigningInWithApple)

            if showsGuestRow {
                Button(action: onGuest) {
                    providerLabel(.guest, .authContinueAsGuest)
                }
                .buttonStyle(.hisploraAuthProvider)
            }

            if let message = model.providerMessage {
                Text(UIStrings.string(message, language))
                    .kultaraFont(.caption)
                    // The masthead's brown for a real outcome (something happened, worth noticing).
                    .foregroundStyle(palette.brownDeep.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    /// A cancelled sheet is not reported — the walker chose to stop, the same as tapping away from
    /// the screen — so only `AppleSignInCoordinator.Failure.invalidResponse` and a genuine
    /// `CredentialLinking` failure reach `providerMessage`.
    private func startAppleSignIn() async {
        do {
            let result = try await appleSignIn.start()
            await model.signInWithApple(
                idToken: result.idToken, nonce: result.nonce,
                givenName: result.givenName, familyName: result.familyName)
        } catch AppleSignInCoordinator.Failure.cancelled {
            return
        } catch {
            model.reportAppleSignInFailure()
        }
    }

    /// `I1429:3256;68:15375` — a 20-point mark, 8 from its label, the pair centred in the row.
    private func providerLabel(
        _ provider: HisploraProviderMark.Provider,
        _ key: UIStringKey
    ) -> some View {
        HStack(spacing: AuthCardMetrics.providerMarkGap) {
            HisploraProviderMark(provider: provider)
                .frame(width: AuthCardMetrics.providerMarkSize,
                       height: AuthCardMetrics.providerMarkSize)
            Text(UIStrings.string(key, language))
        }
    }
}
