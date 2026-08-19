import ContentKit
import DesignSystem
import PhotosUI
import SwiftUI
import UIKit
import UIStringsKit

/// The challenge — one quiz, or one photograph (`FR-SIDE-05`, `FR-SIDE-06`).
///
/// Three accessibility rules shape the layout rather than decorating it. One column of full-width
/// options, each at least 44 points tall (`NFR-A11Y-06`). Options that wrap rather than truncate at
/// the largest Dynamic Type (`NFR-A11Y-02`). And right, wrong and revealed carried in **text and
/// shape** — the sentence, and a filled or hollow marker — never in colour alone (`NFR-A11Y-05`).
///
/// A wrong answer costs nothing and says so. The copy is deliberate: a person stuck on a
/// multiple-choice question in front of a temple gate does not go away and study, they close the
/// app (`s0` D5).
struct SideQuestChallengeView: View {
    @Environment(\.hisploraPalette) private var palette
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showsCamera = false
    @State private var isLoadingPhoto = false

    let language: ContentLanguage
    let challenge: ChallengePresentation
    let selection: Int?
    let feedback: QuizFeedback?
    let isSettled: Bool
    let onSelect: (Int) -> Void
    let onSubmit: () -> Void
    /// `s4` §7 — the picked or captured image, still full-size; downscaling and writing happen
    /// behind `SideQuestFlowViewModel.capturedPhoto(_:)`, which is the engine call's one caller.
    let onCapturePhoto: (UIImage) -> Void
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                HStack {
                    HisploraBackButton(
                        accessibilityLabel: UIStrings.string(.storyRevealBack, language),
                        action: onBack)
                    Spacer()
                }
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.top, KultaraMetrics.lg)

                ScrollView {
                    VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                        Text(UIStrings.string(.sideQuestChallengeHeading, language))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.inkDusty.color)
                            .textCase(.uppercase)
                            .tracking(1.5)
                            .accessibilityAddTraits(.isHeader)
                        switch challenge {
                        case .quiz(let quiz): quizBody(quiz)
                        case .photo(let prompt): photoBody(prompt)
                        }
                    }
                    .padding(.horizontal, KultaraMetrics.lg)
                    .padding(.vertical, KultaraMetrics.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)

                actions
                    .padding(.horizontal, KultaraMetrics.lg)
                    .padding(.bottom, KultaraMetrics.lg)
            }
        }
    }

    // MARK: Quiz

    @ViewBuilder private func quizBody(_ quiz: QuizPresentation) -> some View {
        Text(quiz.question)
            .font(KultaraTypography.font(.questTitle))
            .foregroundStyle(palette.inkCream.color)
            .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: KultaraMetrics.sm) {
            ForEach(quiz.options) { option in
                optionRow(option, isCorrectAnswer: isRevealedAnswer(option.text))
            }
        }

        if let feedback {
            feedbackCard(feedback)
        }
    }

    private func optionRow(_ option: QuizOptionPresentation, isCorrectAnswer: Bool) -> some View {
        let isSelected = selection == option.id
        return Button {
            onSelect(option.id)
        } label: {
            HStack(alignment: .top, spacing: KultaraMetrics.md) {
                // Shape, not tint: a filled marker for the chosen option and a check for the
                // revealed answer (`NFR-A11Y-05`).
                Image(systemName: markerName(isSelected: isSelected,
                                             isCorrectAnswer: isCorrectAnswer))
                    .font(.system(size: 20))
                    .foregroundStyle(palette.inkDark.color)
                Text(option.text)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(palette.inkDark.color)
                    // Wraps rather than truncates at AX5 (`NFR-A11Y-02`).
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(KultaraMetrics.lg)
            // `NFR-A11Y-06` — 44 points minimum, before any padding is counted.
            .frame(minHeight: KultaraMetrics.minimumTapTarget)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.paperCream.color,
                        in: RoundedRectangle(cornerRadius: KultaraMetrics.sm))
            .overlay(
                RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                    .stroke(palette.inkDark.color,
                            lineWidth: isSelected ? KultaraMetrics.hairline * 2 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSettled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func markerName(isSelected: Bool, isCorrectAnswer: Bool) -> String {
        if isCorrectAnswer { return "checkmark.circle.fill" }
        return isSelected ? "largecircle.fill.circle" : "circle"
    }

    /// Only after the answer is revealed. Before that, nothing on this screen knows which option is
    /// right — `QuizOptionPresentation` deliberately carries no `isCorrect`, and the correct text
    /// arrives from the engine only once the answer is settled.
    private func isRevealedAnswer(_ text: String) -> Bool {
        if case .revealed(_, let correctOptionText, _) = feedback {
            return correctOptionText == text
        }
        return false
    }

    private func feedbackCard(_ feedback: QuizFeedback) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            switch feedback {
            case .wrong(let message):
                Text(message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.inkDark.color)
                    .fixedSize(horizontal: false, vertical: true)
            case .correct(let message, let explanation):
                Text(message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.inkDark.color)
                    .fixedSize(horizontal: false, vertical: true)
                explanationBlock(explanation)
            case .revealed(let message, let correctOptionText, let explanation):
                Text(message)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.inkDark.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(correctOptionText)
                    .font(.system(size: 17))
                    .foregroundStyle(palette.inkBody.color)
                    .fixedSize(horizontal: false, vertical: true)
                explanationBlock(explanation)
            }
        }
        .padding(KultaraMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperWarm.color,
                    in: RoundedRectangle(cornerRadius: KultaraMetrics.sm))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func explanationBlock(_ explanation: String) -> some View {
        if !explanation.isEmpty {
            Text(UIStrings.string(.sideQuestQuizExplanation, language))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.inkMuted.color)
                .textCase(.uppercase)
                .tracking(1.5)
            Text(explanation)
                .font(.system(size: 15))
                .foregroundStyle(palette.inkBody.color)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Photo — Phase D

    /// `s4` §7. Camera and library, side by side rather than one gating the other: the Simulator
    /// this project is developed on has no camera at all (`UIImagePickerController.isSourceTypeAvailable`
    /// says so honestly, and the button is absent rather than disabled — a control that cannot work
    /// is worse than one that is not there), while a physical device may prefer either.
    @ViewBuilder private func photoBody(_ prompt: String) -> some View {
        Text(UIStrings.string(.sideQuestPhotoPrompt, language))
            .font(KultaraTypography.font(.questTitle))
            .foregroundStyle(palette.inkCream.color)
            .fixedSize(horizontal: false, vertical: true)

        Text(prompt)
            .font(.system(size: 17))
            .foregroundStyle(palette.inkDark.color)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(KultaraMetrics.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.paperCream.color,
                        in: RoundedRectangle(cornerRadius: KultaraMetrics.sm))

        VStack(spacing: KultaraMetrics.sm) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showsCamera = true
                } label: {
                    Text(UIStrings.string(.sideQuestPhotoTake, language))
                }
                .buttonStyle(.hisploraPill)
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Text(UIStrings.string(.sideQuestPhotoChoose, language))
            }
            .buttonStyle(.hisploraPlain)
        }
        .disabled(isLoadingPhoto)
        .fullScreenCover(isPresented: $showsCamera) {
            CameraCaptureView(
                onCapture: { image in
                    showsCamera = false
                    onCapturePhoto(image)
                },
                onCancel: { showsCamera = false })
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            isLoadingPhoto = true
            Task {
                defer {
                    isLoadingPhoto = false
                    selectedPhotoItem = nil
                }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onCapturePhoto(image)
                }
            }
        }
    }

    // MARK: Actions

    @ViewBuilder private var actions: some View {
        switch challenge {
        case .quiz:
            if isSettled {
                Button(UIStrings.string(.transitionContinue, language), action: onContinue)
                    .buttonStyle(.hisploraPill)
            } else {
                Button(UIStrings.string(.sideQuestQuizSubmit, language), action: onSubmit)
                    .buttonStyle(.hisploraPill)
                    .disabled(selection == nil)
            }
        case .photo:
            // Settled means "attached" — `SideQuestFlowViewModel.capturedPhoto` moves straight to
            // `.letter` on success, so this screen is not on stage to render the settled case in
            // practice. Kept for the same reason the quiz's `Continue` case is: a decision this
            // view should not have to know is unreachable.
            if isSettled {
                Button(UIStrings.string(.transitionContinue, language), action: onContinue)
                    .buttonStyle(.hisploraPill)
            }
        }
    }
}
