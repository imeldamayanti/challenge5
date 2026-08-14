import ContentKit
import DesignSystem
import RunEngine
import SwiftUI

struct KultaraRootView: View {

    private let environment: KultaraEnvironment

    @State private var language: ContentLanguage
    @State private var showsOnboarding: Bool
    @State private var selectedQuestID: String?
    @State private var runDestination: RunDestination?
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

    private enum Tab: String { case quests, settings }

    init(environment: KultaraEnvironment) {
        self.environment = environment
        _language = State(initialValue: LanguageResolver.resolve(
            override: environment.preferences.preferredLanguage))
        _showsOnboarding = State(initialValue: OnboardingGate.shouldPresentOnboarding(
            store: environment.preferences))
    }

    var body: some View {
        KultaraThemeProvider {
            if showsOnboarding {
                OnboardingView(
                    store: environment.preferences,
                    language: language,
                    onFinish: { showsOnboarding = false })
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
            if tab == Tab.settings.rawValue {
                NavigationStack { settingsDestination }
            } else {
                questsStack
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
        if runDestination != nil { return true }
        return false
    }

    private var tabs: [KultaraTab] {
        [KultaraTab(id: Tab.quests.rawValue,
                    title: UIStrings.string(.questListTitle, language),
                    symbolName: "map"),
         KultaraTab(id: Tab.settings.rawValue,
                    title: UIStrings.string(.settingsTitle, language),
                    symbolName: "gearshape")]
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
                onSelect: { selectedQuestID = $0 },
                onOpenRun: openRun)
                .navigationDestination(isPresented: Binding(
                    get: { selectedQuestID != nil },
                    set: { if !$0 { selectedQuestID = nil } })
                ) {
                    previewDestination
                }
                .navigationDestination(item: $runDestination) { destination in
                    runScreen(destination)
                }
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

    @ViewBuilder private var previewDestination: some View {
        if let questID = selectedQuestID {
            ScreenHost {
                QuestPreviewViewModel(
                    repository: environment.repository,
                    questID: questID,
                    language: language,
                    runEngine: environment.runEngine)
            } content: { model in
                KultaraThemeProvider {
                    QuestPreviewView(model: model)
                        .onAppear {
                            model.onBeginRun = { restart in
                                let draft = (try? environment.runStore.activeRun(questID: questID)) ?? nil
                                runDestination = RunDestination(
                                    questID: questID,
                                    existingRunID: restart ? nil : draft?.id,
                                    discardingExistingDraft: restart)
                            }
                        }
                }
            }
        } else {
            // A quest that cannot be built is not a blank screen; the list stays reachable.
            EmptyView()
        }
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
