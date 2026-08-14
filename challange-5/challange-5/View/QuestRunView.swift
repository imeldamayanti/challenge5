import ContentKit
import DesignSystem
import RunEngine
import SwiftUI

/// The whole walking loop on one screen, changing what it shows as the Run moves through its
/// stages: the two notices that precede the first step, the arrival screen, the checkpoint, and the
/// summary at the end.
///
/// One screen rather than four pushed views, because the walker's position in the quest is the
/// navigation. A stack would let them back out of a checkpoint into an arrival screen for a place
/// they are already standing at.
struct QuestRunView: View {
    @Environment(\.kultaraPalette) private var palette
    @Bindable private var model: QuestRunViewModel

    init(model: QuestRunViewModel) {
        self.model = model
    }

    private var language: ContentLanguage { model.language }

    /// The story-flow stages carry their own heading and their own back control, on their own
    /// ground. The museum navigation bar over them is cream on brown and it clips the eyebrow
    /// underneath it, so on those stages it goes away entirely.
    private var isOnStoryFlow: Bool {
        switch model.stage {
        case .storyPreview, .awaitingArrival, .cutsceneIntro, .cutscenePortrait,
             .storyReveal, .placeNotice, .checkpointDetail, .transition:
            true
        case .safetyNotice, .locationNotice, .atCheckpoint, .finished:
            false
        }
    }

    var body: some View {
        content
            .background(palette.paper.color)
            .navigationTitle(isOnStoryFlow ? "" : model.quest.title.value(for: language))
            .kultaraInlineNavigationTitle()
            .toolbar(isOnStoryFlow ? .hidden : .visible, for: .navigationBar)
            .onAppear { model.screenAppeared() }
            .onDisappear { model.screenDisappeared() }
            // `FR-START-09` — the named presence confirmation.
            .kultaraDialog(
                isPresented: Binding(get: { model.isConfirmingPresence },
                                     set: { if !$0 { model.cancelPresenceConfirmation() } }),
                title: model.presenceConfirmationTitle,
                message: UIStrings.string(.runStartConfirmBody, language),
                actions: [
                    KultaraDialogAction(
                        title: UIStrings.string(.runStartConfirmYes, language),
                        kind: .confirm) { model.confirmPresence() },
                    KultaraDialogAction(
                        title: UIStrings.string(.runCancel, language),
                        kind: .cancel) { model.cancelPresenceConfirmation() },
                ])
            // `FR-RUN-04` — the confirmation names what is kept and what is lost.
            .kultaraDialog(
                isPresented: Binding(get: { model.isConfirmingAbandon },
                                     set: { if !$0 { model.cancelAbandon() } }),
                title: UIStrings.string(.runAbandonConfirmTitle, language),
                message: UIStrings.string(.runAbandonConfirmBody, language),
                actions: [
                    KultaraDialogAction(
                        title: UIStrings.string(.runAbandonConfirmAction, language),
                        kind: .destructive) { model.confirmAbandon() },
                    KultaraDialogAction(
                        title: UIStrings.string(.runCancel, language),
                        kind: .cancel) { model.cancelAbandon() },
                ])
            .sheet(isPresented: Binding(get: { model.isPresentingManualOverride },
                                        set: { if !$0 { model.dismissManualOverride() } })) {
                KultaraThemeProvider { manualOverrideSheet }
                    .kultaraManualOverrideSheetPresentation()
            }
    }

    @ViewBuilder private var content: some View {
        switch model.stage {
        case .storyPreview: storyPreview
        case .safetyNotice: safetyNotice
        case .locationNotice: locationNotice
        case .awaitingArrival: arrivalScreen
        case .cutsceneIntro: cutsceneIntro
        case .cutscenePortrait: cutscenePortrait
        case .storyReveal: storyReveal
        case .placeNotice: placeNotice
        case .checkpointDetail: checkpointDetail
        case .transition: transition
        case .atCheckpoint: checkpointScreen
        case .finished: finishedScreen
        }
    }

    // MARK: The Hisplora story stages
    //
    // Each is a `HisploraStage` of its own, so the story flow carries the new visual direction
    // while the quest list, settings and summary stay on the museum theme until frames exist for
    // them. A seam at a screen boundary is survivable; a half-restyled screen is not.

    private var storyPreview: some View {
        StoryPreviewScreen(
            language: language,
            title: model.questTitle,
            hook: model.hookText,
            distanceText: model.routeDistanceText,
            durationText: model.routeDurationText,
            portraitURL: model.cutsceneImageURL,
            onReady: { model.advanceFromStoryPreview() },
            onBack: { model.advanceFromStoryPreview() })
    }

    private var cutsceneIntro: some View {
        CutsceneIntroScreen(
            language: language,
            portraitURL: model.cutsceneImageURL,
            portraitLabel: model.questTitle,
            onAdvance: { model.advanceFromCutsceneIntro() },
            onBack: { model.retreatFromStoryStage() })
    }

    private var cutscenePortrait: some View {
        CutscenePortraitScreen(
            language: language,
            portraitURL: model.cutsceneImageURL,
            portraitLabel: model.questTitle,
            title: model.questTitle,
            subtitle: model.currentPlaceName,
            hook: model.hookText,
            onStart: { model.advanceFromCutscenePortrait() },
            onBack: { model.retreatFromStoryStage() })
    }

    private var storyReveal: some View {
        StoryRevealScreen(
            language: language,
            text: model.storyRevealText,
            // The content tree ships no per-place illustration, so this stays nil — the screen
            // falls back to its own packaged art (`StoryIllustrationMetrics`). See the note atop
            // `StoryRevealScreen`.
            illustrationURL: nil,
            onFinish: { model.advanceFromStoryReveal() },
            onBack: { model.retreatFromStoryStage() })
    }

    @ViewBuilder private var placeNotice: some View {
        if let checkpoint = model.checkpoint {
            PlaceNoticeScreen(
                language: language,
                placeName: checkpoint.placeName,
                description: checkpoint.placeDescription,
                isSacred: checkpoint.isSacred,
                dressCodeText: checkpoint.dressCodeText,
                photoPolicyText: checkpoint.photoPolicyText,
                portraitURL: model.cutsceneImageURL,
                onAcknowledge: { model.advanceFromPlaceNotice() },
                onBack: { model.retreatFromStoryStage() })
        } else {
            EmptyView()
        }
    }

    @ViewBuilder private var checkpointDetail: some View {
        if let checkpoint = model.checkpoint {
            CheckpointDetailScreen(
                language: language,
                placeName: checkpoint.placeName,
                tasks: checkpoint.tasks,
                taskPrompts: checkpoint.taskPrompts,
                onContinue: { model.advanceFromCheckpointDetail() },
                onBack: { model.retreatFromStoryStage() })
        } else {
            EmptyView()
        }
    }

    private var transition: some View {
        StoryTransitionScreen(
            language: language,
            questName: model.questTitle,
            placeName: model.currentPlaceName,
            route: model.routeMap,
            totalCheckpoints: model.totalCheckpoints,
            onContinue: { model.advanceFromTransition() })
    }

    // MARK: Preflight

    /// `NFR-SAFE-03` — traffic, pavements, and the pocket-the-phone model, acknowledged before the
    /// first Run of this quest.
    private var safetyNotice: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                KultaraEyebrow(UIStrings.string(.previewSafetyHeading, language))
                Text(UIStrings.string(.runStartSafetyTitle, language))
                    .kultaraFont(.questTitleLarge)
                    .foregroundStyle(palette.ink.color)
                    .accessibilityAddTraits(.isHeader)
                Text(model.safetyNotes)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(UIStrings.string(.onboardingPocketBody, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                Button(UIStrings.string(.runStartSafetyAck, language)) {
                    model.acknowledgeSafetyNotice()
                }
                .buttonStyle(.seal)
            }
            .padding(KultaraMetrics.lg)
            .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
        }
    }

    /// `FR-START-02` — the explanation comes before the system prompt, never after it.
    private var locationNotice: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                KultaraEyebrow(UIStrings.string(.settingsLocationHeading, language))
                Text(UIStrings.string(.runStartLocationTitle, language))
                    .kultaraFont(.questTitleLarge)
                    .foregroundStyle(palette.ink.color)
                    .accessibilityAddTraits(.isHeader)
                Text(UIStrings.string(.runStartLocationBody, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                Button(UIStrings.string(.runStartLocationContinue, language)) {
                    model.acknowledgeLocationNoticeAndRequestPermission()
                }
                .buttonStyle(.seal)
            }
            .padding(KultaraMetrics.lg)
            .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
        }
    }

    // MARK: Arrival

    /// The arrival screen, on the Hisplora direction — frames `81:617`, `89:1402` and `223:2004`,
    /// which are the three states this screen already had.
    ///
    /// The frames' heading and ground are the design's; the clue, the manual override and the
    /// abandon control are not on any of them and are here anyway, because `FR-CP-03`,
    /// `FR-START-10` and `FR-RUN-04` require them. Order follows Phase 1: the status first, because
    /// QA landed on this screen without noticing it was doing anything at all.
    private var arrivalScreen: some View {
        HisploraStage(ground: \.brownMid) {
            ScrollView {
                VStack(spacing: KultaraMetrics.xl) {
                    // `FR-CP-08` — checkpoints reached out of total, never a distance.
                    Text(model.stepText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(hisplora.inkDusty.color)
                        .textCase(.uppercase)
                        .tracking(1.5)
                    LocationStateHeading(state: model.locationState, language: language)
                    if model.locationState == .checking {
                        LocationWaitingDetail(
                            language: language,
                            elapsedText: model.searchingElapsedText,
                            countdownText: model.manualOverrideCountdownText,
                            progress: model.manualOverrideProgress)
                    }
                    arrivalNumbers
                    routeMap
                    LocationClueCard(
                        language: language,
                        clue: model.clueToCurrentCheckpoint
                            ?? UIStrings.string(.arrivalNoClue, language))
                    if model.arrival == .permissionDenied {
                        SystemSettingsLink(language: language)
                    }
                    manualOverride
                    abandonButton
                }
                .padding(.vertical, KultaraMetrics.xl)
                .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
            }
            .scrollBounceBehavior(.basedOnSize)
            .padding(.horizontal, KultaraMetrics.lg)
        }
    }

    /// `FR-ARR-05` — the distance and the fix quality, as numbers that move. Present in every state
    /// that has a fix; the frames show neither, and a walk without them is a walk with no idea how
    /// far is left.
    @ViewBuilder private var arrivalNumbers: some View {
        switch model.arrival {
        case .approaching(let distance, let accuracy),
             .accuracyInsufficient(let distance, let accuracy):
            VStack(spacing: KultaraMetrics.xs) {
                Text(distance)
                    .font(KultaraTypography.font(.questTitle))
                    .foregroundStyle(hisplora.inkCream.color)
                    .monospacedDigit()
                Text("\(UIStrings.string(.arrivalAccuracy, language)) · \(accuracy)")
                    .font(.system(size: 13))
                    .foregroundStyle(hisplora.inkDusty.color)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
        case .idle, .searching, .permissionDenied:
            EmptyView()
        }
    }

    private var hisplora: HisploraPalette { .standard }

    /// `FR-MAP-02`. Shown whether or not there is a fix: with one it carries the walker's position
    /// and the straight-line distance, without one it is still the route and the stops, which is
    /// the location preview the walk between checkpoints otherwise lacks.
    @ViewBuilder private var routeMap: some View {
        if let route = model.routeMap {
            // No chrome: this screen is on the story flow's brown ground, and the map's own heading
            // and distance row are inked for paper. The heading above and `arrivalNumbers` below
            // carry both, in inks the Hisplora palette measures.
            RunRouteMapView(route: route,
                            language: language,
                            totalCheckpoints: model.totalCheckpoints,
                            showsChrome: false)
        }
    }

    /// `FR-CP-03`, `NFR-SAFE-02` — the clue stays re-readable for the whole walk, at rest, without
    /// re-triggering anything.
    private var clueCard: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                KultaraSectionHeading(UIStrings.string(.arrivalClueHeading, language))
                Text(model.clueToCurrentCheckpoint
                     ?? UIStrings.string(.arrivalNoClue, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// `FR-ARR-05`, `FR-ERR-01` — a distance and a fix quality that move, never an indefinite
    /// spinner.
    ///
    /// The searching state is where "no spinner" used to read as "no feedback". What it gets
    /// instead is a bounded wait: the elapsed time, and a determinate bar counting down to the
    /// moment the manual override appears — which genuinely happens, at 60 s, because `FR-ARR-03`
    /// says so. That is the difference between a progress indicator and a pretence of one.
    private var arrivalStatusCard: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                KultaraSectionHeading(UIStrings.string(.arrivalStatusHeading, language))
                switch model.arrival {
                case .idle, .searching:
                    Text(UIStrings.string(.arrivalSearching, language))
                        .kultaraFont(.sectionHeading)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(UIStrings.string(.arrivalNoFix, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    searchingCountdown
                case .approaching(let distance, let accuracy):
                    LabelledValue(label: UIStrings.string(.arrivalDistanceRemaining, language),
                                  value: distance, emphasised: true)
                    LabelledValue(label: UIStrings.string(.arrivalAccuracy, language),
                                  value: accuracy)
                case .accuracyInsufficient(let distance, let accuracy):
                    LabelledValue(label: UIStrings.string(.arrivalDistanceRemaining, language),
                                  value: distance, emphasised: true)
                    LabelledValue(label: UIStrings.string(.arrivalAccuracy, language),
                                  value: accuracy)
                    Text(UIStrings.string(.arrivalAccuracyInsufficient, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.warning.color)
                        .fixedSize(horizontal: false, vertical: true)
                case .permissionDenied:
                    Text(UIStrings.string(.runStartLocationDeniedTitle, language))
                        .kultaraFont(.sectionHeading)
                        .foregroundStyle(palette.seal.color)
                    // `FR-START-03`, `FR-ERR-02` — say what is blocked, offer the way out, and do
                    // not end the Run over it.
                    Text(UIStrings.string(.runStartLocationDeniedBody, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    SystemSettingsLink(language: language)
                }
            }
        }
    }

    /// The bounded part of the wait, written out. Elapsed time so the screen is visibly doing
    /// something, and a determinate bar for the countdown — determinate because the wait ends.
    @ViewBuilder private var searchingCountdown: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(String(format: UIStrings.string(.arrivalSearchingElapsed, language),
                        model.searchingElapsedText))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkMuted.color)
                .monospacedDigit()
            if let countdown = model.manualOverrideCountdownText {
                ProgressView(value: model.manualOverrideProgress, total: 1)
                    .tint(palette.seal.color)
                    .accessibilityHidden(true)
                Text(String(format: UIStrings.string(.arrivalManualCountdown, language), countdown))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `FR-START-10` — always visible, always at readable weight, and always a real control.
    ///
    /// It used to be a line of muted caption text until 60 s had passed, which is the least
    /// prominent styling the design system has, applied to the one thing that keeps the product
    /// usable when GPS fails. Now it is a button from the start: before availability it carries the
    /// countdown, after it reads `arrivalManualAction`, and either way it opens the sheet where the
    /// explanation and the confirm live.
    private var manualOverride: some View {
        Button {
            model.presentManualOverride()
        } label: {
            Text(manualOverrideLabel)
                .fixedSize(horizontal: false, vertical: true)
                .monospacedDigit()
        }
        .buttonStyle(.hisploraPill)
    }

    private var manualOverrideLabel: String {
        if model.manualOverrideAvailable {
            return UIStrings.string(.arrivalManualAction, language)
        }
        if let countdown = model.manualOverrideCountdownText {
            return String(format: UIStrings.string(.arrivalManualCountdown, language), countdown)
        }
        return UIStrings.string(.arrivalManualPending, language)
    }

    /// `FR-ARR-04`, `FR-ERR-02` — the explanation at body size, the confirm, and, when permission
    /// was refused, the way to Settings. A sheet rather than more rows on the arrival screen: the
    /// clue has to stay readable behind it (`FR-CP-03`, `NFR-SAFE-02`), which is why the *status*
    /// is not a modal and this is.
    private var manualOverrideSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    Text(UIStrings.string(.arrivalManualSheetTitle, language))
                        .kultaraFont(.questTitle)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    KultaraRule()
                }
                Text(UIStrings.string(.arrivalManualNote, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)

                if model.arrival == .permissionDenied {
                    Text(UIStrings.string(.runStartLocationDeniedBody, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    SystemSettingsLink(language: language)
                }

                if model.manualOverrideAvailable {
                    Button(UIStrings.string(.arrivalManualAction, language)) {
                        model.confirmManualOverrideFromSheet()
                    }
                    .buttonStyle(.seal)
                } else {
                    // Not yet offerable (`FR-ARR-03`). The sheet still explains what it is and when
                    // it arrives, rather than being a control that does nothing.
                    Text(UIStrings.string(.arrivalManualPending, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.inkMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(UIStrings.string(.runCancel, language)) {
                    model.dismissManualOverride()
                }
                .buttonStyle(.ruled)
            }
            .padding(KultaraMetrics.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(palette.paperRaised.color)
    }

    // MARK: Checkpoint

    @ViewBuilder private var checkpointScreen: some View {
        if let checkpoint = model.checkpoint {
            ScrollView {
                VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                    checkpointHeading(checkpoint)
                    // `FR-CP-02` — lore, then tasks, then the clue. The order is the requirement.
                    loreSection(checkpoint)
                    tasksSection(checkpoint)
                    clueSection(checkpoint)
                    advanceSection
                    abandonButton
                }
                .padding(KultaraMetrics.lg)
                .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
            }
        } else {
            EmptyView()
        }
    }

    private func checkpointHeading(_ checkpoint: CheckpointPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            KultaraEyebrow(UIStrings.string(.checkpointArrivedHeading, language),
                           index: checkpoint.orderIndex + 1)
            Text(checkpoint.placeName)
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(model.progressText)
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkMuted.color)
            // `FR-CP-07` — the stamp is a fact of arrival, stated before any task is offered.
            Text(UIStrings.string(.checkpointStampAwarded, language))
                .kultaraFont(.metadata)
                .foregroundStyle(palette.seal.color)
            KultaraRule()
        }
    }

    private func loreSection(_ checkpoint: CheckpointPresentation) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            KultaraSectionHeading(UIStrings.string(.checkpointLoreHeading, language))
            LoreClaimList(claims: checkpoint.claims, language: language)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func tasksSection(_ checkpoint: CheckpointPresentation) -> some View {
        if !checkpoint.tasks.isEmpty {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                KultaraSectionHeading(UIStrings.string(.checkpointTasksHeading, language))
                // `FR-TASK-05` — at a sacred Place the dress code and photo policy come before any
                // task is offered, not in a panel further down.
                if checkpoint.isSacred {
                    KultaraCard {
                        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                            Text(UIStrings.string(.previewSacredNotice, language))
                                .kultaraFont(.metadata)
                                .foregroundStyle(palette.seal.color)
                            LabelledValue(
                                label: UIStrings.string(.previewDressCode, language),
                                value: checkpoint.dressCodeText)
                            LabelledValue(
                                label: UIStrings.string(.previewPhotoPolicy, language),
                                value: checkpoint.photoPolicyText)
                        }
                    }
                }
                Text(UIStrings.string(.taskOptionalNote, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(checkpoint.tasks) { task in
                    TaskCard(
                        task: task,
                        prompt: checkpoint.taskPrompts[task.id] ?? "",
                        language: language,
                        resolution: model.resolution(for: task),
                        draft: Binding(
                            get: { model.taskDrafts[task.id] ?? "" },
                            set: { model.taskDrafts[task.id] = $0 }),
                        onSave: { model.saveTask(task) },
                        onSkip: { model.skipTask(task) })
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func clueSection(_ checkpoint: CheckpointPresentation) -> some View {
        if let clue = checkpoint.clueToNext {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                KultaraSectionHeading(UIStrings.string(.checkpointClueHeading, language))
                KultaraCard {
                    Text(clue)
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var advanceSection: some View {
        if model.canAdvance {
            Button(UIStrings.string(.checkpointAdvanceAction, language)) { model.advance() }
                .buttonStyle(.seal)
        } else if model.isCompleted {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                Text(UIStrings.string(.runCompletedHeading, language))
                    .kultaraFont(.sectionHeading)
                    .foregroundStyle(palette.seal.color)
                Text(UIStrings.string(.runCompletedBody, language))
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                Button(UIStrings.string(.summaryOpenAction, language)) { model.openSummary() }
                    .buttonStyle(.seal)
            }
        }
    }

    // MARK: Finished

    @ViewBuilder private var finishedScreen: some View {
        if let run = model.run {
            RunSummaryView(model: RunSummaryViewModel(run: run))
        } else {
            EmptyView()
        }
    }

    // MARK: Shared

    /// Drawn in whichever direction the screen around it is on: the arrival screen is on the story
    /// flow's palette, the checkpoint screen is still on the museum theme.
    @ViewBuilder private var abandonButton: some View {
        if model.run?.state == .active {
            if model.stage == .awaitingArrival {
                Button(UIStrings.string(.runAbandonAction, language)) { model.requestAbandon() }
                    .buttonStyle(.hisploraPlain)
            } else {
                Button(UIStrings.string(.runAbandonAction, language)) { model.requestAbandon() }
                    .buttonStyle(.ruled)
            }
        }
    }
}

private extension View {
    /// A medium detent, so the arrival screen — and the clue on it — stays visible behind the
    /// sheet. `.large` is offered as well because at the largest accessibility text sizes the
    /// explanation does not fit in half a screen.
    func kultaraManualOverrideSheetPresentation() -> some View {
        presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }
}
