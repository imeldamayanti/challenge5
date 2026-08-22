import AuthenticationServices
import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// Sign in with Apple, and nothing else on the screen. `c2` phase 6.
///
/// **This is not a gate.** Every flow in the app works without it (`AD-3`, design §7), and the copy
/// says so rather than implying an account is required — the only thing signing in buys a walker is
/// finding their walks again on a different phone. So "Not now" is the same size as the button
/// beside it, and it does not ask twice.
///
/// Apple only. Google needs an `[auth.external.google]` block that `config.toml` does not have and
/// an OAuth client nobody has created; adding a second provider before the first one is enabled
/// would be two things blocked instead of one.
struct CredentialView: View {

    let language: ContentLanguage
    let onSkip: () -> Void
    let onSignIn: (String, String, String?) async -> CredentialOutcome

    @State private var message: String?
    @State private var isWorking = false
    @Environment(\.kultaraPalette) private var palette

    var body: some View {
        // **A `ScrollView`, because at `AccessibilityXXXL` this screen does not fit.** Seen on
        // iPhone 17: the body paragraph truncated mid-word ("…walks can be f…"), which on a screen
        // whose entire job is to say *nothing here is required* is the one sentence that must not
        // be cut. The stack keeps its `Spacer`s via `minHeight` so the layout is unchanged at every
        // size that does fit (`NFR-A11Y-06`).
        ScrollView {
            content
                .frame(minHeight: minimumHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kultaraGround()
    }

    /// Read once per layout rather than per subview.
    @State private var minimumHeight: CGFloat = 0

    private var content: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(UIStrings.text(.credentialTitle).value(for: language))
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.ink.color)
                .multilineTextAlignment(.center)

            Text(UIStrings.text(.credentialBody).value(for: language))
                .kultaraFont(.body)
                .foregroundStyle(palette.inkMuted.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let message {
                Text(message)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.seal.color)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            // Apple's own button, at Apple's own sizing. A hand-drawn one is a guideline violation
            // before it is a design decision.
            SignInWithAppleButton(.signIn) { request in
                let nonce = AppleSignInNonce.make()
                pendingNonce = nonce.raw
                request.requestedScopes = [.fullName]
                request.nonce = nonce.hashed
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .disabled(isWorking)
            .padding(.horizontal, 24)

            Button(UIStrings.text(.credentialSkipAction).value(for: language), action: onSkip)
                .kultaraFont(.body)
                .foregroundStyle(palette.inkMuted.color)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { proxy in
                Color.clear.onAppear { minimumHeight = proxy.size.height }
            })
    }

    /// Held across the two halves of Apple's callback. `@State` rather than a field on a view model
    /// because the request and the completion are the same view's, one frame apart.
    @State private var pendingNonce: String?

    private func handle(_ result: Result<ASAuthorization, any Error>) {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken,
              let idToken = String(data: data, encoding: .utf8),
              let nonce = pendingNonce
        else {
            // A cancellation is not a failure and must not be reported as one — the walker chose
            // to stop, which is the same thing "Not now" does.
            if case .failure(let error) = result,
               (error as? ASAuthorizationError)?.code == .canceled { return }
            message = UIStrings.text(.credentialFailedMessage).value(for: language)
            return
        }

        isWorking = true
        Task {
            let name = credential.fullName.flatMap {
                PersonNameComponentsFormatter().string(from: $0)
            }
            let outcome = await onSignIn(idToken, nonce, name?.isEmpty == true ? nil : name)
            isWorking = false
            switch outcome {
            case .signedInAndMerged:
                message = UIStrings.text(.credentialMergedMessage).value(for: language)
                onSkip()
            case .signedInWithoutMerge:
                // Signed in, so the screen is done — but the walker is told, because walks that did
                // not come across are still on the anonymous account and that is worth knowing.
                message = UIStrings.text(.credentialNotMergedMessage).value(for: language)
                onSkip()
            case .failed:
                message = UIStrings.text(.credentialFailedMessage).value(for: language)
            }
        }
    }
}
