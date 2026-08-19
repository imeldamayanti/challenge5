import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIStringsKit

/// One task, in the only two shapes this build offers: a written answer, or a note that photo
/// activities are not here yet. Both carry a skip, and neither gates anything (`AD-2`).
struct TaskCard: View {
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
