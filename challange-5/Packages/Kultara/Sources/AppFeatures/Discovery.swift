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
    /// `FR-CP-08` counts progress in checkpoints, so the card counts them by that name. The Home
    /// mockup labels this "5 quests"; a quest containing quests collides with the glossary.
    public let checkpointCount: Int
    public let checkpointCountText: String
    /// The photograph the card is built around. Nil renders as type on paper rather than as a gap.
    public let heroImageURL: URL?

    public var id: String { questID }

    public init(
        questID: String,
        title: String,
        region: String,
        distanceText: String,
        walkingTimeText: String,
        totalDurationText: String,
        costText: String,
        showsCostOnCard: Bool,
        checkpointCount: Int = 0,
        checkpointCountText: String = "",
        heroImageURL: URL? = nil
    ) {
        self.questID = questID
        self.title = title
        self.region = region
        self.distanceText = distanceText
        self.walkingTimeText = walkingTimeText
        self.totalDurationText = totalDurationText
        self.costText = costText
        self.showsCostOnCard = showsCostOnCard
        self.checkpointCount = checkpointCount
        self.checkpointCountText = checkpointCountText
        self.heroImageURL = heroImageURL
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
                    showsCostOnCard: !quest.estimatedCost.isFree,
                    checkpointCount: quest.checkpointCount,
                    checkpointCountText: formatter.checkpointCount(quest.checkpointCount),
                    heroImageURL: quest.heroImageAsset.flatMap { (try? repository.assetURL($0)) ?? nil })
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

    public enum Surface: String, CaseIterable {
        case list, map
    }

    private let model: QuestListViewModel
    private let mapModel: RegionMapViewModel?
    private let onSelect: (String) -> Void
    private let onOpenSettings: () -> Void

    @State private var surface: Surface = .list

    public init(
        model: QuestListViewModel,
        mapModel: RegionMapViewModel? = nil,
        onSelect: @escaping (String) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.model = model
        self.mapModel = mapModel
        self.onSelect = onSelect
        self.onOpenSettings = onOpenSettings
    }

    private var language: ContentLanguage { model.language }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The screen's name is set on the page, not in the chrome — the theme's heading is a
            // line typed at the top of a sheet, and a navigation bar cannot hold one. `.inline`
            // below keeps the system from setting it a second time in its own face.
            Text(UIStrings.string(.questListTitle, language))
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.ink.color)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.bottom, KultaraMetrics.sm)

            Group {
                if surface == .map, let mapModel {
                    RegionMapView(model: mapModel, onSelect: onSelect)
                } else {
                    list
                }
            }
        }
        .background(palette.paper.color)
        .navigationTitle(UIStrings.string(.questListTitle, language))
        .kultaraInlineNavigationTitle()
        .toolbar {
            if mapModel != nil {
                ToolbarItem(placement: .principal) {
                    Picker("", selection: $surface) {
                        Text(UIStrings.string(.questListListTab, language)).tag(Surface.list)
                        Text(UIStrings.string(.questListMapTab, language)).tag(Surface.map)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { onOpenSettings() } label: {
                    Image(systemName: "gearshape")
                        .kultaraTapTarget()
                }
                .accessibilityLabel(UIStrings.string(.settingsTitle, language))
            }
        }
    }

    private var list: some View {
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
    }
}

private struct QuestCard: View {
    @Environment(\.kultaraPalette) private var palette
    let row: QuestListRow
    let language: ContentLanguage

    var body: some View {
        // The card from the Home design: photograph, scrim, typed title, one metadata row. What the
        // design left out is back — FR-DISC-02 requires distance, FR-DISC-05 requires the cost total
        // on the card itself, and NFR-CONT-06 requires walking time and total time as two figures.
        // So the metadata runs to two lines rather than one, and the layout stacks it at
        // accessibility sizes instead of dropping any of it.
        ZStack(alignment: .bottomLeading) {
            hero
            PhotoScrim(height: scrimHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
            caption
        }
        .frame(minHeight: 210)
        .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.sm))
        .overlay(
            RoundedRectangle(cornerRadius: KultaraMetrics.sm)
                .stroke(palette.rule.color, lineWidth: KultaraMetrics.hairline))
        .overlay(alignment: .topTrailing) {
            SealArrowBadge()
                .padding(KultaraMetrics.sm)
        }
        .accessibilityElement(children: .combine)
    }

    /// Grows with Dynamic Type, because the caption block does.
    @ScaledMetric(relativeTo: .subheadline) private var scrimHeight: CGFloat = 190

    @ViewBuilder private var hero: some View {
        if let url = row.heroImageURL, let image = BundledImage.load(url) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        } else {
            // No hero is not a broken card, just a plainer one.
            palette.paperSunken.color
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            Text(row.title)
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.inkOnPhoto.color)
                .fixedSize(horizontal: false, vertical: true)

            // Two rows of facts, wrapping rather than truncating. FR-DISC-02's six fields do not
            // fit on one line at any accessibility size, and dropping one is not an option.
            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    HStack(spacing: KultaraMetrics.md) { region; checkpoints; walking }
                    HStack(spacing: KultaraMetrics.md) { total; distance; cost }
                }
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    region; checkpoints; walking; total; distance; cost
                }
            }
        }
        .padding(KultaraMetrics.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var region: some View {
        PhotoCardFact(symbolName: "mappin", label: UIStrings.string(.labelRegion, language), value: row.region)
    }
    private var checkpoints: some View {
        PhotoCardFact(symbolName: "flag", label: UIStrings.string(.previewCheckpointsHeading, language),
                      value: row.checkpointCountText)
    }
    private var walking: some View {
        PhotoCardFact(symbolName: "figure.walk", label: UIStrings.string(.labelWalkingTime, language),
                      value: row.walkingTimeText)
    }
    private var total: some View {
        PhotoCardFact(symbolName: "clock", label: UIStrings.string(.labelTotalDuration, language),
                      value: row.totalDurationText)
    }
    private var distance: some View {
        PhotoCardFact(symbolName: "point.topleft.down.curvedto.point.bottomright.up",
                      label: UIStrings.string(.labelDistance, language), value: row.distanceText)
    }
    /// `FR-DISC-05`. Emphasised when the quest costs money — by weight and symbol, not by hue,
    /// since on a photograph the seal red is not a measurable colour.
    private var cost: some View {
        PhotoCardFact(symbolName: row.showsCostOnCard ? "banknote" : "gift",
                      label: UIStrings.string(.labelEstimatedCost, language),
                      value: row.costText, emphasised: row.showsCostOnCard)
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
