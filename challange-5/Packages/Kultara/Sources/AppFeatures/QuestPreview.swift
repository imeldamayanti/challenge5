import ContentKit
import DesignSystem
import RunEngine
import SwiftUI

/// A labelled claim, ready to render. `FR-CP-05` — the accuracy label is visible, as text, never
/// behind a tap.
public struct LoreBlockPresentation: Sendable, Identifiable, Equatable {
    /// Which palette ink the chip uses. An enum rather than a `KeyPath`, so the presentation
    /// stays `Sendable` and the palette lookup happens where the palette actually is — in the view.
    public enum Ink: Sendable, Equatable {
        case documented, oral

        var path: KeyPath<KultaraPalette, SRGBColor> {
            switch self {
            case .documented: \.documentedInk
            case .oral: \.oralInk
            }
        }
    }

    public let id: Int
    public let text: String
    public let accuracyLabel: String
    public let appearance: ChipAppearance
    public let ink: Ink
}

/// One row in the preview's checkpoint list.
///
/// There is deliberately no field here that could hold a lore segment or a clue. `FR-DISC-04` says
/// Place names and the map are shown and the story is not, and the cheapest way to keep that true is
/// to leave nowhere to put it.
public struct CheckpointPreviewRow: Sendable, Identifiable, Equatable {
    public let id: String
    public let orderIndex: Int
    /// `NFR-I18N-04` — the official local form, in either interface language.
    public let placeName: String
    public let isSacred: Bool
    public let dressCodeText: String
    public let photoPolicyText: String
    /// `NFR-A11Y-07` — nil when the Place has no steps, so the disclosure is honest either way.
    public let stepsText: String?
    public let surfaceText: String
    public let accessibilityNotes: String
    public let openingText: String
}

@MainActor
@Observable
public final class QuestPreviewViewModel {

    public let questID: String
    public let language: ContentLanguage

    public let title: String
    public let region: String
    public let hookLore: [LoreBlockPresentation]
    public let descriptionText: String

    public let distanceText: String
    public let walkingTimeText: String
    public let totalDurationText: String

    public let costText: String
    public let costBreakdown: [(placeName: String, amountText: String)]
    public let estimatedCostMinorUnits: Int
    public let costBreakdownTotalMinor: Int

    public let terrainText: String
    public let recommendedWindowText: String
    public let latestStartText: String
    public let safetyNotes: String

    public let checkpoints: [CheckpointPreviewRow]
    public let routeImageURL: URL?

    /// `FR-DISC-06` — non-blocking, and it names the site that closes and its closing time, or it
    /// is not actionable.
    public let lateStartWarning: String?

    /// What the start control does when tapped.
    ///
    /// `FR-START-08` is not weakened by any of these: none of them starts a Run. They open the
    /// arrival screen, where the radius and the accuracy gate decide. The distinction matters —
    /// preview must remain fully usable at any location on earth (`FR-DISC-01`), and the only way
    /// to have both is for the button to lead to the gate rather than through it.
    public enum StartState: Sendable, Equatable {
        /// No Run store is wired — previews and tests. The screen says so rather than offering a
        /// control that does nothing.
        case unavailable
        case start
        /// `FR-START-06` — an existing draft, offering resume or restart.
        case resume(runID: UUID, progressText: String)
    }

    public private(set) var startState: StartState = .unavailable
    public private(set) var isChoosingResumeOrRestart = false
    public let startUnavailableExplanation: String

    /// Called with `restart == true` when the user chose to discard an existing draft. The screen
    /// that owns location does the starting; this one only asks which walk is meant.
    public var onBeginRun: ((_ restart: Bool) -> Void)?

    public init?(
        repository: any ContentRepository,
        questID: String,
        language: ContentLanguage,
        runEngine: RunEngine? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard let quest = (try? repository.quest(id: questID)) ?? nil else { return nil }

        self.questID = quest.id
        self.language = language
        let formatter = ContentFormatter(language: language)

        title = quest.title.value(for: language)
        region = quest.region
        descriptionText = quest.description.value(for: language)
        hookLore = quest.hookLore.enumerated().map { index, block in
            LoreBlockPresentation(
                id: index,
                text: block.text.value(for: language),
                accuracyLabel: formatter.accuracyLabel(block.accuracy),
                appearance: block.accuracy == .documented ? .documented : .oral,
                ink: block.accuracy == .documented ? .documented : .oral)
        }

        distanceText = formatter.distance(metres: quest.route.totalDistanceM)
        walkingTimeText = formatter.duration(minutes: quest.route.walkingTimeMin)
        totalDurationText = formatter.duration(minutes: quest.route.totalDurationMin)

        costText = formatter.cost(
            amount: quest.estimatedCost.amount, currency: quest.estimatedCost.currency)
        estimatedCostMinorUnits = quest.estimatedCost.amount
        costBreakdownTotalMinor = quest.estimatedCost.breakdown.reduce(0) { $0 + $1.amount }
        costBreakdown = quest.estimatedCost.breakdown.map { entry in
            let place = (try? repository.place(id: entry.placeId)) ?? nil
            return (placeName: place?.nameOfficial.value(for: language) ?? entry.placeId,
                    amountText: formatter.cost(amount: entry.amount, currency: quest.estimatedCost.currency))
        }

        terrainText = quest.terrainSummary.value(for: language)
        recommendedWindowText = formatter.window(quest.recommendedStartWindow, calendar: calendar)
        latestStartText = formatter.time(quest.hardLatestStart, calendar: calendar)
        safetyNotes = quest.safetyNotes.value(for: language)

        let places = quest.orderedCheckpoints.map { checkpoint -> (Checkpoint, Place?) in
            (checkpoint, (try? repository.place(id: checkpoint.placeId)) ?? nil)
        }

        checkpoints = places.map { checkpoint, place in
            let steps: String? = {
                guard let place, place.accessibility.hasSteps else { return nil }
                if let count = place.accessibility.stepCount {
                    return "\(UIStrings.string(.previewStepsPresent, language)) · \(count)"
                }
                return UIStrings.string(.previewStepsPresent, language)
            }()
            let opening = place?.visitingHours.weekly.first.map {
                "\(formatter.time($0.open, calendar: calendar))–\(formatter.time($0.close, calendar: calendar))"
            } ?? ""
            return CheckpointPreviewRow(
                id: checkpoint.id,
                orderIndex: checkpoint.orderIndex,
                placeName: place?.nameOfficial.value(for: language) ?? checkpoint.placeId,
                isSacred: place?.isSacred ?? false,
                dressCodeText: place?.dressCode.value(for: language) ?? "",
                photoPolicyText: place.map { formatter.photoPolicy($0.photoPolicy.level) } ?? "",
                stepsText: steps,
                surfaceText: place?.accessibility.surface ?? "",
                accessibilityNotes: place?.accessibility.notes.value(for: language) ?? "",
                openingText: opening)
        }

        routeImageURL = (try? repository.assetURL(quest.route.previewImageAsset)) ?? nil

        startUnavailableExplanation = UIStrings.string(.previewStartUnavailableDetail, language)

        if let runEngine {
            if let draft = (try? runEngine.activeRun(questID: quest.id)) ?? nil {
                startState = .resume(
                    runID: draft.id,
                    progressText: String(
                        format: UIStrings.string(.checkpointProgress, language),
                        draft.reachedCount, draft.checkpointCount))
            } else {
                startState = .start
            }
        }

        // FR-DISC-06. The boundary belongs to the user: exactly at `hardLatestStart` is a start
        // time the content endorses, so the warning fires strictly after it.
        let minutesNow = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        if minutesNow > quest.hardLatestStart.minutesFromMidnight,
           let closing = Self.earliestClosing(for: quest, repository: repository) {
            let template = UIStrings.string(.previewLateWarning, language)
            lateStartWarning = String(
                format: template,
                closing.place.nameOfficial.value(for: language),
                formatter.time(closing.time, calendar: calendar))
        } else {
            lateStartWarning = nil
        }
    }

    // MARK: - Starting

    public func tapStart() {
        switch startState {
        case .unavailable: break
        case .start: onBeginRun?(false)
        case .resume: isChoosingResumeOrRestart = true
        }
    }

    public func chooseResume() {
        isChoosingResumeOrRestart = false
        onBeginRun?(false)
    }

    /// `FR-START-06` — the warning that photos and reflections go is shown by the dialog that calls
    /// this, not buried afterwards.
    public func chooseRestart() {
        isChoosingResumeOrRestart = false
        onBeginRun?(true)
    }

    public func cancelResumeChoice() {
        isChoosingResumeOrRestart = false
    }

    /// The site that shuts first is the one that decides whether the walk can finish, so it is the
    /// one the warning names.
    private static func earliestClosing(
        for quest: Quest,
        repository: any ContentRepository
    ) -> (place: Place, time: TimeOfDay)? {
        var earliest: (place: Place, time: TimeOfDay)?
        for checkpoint in quest.orderedCheckpoints {
            guard let place = (try? repository.place(id: checkpoint.placeId)) ?? nil,
                  let close = place.visitingHours.weekly.map(\.close).min() else { continue }
            if earliest == nil || close < earliest!.time {
                earliest = (place, close)
            }
        }
        return earliest
    }

    /// Every string this screen renders. Used by the `FR-DISC-04` test to prove no checkpoint lore
    /// or clue text has leaked in — the assertion is about the text, not about property names.
    public var allRenderedText: [String] {
        var strings = [title, region, descriptionText, distanceText, walkingTimeText,
                       totalDurationText, costText, terrainText, recommendedWindowText,
                       latestStartText, safetyNotes, startUnavailableExplanation]
        strings += hookLore.flatMap { [$0.text, $0.accuracyLabel] }
        strings += costBreakdown.flatMap { [$0.placeName, $0.amountText] }
        strings += checkpoints.flatMap {
            [$0.placeName, $0.dressCodeText, $0.photoPolicyText, $0.stepsText ?? "",
             $0.surfaceText, $0.accessibilityNotes, $0.openingText]
        }
        if let lateStartWarning { strings.append(lateStartWarning) }
        return strings
    }
}

// MARK: - View

public struct QuestPreviewView: View {
    @Environment(\.kultaraPalette) private var palette
    private let model: QuestPreviewViewModel

    public init(model: QuestPreviewViewModel) {
        self.model = model
    }

    private var language: ContentLanguage { model.language }

    public var body: some View {
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
        Section(heading: .previewHookHeading, language: language) {
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
        Section(heading: .previewAboutHeading, language: language) {
            Text(model.descriptionText)
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var route: some View {
        Section(heading: .previewRouteHeading, language: language) {
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
        Section(heading: .previewCheckpointsHeading, language: language) {
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
        Section(heading: .previewCostHeading, language: language) {
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
        Section(heading: .previewTerrainHeading, language: language) {
            Text(model.terrainText)
                .kultaraFont(.body)
                .foregroundStyle(palette.ink.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timing: some View {
        Section(heading: .previewTimingHeading, language: language) {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                LabelledValue(label: UIStrings.string(.previewRecommendedWindow, language),
                              value: model.recommendedWindowText)
                LabelledValue(label: UIStrings.string(.previewLatestStart, language),
                              value: model.latestStartText)
            }
        }
    }

    private var safety: some View {
        Section(heading: .previewSafetyHeading, language: language) {
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

private struct Section<Content: View>: View {
    let heading: UIStringKey
    let language: ContentLanguage
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            KultaraSectionHeading(UIStrings.string(heading, language))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
