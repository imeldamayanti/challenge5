import AuthenticationServices
import Foundation
import UIKit

/// Drives Sign in with Apple from a custom-styled button, rather than SwiftUI's
/// `SignInWithAppleButton`.
///
/// `AuthProviderBlock` draws its own pill — `HisploraProviderMark` plus "Continue with Apple" —
/// because the entry screens are one page in the Hisplora direction and Apple's own button would be
/// a different picture dropped into it. Apple's Human Interface Guidelines allow a custom button
/// provided the mark and wording are exact, which is what the frame already draws; this talks to
/// `ASAuthorizationController` directly instead of adopting a view it does not style.
@MainActor
final class AppleSignInCoordinator: NSObject {

    struct Result: Sendable {
        let idToken: String
        let nonce: String
        let fullName: String?
    }

    enum Failure: Error {
        case cancelled
        case invalidResponse
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var pendingNonce: String?

    /// Presents Apple's own sheet and suspends until the walker resolves it. Cancelling the sheet
    /// throws `.cancelled`, which the caller must not report as a failure — the walker chose to
    /// stop, the same as tapping away from the screen.
    func start() async throws -> Result {
        let nonce = AppleSignInNonce.make()
        pendingNonce = nonce.raw

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]
        request.nonce = nonce.hashed

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = pendingNonce
        else {
            continuation?.resume(throwing: Failure.invalidResponse)
            continuation = nil
            return
        }
        // Apple hands over a name only the first time a walker ever authorises this app; every
        // later sign-in returns nil, which `AuthViewModel.finish` already treats as "leave whatever
        // is stored alone" rather than as a name to overwrite with nothing.
        let name = credential.fullName.flatMap { PersonNameComponentsFormatter().string(from: $0) }
        continuation?.resume(returning: Result(
            idToken: idToken, nonce: nonce, fullName: (name?.isEmpty == true) ? nil : name))
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithError error: any Error
    ) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: Failure.cancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
