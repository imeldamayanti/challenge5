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
public struct QuestRunView: View {
    @Environment(\.kultaraPalette) private var palette
    @Bindable private var model: QuestRunViewModel

    public init(model: QuestRunViewModel) {
        self.model = model
    }

    private var language: ContentLanguage { model.language }

    public var body: some View {
        content
            .background(palette.paper.color)
            .navigationTitle(model.quest.title.value(for: language))
            .kultaraInlineNavigationTitle()
            .onAppear { model.screenAppeared() }
            .onDisappear { model.screenDisappeared() }
            .confirmationDialog(
                model.presenceConfirmationTitle,
                isPresented: Binding(get: { model.isConfirmingPresence },
                                     set: { if !$0 { model.cancelPresenceConfirmation() } }),
                titleVisibility: .visible
            ) {
                Button(UIStrings.string(.runStartConfirmYes, language)) {
                    model.confirmPresence()
                }
                Button(UIStrings.string(.runCancel, language), role: .cancel) {
                    model.cancelPresenceConfirmation()
                }
            } message: {
                Text(UIStrings.string(.runStartConfirmBody, language))
            }
            .confirmationDialog(
                UIStrings.string(.runAbandonConfirmTitle, language),
                isPresented: Binding(get: { model.isConfirmingAbandon },
                                     set: { if !$0 { model.cancelAbandon() } }),
                titleVisibility: .visible
            ) {
                Button(UIStrings.string(.runAbandonConfirmAction, language), role: .destructive) {
                    model.confirmAbandon()
                }
                Button(UIStrings.string(.runCancel, language), role: .cancel) {
                    model.cancelAbandon()
                }
            } message: {
                Text(UIStrings.string(.runAbandonConfirmBody, language))
            }
    }

    @ViewBuilder private var content: some View {
        switch model.stage {
        case .safetyNotice: safetyNotice
        case .locationNotice: locationNotice
        case .awaitingArrival: arrivalScreen
        case .atCheckpoint: checkpointScreen
        case .finished: finishedScreen
        }
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

    private var arrivalScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    KultaraEyebrow(model.stepText)
                    Text(model.headingText)
                        .kultaraFont(.questTitleLarge)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    KultaraRule()
                }
                clueCard
                arrivalStatusCard
                manualOverride
                abandonButton
            }
            .padding(KultaraMetrics.lg)
            .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
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
    private var arrivalStatusCard: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                switch model.arrival {
                case .idle, .searching:
                    Text(UIStrings.string(.arrivalSearching, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                    Text(UIStrings.string(.arrivalNoFix, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.inkMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
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

    @ViewBuilder private var manualOverride: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            if model.manualOverrideAvailable {
                Button(UIStrings.string(.arrivalManualAction, language)) {
                    model.useManualOverride()
                }
                .buttonStyle(.ruled)
                // `FR-ARR-04` — stated plainly, because an override that feels like cheating is an
                // override people will not use where they need it most.
                Text(UIStrings.string(.arrivalManualNote, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(UIStrings.string(.arrivalManualPending, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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

    @ViewBuilder private var abandonButton: some View {
        if model.run?.state == .active {
            Button(UIStrings.string(.runAbandonAction, language)) { model.requestAbandon() }
                .buttonStyle(.ruled)
        }
    }
}

/// One task, in the only two shapes this build offers: a written answer, or a note that photo
/// activities are not here yet. Both carry a skip, and neither gates anything (`AD-2`).
private struct TaskCard: View {
    @Environment(\.kultaraPalette) private var palette

    let task: ContentTask
    let prompt: String
    let language: ContentLanguage
    let resolution: TaskResult?
    @Binding var draft: String
    let onSave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                Text(prompt)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)

                if let resolution {
                    Text(resolution.skipped
                         ? UIStrings.string(.taskSkippedNote, language)
                         : UIStrings.string(.taskAnsweredNote, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.inkMuted.color)
                    if let text = resolution.text {
                        Text(text)
                            .kultaraFont(.body)
                            .foregroundStyle(palette.ink.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if task.type == .photo {
                    Text(UIStrings.string(.taskPhotoNotInThisBuild, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.warning.color)
                        .fixedSize(horizontal: false, vertical: true)
                    skipButton
                } else {
                    TextField(UIStrings.string(.taskAnswerPlaceholder, language),
                              text: $draft, axis: .vertical)
                        .kultaraFont(.body)
                        .lineLimit(3...8)
                        .textFieldStyle(.plain)
                        .padding(KultaraMetrics.sm)
                        .background(palette.paperSunken.color)
                        .frame(minHeight: KultaraMetrics.minimumTapTarget)
                    HStack(spacing: KultaraMetrics.md) {
                        Button(UIStrings.string(.taskSaveAction, language), action: onSave)
                            .buttonStyle(.ruled)
                        // `FR-TASK-02` — an explicit, non-apologetic skip. Same weight as saving.
                        skipButton
                    }
                }
            }
        }
    }

    private var skipButton: some View {
        Button(UIStrings.string(.taskSkipAction, language), action: onSkip)
            .buttonStyle(.ruled)
    }
}

/// `FR-START-03` — a path to Settings wherever a refused permission is explained.
private struct SystemSettingsLink: View {
    @Environment(\.kultaraPalette) private var palette
    @Environment(\.openURL) private var openURL
    let language: ContentLanguage

    var body: some View {
        if let url = URL(string: "app-settings:") {
            Button(UIStrings.string(.settingsOpenSystemSettings, language)) { openURL(url) }
                .buttonStyle(.ruled)
        }
    }
}
