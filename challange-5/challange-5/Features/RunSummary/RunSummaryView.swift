import ContentKit
import DesignSystem
import RunEngine
import SwiftUI
import UIKit
import UIStringsKit

struct RunSummaryView: View {
    @Environment(\.kultaraPalette) private var palette
    private let model: RunSummaryViewModel
    /// Writes the walk's closing journal entry (`WriteJournalScreen`) and hands back the updated
    /// Run, or `nil` on failure. Owned by `QuestRunViewModel`, which alone holds the `RunEngine`
    /// and the `PhotoStore` a save needs — this view stays as free of both as `RunSummaryViewModel`
    /// already is.
    private let onSaveJournal: (String, UIImage?, UIImage?) -> Run?
    /// Opens the walk's real Trip Summary (`Letters.TripSummaryScreen`) from `JourneySavedScreen`'s
    /// "See Journey Recap" — a root-level concern (switching to the Journal tab), so it is handed
    /// down as a closure rather than this screen reaching for app state it should not know about.
    private let onOpenRecap: (Run) -> Void

    init(
        model: RunSummaryViewModel,
        onSaveJournal: @escaping (String, UIImage?, UIImage?) -> Run?,
        onOpenRecap: @escaping (Run) -> Void
    ) {
        self.model = model
        self.onSaveJournal = onSaveJournal
        self.onOpenRecap = onOpenRecap
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
            }
            .padding(KultaraMetrics.lg)
            .kultaraFloatingTabBarClearance()
        }
        .kultaraSpeckledGround(palette.paper)
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

    /// What the flow chart draws after this screen: write a journal entry, then — through it — the
    /// trip summary, the share card and the recommendation. The journal is real now
    /// (`WriteJournalScreen` → `JourneySavedScreen` → the walk's own Trip Summary); the share card
    /// and the recommendation stay wireframes, reached the same way they always were.
    private var nextInFlowSection: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            NavigationLink {
                WriteJournalScreen(
                    language: language, onSave: onSaveJournal, onOpenRecap: onOpenRecap)
            } label: {
                Text(UIStrings.string(.writeJournalTitle, language))
            }
            .buttonStyle(.ruled)

            KultaraSectionHeading(WireframeCatalog.stamp.value(for: language))
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
