import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

struct KultaraRootView: View {

    private let environment: KultaraEnvironment

    @Environment(\.scenePhase) private var scenePhase

    @State private var language: ContentLanguage
    @State private var showsOnboarding: Bool
    /// The splash the app-flow chart opens with, which is still a wireframe. Held in `@State`
    /// rather than persisted for exactly that reason: it is a drawing, and a persisted flag would
    /// mean the team has to clear app data to see it again. One tap gets past it.
    @State private var showsSplash = true
    /// Whether the entry screens still have something to ask (Figma `791:5145`, `791:5109`,
    /// `822:2235`).
    ///
    /// **Persisted, unlike the splash above.** These are built screens now, not drawings, and a
    /// form that asks a walker their name on every launch is a defect rather than a review aid.
    /// `AccountEntryGate` owns the reading; Settings → erase local data puts them back
    /// (`FR-SET-02`).
    @State private var showsAuth: Bool
    @State private var runDestination: RunDestination?
    /// The letter the Journal has opened, drawn full screen over the shelf.
    ///
    /// **Not a navigation destination.** Unsealing used to push `runScreen`, which handed the
    /// reader out to the museum summary after an animation that had just spent four seconds saying
    /// *this is a letter*. The letter now opens where it is: `JournalLetterView` renders the same
    /// snapshots as a page, and there is no stack to pop.
    @State private var journalLetter: SealedLetterPresentation?
    /// Which part of that letter it opened at — the paper the reader chose in the modal.
    @State private var journalLetterSection: JournalPaperPresentation.Kind = .summary
    /// The two papers, drawn over the shelf once the envelope has finished opening (`791:5551`).
    ///
    /// Held here rather than inside the Journal tab because the floating tab bar is published over
    /// the tab's own content: a modal underneath the bar is not a modal.
    @State private var journalPapers: SealedLetterPresentation?
    /// And a third, for the Profile tab's Quests list. Same argument as the one above it.
    @State private var profileRunDestination: RunDestination?
    /// The walk "See Journey Recap" is showing the Strava-style completion carousel for, before
    /// `openRecap` hands it on to the real Trip Summary. A `fullScreenCover`, same shape as
    /// `sideQuestCover` below — this flow arrives from outside the navigation stack the run screen
    /// was just popped off of.
    @State private var completionRecapRun: Run?
    /// Bumped whenever a walk changes, so the home screen's journal is rebuilt. The store is not
    /// observable — it is a protocol with a file behind it — and a counter is a smaller thing to
    /// own than an observation layer this milestone would use in exactly one place.
    @State private var journalRevision = 0
    /// `c2` phase 7. True when a restore was attempted and the read did not land. Shown rather than
    /// swallowed: a walker looking at an empty Journal cannot tell "you had nothing" from "we could
    /// not fetch it", and only the second is recoverable by trying again.
    @State private var restoreFailed = false
    /// Which sidequest to present, set by the nearby list, by a notification tap, and by a
    /// foreground region entry (`s3`). Owned by `challange_5App` and handed down, because the
    /// notification delegate and `SystemProximityMonitor.onSideQuestNearby` both have to reach it
    /// from outside this view's hierarchy.
    ///
    /// A full-screen cover over whatever tab is showing, because a sidequest arrives from *outside*
    /// the navigation stacks — a notification tap has no stack to push onto (PRD §5.15).
    private let router: SideQuestRouter
    /// The collection reached from the Journal tab, or from the letter screen.
    @State private var collectionDestination: String?
    /// Whether the Profile tab has pushed App preferences. A boolean rather than an item, because
    /// there is exactly one preferences screen and nothing to identify.
    @State private var showsPreferences = false
    /// Bumped when a sidequest record changes, so the collection and the nearby list are rebuilt
    /// for the same reason `journalRevision` exists.
    @State private var sideQuestRevision = 0

    /// Which walk the run screen should open, and whether an existing draft is being replaced.
    private struct RunDestination: Identifiable, Hashable {
        let id = UUID()
        let questID: String
        let existingRunID: UUID?
        let discardingExistingDraft: Bool
        /// Whether this walk opens on a story stage, decided by whoever already holds the Run.
        /// `runScreen` needs it before `ScreenHost` has built the view model, so the placeholder
        /// hides the museum bar rather than letting it appear for a frame and vanish under the
        /// story preview.
        let opensOnStoryFlow: Bool

        init(questID: String, existingRun: Run?, discardingExistingDraft: Bool) {
            self.questID = questID
            self.existingRunID = existingRun?.id
            self.discardingExistingDraft = discardingExistingDraft
            self.opensOnStoryFlow = QuestRunViewModel.opensOnStoryFlow(existingRun: existingRun)
        }
    }
    /// The floating bar's selection. Two destinations is what the app has in M5; the bar exists
    /// because the Home design puts one there, and because a settings screen reached only from a
    /// gear in a bar has nowhere to live once the bar is gone.
    @State private var tab = Tab.quests.rawValue
    /// Which surface the quests tab is showing. Held here, not inside `QuestListView`, because the
    /// bar below is drawn by this view and the map is the one screen that wants it gone.
    @State private var questSurface = QuestListView.Surface.list

    /// The three branches the flow chart draws out of Home. Settings is no longer a tab of its
    /// own: the chart reaches it as Profile → Account settings → App preferences, and it is still
    /// two taps away.
    private enum Tab: String { case quests, journal, profile }

    init(environment: KultaraEnvironment, router: SideQuestRouter) {
        self.environment = environment
        self.router = router
        _language = State(initialValue: LanguageResolver.resolve(
            override: environment.preferences.preferredLanguage))
        _showsOnboarding = State(initialValue: OnboardingGate.shouldPresentOnboarding(
            store: environment.preferences))
        _showsAuth = State(initialValue: AccountEntryGate.shouldPresentEntry(
            store: environment.preferences))
    }

    var body: some View {
        KultaraThemeProvider {
            // Splash → Onboarding → Sign up / Sign in / Guest → Home, as the flow chart opens.
            // The splash is still a wireframe; onboarding and the three entry screens are built.
            if showsSplash {
                SplashWireframeView(language: language, onFinish: { showsSplash = false })
            } else if showsOnboarding {
                OnboardingView(
                    store: environment.preferences,
                    language: language,
                    onFinish: { showsOnboarding = false })
            } else if showsAuth {
                // The flow chart's login node, built rather than drawn — but **not a gate**: every
                // flow works without it. Apple is wired to `c2` phase 6's `CredentialLinking`;
                // email/password and guest stay local-profile-only, per `AuthViewModel`'s own
                // account of why. `AuthWireframeView` and `CredentialView` are both gone; this is
                // the one screen left standing where two were built in parallel.
                AuthView(
                    store: environment.preferences,
                    credentials: environment.credentials,
                    language: language,
                    onFinish: {
                        showsAuth = false
                        // Covers every path that reaches here, not only a merge: harmless to bump
                        // for a local guest profile too, and simpler than threading the outcome
                        // back out through `onFinish`'s empty signature. A merge moves the rows on
                        // the server; this device's copy is unchanged, so nothing needs re-reading
                        // here — a restore on the *next* launch is what brings them to another
                        // phone (`c2` phase 7).
                        journalRevision += 1
                    })
            } else {
                browser
            }
        }
        // `AD-5` — one attempt on launch and one on every foreground, and neither blocks a draw.
        // The document the app already holds was read from disk at construction, so this updates an
        // answer rather than producing one (`FR-ERR-09`).
        .task {
            // `c2` phase 1. Fire-and-forget on purpose: `prepare()` returns before the network is
            // touched, so the session arrives when it arrives and the quest list never waits for
            // it. A walker who is offline forever simply never has one.
            (environment.session as? SupabaseSession)?.prepare()
            await refreshGovernance()
            // `c2` phase 7. After the session, because there is nothing to read without one, and
            // only ever into an empty store — the restorer checks that itself, immediately before
            // it reads, so a walk started in between is still seen.
            await restoreWalksIfThisDeviceHasNone()
        }
        // `c2` phase 7. The one thing a restore is allowed to put on screen, and only when it
        // failed: a walker cannot tell an empty Journal that is theirs from one that is a failed
        // fetch, and only the second is worth trying again. The retry needs no sign-out.
        .alert(
            UIStrings.text(.restoreFailedTitle).value(for: language),
            isPresented: $restoreFailed
        ) {
            Button(UIStrings.text(.restoreRetryAction).value(for: language)) {
                Task { await restoreWalksIfThisDeviceHasNone() }
            }
            Button(
                UIStrings.text(.restoreDismissAction).value(for: language),
                role: .cancel) {}
        } message: {
            Text(UIStrings.text(.restoreFailedBody).value(for: language))
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                (environment.session as? SupabaseSession)?.prepare()
                Task { await refreshGovernance() }
                // Opportunistic, never on a timer and never on a transition somebody is waiting
                // for (`NFR-BAT-04`'s reputation, if not its letter).
                environment.telemetry.flush()
                // `c2` phase 3. Foreground is one of three triggers — the others are completing a
                // walk and abandoning one, both raised by `QuestRunViewModel`. Never during arrival,
                // lore or a task: those are the moments a walker is waiting for a screen.
                Task { await environment.sync.push() }
            case .background:
                environment.telemetry.flush()
            default:
                break
            }
        }
    }

    /// `c2` phase 7. A device with no walks asks whether this walker has any elsewhere.
    ///
    /// Nothing waits on this and nothing is shown while it runs. **A failure is not silent
    /// though** — see `RestoreOutcome.succeeded`: a walker cannot tell "you had nothing" from "we
    /// could not fetch it", and only the second is worth trying again.
    private func restoreWalksIfThisDeviceHasNone() async {
        guard let outcome = await environment.restore.restoreIfLocalStoreIsEmpty() else { return }
        if outcome.restoredRuns > 0 {
            journalRevision += 1
        }
        restoreFailed = !outcome.succeeded
    }

    /// One kill-switch refresh, and everything that has to follow it.
    ///
    /// Nothing here can fail in a way the walker sees: a refresh that does not land keeps the last
    /// good document, and every step below then re-applies what was already applied.
    private func refreshGovernance() async {
        await environment.governance.refresh()
        // Regions outlive the screen that registered them, so the monitor is told directly rather
        // than being handed a set at a call site (`FR-SIDE-14`).
        environment.proximityMonitor.suppressedSideQuestIDs =
            environment.governance.suppressedSideQuestIDs
        environment.proximityMonitor.suppressedPlaceIDs =
            environment.governance.suppressedPlaceIDs
        environment.proximityMonitor.refreshRegions()
        abandonSuppressedRuns()
    }

    /// A walk whose ground has been withdrawn under it ends as `placeSuppressed` rather than
    /// carrying on to a checkpoint that must not be visited (`AD-5`).
    ///
    /// **Active walks only.** A finished walk renders from snapshots taken at completion — its lore,
    /// place names and citations were copied into the Run — and suppression must never reach into a
    /// summary of something that already happened.
    private func abandonSuppressedRuns() {
        guard let runs = try? environment.runStore.runs() else { return }
        let engine = environment.runEngine
        for run in runs where run.state == .active {
            guard let quest = (try? environment.repository.quest(id: run.questID)) ?? nil else {
                continue
            }
            guard environment.governance.suppresses(
                questID: run.questID, placeIDs: quest.checkpoints.map(\.placeId))
            else { continue }
            guard (try? engine.abandon(runID: run.id, reason: .placeSuppressed)) != nil else {
                continue
            }
            environment.telemetry.questAbandoned(
                questID: run.questID,
                lastOrderIndex: run.orderedCheckpointResults.last?.orderIndex ?? -1,
                reason: AbandonReason.placeSuppressed.rawValue,
                runID: run.id)
            // The screen showing that walk has to go with it. Leaving it up would be a run screen
            // driving a Run the store now calls abandoned.
            if runDestination?.existingRunID == run.id { runDestination = nil }
            if profileRunDestination?.existingRunID == run.id { profileRunDestination = nil }
            journalRevision += 1
        }
    }

    private var browser: some View {
        // The bar is drawn rather than taken from `TabView`, and it is attached as a safe-area
        // inset rather than stacked on top: the inset reserves exactly the height the bar actually
        // has, so a bar whose labels have grown at an accessibility size cannot end up sitting on
        // the last card. The full-bleed map ignores the safe area and still runs underneath it.
        Group {
            switch Tab(rawValue: tab) ?? .quests {
            case .quests: questsStack
            case .journal: journalStack
            case .profile: profileStack
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // The map is a full-bleed illustration the reader pinches and drags edge to edge, and
            // it carries its own way back. A floating bar over it both covers artwork and puts
            // buttons under the fingers doing the panning, so on that surface there is no bar and
            // the inset reserves nothing.
            if !hidesTabBar {
                // The bar opts out of keyboard avoidance; the content above it does not. SwiftUI
                // raises the bottom safe area when a field takes focus, and inset content laid out
                // against it rides up and sits on the keyboard. The modifier belongs here, on the
                // bar alone — putting it on the container would also stop the screen beneath from
                // moving, which would leave the task-answer fields in `TaskCard` under the keyboard.
                KultaraTabBar(tabs: tabs, selection: $tab)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        // `FR-SIDE-01`, `FR-PROX-08` — belt to `ProximityGate`'s braces. A walker mid-quest is
        // engaged, and interrupting them is the exact thing the requirement forbids; the gate that
        // decides whether an alert is *sent* is `s3`'s, and this is the one that decides whether a
        // flow is ever *presented*.
        .fullScreenCover(item: sideQuestCover) { destination in
            sideQuestFlow(destination.id)
        }
        .fullScreenCover(item: $completionRecapRun) { run in
            completionRecapScreen(for: run)
        }
    }

    /// `nil` while a walk is in progress, which suppresses both entry paths at once — the nearby
    /// list's tap and, once `s3` lands, the notification's.
    private var sideQuestCover: Binding<SideQuestDestination?> {
        Binding(
            get: {
                guard runDestination == nil, journalLetter == nil, journalPapers == nil,
                      completionRecapRun == nil
                else { return nil }
                return router.pendingSideQuestID.map(SideQuestDestination.init)
            },
            set: { if $0 == nil { router.pendingSideQuestID = nil } })
    }

    private struct SideQuestDestination: Identifiable, Hashable {
        let id: String
    }

    private var hidesTabBar: Bool {
        // The full-bleed map carries its own way back, and a floating bar over it both covers
        // artwork and puts buttons under the panning fingers.
        if tab == Tab.quests.rawValue && questSurface == .map { return true }
        // A walk in progress is a full-screen flow with its own controls at the foot — the story
        // preview's "Ready to Explore", the arrival screen's override, the cutscene's "Start the
        // Journey". The bar sits on top of every one of them, which is the same defect QA reported
        // against the keyboard: a floating bar covering the control the screen is asking for.
        // Switching tabs mid-walk is not an interaction the run flow offers anyway.
        if runDestination != nil { return true }
        // The opened letter is a full-screen page drawn inside the Journal's own stack rather than
        // a modal over it, so nothing else takes the bar away.
        if journalLetter != nil { return true }
        // And the papers are a modal over the whole screen, scrim included (`791:5555` draws the
        // bar hidden).
        if journalPapers != nil { return true }
        return false
    }

    private var tabs: [KultaraTab] {
        [KultaraTab(id: Tab.quests.rawValue,
                    title: UIStrings.string(.questListTitle, language),
                    symbolName: "map"),
         KultaraTab(id: Tab.journal.rawValue,
                    title: UIStrings.string(.tabJournal, language),
                    symbolName: "book"),
         KultaraTab(id: Tab.profile.rawValue,
                    title: UIStrings.string(.tabProfile, language),
                    symbolName: "person.crop.circle")]
    }

    private var questsStack: some View {
        NavigationStack {
            QuestListView(
                // Rebuilt when the language changes: every string in the list is resolved at
                // construction, so the identity of the view model *is* the language.
                // `AD-5` — the kill-switch's whole point is that a withdrawn place stops being
                // offered. The sets are read here, in the body, so a document that arrives on a
                // foreground rebuilds both surfaces without anything polling for it.
                model: QuestListViewModel(
                    repository: environment.repository,
                    language: language,
                    suppressedQuestIDs: environment.governance.suppressedQuestIDs,
                    suppressedPlaceIDs: environment.governance.suppressedPlaceIDs),
                mapModel: RegionMapViewModel(
                    repository: environment.repository,
                    language: language,
                    suppressedQuestIDs: environment.governance.suppressedQuestIDs,
                    suppressedPlaceIDs: environment.governance.suppressedPlaceIDs),
                surface: $questSurface,
                journal: journal,
                // `FR-SIDE-07` — a way into a sidequest that does not wait for a notification.
                nearby: nearbySideQuests,
                makeLocationProvider: environment.makeLocationProvider,
                onSelect: { startOrResumeRun(questID: $0) },
                onOpenRun: openRun,
                onOpenSideQuest: { router.pendingSideQuestID = $0 })
                .navigationDestination(item: $runDestination) { destination in
                    runScreen(destination)
                }
        }
    }

    private var nearbySideQuests: [NearbySideQuestRow] {
        // Read so the list is recomputed when a sidequest record changes.
        _ = sideQuestRevision
        return NearbySideQuestListViewModel(
            repository: environment.repository,
            engine: environment.sideQuestEngine,
            language: language,
            // `FR-SIDE-14` — a withdrawn sidequest, or one standing at a withdrawn place,
            // disappears from every surface.
            suppressedSideQuestIDs: environment.governance.suppressedSideQuestIDs,
            suppressedPlaceIDs: environment.governance.suppressedPlaceIDs).rows
    }

    private func sideQuestFlow(_ sideQuestID: String) -> some View {
        ScreenHost {
            SideQuestFlowViewModel(
                engine: environment.sideQuestEngine,
                repository: environment.repository,
                locationProvider: environment.makeLocationProvider(),
                photoStore: environment.photoStore,
                sideQuestID: sideQuestID,
                language: language)
        } content: { model in
            KultaraThemeProvider {
                SideQuestFlowView(
                    model: model,
                    onFinish: { router.pendingSideQuestID = nil },
                    onOpenCollection: { collectionID in
                        router.pendingSideQuestID = nil
                        tab = Tab.journal.rawValue
                        collectionDestination = collectionID
                    })
            }
            .onDisappear {
                sideQuestRevision += 1
                // `system-design.md` §6.2 — a completed sidequest deregisters its own region
                // (`FR-PROX-12` equivalent) and the budget it frees may seat another candidate.
                // Cheap and idempotent, so this runs on every close rather than only a completed
                // one.
                environment.proximityMonitor.refreshRegions()
            }
        }
    }

    /// Home → Journal, which is now "Sealed Letters" (Figma `332:1607`) rather than a wireframe:
    /// a shelf of envelopes, one per walk, that open onto the walk itself.
    ///
    /// The Journal's own navigation bar is hidden. The shelf is a Hisplora surface drawn edge to
    /// edge on a brown ground, the same rule `QuestRunView.isOnStoryFlow` follows — museum chrome
    /// over that ground is the contrast bug `RunRouteMapView.showsChrome` exists to prevent.
    private var journalStack: some View {
        NavigationStack {
            ScreenHost {
                SealedLettersViewModel(
                    store: environment.runStore,
                    repository: environment.repository,
                    language: language)
            } content: { model in
                SealedLettersView(
                    model: model,
                    language: language,
                    collections: collectionIDs,
                    onOpenPapers: { runID in
                        journalPapers = model.letters.first { $0.id == runID }
                    },
                    onOpenCollection: { collectionDestination = $0 })
            }
            .toolbar(.hidden, for: .navigationBar)
            // `FR-SIDE-08` — the collection lives in the Journal tab. It stays museum: it is a
            // catalogue, and the seam between the two directions falls between whole screens.
            .navigationDestination(item: $collectionDestination) { collectionID in
                collectionScreen(collectionID)
            }
        }
        // **An overlay, not a `fullScreenCover`.** A cover slides up from the bottom, and the beat
        // before it is a page zooming *toward* the reader — so the opening ended by throwing the
        // page away and sliding a different one in from somewhere else. Drawn here, the letter
        // picks the zoom up where it stopped: it enters a little over-size and settles, which is
        // the same motion the envelope's last beat was making.
        .overlay {
            if let letter = journalPapers {
                JournalPapersModal(
                    letter: letter,
                    language: language,
                    onOpen: { kind in
                        journalLetterSection = kind
                        journalLetter = letter
                        journalPapers = nil
                    },
                    onClose: { journalPapers = nil })
                    // The papers arrive over-size and settle, picking up the zoom the envelope's
                    // last beat was already making rather than sliding in from an edge.
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.18)),
                        removal: .opacity.combined(with: .scale(scale: 0.96))))
            }
        }
        .overlay {
            if let letter = journalLetter {
                journalLetterScreen(letter)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.14)),
                        removal: .opacity.combined(with: .scale(scale: 0.97))))
            }
        }
        .animation(.easeOut(duration: 0.42), value: journalLetter)
        .animation(.easeOut(duration: 0.42), value: journalPapers)
    }

    /// The opened letter, full screen and scrollable.
    ///
    /// Built from the Run rather than from the shelf's own row: the page prints the walk's lore
    /// snapshots, its written answers and its pinned content version, none of which a card on a
    /// shelf carries. A Run that has gone — erased from another screen while this one was open —
    /// closes the cover rather than drawing an empty page.
    @ViewBuilder private func journalLetterScreen(_ letter: SealedLetterPresentation) -> some View {
        if let run = (try? environment.runStore.run(id: letter.id)) ?? nil {
            JournalLetterView(
                model: RunSummaryViewModel(run: run),
                letter: letter,
                section: journalLetterSection,
                photoStore: environment.photoStore,
                shareCards: environment.shareCards,
                // Back to the papers, not out to the shelf. The two pages are reached *through*
                // `791:5551`, so the way back from one is the choice that opened it — a reader who
                // finished the summary and wants the history should not have to unseal the envelope
                // again to get at it.
                onClose: {
                    journalLetter = nil
                    journalPapers = letter
                })
        } else {
            Color.clear.onAppear { journalLetter = nil }
        }
    }

    private var collectionIDs: [(id: String, title: String)] {
        _ = sideQuestRevision
        return ((try? environment.repository.collections()) ?? []).map {
            (id: $0.id, title: $0.title.value(for: language))
        }
    }

    private func collectionScreen(_ collectionID: String) -> some View {
        ScreenHost {
            LetterCollectionViewModel(
                engine: environment.sideQuestEngine,
                repository: environment.repository,
                language: language,
                collectionID: collectionID)
        } content: { model in
            KultaraThemeProvider {
                LetterCollectionView(
                    model: model,
                    language: language,
                    // `FR-SIDE-07` — an unearned slot opens its sidequest from here, without
                    // waiting for a notification.
                    onOpenSideQuest: { router.pendingSideQuestID = $0 })
            }
        }
    }

    /// Home → Profile, which is now the Explorer's Card (Figma `547:2724`) rather than a
    /// wireframe. The chart's "Account settings" node between it and App preferences is gone with
    /// its wireframe: the card is a real screen and the design gives it one control, which goes
    /// straight to the preferences that exist.
    private var profileStack: some View {
        NavigationStack {
            ScreenHost {
                ExplorerCardViewModel(
                    runStore: environment.runStore,
                    sideQuestStore: environment.sideQuestStore,
                    repository: environment.repository,
                    preferences: environment.preferences,
                    language: language)
            } content: { model in
                ExplorerCardView(
                    model: model,
                    language: language,
                    onOpenPreferences: { showsPreferences = true },
                    // The same hand-off the Journal's envelopes make, from the other tab: a walk
                    // listed as unfinished is picked up where it was left.
                    onResumeRun: { runID in
                        guard let run = (try? environment.runStore.run(id: runID)) ?? nil else { return }
                        profileRunDestination = RunDestination(
                            questID: run.questID, existingRun: run,
                            discardingExistingDraft: false)
                    })
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $profileRunDestination) { destination in
                runScreen(destination)
            }
            .navigationDestination(isPresented: $showsPreferences) { settingsDestination }
        }
    }

    private var journal: RunJournalSummary {
        // `journalRevision` is read so the value is recomputed when a walk changes.
        _ = journalRevision
        return RunJournalSummary(store: environment.runStore, language: language)
    }

    private func openRun(_ runID: UUID) {
        guard let run = (try? environment.runStore.run(id: runID)) ?? nil else { return }
        runDestination = RunDestination(
            questID: run.questID, existingRun: run, discardingExistingDraft: false)
    }

    /// A quest tapped from the catalogue (or a map marker — they share this closure) goes straight
    /// into the run rather than through a browsing step first. An existing draft is picked up where
    /// it stands, never silently restarted: restarting a Run discards its progress, and the only
    /// place that discard was ever offered — the preview screen's resume/restart choice — no longer
    /// sits in front of it.
    private func startOrResumeRun(questID: String) {
        let draft = (try? environment.runStore.activeRun(questID: questID)) ?? nil
        runDestination = RunDestination(
            questID: questID, existingRun: draft, discardingExistingDraft: false)
    }

    /// "See Journey Recap" (`JourneySavedScreen`) no longer jumps straight to the Journal — it opens
    /// the Strava-style completion carousel first (`TripRecapCarouselScreen`), whose own finish is
    /// what now does the jump `openRecap` used to do directly.
    private func openRecap(for run: Run) {
        runDestination = nil
        completionRecapRun = run
    }

    /// The carousel's own "Skip"/"Close Summary" (`921:2867`): the papers picker — "Modal Cerita"
    /// (`921:2346`), this app's own `JournalPapersModal` — over the Journal letter this Run already
    /// has a shelf entry for, built the same way `SealedLettersViewModel` builds every other one
    /// rather than by a second, parallel path.
    ///
    /// Reuses `SealedLettersViewModel`'s own builder instead of duplicating it: stamp tiering
    /// (`StampArtworkResolver`) counts finished walks *per place*, which is a fact about every Run,
    /// not just this one, so a hand-rolled `SealedLetterPresentation` here could tier a stamp
    /// differently from the one the shelf itself would show for the same walk.
    private func finishCompletionRecap(for run: Run) {
        completionRecapRun = nil
        let letters = SealedLettersViewModel(
            store: environment.runStore, repository: environment.repository, language: language)
        guard let letter = letters.letters.first(where: { $0.id == run.id }) else { return }
        journalPapers = letter
        tab = Tab.journal.rawValue
    }

    /// The carousel's own data, assembled here rather than inside the screen: `RunSummaryViewModel`
    /// deliberately holds no `ContentRepository`, and the stamp collage needs one to resolve a
    /// region and a place's tiered artwork (`StampArtworkResolver`) — the same reason
    /// `ExplorerCardViewModel` builds its stamps where a repository is already in scope.
    private func completionRecapScreen(for run: Run) -> some View {
        let runs = (try? environment.runStore.runs()) ?? []
        let region = (try? environment.repository.quest(id: run.questID))??.region ?? ""
        let resolver = StampArtworkResolver(runs: runs, repository: environment.repository)
        let stamps = run.awards
            .filter { $0.type == .stamp }
            .map { award in
                TripRecapStampPresentation(
                    id: "\(run.id)-\(award.sourceID)",
                    placeName: award.snapshotName,
                    region: region,
                    artworkName: resolver.artworkName(
                        questID: run.questID, stampSourceID: award.sourceID))
            }
        return TripRecapCarouselScreen(
            language: language,
            summary: RunSummaryViewModel(run: run),
            completedQuestsCount: runs.filter { $0.state == .completed }.count,
            region: region,
            stamps: stamps,
            photoStore: environment.photoStore,
            onFinish: { finishCompletionRecap(for: run) })
    }

    private func runScreen(_ destination: RunDestination) -> some View {
        ScreenHost(navigationBarWhileLoading: destination.opensOnStoryFlow ? .hidden : .automatic) {
            let existing = destination.existingRunID
                .flatMap { (try? environment.runStore.run(id: $0)) ?? nil }
            return QuestRunViewModel(
                engine: environment.runEngine,
                repository: environment.repository,
                preferences: environment.preferences,
                locationProvider: environment.makeLocationProvider(),
                questID: destination.questID,
                language: language,
                existingRun: existing,
                discardingExistingDraft: destination.discardingExistingDraft,
                // `1:4827`'s photograph. The same store the sidequest photo challenge writes to and
                // the same one "delete all local data" empties (`FR-SET-02`), so a quest photo is
                // not a fourth aggregate the eraser would have to learn about.
                photoStore: environment.photoStore,
                telemetry: environment.telemetry,
                sync: environment.sync)
        } content: { model in
            KultaraThemeProvider {
                QuestRunView(model: model, onOpenRecap: openRecap)
            }
                .onDisappear {
                    journalRevision += 1
                    // `system-design.md` §6.2 — a completed quest deregisters its start region;
                    // cheap and idempotent, so this runs on every close rather than only a
                    // completed one.
                    environment.proximityMonitor.refreshRegions()
                }
        }
    }

    private var settingsDestination: some View {
        let model = SettingsViewModel(
            repository: environment.repository,
            store: environment.preferences,
            language: language,
            locationAuthorization: environment.locationAuthorization,
            // `FR-SET-02` — Runs, sidequest records, proximity alert rows, *and* photo files. Four
            // separate aggregates (`FR-SIDE-01`, `s3` §2, `s4` §7), so the eraser has to name all
            // four or something survives "delete all local data".
            eraser: RunAndPreferencesDataEraser(
                store: environment.runStore,
                sideQuestStore: environment.sideQuestStore,
                proximityMonitor: environment.proximityMonitor,
                photoStore: environment.photoStore,
                telemetry: environment.telemetry,
                session: environment.session,
                accountDeleter: environment.accountDeleter,
                syncState: environment.syncState,
                preferences: environment.preferences),
            storage: environment.storage,
            proximityMonitor: environment.proximityMonitor)
        model.onLanguageChange = { language = $0 }
        return KultaraThemeProvider { SettingsView(model: model) }
    }
}
