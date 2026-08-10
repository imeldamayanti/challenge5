import ContentKit
import DesignSystem
import SwiftUI

/// One card in the discovery list, carrying every field `FR-DISC-02` requires plus the quest id, so
/// reaching preview is one tap and not a fetch (`FR-DISC-07`).
public struct QuestListRow: Sendable, Identifiable, Equatable {
    public let questID: String
    public let title: String
    public let region: String
    public let distanceText: String
    public let walkingTimeText: String
    public let totalDurationText: String
    public let costText: String
    /// `FR-DISC-05` — a quest that costs money shows its total on the card, not only in preview.
    public let showsCostOnCard: Bool

    public var id: String { questID }

    public init(
        questID: String,
        title: String,
        region: String,
        distanceText: String,
        walkingTimeText: String,
        totalDurationText: String,
        costText: String,
        showsCostOnCard: Bool
    ) {
        self.questID = questID
        self.title = title
        self.region = region
        self.distanceText = distanceText
        self.walkingTimeText = walkingTimeText
        self.totalDurationText = totalDurationText
        self.costText = costText
        self.showsCostOnCard = showsCostOnCard
    }
}

/// `FR-DISC-01` — browsing works at any location on earth, with no network, and with location
/// permission denied. There is nothing in this type that could want any of the three.
@MainActor
@Observable
public final class QuestListViewModel {

    public private(set) var rows: [QuestListRow] = []
    /// A content problem must leave the screen usable rather than take the app down
    /// (`NFR-REL-04`).
    public private(set) var loadFailed = false

    public let language: ContentLanguage

    public init(
        repository: any ContentRepository,
        language: ContentLanguage,
        suppressedQuestIDs: Set<String> = [],
        suppressedPlaceIDs: Set<String> = []
    ) {
        self.language = language
        let formatter = ContentFormatter(language: language)
        do {
            let quests = try repository.quests(
                suppressingQuestIDs: suppressedQuestIDs,
                suppressingPlaceIDs: suppressedPlaceIDs)
            rows = quests.map { quest in
                QuestListRow(
                    questID: quest.id,
                    title: quest.title.value(for: language),
                    region: quest.region,
                    distanceText: formatter.distance(metres: quest.route.totalDistanceM),
                    walkingTimeText: formatter.duration(minutes: quest.route.walkingTimeMin),
                    totalDurationText: formatter.duration(minutes: quest.route.totalDurationMin),
                    costText: formatter.cost(
                        amount: quest.estimatedCost.amount, currency: quest.estimatedCost.currency),
                    showsCostOnCard: !quest.estimatedCost.isFree)
            }
        } catch {
            rows = []
            loadFailed = true
        }
    }

    public var isEmpty: Bool { rows.isEmpty }
}

// MARK: - View

public struct QuestListView: View {
    @Environment(\.kultaraPalette) private var palette

    private let model: QuestListViewModel
    private let onSelect: (String) -> Void
    private let onOpenSettings: () -> Void

    public init(
        model: QuestListViewModel,
        onSelect: @escaping (String) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.model = model
        self.onSelect = onSelect
        self.onOpenSettings = onOpenSettings
    }

    private var language: ContentLanguage { model.language }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                Text(UIStrings.string(.questListSubtitle, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)

                if model.isEmpty {
                    KultaraCard {
                        Text(UIStrings.string(.questListEmpty, language))
                            .kultaraFont(.body)
                            .foregroundStyle(palette.ink.color)
                    }
                } else {
                    ForEach(model.rows) { row in
                        Button { onSelect(row.questID) } label: {
                            QuestCard(row: row, language: language)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(UIStrings.string(.settingsPlaceholderContentNotice, language))
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
            }
            .padding(KultaraMetrics.lg)
        }
        .background(palette.paper.color)
        .navigationTitle(UIStrings.string(.questListTitle, language))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { onOpenSettings() } label: {
                    Image(systemName: "gearshape")
                        .kultaraTapTarget()
                }
                .accessibilityLabel(UIStrings.string(.settingsTitle, language))
            }
        }
    }
}

private struct QuestCard: View {
    @Environment(\.kultaraPalette) private var palette
    let row: QuestListRow
    let language: ContentLanguage

    var body: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.md) {
                Text(row.title)
                    .kultaraFont(.questTitle)
                    .foregroundStyle(palette.ink.color)

                LabelledValue(label: UIStrings.string(.labelRegion, language), value: row.region)
                KultaraRule()

                // A grid rather than a single line: at accessibility sizes a row of four metrics
                // wraps into an unreadable ribbon (`NFR-A11Y-01`).
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    LabelledValue(label: UIStrings.string(.labelDistance, language), value: row.distanceText)
                    LabelledValue(label: UIStrings.string(.labelWalkingTime, language), value: row.walkingTimeText)
                    LabelledValue(label: UIStrings.string(.labelTotalDuration, language), value: row.totalDurationText)
                    // Shown either way; `showsCostOnCard` marks the case FR-DISC-05 is about,
                    // which gets the seal ink so a cost is not something the eye skips.
                    LabelledValue(
                        label: UIStrings.string(.labelEstimatedCost, language),
                        value: row.costText,
                        emphasised: row.showsCostOnCard)
                }
            }
        }
    }
}

struct LabelledValue: View {
    @Environment(\.kultaraPalette) private var palette
    let label: String
    let value: String
    var emphasised: Bool = false

    var body: some View {
        // `ViewThatFits` keeps one line when it fits and stacks when Dynamic Type makes it too
        // wide, rather than truncating either side.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: KultaraMetrics.sm) {
                labelText
                Spacer(minLength: KultaraMetrics.sm)
                valueText
            }
            VStack(alignment: .leading, spacing: 2) {
                labelText
                valueText
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var labelText: some View {
        Text(label)
            .kultaraFont(.metadata)
            .foregroundStyle(palette.inkMuted.color)
    }

    private var valueText: some View {
        Text(value)
            .kultaraFont(.metadata)
            .foregroundStyle(emphasised ? palette.seal.color : palette.ink.color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
