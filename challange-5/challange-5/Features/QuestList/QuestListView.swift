import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

struct QuestListView: View {
    @Environment(\.kultaraPalette) private var palette

    enum Surface: String, CaseIterable {
        case list, map
    }

    enum MapScope: String, CaseIterable {
        case denpasar, wholeBali
    }

    private let model: QuestListViewModel
    private let mapModel: RegionMapViewModel?
    private let journal: RunJournalSummary
    private let makeLocationProvider: (@MainActor () -> any LocationProviding)?
    private let onSelect: (String) -> Void

    /// Owned by whatever presents this screen rather than held here, because the map is full-bleed
    /// and the floating tab bar belongs to the root: the root cannot hide a bar for a surface it
    /// cannot see.
    @Binding private var surface: Surface
    @State private var mapScope: MapScope = .denpasar

    init(
        model: QuestListViewModel,
        mapModel: RegionMapViewModel? = nil,
        surface: Binding<Surface>,
        journal: RunJournalSummary = .empty,
        makeLocationProvider: (@MainActor () -> any LocationProviding)? = nil,
        onSelect: @escaping (String) -> Void
    ) {
        self.model = model
        self.mapModel = mapModel
        _surface = surface
        self.journal = journal
        self.makeLocationProvider = makeLocationProvider
        self.onSelect = onSelect
    }

    private var language: ContentLanguage { model.language }

    var body: some View {
        // The map is full-bleed in the Home design — it runs under the status bar and to every
        // edge — so it replaces the whole screen rather than sitting below the masthead. Only the
        // list surface keeps the header.
        Group {
            if surface == .map {
                mapSurface
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

    @ViewBuilder private var mapSurface: some View {
        if let mapModel {
            // `275:2309` and `276:2520` are one screen with two grounds, so the discovery map is
            // `QuestMapScreen` rather than either frame alone. It falls back to `RegionMapView` —
            // the illustrated surface that needs no network — when the basemap does not load.
            QuestMapScreen(
                model: mapModel,
                map: QuestMapViewModel(locationProvider: makeLocationProvider?()),
                onSelect: { questID in
                    surface = .list
                    onSelect(questID)
                },
                onClose: { surface = .list }
            )
        } else if mapScope == .denpasar {
            HisploraInteractiveMapScreen(
                model: HisploraMapViewModel(
                    language: language,
                    locationProvider: makeLocationProvider?()
                ),
                onBack: { surface = .list },
                onSwitchScope: { mapScope = .wholeBali },
                onBeginTrace: { trace in
                    surface = .list
                    onSelect(trace.placeId ?? "badung-empat-wajah")
                }
            )
        } else {
            HisploraBaliMapScreen(
                model: HisploraBaliMapViewModel(
                    language: language,
                    locationProvider: makeLocationProvider?()
                ),
                onBack: { surface = .list },
                onSwitchScope: { mapScope = .denpasar },
                onOpenQuest: { landmark in
                    surface = .list
                    onSelect(landmark.id == "denpasar-heritage-district" ? "badung-empat-wajah" : landmark.id)
                }
            )
        }
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
        .kultaraSpeckledGround(palette.paper)
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
                // Owner spec, 2026-08-27: the masthead is set at the frame's own values —
                // SF Pro Display Medium 31 / 0.38 tracking / #141212 — rather than at
                // `.questTitleLarge` on `palette.seal`. Two deliberate bends: the size is fixed,
                // so it does not answer Dynamic Type (NFR-A11Y-01, the same bend the quest card's
                // caption makes), and the ink is a literal rather than a measured token
                // (18.6:1 on `paper`, so contrast is not what it costs).
                Text(UIStrings.string(.homeMasthead, language))
                    .font(Font.custom("SF Pro Display", size: 31).weight(.medium))
                    .kerning(0.38)
                    .foregroundColor(Color(red: 0.08, green: 0.07, blue: 0.07))
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
                // `FR-RUN-03` — a walk in progress is still reachable from this screen, but not
                // as a second card: its own catalogue card wears the ongoing tag
                // (`journal.activeQuestIDs`) and tapping it resumes the walk. A separate
                // "In Progress" entry above the list said the same thing twice.

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
                            QuestCard(
                                row: row, language: language,
                                isOngoing: journal.activeQuestIDs.contains(row.questID))
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

                // Owner instruction, 2026-08-27: nothing but quest cards stands on this screen.
                // What used to follow them is gone — the nearby-sidequest list (`FR-SIDE-07`),
                // the dummy gulungan entry, the finished-walks section (`FR-DONE-06`, still
                // listed in the Journal and on Profile → Quests) and the footer notices about
                // the offline promise, the filler cards and the sample content.
            }
            .padding(.horizontal, KultaraMetrics.xl)
            .kultaraFloatingTabBarClearance()
        }
    }
}
