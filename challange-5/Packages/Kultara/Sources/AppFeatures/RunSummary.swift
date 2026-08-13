import ContentKit
import DesignSystem
import Foundation
import RunEngine
import SwiftUI

/// The trip summary, built from the Run's own snapshots and nothing else.
///
/// There is deliberately no `ContentRepository` in this type. `FR-DONE-04` requires the summary to
/// render the pinned content version rather than current content, and `FR-DONE-05` requires it to
/// render offline forever — and the cheapest way to guarantee both is to leave the model no way to
/// look anything up. A place withdrawn under `AD-5` cannot blank a walk somebody finished, because
/// nothing here asks whether it still exists.
@MainActor
@Observable
public final class RunSummaryViewModel {

    public struct Stop: Sendable, Identifiable, Equatable {
        public let id: String
        public let orderIndex: Int
        public let placeName: String
        public let claims: [LoreClaimPresentation]
        public let arrivalNote: String?
        /// Answers the walker wrote, in the order they were asked. Skipped tasks contribute
        /// nothing — a skip is a resolution, not an empty answer to print (`AD-2`).
        public let writtenAnswers: [(prompt: String, text: String)]

        public static func == (lhs: Stop, rhs: Stop) -> Bool {
            lhs.id == rhs.id && lhs.claims == rhs.claims
                && lhs.writtenAnswers.map(\.text) == rhs.writtenAnswers.map(\.text)
        }
    }

    public let run: Run
    public let language: ContentLanguage
    public let stops: [Stop]

    public init(run: Run) {
        self.run = run
        // The Run's own language, not the app's. Switching the interface to English after finishing
        // an Indonesian walk must not half-translate a summary; `NFR-I18N-03` forbids the mixture,
        // and the snapshot only holds one language anyway.
        self.language = run.language
        let formatter = ContentFormatter(language: run.language)

        stops = run.orderedCheckpointResults.map { result in
            Stop(
                id: result.checkpointID,
                orderIndex: result.orderIndex,
                placeName: result.snapshotPlaceName,
                claims: result.snapshotLore.enumerated().map { offset, snapshot in
                    LoreClaimPresentation(
                        id: offset,
                        block: LoreBlockPresentation(
                            id: offset,
                            text: snapshot.text,
                            accuracyLabel: formatter.accuracyLabel(snapshot.accuracy),
                            appearance: snapshot.accuracy == .documented ? .documented : .oral,
                            ink: snapshot.accuracy == .documented ? .documented : .oral),
                        citations: snapshot.sourceCitations)
                },
                arrivalNote: nil,
                writtenAnswers: result.taskResults
                    .filter { !$0.skipped }
                    .compactMap { task in
                        guard let text = task.text, !text.isEmpty else { return nil }
                        return (prompt: task.promptSnapshot, text: text)
                    })
        }
    }

    public var title: String { run.snapshotQuestTitle }

    public var stamps: [Award] { run.awards.filter { $0.type == .stamp } }

    public var badges: [Award] { run.awards.filter { $0.type == .badge } }

    public var progressText: String {
        String(format: UIStrings.string(.checkpointProgress, language),
               run.reachedCount, run.checkpointCount)
    }

    /// Names the pinned version, because a summary that silently disagrees with the current app is
    /// worse than one that says why (`AD-4`).
    public var snapshotNote: String {
        String(format: UIStrings.string(.summarySnapshotNote, language), run.contentVersion)
    }

    public var wasAbandoned: Bool { run.state == .abandoned }
}

// MARK: - View

public struct RunSummaryView: View {
    @Environment(\.kultaraPalette) private var palette
    private let model: RunSummaryViewModel

    public init(model: RunSummaryViewModel) {
        self.model = model
    }

    private var language: ContentLanguage { model.language }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                heading
                ForEach(model.stops) { stop in
                    stopSection(stop)
                }
                awardsSection
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
}

/// Shared by the checkpoint screen and the summary, so a claim cannot be styled one way while it is
/// being read and another way when it is remembered.
struct LoreClaimList: View {
    @Environment(\.kultaraPalette) private var palette
    let claims: [LoreClaimPresentation]
    let language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
            ForEach(claims) { claim in
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    // `FR-CP-05` — the label is text on the page, never behind a tap, and it is
                    // never carried by colour alone (`NFR-A11Y-05`).
                    AccuracyChip(text: claim.block.accuracyLabel,
                                 appearance: claim.block.appearance,
                                 ink: claim.block.ink.path)
                    Text(claim.block.text)
                        .kultaraFont(.lore)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    // `FR-CP-06` — sources within one tap of the lore. A disclosure group is that
                    // one tap, and it keeps the citation on the same screen as the claim.
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 2) {
                            if claim.citations.isEmpty {
                                Text(UIStrings.string(.checkpointSourcesEmpty, language))
                                    .kultaraFont(.metadata)
                                    .foregroundStyle(palette.inkMuted.color)
                            }
                            ForEach(claim.citations, id: \.self) { citation in
                                Text("· \(citation)")
                                    .kultaraFont(.metadata)
                                    .foregroundStyle(palette.inkMuted.color)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } label: {
                        Text(UIStrings.string(.checkpointSourcesHeading, language))
                            .kultaraFont(.metadata)
                            .foregroundStyle(palette.seal.color)
                            .frame(minHeight: KultaraMetrics.minimumTapTarget,
                                   alignment: .leading)
                    }
                }
            }
        }
    }
}
