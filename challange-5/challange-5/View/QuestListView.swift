import ContentKit
import DesignSystem
import SwiftUI

struct QuestListView: View {
    @Environment(\.kultaraPalette) private var palette

    enum Surface: String, CaseIterable {
        case list, map
    }

    private let model: QuestListViewModel
    private let mapModel: RegionMapViewModel?
    private let journal: RunJournalSummary
    private let onSelect: (String) -> Void
    private let onOpenRun: (UUID) -> Void

    /// Owned by whatever presents this screen rather than held here, because the map is full-bleed
    /// and the floating tab bar belongs to the root: the root cannot hide a bar for a surface it
    /// cannot see.
    @Binding private var surface: Surface

    init(
        model: QuestListViewModel,
        mapModel: RegionMapViewModel? = nil,
        surface: Binding<Surface>,
        journal: RunJournalSummary = .empty,
        onSelect: @escaping (String) -> Void,
        onOpenRun: @escaping (UUID) -> Void = { _ in }
    ) {
        self.model = model
        self.mapModel = mapModel
        _surface = surface
        self.journal = journal
        self.onSelect = onSelect
        self.onOpenRun = onOpenRun
    }

    private var language: ContentLanguage { model.language }

    var body: some View {
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
                .padding(.horizontal, KultaraMetrics.xl)
                .padding(.bottom, KultaraMetrics.xl)
            list
        }
        .background(palette.paper.color)
    }

    /// Masthead and the search field beneath it, as the Ngalcer Home frame opens (`28:171`,
    /// `28:168`): the title in the serif, in seal red, with the round button that swaps in the map
    /// on the same line, and the search pill running the full width below it.
    ///
    /// The frame sets the title in a warm brown (#6E3B26) rather than this theme's brick red
    /// (#8C2F1E). The seal is what the palette measures and what every other accent on the screen
    /// already is, so the theme's own token stands: two near-identical browns doing the same job
    /// would be one unmeasured colour more than the page needs.
    private var header: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            HStack(alignment: .center, spacing: KultaraMetrics.md) {
                Text(UIStrings.string(.homeMasthead, language))
                    .kultaraFont(.questTitleLarge)
                    .foregroundStyle(palette.seal.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                if mapModel != nil {
                    MapSurfaceButton(label: UIStrings.string(.questListMapTab, language)) {
                        surface = .map
                    }
                }
            }

            KultaraSearchField(
                placeholder: UIStrings.string(.questListSearchPlaceholder, language),
                clearLabel: UIStrings.string(.questListSearchClear, language),
                text: Binding(get: { model.searchText },
                              set: { model.searchText = $0 }))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                // `FR-RUN-03` — a walk in progress has a visible entry point on the home screen,
                // naming the quest and how far it got. Above the catalogue, because an unfinished
                // walk is the one thing on this screen with a claim on the user's attention.
                if let active = journal.activeRun {
                    JournalEntryCard(
                        heading: UIStrings.string(.homeActiveRunHeading, language),
                        entry: active,
                        actionTitle: UIStrings.string(.homeActiveRunAction, language),
                        language: language,
                        action: { onOpenRun(active.id) })
                }

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

                    // The Ngalcer frame draws four cards; the content tree holds one quest. The
                    // remaining three are filler so the screen can be seen as designed — see
                    // `PlaceholderQuestCatalog` for what they are not. They are hidden while a
                    // search is running, because a placeholder that survives a filter reads as a
                    // result.
                    if model.searchText.isEmpty {
                        ForEach(PlaceholderQuestCatalog.all) { entry in
                            PlaceholderQuestCard(entry: entry, language: language)
                        }
                    }
                }

                // `FR-DONE-06` — completed walks are listed and re-openable before the Journal
                // exists. Below the catalogue: these are finished, and they keep.
                if !journal.completed.isEmpty {
                    KultaraSectionHeading(UIStrings.string(.homeCompletedHeading, language))
                    ForEach(journal.completed) { entry in
                        JournalEntryCard(
                            heading: UIStrings.string(.summaryHeading, language),
                            entry: entry,
                            actionTitle: UIStrings.string(.summaryOpenAction, language),
                            language: language,
                            action: { onOpenRun(entry.id) })
                    }
                }

                // The footer the header used to carry. The frame's masthead is a title and a search
                // field and nothing else, so the two things the page still has to say — `AD-3`'s
                // promise that this works with no network, and what the filler cards are — are said
                // at the foot instead of being dropped.
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    Text(UIStrings.string(.questListSubtitle, language))
                    if model.searchText.isEmpty {
                        Text(UIStrings.string(.homePlaceholderCardsNotice, language))
                    }
                    Text(UIStrings.string(.settingsPlaceholderContentNotice, language))
                }
                .kultaraFont(.caption)
                .foregroundStyle(palette.inkMuted.color)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, KultaraMetrics.sm)
            }
            .padding(.horizontal, KultaraMetrics.xl)
            .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
        }
    }
}
