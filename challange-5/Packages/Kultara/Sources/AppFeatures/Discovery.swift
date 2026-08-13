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

    /// What the reader has typed into the Home design's search field. Filtering happens over the
    /// rows already in memory: `FR-DISC-01` and `AD-3` mean browsing works in airplane mode, and a
    /// search that queried anything would be the first thing in the app that does not.
    public var searchText: String = ""

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

    /// The rows the list draws. Order is the authored order (`FR-DISC-03`) with non-matches
    /// removed — never a relevance ranking, which would make the same content appear in a
    /// different sequence depending on what was typed.
    public var visibleRows: [QuestListRow] {
        let query = Self.fold(searchText)
        guard !query.isEmpty else { return rows }
        return rows.filter { row in
            Self.fold(row.title).contains(query) || Self.fold(row.region).contains(query)
        }
    }

    /// True only when a search is active and matched nothing, so the screen can say so. Showing
    /// everything on no match would leave the reader unable to tell "no match" from "broken".
    public var hasNoSearchResults: Bool {
        !Self.fold(searchText).isEmpty && visibleRows.isEmpty
    }

    /// Case- and diacritic-insensitive, because Indonesian place names carry marks the reader will
    /// not type.
    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
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

    /// Owned by whatever presents this screen rather than held here, because the map is full-bleed
    /// and the floating tab bar belongs to the root: the root cannot hide a bar for a surface it
    /// cannot see.
    @Binding private var surface: Surface

    public init(
        model: QuestListViewModel,
        mapModel: RegionMapViewModel? = nil,
        surface: Binding<Surface>,
        onSelect: @escaping (String) -> Void
    ) {
        self.model = model
        self.mapModel = mapModel
        _surface = surface
        self.onSelect = onSelect
    }

    private var language: ContentLanguage { model.language }

    public var body: some View {
        // The map is full-bleed in the Home design — it runs under the status bar and to every
        // edge — so it replaces the whole screen rather than sitting below the masthead. Only the
        // list surface keeps the header.
        Group {
            if surface == .map, let mapModel {
                RegionMapView(model: mapModel,
                              onSelect: onSelect,
                              onClose: { surface = .list })
            } else {
                listSurface
            }
        }
        .navigationTitle(UIStrings.string(.questListTitle, language))
        .kultaraInlineNavigationTitle()
        // Home has no bar at all in this design: the masthead is on the page and the map is
        // full-bleed. The title above stays set for VoiceOver's rotor and for the back button of
        // whatever pushes on top of this.
        .kultaraHiddenNavigationBar()
    }

    private var listSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The screen's name is set on the page, not in the chrome — the design's masthead is
            // the first thing on the sheet, and a navigation bar cannot hold one.
            header
                .padding(.horizontal, KultaraMetrics.lg)
                .padding(.bottom, KultaraMetrics.md)
            list
        }
        .background(palette.paper.color)
    }

    /// Masthead and the search row beneath it, as the Home design opens: the title in the serif,
    /// in seal red, then the field and the button that swaps in the map.
    private var header: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            Text(UIStrings.string(.questListTitle, language))
                .kultaraFont(.questTitleLarge)
                .foregroundStyle(palette.seal.color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: KultaraMetrics.md) {
                KultaraSearchField(
                    placeholder: UIStrings.string(.questListSearchPlaceholder, language),
                    clearLabel: UIStrings.string(.questListSearchClear, language),
                    text: Binding(get: { model.searchText },
                                  set: { model.searchText = $0 }))

                if let mapModel {
                    MapSurfaceButton(
                        thumbnail: mapModel.mapImageURL.flatMap(BundledImage.load),
                        label: UIStrings.string(.questListMapTab, language)) {
                            surface = .map
                        }
                }
            }

            // `AD-3` in one line, kept because it is the promise the whole architecture is built
            // on and the reference sheet simply had nothing to say in its place.
            Text(UIStrings.string(.questListSubtitle, language))
                .kultaraFont(.caption)
                .foregroundStyle(palette.inkMuted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                if model.isEmpty || model.hasNoSearchResults {
                    KultaraCard {
                        Text(UIStrings.string(
                            model.hasNoSearchResults ? .questListSearchEmpty : .questListEmpty,
                            language))
                            .kultaraFont(.body)
                            .foregroundStyle(palette.ink.color)
                    }
                } else {
                    ForEach(model.visibleRows) { row in
                        Button { onSelect(row.questID) } label: {
                            QuestCard(row: row, language: language)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(UIStrings.string(.settingsPlaceholderContentNotice, language))
                    .kultaraFont(.caption)
                    .foregroundStyle(palette.inkMuted.color)
                    .padding(.top, KultaraMetrics.sm)
            }
            .padding(.horizontal, KultaraMetrics.lg)
            .padding(.bottom, KultaraMetrics.lg)
        }
    }
}

private struct QuestCard: View {
    @Environment(\.kultaraPalette) private var palette
    let row: QuestListRow
    let language: ContentLanguage

    var body: some View {
        // The Home design's card: one photograph, rounded, with the title and the facts written
        // over its lower edge and a filled arrow in the corner. The text sits on `photoScrim` at
        // full opacity and the gradient above it is decoration, because a ratio measured against
        // "whatever the photo happens to be" is not a measurement (`NFR-A11Y-03`).
        //
        // What the design leaves out is still here — FR-DISC-02 requires distance, FR-DISC-05
        // requires the cost total on the card itself, and NFR-CONT-06 requires walking time and
        // total time as two figures. So the facts run to two lines rather than the design's one,
        // and stack at accessibility sizes instead of dropping any of it.
        //
        // The caption is laid out first and the photograph is its *background*: a background
        // cannot make its parent smaller, so at the largest accessibility sizes the card grows to
        // fit the words instead of clipping them (`NFR-A11Y-01`). The reverse — a fixed-height
        // card with the caption overlaid — loses the title off the top of the scrim, which is
        // exactly what it did before this was written down.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [palette.photoScrim.color.opacity(0), palette.photoScrim.color],
                startPoint: .top, endPoint: .bottom)
                .frame(height: fadeHeight)
                .accessibilityHidden(true)
            caption
                .background(palette.photoScrim.color)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: cardHeight)
        .background { hero }
        .clipShape(RoundedRectangle(cornerRadius: KultaraMetrics.photoCardCornerRadius))
        .overlay(alignment: .topTrailing) {
            SealArrowBadge()
                .padding(KultaraMetrics.md)
        }
        .accessibilityElement(children: .combine)
    }

    /// The photograph's own height at default size. It is a minimum, not a height: the caption
    /// decides how tall the card actually is.
    @ScaledMetric(relativeTo: .subheadline) private var scaledCardHeight: CGFloat = 224
    @ScaledMetric(relativeTo: .subheadline) private var fadeHeight: CGFloat = 72
    private var cardHeight: CGFloat { min(scaledCardHeight, 340) }

    @ViewBuilder private var hero: some View {
        if let url = row.heroImageURL, let image = BundledImage.load(url) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        } else {
            // No hero is not a broken card, just a plainer one — and the caption still lands on
            // the scrim, so its ratio is the measured one either way.
            palette.paperSunken.color
        }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
            Text(row.title)
                .kultaraFont(.questTitle)
                .foregroundStyle(palette.inkOnPhoto.color)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    HStack(spacing: KultaraMetrics.md) { region; walking; checkpoints }
                    HStack(spacing: KultaraMetrics.md) { total; distance; cost }
                }
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    region; walking; checkpoints; total; distance; cost
                }
            }
        }
        .padding(KultaraMetrics.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var region: some View {
        PhotoCardFact(symbolName: "mappin", label: UIStrings.string(.labelRegion, language),
                      value: row.region)
    }
    private var checkpoints: some View {
        PhotoCardFact(symbolName: "flag", label: UIStrings.string(.previewCheckpointsHeading, language),
                      value: row.checkpointCountText)
    }
    private var walking: some View {
        PhotoCardFact(symbolName: "clock", label: UIStrings.string(.labelWalkingTime, language),
                      value: row.walkingTimeText)
    }
    private var total: some View {
        PhotoCardFact(symbolName: "hourglass", label: UIStrings.string(.labelTotalDuration, language),
                      value: row.totalDurationText)
    }
    private var distance: some View {
        PhotoCardFact(symbolName: "figure.walk",
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
