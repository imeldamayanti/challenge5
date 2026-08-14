import ContentKit
import DesignSystem
import RunEngine
import SwiftUI

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
    /// The same run screen, reached from the Journal tab. A second piece of state rather than a
    /// shared one, because each tab owns its own navigation stack and a destination pushed on one
    /// cannot be popped by the other.
    @State private var journalRunDestination: RunDestination?
    /// Bumped whenever a walk changes, so the home screen's journal is rebuilt. The store is not
    /// observable — it is a protocol with a file behind it — and a counter is a smaller thing to
    /// own than an observation layer this milestone would use in exactly one place.
    @State private var journalRevision = 0

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

    init(environment: KultaraEnvironment) {
        self.environment = environment
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
        if runDestination != nil || journalRunDestination != nil { return true }
        return false
    }

    private var tabs: [KultaraTab] {
        [KultaraTab(id: Tab.quests.rawValue,
                    title: UIStrings.string(.questListTitle, language),
                    symbolName: "map"),
         KultaraTab(id: Tab.journal.rawValue,
                    title: WireframeCatalog.journal.title.value(for: language),
                    symbolName: "book"),
         KultaraTab(id: Tab.profile.rawValue,
                    title: WireframeCatalog.profile.title.value(for: language),
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
                onSelect: { startOrResumeRun(questID: $0) },
                onOpenRun: openRun)
                .navigationDestination(item: $runDestination) { destination in
                    runScreen(destination)
                }
        }
    }

    /// Home → Journal → visited places → trip summary. The visited places are real; the screens
    /// hung off them are wireframes.
    private var journalStack: some View {
        NavigationStack {
            JournalWireframeView(
                language: language,
                journal: journal,
                onOpenRun: { runID in
                    guard let run = (try? environment.runStore.run(id: runID)) ?? nil else { return }
                    journalRunDestination = RunDestination(
                        questID: run.questID, existingRunID: run.id, discardingExistingDraft: false)
                })
                .navigationDestination(item: $journalRunDestination) { destination in
                    runScreen(destination)
                }
        }
    }

    /// Home → Profile → Account settings → App preferences.
    private var profileStack: some View {
        NavigationStack {
            ProfileWireframeView(language: language) { settingsDestination }
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
                discardingExistingDraft: destination.discardingExistingDraft)
        } content: { model in
            KultaraThemeProvider { QuestRunView(model: model) }
                .onDisappear { journalRevision += 1 }
        }
    }

    private var settingsDestination: some View {
        let model = SettingsViewModel(
            repository: environment.repository,
            store: environment.preferences,
            language: language,
            locationAuthorization: environment.locationAuthorization,
            eraser: RunAndPreferencesDataEraser(
                store: environment.runStore, preferences: environment.preferences),
            storage: environment.storage)
        model.onLanguageChange = { language = $0 }
        return KultaraThemeProvider { SettingsView(model: model) }
    }
}
