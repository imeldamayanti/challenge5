import ContentKit
import Foundation
import UIStringsKit

/// The three entry screens' one view model — Figma `791:5145` (Sign Up), `791:5109` (Sign In) and
/// `822:2235` (Guest).
///
/// **What this does and does not connect to.** There is no account backend in front of these
/// screens. `supabase/` is deployed and `GovernanceKit`/`TelemetryKit` exist, but nothing in the app
/// calls either yet, and none of them is an identity provider. So what a walker types here builds a
/// **local profile** — the display name `822:2249` promises will appear on their Explorer's Card and
/// in their journal — and nothing else. No credential is stored, transmitted, or checked: the email
/// and the password are validated for shape, and then discarded.
///
/// That is a deliberate reading of the frames rather than an omission dressed up as one. The
/// alternative — a screen that behaves as though it authenticated something — would be the app
/// telling the walker their account exists somewhere. `FR-ONB-05` and `AD-3` also both hold here:
/// every core flow works in airplane mode, and this screen must not become the first one that does
/// not.
///
/// **Apple is the one provider on screen, and it is wired.** `c2` phase 6 enabled
/// `[auth.external.apple]` on the deployed project and shipped `CredentialLinking` — this reads
/// that rather than duplicating it. Google's row was removed rather than left disabled: a control
/// with no `[auth.external.google]` block behind it and no OAuth client anywhere is a promise the
/// app cannot keep, and Google's own brand terms allow their mark only on a real Google Sign-In
/// control — which this never was.
@MainActor
@Observable
final class AuthViewModel {

    /// The three frames, in the order the flow chart reaches them. `signUp` is first: the entry
    /// point named in the brief, and the screen onboarding hands over to.
    enum Stage: String, Sendable, CaseIterable {
        case signUp
        case signIn
        case guestName
    }

    /// Which field a message belongs under. Kept as one value rather than three optionals so a
    /// submission cannot leave two contradictory messages on screen at once.
    enum Field: String, Sendable, CaseIterable {
        case name
        case email
        case password
    }

    /// What a submission was wrong about: the field, and the words to print under it.
    struct Problem: Sendable, Equatable {
        let field: Field
        let message: UIStringKey
    }

    /// The shortest password this build will accept.
    ///
    /// A shape check, not a security control — nothing here hashes, stores or transmits a password.
    /// It exists so the field means something rather than as a claim about strength.
    static let minimumPasswordLength = 8

    private(set) var stage: Stage = .signUp

    var name = ""
    var email = ""
    var password = ""
    /// The guest screen's one field. Separate from `name` rather than shared: backing out of the
    /// guest screen returns to the sign-up form, and a walker who had typed a name there should
    /// find it still there.
    var guestDisplayName = ""

    /// What the last submission was wrong about, and which field it was wrong about. Cleared the
    /// moment the walker edits anything, because a message about text they have since changed is a
    /// message about nothing.
    private(set) var problem: Problem?

    /// Set once the entry screens are done with. The view watches it rather than the view model
    /// dismissing itself, which is how every other screen in this app hands control back.
    private(set) var isFinished = false

    /// What Sign in with Apple last said, shown under the provider block. Separate from `problem`,
    /// which is scoped to one of the three form fields — this is not about a field.
    private(set) var providerMessage: UIStringKey?
    /// True for the span of the native Apple sheet, so a second tap cannot start a second flow
    /// while the first is still on screen.
    private(set) var isSigningInWithApple = false

    private let store: any AppPreferencesStore
    private let credentials: any CredentialLinking

    init(store: any AppPreferencesStore, credentials: any CredentialLinking = NoCredentialLinking()) {
        self.store = store
        self.credentials = credentials
    }

    // MARK: Navigation

    func showSignIn() {
        problem = nil
        stage = .signIn
    }

    func showSignUp() {
        problem = nil
        stage = .signUp
    }

    func continueAsGuest() {
        problem = nil
        // The sign-up form's name carries over: a walker who typed one and then chose the guest
        // route has already answered the guest screen's only question.
        if guestDisplayName.isEmpty { guestDisplayName = name }
        stage = .guestName
    }

    /// The guest screen's back chevron (`822:2235`). It returns to the screen that offered the
    /// guest route rather than to a fixed one, so the way back is the way in.
    func back() {
        problem = nil
        stage = .signUp
    }

    /// Anything the walker types clears the standing message.
    func clearProblem() {
        problem = nil
    }

    // MARK: Submission

    func submitSignUp() {
        if let problem = Self.problemWithSignUp(name: name, email: email, password: password) {
            self.problem = problem
            return
        }
        finish(displayName: name)
    }

    func submitSignIn() {
        if let problem = Self.problemWithSignIn(email: email, password: password) {
            self.problem = problem
            return
        }
        // No name is asked for here and none is invented from the email: a local profile that says
        // "budi.santoso" because that is what came before the `@` is the app naming the reader
        // something they never typed. Whatever name is already stored survives; if there is none,
        // the Explorer's Card goes on naming them by their role.
        finish(displayName: nil)
    }

    func submitGuest() {
        if let problem = Self.problemWithGuestName(guestDisplayName) {
            self.problem = problem
            return
        }
        finish(displayName: guestDisplayName)
    }

    /// The Apple provider row's action. `idToken`/`nonce` and both name parts come from
    /// `AppleSignInCoordinator`, which owns talking to `ASAuthorizationController` — this only
    /// decides what the outcome means for the entry flow.
    ///
    /// A successful sign-in always finishes the flow. Apple hands a name only on the very first
    /// authorisation a walker ever grants this app; every later one gets nil, which `finish`
    /// already reads as "leave whatever is stored alone" rather than as a name to erase. With
    /// nothing stored either, the walker enters right away and the account's own copy of the name —
    /// saved there by an earlier sign-in that did get one — arrives in the store when it lands,
    /// which the Explorer's Card reads on its next look. Asking them to type a name right after a
    /// one-tap sign-in is the second ask this screen was built not to make.
    func signInWithApple(idToken: String, nonce: String, givenName: String?, familyName: String?) async {
        providerMessage = nil
        isSigningInWithApple = true
        let outcome = await credentials.signInWithApple(
            idToken: idToken, nonce: nonce, givenName: givenName, familyName: familyName)
        isSigningInWithApple = false
        switch outcome {
        case .signedInAndMerged, .signedInWithoutMerge:
            if let givenName {
                // The card heads its reader by their given name; the surname travels to the
                // account metadata with the sign-in above, but never onto the card unasked.
                finish(displayName: givenName)
            } else {
                // The entry screens are not a gate, so nothing here waits on the network. A fetch
                // that fails is the offline case and leaves the card role-named; one that succeeds
                // fills the store, which every reader of it re-reads on its next appearance.
                finish(displayName: nil)
                if store.explorerDisplayName == nil {
                    Task { [store, credentials] in
                        if let stored = await credentials.storedDisplayName() {
                            store.explorerDisplayName = stored
                        }
                    }
                }
            }
        case .failed:
            providerMessage = .credentialFailedMessage
        }
    }

    /// Apple's own sheet failed before there was anything to hand `credentials`, so there is no
    /// `CredentialOutcome` to switch on — `AppleSignInCoordinator` calls this directly instead.
    func reportAppleSignInFailure() {
        providerMessage = .credentialFailedMessage
    }

    private func finish(displayName: String?) {
        problem = nil
        if let displayName {
            store.explorerDisplayName = displayName
        }
        store.accountEntryCompletedAt = Date()
        isFinished = true
    }

    // MARK: The rules, as values
    //
    // Pure and static so they are testable without a store, a view, or a simulator — the same
    // argument `ArrivalEvaluator` and `OnboardingGate` make about the rules they own.

    static func problemWithSignUp(
        name: String,
        email: String,
        password: String
    ) -> Problem? {
        if !isPresent(name) { return Problem(field: .name, message: .authMissingName) }
        if !isPlausibleEmail(email) { return Problem(field: .email, message: .authInvalidEmail) }
        if !isLongEnough(password) { return Problem(field: .password, message: .authShortPassword) }
        return nil
    }

    static func problemWithSignIn(
        email: String,
        password: String
    ) -> Problem? {
        if !isPlausibleEmail(email) { return Problem(field: .email, message: .authInvalidEmail) }
        // The length floor is deliberately *not* applied here. It is a rule about choosing a
        // password, and applying it on the way back in would lock out an account made under a
        // different rule — which is what a sign-in form that validates strength always does.
        if !isPresent(password) { return Problem(field: .password, message: .authMissingPassword) }
        return nil
    }

    static func problemWithGuestName(_ name: String) -> Problem? {
        isPresent(name) ? nil : Problem(field: .name, message: .authMissingName)
    }

    /// Whether an address is worth accepting.
    ///
    /// Shape only, and deliberately loose: a local part, an `@`, a dotted domain with something on
    /// both sides of the last dot, and no whitespace. Every stricter rule in circulation rejects
    /// addresses that are genuinely deliverable, and the only test that an address is real is
    /// sending to it — which this build does not do.
    static func isPlausibleEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { return false }

        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }

        let domain = parts[1]
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        return labels.count >= 2 && labels.allSatisfy { !$0.isEmpty } && labels.last!.count >= 2
    }

    static func isLongEnough(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }

    static func isPresent(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Whether the entry screens have anything left to ask.
///
/// A type of its own beside `OnboardingGate`, and read by `KultaraRootView` the same way: the
/// decision belongs somewhere a test can reach without a view.
enum AccountEntryGate {
    static func shouldPresentEntry(store: any AppPreferencesStore) -> Bool {
        store.accountEntryCompletedAt == nil
    }
}
