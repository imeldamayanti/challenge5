import Foundation
import Testing
import UIStringsKit
@testable import challange_5

/// The entry screens' rules — Figma `791:5145`, `791:5109` and `822:2235`.
///
/// These live in the app target rather than in a package for the reason the folder's own note
/// gives: `AuthViewModel` reads `AppPreferencesStore`, which is an app-target protocol. The rules
/// themselves are static and pure, so most of what is below needs no store at all.
@MainActor
@Suite("Entry screens")
struct AuthTests {

    // MARK: The shape of an address

    @Test(arguments: [
        "a@b.co",
        "walker@example.com",
        "first.last@sub.example.co.id",
        "walker+quest@example.com",
    ])
    func acceptsAnAddressWithALocalPartAndADottedDomain(_ email: String) {
        #expect(AuthViewModel.isPlausibleEmail(email))
    }

    @Test(arguments: [
        "",
        "   ",
        "walker",              // no domain at all
        "walker@example",      // no dot in the domain
        "@example.com",        // no local part
        "walker@@example.com", // two separators
        "walker@example.",     // an empty last label
        "walker@.com",         // an empty first label
        "walker@example.c",    // a one-character tld
        "wal ker@example.com", // whitespace anywhere
    ])
    func rejectsAnAddressThatIsNotOne(_ email: String) {
        #expect(!AuthViewModel.isPlausibleEmail(email))
    }

    // MARK: What each form insists on

    @Test func signingUpAsksForAName() {
        let problem = AuthViewModel.problemWithSignUp(
            name: "   ", email: "walker@example.com", password: "aaaaaaaa")
        #expect(problem == AuthViewModel.Problem(field: .name, message: .authMissingName))
    }

    @Test func signingUpChecksTheAddressBeforeThePassword() {
        // Both are wrong. The message names the field nearer the top of the form, so a walker
        // fixes the page in the order they filled it in.
        let problem = AuthViewModel.problemWithSignUp(
            name: "Ayu", email: "nope", password: "short")
        #expect(problem == AuthViewModel.Problem(field: .email, message: .authInvalidEmail))
    }

    @Test func signingUpHoldsThePasswordToTheLengthFloor() {
        let problem = AuthViewModel.problemWithSignUp(
            name: "Ayu", email: "walker@example.com", password: "1234567")
        #expect(problem == AuthViewModel.Problem(field: .password, message: .authShortPassword))
        #expect(AuthViewModel.problemWithSignUp(
            name: "Ayu", email: "walker@example.com", password: "12345678") == nil)
    }

    /// The rule that is easy to "tidy" into a bug: a length floor is about *choosing* a password,
    /// and applying it on the way back in locks out an account made under a different rule.
    @Test func signingInDoesNotHoldThePasswordToTheLengthFloor() {
        #expect(AuthViewModel.problemWithSignIn(email: "walker@example.com", password: "abc") == nil)
    }

    @Test func signingInStillNeedsAPasswordAndSaysSoInItsOwnWords() {
        let problem = AuthViewModel.problemWithSignIn(email: "walker@example.com", password: "")
        #expect(problem == AuthViewModel.Problem(field: .password, message: .authMissingPassword))
    }

    @Test func theGuestScreenRefusesANameOfNothingButSpaces() {
        #expect(AuthViewModel.problemWithGuestName("  \n ")
            == AuthViewModel.Problem(field: .name, message: .authMissingName))
        #expect(AuthViewModel.problemWithGuestName("Ayu") == nil)
    }

    // MARK: What a finished form leaves behind

    @Test func signingUpKeepsTheNameAndMarksTheEntryDone() {
        let store = InMemoryAppPreferencesStore()
        let model = AuthViewModel(store: store)
        model.name = "  Ayu  "
        model.email = "walker@example.com"
        model.password = "kembang123"
        model.submitSignUp()

        #expect(model.isFinished)
        // Trimmed by the store, which normalises on the way in so nothing downstream has to.
        #expect(store.explorerDisplayName == "Ayu")
        #expect(store.accountEntryCompletedAt != nil)
    }

    @Test func theGuestScreenKeepsTheNameItAsksFor() {
        let store = InMemoryAppPreferencesStore()
        let model = AuthViewModel(store: store)
        model.guestDisplayName = "Wayan"
        model.submitGuest()

        #expect(model.isFinished)
        #expect(store.explorerDisplayName == "Wayan")
    }

    /// Sign-in asks for no name, and inventing one from the address would be the app calling the
    /// reader something they never typed.
    @Test func signingInInventsNoNameAndLeavesAnExistingOneAlone() {
        let store = InMemoryAppPreferencesStore(explorerDisplayName: "Ayu")
        let model = AuthViewModel(store: store)
        model.email = "budi.santoso@example.com"
        model.password = "kembang123"
        model.submitSignIn()

        #expect(model.isFinished)
        #expect(store.explorerDisplayName == "Ayu")
    }

    @Test func aFormThatIsWrongFinishesNothing() {
        let store = InMemoryAppPreferencesStore()
        let model = AuthViewModel(store: store)
        model.name = "Ayu"
        model.email = "nope"
        model.password = "kembang123"
        model.submitSignUp()

        #expect(!model.isFinished)
        #expect(model.problem?.field == .email)
        #expect(store.accountEntryCompletedAt == nil)
        #expect(store.explorerDisplayName == nil)
    }

    // MARK: Moving between the three frames

    @Test func theGuestScreenStartsWithWhateverNameWasAlreadyTyped() {
        let model = AuthViewModel(store: InMemoryAppPreferencesStore())
        model.name = "Ayu"
        model.continueAsGuest()

        #expect(model.stage == .guestName)
        #expect(model.guestDisplayName == "Ayu")
    }

    @Test func backingOutOfTheGuestScreenReturnsToTheFormThatOfferedIt() {
        let model = AuthViewModel(store: InMemoryAppPreferencesStore())
        model.continueAsGuest()
        model.back()
        #expect(model.stage == .signUp)
    }

    @Test func changingScreenClearsAMessageAboutTheOldOne() {
        let model = AuthViewModel(store: InMemoryAppPreferencesStore())
        model.submitSignUp()
        #expect(model.problem != nil)
        model.showSignIn()
        #expect(model.problem == nil)
    }

    @Test func editingAFieldClearsTheStandingMessage() {
        let model = AuthViewModel(store: InMemoryAppPreferencesStore())
        model.submitSignUp()
        #expect(model.problem != nil)
        model.clearProblem()
        #expect(model.problem == nil)
    }

    // MARK: The gate

    @Test func theEntryScreensAreShownUntilTheyHaveBeenPassed() {
        #expect(AccountEntryGate.shouldPresentEntry(store: InMemoryAppPreferencesStore()))
        #expect(!AccountEntryGate.shouldPresentEntry(
            store: InMemoryAppPreferencesStore(accountEntryCompletedAt: Date())))
    }

    /// `FR-SET-02`: erasing local data puts a walker back at the start of the flow, name and all.
    @Test func erasingLocalDataPutsTheEntryScreensBack() {
        let store = InMemoryAppPreferencesStore()
        AuthViewModel(store: store).apply { model in
            model.guestDisplayName = "Wayan"
            model.submitGuest()
        }
        #expect(!AccountEntryGate.shouldPresentEntry(store: store))

        store.removeAll()
        #expect(AccountEntryGate.shouldPresentEntry(store: store))
        #expect(store.explorerDisplayName == nil)
    }

    // MARK: Apple, wired to `c2` phase 6's `CredentialLinking`

    final class SpyCredentialLinking: CredentialLinking, @unchecked Sendable {
        private let lock = NSLock()
        private var calls: [
            (idToken: String, nonce: String, givenName: String?, familyName: String?)
        ] = []
        let answer: CredentialOutcome
        /// What `storedDisplayName` answers — the name an earlier sign-in left on the account.
        var storedName: String?

        init(answer: CredentialOutcome) { self.answer = answer }

        var callCount: Int { lock.withLock { calls.count } }
        var lastCall: (idToken: String, nonce: String, givenName: String?, familyName: String?)? {
            lock.withLock { calls.last }
        }

        func signInWithApple(
            idToken: String, nonce: String, givenName: String?, familyName: String?
        ) async -> CredentialOutcome {
            lock.withLock { calls.append((idToken, nonce, givenName, familyName)) }
            return answer
        }

        func storedDisplayName() async -> String? { storedName }

        func signOut() async {}
    }

    /// A merge finishes the entry flow exactly like any other successful form — the walker's own
    /// name comes back from Apple only on first authorisation, and it is kept the same way a typed
    /// name is.
    @Test func aSuccessfulAppleSignInFinishesTheFlowAndKeepsTheName() async {
        let store = InMemoryAppPreferencesStore()
        let credentials = SpyCredentialLinking(answer: .signedInAndMerged)
        let model = AuthViewModel(store: store, credentials: credentials)

        await model.signInWithApple(idToken: "a-token", nonce: "a-nonce", givenName: "Ayu", familyName: nil)

        #expect(credentials.callCount == 1)
        #expect(credentials.lastCall?.idToken == "a-token")
        #expect(credentials.lastCall?.nonce == "a-nonce")
        #expect(model.isFinished)
        #expect(store.explorerDisplayName == "Ayu")
        #expect(model.providerMessage == nil)
        #expect(!model.isSigningInWithApple)
    }

    /// Signed in, but the merge did not run. The walker still finishes the flow — the walks are on
    /// the anonymous account, not gone — and is told, because this is the one outcome worth hearing
    /// about (`CredentialOutcome.signedInWithoutMerge`'s own doc comment). Apple handed a name here;
    /// what happens when it did not is the next test's subject.
    @Test func signingInWithoutAMergeStillFinishesTheFlow() async {
        let store = InMemoryAppPreferencesStore()
        let credentials = SpyCredentialLinking(answer: .signedInWithoutMerge)
        let model = AuthViewModel(store: store, credentials: credentials)

        await model.signInWithApple(idToken: "a-token", nonce: "a-nonce", givenName: "Ayu", familyName: nil)

        #expect(model.isFinished)
        #expect(store.accountEntryCompletedAt != nil)
    }

    /// Apple returns no name on a repeat sign-in, and that must not erase a name already stored —
    /// the same rule `signingInInventsNoNameAndLeavesAnExistingOneAlone` holds for email sign-in.
    @Test func aRepeatAppleSignInLeavesAnExistingNameAlone() async {
        let store = InMemoryAppPreferencesStore(explorerDisplayName: "Ayu")
        let model = AuthViewModel(
            store: store, credentials: SpyCredentialLinking(answer: .signedInAndMerged))

        await model.signInWithApple(idToken: "a-token", nonce: "a-nonce", givenName: nil, familyName: nil)

        #expect(model.isFinished)
        #expect(store.explorerDisplayName == "Ayu")
    }

    /// Apple hands a name only on the very first authorisation; every later one returns nil. With
    /// no name from Apple and none already stored, the flow still finishes — one tap signed the
    /// walker in, and asking them to type a name right after is the second ask this screen was
    /// built not to make. The account's own copy of the name is fetched behind the walker instead:
    /// the entry finishes immediately, and the store fills when the fetch lands.
    @Test func anAppleSignInWithNoNameFetchesTheOneTheAccountKeeps() async {
        let store = InMemoryAppPreferencesStore()
        let credentials = SpyCredentialLinking(answer: .signedInAndMerged)
        credentials.storedName = "Alief"
        let model = AuthViewModel(store: store, credentials: credentials)

        await model.signInWithApple(idToken: "a-token", nonce: "a-nonce", givenName: nil, familyName: nil)

        #expect(model.isFinished)
        #expect(store.accountEntryCompletedAt != nil)
        // The fetch runs off the entry flow, so the test waits for the thing rather than for the
        // clock: bounded yielding until the store fills, never a fixed sleep.
        for _ in 0..<10_000 where store.explorerDisplayName == nil {
            await Task.yield()
        }
        #expect(store.explorerDisplayName == "Alief")
    }

    /// The same sign-in with nothing on the account either: the card stays role-named and nothing
    /// is invented.
    @Test func anAppleSignInWithNoNameAnywhereStaysRoleNamed() async {
        let store = InMemoryAppPreferencesStore()
        let model = AuthViewModel(
            store: store, credentials: SpyCredentialLinking(answer: .signedInAndMerged))

        await model.signInWithApple(idToken: "a-token", nonce: "a-nonce", givenName: nil, familyName: nil)

        #expect(model.isFinished)
        #expect(store.accountEntryCompletedAt != nil)
        for _ in 0..<10_000 where store.explorerDisplayName != nil {
            await Task.yield()
        }
        #expect(store.explorerDisplayName == nil)
    }

    /// A failed sign-in does not finish the flow, and says so under the provider block rather than
    /// leaving the walker looking at buttons that did nothing.
    @Test func aFailedAppleSignInStaysOnScreenAndSaysSo() async {
        let store = InMemoryAppPreferencesStore()
        let model = AuthViewModel(
            store: store, credentials: SpyCredentialLinking(answer: .failed))

        await model.signInWithApple(idToken: "a-token", nonce: "a-nonce", givenName: nil, familyName: nil)

        #expect(!model.isFinished)
        #expect(model.providerMessage == .credentialFailedMessage)
        #expect(store.accountEntryCompletedAt == nil)
    }

    /// Apple issues a name exactly once per Apple ID per app. A sign-in that fails downstream — a
    /// provider whose Services ID does not match the build's bundle id, an offline attempt, a build
    /// with no backend at all — used to throw that one copy away with it, and every later
    /// authorisation arrives with nil, so the card read "Explorer" forever. The name is kept; the
    /// entry still does not complete.
    @Test func aFailedAppleSignInStillKeepsTheNameAppleWillNeverSendAgain() async {
        let store = InMemoryAppPreferencesStore()
        let model = AuthViewModel(
            store: store, credentials: SpyCredentialLinking(answer: .failed))

        await model.signInWithApple(
            idToken: "a-token", nonce: "a-nonce", givenName: "Ayu", familyName: "Kartika")

        #expect(!model.isFinished)
        #expect(store.accountEntryCompletedAt == nil)
        #expect(store.explorerDisplayName == "Ayu Kartika")
    }

    /// Both halves go on the card, not the given name alone — `822:2249`'s promise, and what
    /// `CredentialLinking` already stores on the account as `full_name`.
    @Test func anAppleSignInKeepsTheWholeNameOnTheCard() async {
        let store = InMemoryAppPreferencesStore()
        let model = AuthViewModel(
            store: store, credentials: SpyCredentialLinking(answer: .signedInAndMerged))

        await model.signInWithApple(
            idToken: "a-token", nonce: "a-nonce", givenName: "Ayu", familyName: "Kartika")

        #expect(model.isFinished)
        #expect(store.explorerDisplayName == "Ayu Kartika")
    }

    /// Apple can hand over a surname with no given name, and a blank part must not become a space.
    @Test func onlyTheNamePartsAppleActuallySentAreJoined() {
        #expect(AuthViewModel.wholeName(givenName: "Ayu", familyName: nil) == "Ayu")
        #expect(AuthViewModel.wholeName(givenName: nil, familyName: "Kartika") == "Kartika")
        #expect(AuthViewModel.wholeName(givenName: "Ayu", familyName: "  ") == "Ayu")
        #expect(AuthViewModel.wholeName(givenName: nil, familyName: nil) == nil)
        #expect(AuthViewModel.wholeName(givenName: " ", familyName: " ") == nil)
    }

    /// `AppleSignInCoordinator` calls this directly when Apple's own sheet fails before there is
    /// anything to hand `CredentialLinking` — a different path to the same message.
    @Test func aFailureBeforeCredentialLinkingIsCalledReportsTheSameMessage() {
        let model = AuthViewModel(store: InMemoryAppPreferencesStore())
        model.reportAppleSignInFailure()
        #expect(model.providerMessage == .credentialFailedMessage)
        #expect(!model.isFinished)
    }

    /// A cancelled Apple sheet is not a failure — the walker chose to stop, the same as tapping
    /// away from the screen — and `AuthProviderBlock.startAppleSignIn` returns without calling
    /// either of the two paths above. Nothing to assert on the model beyond it being untouched: this
    /// documents the contract those two report-failure tests deliberately do not cover.
    @Test func aCancelledSignInReportsNothing() {
        let model = AuthViewModel(store: InMemoryAppPreferencesStore())
        #expect(model.providerMessage == nil)
        #expect(!model.isFinished)
    }
}

private extension AuthViewModel {
    /// A one-liner for "build it, drive it, throw it away" — the store is what the assertion is
    /// about in the test above, not the model.
    @discardableResult
    func apply(_ body: (AuthViewModel) -> Void) -> AuthViewModel {
        body(self)
        return self
    }
}
