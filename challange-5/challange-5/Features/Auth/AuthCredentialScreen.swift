import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// Sign In (`1429:2829`, "Login") and Register (`1429:3260`).
///
/// **One screen in two configurations, because the frames are one screen drawn twice.** Same
/// masthead band, same white card, same boxed fields, same near-black action, same "Or login with"
/// rule, same provider rows, same closing line — the differences are the two lines of the masthead,
/// how many fields there are, whether the Remember row is drawn, and which way the closing line
/// points. Two views would be two places to fix the next layout change in, and the second one is
/// always the one that gets missed. That rule survives the redesign; only the drawing changed.
///
/// ### How the frames' coordinates reach a real device
///
/// Everything in the frames is measured from the top of an 812-point canvas whose status bar is 44
/// points tall. A real phone's is not 44. So the frames' numbers are taken **below the status bar**
/// and the band grows by whatever the device puts above it: the masthead is 397 − 44 tall, the card
/// starts 257 − 44 down, and the 140 points by which the card overlaps the brown — the one
/// relationship a reader actually sees — is preserved exactly on every screen. Pinning the card to
/// the frame's absolute 257 instead would slide it up or down the band on any phone that is not
/// the drawing.
///
/// ### What is drawn and does nothing
///
/// The Remember / Forgot row (`1429:3245`), at the owner's instruction of 2026-08-26. There is no
/// account backend in front of these screens — `AuthViewModel` has the whole account of that — so
/// it is drawn as one static element rather than as two controls. `HisploraAuthRememberRow` says
/// why in its own documentation.
///
/// ### What is here and not in the frames
///
/// The guest row, under Apple's and at the same size, at the owner's instruction of the same day.
/// The frames offer no way in that is not an account, and this build's "account" is a local profile
/// — removing the guest route would have removed the one honest entry the app has.
struct AuthCredentialScreen: View {

    /// Everything that differs between the two frames.
    struct Configuration: Sendable {
        let title: UIStringKey
        let subtitle: UIStringKey
        /// Whether `1429:3674`'s name field is drawn. The sign-in frame does not ask for one.
        let asksForName: Bool
        /// Whether `1429:3677`'s second password box is drawn. Only the register frame repeats it.
        let confirmsPassword: Bool
        /// Whether `1429:3245` is drawn. The register frame has no Remember row — its four fields
        /// run straight into the action.
        let showsRememberRow: Bool
        let action: UIStringKey
        /// Whether the guest row is offered. Only the register frame draws it: the guest screen is
        /// where a *new* walker goes, and offering it on the way back in would be offering someone
        /// with a profile a way to lose it.
        let offersGuestRow: Bool
        let switchQuestion: UIStringKey
        let switchAction: UIStringKey

        static let signUp = Configuration(
            title: .authSignUpTitle,
            subtitle: .authSignUpSubtitle,
            asksForName: true,
            confirmsPassword: true,
            showsRememberRow: false,
            action: .authSignUpAction,
            offersGuestRow: true,
            switchQuestion: .authHaveAccount,
            switchAction: .authSignInLink)

        static let signIn = Configuration(
            title: .authSignInTitle,
            subtitle: .authSignInSubtitle,
            asksForName: false,
            confirmsPassword: false,
            showsRememberRow: true,
            action: .authSignInAction,
            offersGuestRow: false,
            switchQuestion: .authNoAccount,
            switchAction: .authSignUpLink)
    }

    let configuration: Configuration
    @Bindable var model: AuthViewModel
    let language: ContentLanguage

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    HisploraAuthHead(
                        title: UIStrings.string(configuration.title, language),
                        subtitle: UIStrings.string(configuration.subtitle, language),
                        topInset: geo.safeAreaInsets.top)
                    card
                        .padding(.horizontal, AuthCardMetrics.cardInset)
                        // The card starts inside the brown band, 140 points above its foot.
                        .padding(.top, -(AuthCardMetrics.headHeight - AuthCardMetrics.cardTop))
                }
                .padding(.bottom, KultaraMetrics.xxl)
            }
            // The band bleeds under the status bar. The scroll view is what ignores the inset, so
            // the brown moves with the page rather than staying pinned while the card slides under
            // it — which is what a background layered outside the scroll would have done.
            .ignoresSafeArea(edges: .top)
            // The register form is taller than the keyboard leaves room for on the smaller phones,
            // so a swipe over the page puts the keyboard away rather than the walker having to find
            // a Done key this design does not draw.
            .scrollDismissesKeyboard(.interactively)
            // A swipe is not the only way out: a tap on the card's own quiet areas puts the
            // keyboard away too, which is what a walker who has finished a field reaches for.
            .kultaraDismissesKeyboardOnTap()
        }
    }

    /// `1429:3241` — the five blocks, 24 apart.
    private var card: some View {
        HisploraAuthCard {
            fields
            Button(UIStrings.string(configuration.action, language)) { submit() }
                .buttonStyle(.hisploraAuthAction)
            HisploraAuthRuleDivider(label: UIStrings.string(.authOr, language))
            providers
            HisploraAuthSwitchLine(
                question: UIStrings.string(configuration.switchQuestion, language),
                action: UIStrings.string(configuration.switchAction, language),
                onTap: {
                    if configuration.asksForName { model.showSignIn() } else { model.showSignUp() }
                })
        }
    }

    /// `1429:3242` / `1429:3673` — the fields, 16 apart, with the Remember row as the last step of
    /// the same block on the sign-in frame.
    private var fields: some View {
        VStack(spacing: AuthCardMetrics.fieldGap) {
            if configuration.asksForName {
                AuthCardField(
                    kind: .name,
                    placeholder: .authNamePlaceholder,
                    field: .name,
                    model: model,
                    language: language,
                    text: $model.name)
            }
            AuthCardField(
                kind: .email,
                placeholder: .authEmailPlaceholder,
                field: .email,
                model: model,
                language: language,
                text: $model.email)
            AuthCardField(
                kind: .password,
                placeholder: .authPasswordPlaceholder,
                field: .password,
                model: model,
                language: language,
                text: $model.password)
            if configuration.confirmsPassword {
                AuthCardField(
                    kind: .password,
                    placeholder: .authConfirmPasswordPlaceholder,
                    field: .confirmPassword,
                    model: model,
                    language: language,
                    text: $model.confirmPassword)
            }
            if configuration.showsRememberRow {
                HisploraAuthRememberRow(
                    rememberLabel: UIStrings.string(.authRememberMe, language),
                    forgotLabel: UIStrings.string(.authForgotPassword, language),
                    spokenLabel: UIStrings.string(.authRememberRowSpoken, language))
            }
        }
    }

    private var providers: some View {
        AuthProviderBlock(
            showsGuestRow: configuration.offersGuestRow,
            language: language,
            model: model,
            onGuest: { model.continueAsGuest() })
    }

    private func submit() {
        if configuration.asksForName {
            model.submitSignUp()
        } else {
            model.submitSignIn()
        }
    }
}
