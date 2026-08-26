import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// Sign Up (`791:5145`) and Sign In (`791:5109`).
///
/// **One screen in two configurations, because the frames are one screen drawn twice.** Same page
/// margin, same capsule fields, same seal-red action, same ruled `OR`, same provider block, same
/// closing line — the differences are the masthead, whether there is a name field, whether the guest
/// row is offered, and which way the closing line points. Two views would be two places to fix the
/// next layout change in, and the second one is always the one that gets missed.
struct AuthCredentialScreen: View {
    @Environment(\.hisploraPalette) private var palette

    /// Everything that differs between the two frames.
    struct Configuration: Sendable {
        let title: UIStringKey
        /// Whether `791:5155`'s name field is drawn. Sign In does not ask for one.
        let asksForName: Bool
        let action: UIStringKey
        /// Whether `791:5180`'s guest row is offered. Only the sign-up frame draws it — the guest
        /// screen is where a *new* walker goes, and offering it again on the way back in would be
        /// offering someone with an account a way to lose it.
        let offersGuestRow: Bool
        let switchQuestion: UIStringKey
        let switchAction: UIStringKey

        static let signUp = Configuration(
            title: .authSignUpTitle,
            asksForName: true,
            action: .authSignUpAction,
            offersGuestRow: true,
            switchQuestion: .authHaveAccount,
            switchAction: .authSignInLink)

        static let signIn = Configuration(
            title: .authSignInTitle,
            asksForName: false,
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
                    masthead
                    // The frames spread their content across the full screen, so the gaps between
                    // the page's four blocks stretch on a tall screen and fall back to the frames'
                    // own steps when the keyboard squeezes the page — a spacer's `minLength` is
                    // the frame's number, and the stretch is what kills the dead band under the
                    // form on the screens the frames were drawn for.
                    Spacer(minLength: AuthMetrics.titleBand)
                    credentials
                    Spacer(minLength: AuthMetrics.blockGap)
                    HisploraRuleDivider(
                        label: UIStrings.string(.authOr, language),
                        accessibilityLabel: UIStrings.string(.authOrSpoken, language))
                    Spacer(minLength: AuthMetrics.blockGap)
                    providers
                }
                .padding(.horizontal, AuthMetrics.margin)
                .padding(.top, AuthMetrics.titleTop)
                .padding(.bottom, KultaraMetrics.xxl)
                // At least the viewport, so the spacers have something to stretch into — and
                // alignment .top, so a form taller than the viewport simply scrolls as it did.
                .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .top)
            }
            // The form is taller than the keyboard leaves room for on the smaller phones, so a swipe
            // over the page puts the keyboard away rather than the walker having to find a Done key
            // this design does not draw.
            .scrollDismissesKeyboard(.interactively)
            // A swipe is not the only way out: a tap on the page's own quiet areas puts the
            // keyboard away too, which is what a walker who has finished a field reaches for.
            .kultaraDismissesKeyboardOnTap()
        }
    }

    private var masthead: some View {
        Text(UIStrings.string(configuration.title, language))
            .kultaraFont(.authDisplay)
            .foregroundStyle(palette.brownSeal.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// `791:5154` and `791:5152`: the fields, then the one filled action under them.
    private var credentials: some View {
        VStack(spacing: AuthMetrics.controlGap) {
            if configuration.asksForName {
                AuthField(
                    kind: .name,
                    placeholder: .authNamePlaceholder,
                    field: .name,
                    model: model,
                    language: language,
                    text: $model.name)
            }
            AuthField(
                kind: .email,
                placeholder: .authEmailPlaceholder,
                field: .email,
                model: model,
                language: language,
                text: $model.email)
            AuthField(
                kind: .password,
                placeholder: .authPasswordPlaceholder,
                field: .password,
                model: model,
                language: language,
                text: $model.password)

            Button(UIStrings.string(configuration.action, language)) { submit() }
                .buttonStyle(.hisploraSealPill)
                .padding(.top, AuthMetrics.actionGap - AuthMetrics.controlGap)
        }
    }

    private var providers: some View {
        VStack(spacing: 0) {
            AuthProviderBlock(
                showsGuestRow: configuration.offersGuestRow,
                language: language,
                model: model,
                onGuest: { model.continueAsGuest() })
            AuthSwitchLine(
                question: configuration.switchQuestion,
                action: configuration.switchAction,
                language: language,
                onTap: {
                    if configuration.asksForName { model.showSignIn() } else { model.showSignUp() }
                })
            .padding(.top, AuthMetrics.footerGap)
        }
    }

    private func submit() {
        if configuration.asksForName {
            model.submitSignUp()
        } else {
            model.submitSignIn()
        }
    }
}
