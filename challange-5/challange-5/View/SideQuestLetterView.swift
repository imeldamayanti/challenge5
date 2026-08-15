import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The letter, and the phrase so far (`FR-SIDE-05`, `FR-SIDE-08`).
///
/// The letter is set large because it is the reward, and it is spoken as a letter rather than left
/// to VoiceOver's guess at a single capital (`NFR-A11Y-01`). Reduce Motion collapses the entrance
/// to nothing — `HisploraMotion`'s own rule, and the same one `StoryTransitionScreen` follows.
struct SideQuestLetterView: View {
    @Environment(\.hisploraPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let language: ContentLanguage
    let letter: String?
    let placeName: String
    let progressText: String?
    let hasCollection: Bool
    let onKeepExploring: () -> Void
    let onOpenCollection: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        HisploraStage(ground: \.brownDeep) {
            VStack(spacing: KultaraMetrics.xl) {
                Spacer()

                VStack(spacing: KultaraMetrics.md) {
                    Text(UIStrings.string(.sideQuestLetterAwarded, language))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.inkDusty.color)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .accessibilityAddTraits(.isHeader)

                    if let letter {
                        Text(letter)
                            .font(KultaraTypography.font(.questTitleLarge))
                            .foregroundStyle(palette.inkCream.color)
                            .padding(KultaraMetrics.xl)
                            .background(
                                RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                                    .stroke(palette.buttonRing.color,
                                            lineWidth: KultaraMetrics.hairline))
                            .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.9)
                            .opacity(hasAppeared || reduceMotion ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.35),
                                       value: hasAppeared)
                            .accessibilityLabel(letter)
                    }

                    Text(placeName)
                        .font(.system(size: 15))
                        .foregroundStyle(palette.inkDusty.color)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if let progressText {
                        Text(progressText)
                            .font(.system(size: 17))
                            .foregroundStyle(palette.inkCream.color)
                            .monospacedDigit()
                    }
                }

                Spacer()

                VStack(spacing: KultaraMetrics.sm) {
                    if hasCollection {
                        Button(UIStrings.string(.sideQuestCollectionOpen, language),
                               action: onOpenCollection)
                            .buttonStyle(.hisploraPill)
                    }
                    Button(UIStrings.string(.sideQuestKeepExploring, language),
                           action: onKeepExploring)
                        .buttonStyle(.hisploraPlain)
                }
            }
            .padding(KultaraMetrics.lg)
            .onAppear { hasAppeared = true }
        }
    }
}
