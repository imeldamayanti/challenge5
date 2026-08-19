import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The whole sidequest on one screen, changing what it shows as the flow moves through its stages —
/// the same shape `QuestRunView` uses, and for the same reason: the walker's position in the flow
/// *is* the navigation, and a stack would let them back out of a letter into an arrival screen for
/// a place they are already standing at.
struct SideQuestFlowView: View {
    @Bindable private var model: SideQuestFlowViewModel
    let onFinish: () -> Void
    let onOpenCollection: (String) -> Void

    init(
        model: SideQuestFlowViewModel,
        onFinish: @escaping () -> Void,
        onOpenCollection: @escaping (String) -> Void
    ) {
        self.model = model
        self.onFinish = onFinish
        self.onOpenCollection = onOpenCollection
    }

    private var language: ContentLanguage { model.language }

    /// Mirrors `QuestRunView.isOnStoryFlow`. Every stage but the location notice is a Hisplora
    /// screen carrying its own heading and its own back control, so the museum navigation bar over
    /// them is cream on brown and clips the eyebrow underneath. On those stages it goes away.
    private var isOnStoryFlow: Bool {
        switch model.stage {
        case .notice, .awaitingArrival, .story, .challenge, .letter: true
        case .locationNotice, .done: false
        }
    }

    var body: some View {
        content
            .navigationTitle(isOnStoryFlow ? "" : model.title)
            .kultaraInlineNavigationTitle()
            .toolbar(isOnStoryFlow ? .hidden : .visible, for: .navigationBar)
            .onAppear { model.screenAppeared() }
            .onDisappear { model.screenDisappeared() }
            .onChange(of: model.stage) { _, stage in
                if stage == .done { onFinish() }
            }
            .sheet(isPresented: Binding(
                get: { model.sampling.isPresentingManualOverride },
                set: { if !$0 { model.dismissManualOverride() } })) {
                KultaraThemeProvider {
                    SideQuestManualOverrideSheet(
                        language: language,
                        isPermissionDenied: model.sampling.status == .permissionDenied,
                        isAvailable: model.sampling.manualOverrideAvailable,
                        onConfirm: { model.confirmManualOverrideFromSheet() },
                        onCancel: { model.dismissManualOverride() })
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder private var content: some View {
        switch model.stage {
        case .notice:
            SideQuestNoticeView(
                language: language,
                presentation: model.presentation,
                isAlreadyDiscovered: model.record != nil,
                onAccept: { model.accept() },
                onDecline: { model.decline() })
        case .locationNotice:
            locationNotice
        case .awaitingArrival:
            SideQuestArrivalView(
                language: language,
                placeName: model.placeName,
                sampling: model.sampling,
                onBack: { model.decline() })
        case .story:
            SideQuestStoryView(
                language: language,
                claims: model.storyClaims,
                text: model.storyText,
                heroImageURL: model.presentation.heroImageURL,
                onFinish: { model.advanceFromStory() },
                onBack: { model.retreatFromStory() })
        case .challenge:
            SideQuestChallengeView(
                language: language,
                challenge: model.presentation.challenge,
                selection: model.quizSelection,
                feedback: model.quizFeedback,
                isSettled: model.isChallengeSettled,
                onSelect: { model.selectOption($0) },
                onSubmit: { model.submitQuiz() },
                onCapturePhoto: { model.capturedPhoto($0) },
                onContinue: { model.advanceFromChallenge() },
                onBack: { model.retreatFromChallenge() })
        case .letter:
            SideQuestLetterView(
                language: language,
                letter: model.awardedLetter,
                placeName: model.placeName,
                progressText: model.collectionProgressText,
                hasCollection: model.collectionID != nil,
                onKeepExploring: { model.finish() },
                onOpenCollection: {
                    if let id = model.collectionID { onOpenCollection(id) }
                    model.finish()
                })
        case .done:
            Color.clear
        }
    }

    /// `FR-START-02` — the plain-language explanation before the system prompt, never after it. On
    /// the museum theme, because a permission notice is chrome rather than a story stage, exactly
    /// as `QuestRunView` treats its own.
    private var locationNotice: some View {
        LocationNoticeScreen(
            language: language,
            onContinue: { model.acknowledgeLocationNoticeAndRequestPermission() })
    }
}

/// The `FR-START-02` explanation, extracted so both flows show the same words and the same order.
struct LocationNoticeScreen: View {
    @Environment(\.kultaraPalette) private var palette

    let language: ContentLanguage
    let onContinue: () -> Void

    var body: some View {
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
                Button(UIStrings.string(.runStartLocationContinue, language), action: onContinue)
                    .buttonStyle(.seal)
            }
            .padding(KultaraMetrics.lg)
            .kultaraFloatingTabBarClearance()
        }
        .kultaraGround()
    }
}
