import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

struct KultaraRootView: View {

    private let environment: KultaraEnvironment

    @State private var language: ContentLanguage
    @State private var showsOnboarding: Bool
    /// The two entry screens the app-flow chart opens with, neither of which is built. Held in
    /// `@State` rather than persisted: they are wireframes, and a persisted flag would mean the
    /// team has to clear app data to see them again. Both are one tap to get past.
    @State private var showsSplash = true
    @State private var showsAuth = true
    @State private var runDestination: RunDestination?
    /// The letter the Journal has opened, drawn full screen over the shelf.
    ///
    /// **Not a navigation destination.** Unsealing used to push `runScreen`, which handed the
    /// reader out to the museum summary after an animation that had just spent four seconds saying
    /// *this is a letter*. The letter now opens where it is: `JournalLetterView` renders the same
    /// snapshots as a page, and there is no stack to pop.
    @State private var journalLetter: SealedLetterPresentation?
    /// And a third, for the Profile tab's Quests list. Same argument as the one above it.
    @State private var profileRunDestination: RunDestination?
    /// Bumped whenever a walk changes, so the home screen's journal is rebuilt. The store is not
    /// observable — it is a protocol with a file behind it — and a counter is a smaller thing to
    /// own than an observation layer this milestone would use in exactly one place.
    @State private var journalRevision = 0
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
    }

    var body: some View {
        KultaraThemeProvider {
            // Splash → Onboarding → Login/Register → Home, as the flow chart opens. The first and
            // third of those are wireframes; only onboarding is a built screen.
            if showsSplash {
                SplashWireframeView(language: language, onFinish: { showsSplash = false })
            } else if showsOnboarding {
                OnboardingView(
                    store: environment.preferences,
                    language: language,
                    onFinish: { showsOnboarding = false })
            } else if showsAuth {
                AuthWireframeView(language: language, onSkip: { showsAuth = false })
            } else {
                browser
            }
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
    }

    /// `nil` while a walk is in progress, which suppresses both entry paths at once — the nearby
    /// list's tap and, once `s3` lands, the notification's.
    private var sideQuestCover: Binding<SideQuestDestination?> {
        Binding(
            get: {
                guard runDestination == nil, journalLetter == nil else { return nil }
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
                model: QuestListViewModel(repository: environment.repository, language: language),
                mapModel: RegionMapViewModel(repository: environment.repository, language: language),
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
            language: language).rows
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
                    onOpenRun: { runID in
                        journalLetter = model.letters.first { $0.id == runID }
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
            if let letter = journalLetter {
                journalLetterScreen(letter)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 1.14)),
                        removal: .opacity.combined(with: .scale(scale: 0.97))))
            }
        }
        .animation(.easeOut(duration: 0.42), value: journalLetter)
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
                onClose: { journalLetter = nil })
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
                            questID: run.questID, existingRunID: run.id,
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
            questID: run.questID, existingRunID: run.id, discardingExistingDraft: false)
    }

    /// A quest tapped from the catalogue (or a map marker — they share this closure) goes straight
    /// into the run rather than through a browsing step first. An existing draft is picked up where
    /// it stands, never silently restarted: restarting a Run discards its progress, and the only
    /// place that discard was ever offered — the preview screen's resume/restart choice — no longer
    /// sits in front of it.
    private func startOrResumeRun(questID: String) {
        let draft = (try? environment.runStore.activeRun(questID: questID)) ?? nil
        runDestination = RunDestination(
            questID: questID, existingRunID: draft?.id, discardingExistingDraft: false)
    }

    private func runScreen(_ destination: RunDestination) -> some View {
        ScreenHost {
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
                photoStore: environment.photoStore)
        } content: { model in
            KultaraThemeProvider { QuestRunView(model: model) }
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
                preferences: environment.preferences),
            storage: environment.storage,
            proximityMonitor: environment.proximityMonitor)
        model.onLanguageChange = { language = $0 }
        return KultaraThemeProvider { SettingsView(model: model) }
    }
}
