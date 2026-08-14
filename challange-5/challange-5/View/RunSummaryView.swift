import ContentKit
import DesignSystem
import RunEngine
import SwiftUI

struct RunSummaryView: View {
    @Environment(\.kultaraPalette) private var palette
    private let model: RunSummaryViewModel

    init(model: RunSummaryViewModel) {
        self.model = model
    }

    private var language: ContentLanguage { model.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                heading
                ForEach(model.stops) { stop in
                    stopSection(stop)
                }
                awardsSection
                nextInFlowSection
                Text(model.snapshotNote)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(KultaraMetrics.lg)
            .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
        }
        .background(palette.paper.color)
        .navigationTitle(UIStrings.string(.summaryHeading, language))
        .kultaraInlineNavigationTitle()
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            KultaraEyebrow(UIStrings.string(.summaryHeading, language))
            Text(model.title)
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(model.progressText)
                .kultaraFont(.metadata)
                .foregroundStyle(palette.inkMuted.color)
            if model.wasAbandoned {
                Text(UIStrings.string(.runAbandonedNote, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.warning.color)
            }
            KultaraRule()
        }
    }

    private func stopSection(_ stop: RunSummaryViewModel.Stop) -> some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            KultaraEyebrow(UIStrings.string(.previewCheckpointsHeading, language),
                           index: stop.orderIndex + 1)
            Text(stop.placeName)
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
            LoreClaimList(claims: stop.claims, language: language)
            if !stop.writtenAnswers.isEmpty {
                KultaraCard {
                    VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                        KultaraSectionHeading(
                            UIStrings.string(.summaryReflectionHeading, language))
                        ForEach(Array(stop.writtenAnswers.enumerated()), id: \.offset) { _, answer in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(answer.prompt)
                                    .kultaraFont(.metadata)
                                    .foregroundStyle(palette.inkMuted.color)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(answer.text)
                                    .kultaraFont(.body)
                                    .foregroundStyle(palette.ink.color)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var awardsSection: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            KultaraSectionHeading(UIStrings.string(.summaryStampsHeading, language))
            ForEach(model.stamps) { award in
                LabelledValue(label: UIStrings.string(.checkpointStampAwarded, language),
                              value: award.snapshotName)
            }
            ForEach(model.badges) { award in
                LabelledValue(
                    label: UIStrings.string(.summaryStampsHeading, language),
                    value: String(format: UIStrings.string(.runBadgeAwarded, language),
                                  award.snapshotName),
                    emphasised: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What the flow chart draws after this screen: the journal question, and — through it — the
    /// trip summary, the share card and the recommendation. All four are wireframes; this section
    /// is the way into them, and it says which side of the line it is on.
    private var nextInFlowSection: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            KultaraSectionHeading(WireframeCatalog.stamp.value(for: language))
            NavigationLink {
                CreateJournalWireframeView(language: language)
            } label: {
                Text(WireframeCatalog.createJournal.title.value(for: language))
            }
            .buttonStyle(.ruled)

            NavigationLink {
                TripSummaryWireframeView(language: language)
            } label: {
                Text(WireframeCatalog.tripSummary.title.value(for: language))
            }
            .buttonStyle(.ruled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
