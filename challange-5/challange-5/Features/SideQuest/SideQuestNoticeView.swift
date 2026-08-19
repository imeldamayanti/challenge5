import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// "A historical place is near you" — the synopsis, and the question (PRD §5.15, `FR-SIDE-11`).
///
/// Hisplora, because this is a story flow and it is the same flow the run's story stages already
/// use. It replaces `WireframeCatalog.nearbyNotice`, which was a drawing of exactly this screen and
/// is deleted in the same commit (`s0` D12).
///
/// **The sacred-place notice comes first.** `FR-TASK-05` puts the dress code and the photo policy
/// before any challenge is offered, and "before" here means before the walker has even agreed to
/// the story — the same order `CheckpointScreen` and `PlaceNoticeScreen` use. Declining costs
/// nothing and records nothing (`FR-SIDE-07`).
struct SideQuestNoticeView: View {
    @Environment(\.hisploraPalette) private var palette

    let language: ContentLanguage
    let presentation: SideQuestPresentation
    let isAlreadyDiscovered: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HisploraStage(ground: \.brownStone) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: KultaraMetrics.lg) {
                        HisploraFramedImage(
                            url: presentation.heroImageURL, label: presentation.placeName)
                            .padding(.horizontal, KultaraMetrics.xxl)
                        heading
                        card
                    }
                    .padding(.vertical, KultaraMetrics.lg)
                    .padding(.horizontal, KultaraMetrics.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
                actions
                    .padding(.horizontal, KultaraMetrics.lg)
                    .padding(.bottom, KultaraMetrics.lg)
            }
        }
    }

    private var heading: some View {
        VStack(spacing: KultaraMetrics.xs) {
            Text(UIStrings.string(.sideQuestNoticeTitle, language))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.inkDusty.color)
                .textCase(.uppercase)
                .tracking(1.5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(presentation.title)
                .font(KultaraTypography.font(.questTitleLarge))
                .foregroundStyle(palette.inkCream.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(presentation.placeName)
                .font(.system(size: 15))
                .foregroundStyle(palette.inkDusty.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
            Text(presentation.synopsis)
                .font(.system(size: 15))
                .foregroundStyle(palette.inkBody.color)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // `FR-TASK-05` — stated before the question, not in a panel further down.
            if presentation.isSacred {
                VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                    Text(UIStrings.string(.previewSacredNotice, language))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.inkDark.color)
                        .fixedSize(horizontal: false, vertical: true)
                    point(UIStrings.string(.previewDressCode, language),
                          presentation.dressCodeText)
                    point(UIStrings.string(.previewPhotoPolicy, language),
                          presentation.photoPolicyText)
                }
            }

            Text(UIStrings.string(.sideQuestNoticeQuestion, language))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.inkDark.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KultaraMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperCream.color, in: RoundedRectangle(cornerRadius: KultaraMetrics.sm))
    }

    private func point(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(palette.inkMuted.color)
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(palette.inkBody.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        VStack(spacing: KultaraMetrics.sm) {
            Button(UIStrings.string(.sideQuestNoticeYes, language), action: onAccept)
                .buttonStyle(.hisploraPill)
            Button(UIStrings.string(.sideQuestNoticeNo, language), action: onDecline)
                .buttonStyle(.hisploraPlain)
            // `FR-SIDE-07` — an incomplete sidequest is re-openable at its place forever, and a
            // returning walker should be told that is what they are looking at rather than left to
            // wonder whether they are about to start again.
            if isAlreadyDiscovered {
                Text(UIStrings.string(.sideQuestKeepExploring, language))
                    .font(.system(size: 13))
                    .foregroundStyle(palette.inkDusty.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
