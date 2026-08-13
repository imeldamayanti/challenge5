import ContentKit
import DesignSystem
import SwiftUI

struct QuestPreviewView: View {
    @Environment(\.kultaraPalette) private var palette
    private let model: QuestPreviewViewModel

    init(model: QuestPreviewViewModel) {
        self.model = model
    }

    private var language: ContentLanguage { model.language }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.xl) {
                if let warning = model.lateStartWarning {
                    lateWarning(warning)
                }
                heading
                hook
                about
                route
                checkpointList
                cost
                terrain
                timing
                safety
                startNotice
            }
            .padding(KultaraMetrics.lg)
            .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
        }
        .background(palette.paper.color)
        .navigationTitle(model.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog(
            UIStrings.string(.runResumeHeading, language),
            isPresented: Binding(get: { model.isChoosingResumeOrRestart },
                                 set: { if !$0 { model.cancelResumeChoice() } }),
            titleVisibility: .visible
        ) {
            Button(UIStrings.string(.runResumeAction, language)) { model.chooseResume() }
            Button(UIStrings.string(.runRestartAction, language), role: .destructive) {
                model.chooseRestart()
            }
            Button(UIStrings.string(.runCancel, language), role: .cancel) {
                model.cancelResumeChoice()
            }
        } message: {
            Text(UIStrings.string(.runRestartWarning, language))
        }
    }

    private func lateWarning(_ warning: String) -> some View {
        // Non-blocking by construction: a panel in the flow, not an alert. FR-DISC-06.
        HStack(alignment: .top, spacing: KultaraMetrics.sm) {
            Image(systemName: "clock.badge.exclamationmark")
                .accessibilityHidden(true)
            Text(warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        .kultaraFont(.body)
        .foregroundStyle(palette.warning.color)
        .padding(KultaraMetrics.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paperSunken.color)
        .overlay(RoundedRectangle(cornerRadius: KultaraMetrics.cardCornerRadius)
            .stroke(palette.warning.color, lineWidth: KultaraMetrics.hairline))
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            KultaraEyebrow(model.region)
            Text(model.title)
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            KultaraRule()
        }
    }

    private var hook: some View {
        SectionContainer(heading: .previewHookHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                ForEach(model.hookLore) { block in
                    VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                        AccuracyChip(text: block.accuracyLabel,
                                     appearance: block.appearance,
                                     ink: block.ink.path)
                        Text(block.text)
                            .kultaraFont(.lore)
                            .foregroundStyle(palette.ink.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(UIStrings.string(.previewStoryWithheld, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
            }
        }
    }

    private var about: some View {
        SectionContainer(heading: .previewAboutHeading, language: language) {
            Text(model.descriptionText)
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var route: some View {
        SectionContainer(heading: .previewRouteHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                // FR-MAP-01 / FR-OFF-03: a shipped image, so the route renders with no network and
                // no tile cache to miss.
                if let url = model.routeImageURL, let image = routeImage(url) {
                    VStack(spacing: KultaraMetrics.sm) {
                        KultaraPlate {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel(UIStrings.string(.previewRouteImageAlt, language))
                        }
                        KultaraPlateCaption(title: model.title, detail: model.region,
                                            alignment: .center)
                    }
                }
                LabelledValue(label: UIStrings.string(.labelDistance, language), value: model.distanceText)
                LabelledValue(label: UIStrings.string(.labelWalkingTime, language), value: model.walkingTimeText)
                LabelledValue(label: UIStrings.string(.labelTotalDuration, language), value: model.totalDurationText)
            }
        }
    }

    private func routeImage(_ url: URL) -> Image? {
        #if canImport(UIKit)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #else
        return nil
        #endif
    }

    private var checkpointList: some View {
        SectionContainer(heading: .previewCheckpointsHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                ForEach(model.checkpoints) { row in
                    KultaraCard {
                        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                            // The stop's number as the catalogue sets a plate number, and the name
                            // in the serif beneath it. The number stays part of the name's
                            // accessibility label rather than becoming a separate element, because
                            // the order is the one thing `FR-CP-08` makes load-bearing.
                            KultaraEyebrow(UIStrings.string(.previewCheckpointsHeading, language),
                                           index: row.orderIndex + 1)
                            Text(row.placeName)
                                .kultaraFont(.questTitle)
                                .foregroundStyle(palette.ink.color)
                                .fixedSize(horizontal: false, vertical: true)
                            if row.isSacred {
                                Text(UIStrings.string(.previewSacredNotice, language))
                                    .kultaraFont(.metadata)
                                    .foregroundStyle(palette.seal.color)
                            }
                            LabelledValue(label: UIStrings.string(.previewPhotoPolicy, language),
                                          value: row.photoPolicyText)
                            LabelledValue(label: UIStrings.string(.previewDressCode, language),
                                          value: row.dressCodeText)
                            LabelledValue(
                                label: UIStrings.string(.previewSurface, language),
                                value: [row.stepsText, row.surfaceText]
                                    .compactMap { $0 }.joined(separator: " · "))
                            Text(row.accessibilityNotes)
                                .kultaraFont(.metadata)
                                .foregroundStyle(palette.inkMuted.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var cost: some View {
        SectionContainer(heading: .previewCostHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                LabelledValue(label: UIStrings.string(.labelEstimatedCost, language),
                              value: model.costText, emphasised: true)
                KultaraRule()
                ForEach(Array(model.costBreakdown.enumerated()), id: \.offset) { _, entry in
                    LabelledValue(label: entry.placeName, value: entry.amountText)
                }
            }
        }
    }

    private var terrain: some View {
        SectionContainer(heading: .previewTerrainHeading, language: language) {
            Text(model.terrainText)
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timing: some View {
        SectionContainer(heading: .previewTimingHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                LabelledValue(label: UIStrings.string(.previewRecommendedWindow, language),
                              value: model.recommendedWindowText)
                LabelledValue(label: UIStrings.string(.previewLatestStart, language),
                              value: model.latestStartText)
            }
        }
    }

    private var safety: some View {
        SectionContainer(heading: .previewSafetyHeading, language: language) {
            Text(model.safetyNotes)
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var startNotice: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                Text(UIStrings.string(.previewStartUnavailable, language))
                    .kultaraFont(.sectionHeading)
                    .foregroundStyle(palette.seal.color)
                // The explanation stays whatever the button says. `FR-START-08` is a fact about
                // the product, not a message shown only while the feature is missing.
                Text(model.startUnavailableExplanation)
                    .kultaraFont(.body)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)

                switch model.startState {
                case .unavailable:
                    EmptyView()
                case .start:
                    Button(UIStrings.string(.runStartAction, language)) { model.tapStart() }
                        .buttonStyle(.seal)
                case .resume(_, let progressText):
                    LabelledValue(label: UIStrings.string(.homeActiveRunHeading, language),
                                  value: progressText, emphasised: true)
                    Button(UIStrings.string(.runResumeAction, language)) { model.tapStart() }
                        .buttonStyle(.seal)
                }
            }
        }
    }
}
