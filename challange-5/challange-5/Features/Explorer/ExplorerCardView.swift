import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// The Profile tab — "Explorer's Card" (Figma `547:2724` Quests, `547:2848` Stamps,
/// `547:2952` Badges).
///
/// One screen with three surfaces, not three screens: the frames differ only in what sits under
/// the strip, and the header, the roundel and the counts are the same object in all three.
///
/// **The name is the reader's own, when there is one.** The frame prints "Umar" under a portrait.
/// There are still no accounts in this build, but the entry screens do ask — `822:2235` promises
/// the display name typed there "will appear on your Explorer's Card and journal", and this is
/// where that promise is kept. A reader who signed in rather than naming themselves, or who has
/// erased their local data, is named by their role instead: the app does not invent one, and the
/// roundel stays empty for the same reason a stock face would be a claim it cannot make.
struct ExplorerCardView: View {
    @Environment(\.hisploraPalette) private var palette

    private let model: ExplorerCardViewModel
    let language: ContentLanguage
    /// Home → Profile → App preferences, which is the only route to Settings now that it is not a
    /// tab. The frame's header row is a `justify-between` with one child; this is the other slot.
    let onOpenPreferences: () -> Void
    /// The walk a row on the Quests tab picks back up. A list of unfinished walks that could not be
    /// resumed from where it is read would be a reminder rather than a card.
    let onResumeRun: (UUID) -> Void

    init(
        model: ExplorerCardViewModel,
        language: ContentLanguage,
        onOpenPreferences: @escaping () -> Void,
        onResumeRun: @escaping (UUID) -> Void = { _ in }
    ) {
        self.model = model
        self.language = language
        self.onOpenPreferences = onOpenPreferences
        self.onResumeRun = onResumeRun
    }

    var body: some View {
        // `547:2953` prints the card's ground as `brownMid` under a fine white speckle, which is
        // `HisploraGround`. See that file for the measured ratios — the sheet is drawn over the
        // token rather than replacing it, so `HisploraThemeTests` still describes this screen.
        HisploraStage(ground: \.paperSheet, grain: true) {
            VStack(spacing: 0) {
                header
                identity
                    .padding(.horizontal, KultaraMetrics.xl)
                    .padding(.vertical, KultaraMetrics.xl)
                HisploraTabStrip(
                    tabs: ExplorerCardPresentation.Tab.allCases,
                    selection: Binding(get: { model.tab }, set: { model.tab = $0 }),
                    title: title(for:))
                ScrollView {
                    surface
                        .padding(.horizontal, KultaraMetrics.xl)
                        .padding(.top, KultaraMetrics.lg)
                        .padding(.bottom, KultaraMetrics.floatingTabBarClearance)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear { model.reload() }
    }

    // MARK: - Header and identity

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(UIStrings.string(.profileHeading, language))
                .kultaraFont(.storyDisplay)
                .foregroundStyle(palette.inkDark.color)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: KultaraMetrics.sm)
            Button {
                onOpenPreferences()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 20))
                    .foregroundStyle(palette.inkDark.color)
                    .kultaraTapTarget()
            }
            .buttonStyle(.plain)
            // Named "Settings", not "App preferences": it is the same screen the chart reaches as
            // Profile → App preferences, and `DiscoveryFlowUITests.openSettings` finds it by that
            // name. One control, one name.
            .accessibilityLabel(UIStrings.string(.settingsTitle, language))
        }
        .padding(.horizontal, KultaraMetrics.xl)
        .padding(.top, KultaraMetrics.lg)
    }

    private var identity: some View {
        HStack(spacing: KultaraMetrics.xl) {
            HisploraExplorerRoundel(
                accessibilityLabel: model.presentation.name
            ) {
                // Deliberately empty — see the note at the head of this file.
                Rectangle().fill(palette.paperWarm.color)
            }
            .frame(width: 132)

            VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
                Text(model.presentation.name)
                    .kultaraFont(.questTitle)
                    .foregroundStyle(palette.inkDark.color)
                    // The note only belongs on the fallback. Once the card carries a name the
                    // reader typed, explaining why it does not have one is a hint about nothing.
                    .accessibilityHint(model.presentation.isNamed
                        ? "" : UIStrings.string(.profileExplorerNameNote, language))
                // A flow rather than an `HStack`: at an accessibility size three labels do not fit
                // across 192 points, and the frame's row becomes a column instead of three
                // truncations (`NFR-A11Y-01`).
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: KultaraMetrics.lg) { statRow }
                    VStack(alignment: .leading, spacing: KultaraMetrics.sm) { statRow }
                }
            }
            // No trailing spacer: the stats row is measured by `ViewThatFits`, and a spacer
            // competing for the same width makes it choose the stacked layout on a screen where
            // the row plainly fits.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var statRow: some View {
        stat(model.presentation.questCount, .profileStatQuests)
        stat(model.presentation.stampCount, .profileStatStamps)
        stat(model.presentation.badgeCount, .profileStatBadges)
    }

    /// A count over its name. The name never wraps: "Badges" broken across two lines reads as two
    /// labels, and the row is three of them side by side. It shrinks instead, and only down to a
    /// floor — past that the row wraps as a whole at the largest accessibility sizes.
    private func stat(_ value: Int, _ key: UIStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
            Text(UIStrings.string(key, language))
                .font(.system(size: 15, weight: .light))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(palette.inkDark.color)
        .accessibilityElement(children: .combine)
    }

    private func title(for filter: ExplorerCardPresentation.QuestFilter) -> String {
        switch filter {
        case .all: UIStrings.string(.profileQuestFilterAll, language)
        case .unfinished: UIStrings.string(.profileQuestFilterUnfinished, language)
        case .done: UIStrings.string(.profileQuestFilterDone, language)
        }
    }

    /// Each filter says what would put something in *its* list. One empty line for three lists
    /// would describe the wrong one twice.
    private func emptyKey(for filter: ExplorerCardPresentation.QuestFilter) -> UIStringKey {
        switch filter {
        case .all: .profileQuestsAllEmpty
        case .unfinished: .profileQuestsEmpty
        case .done: .profileQuestsDoneEmpty
        }
    }

    private func title(for tab: ExplorerCardPresentation.Tab) -> String {
        switch tab {
        case .quests: UIStrings.string(.profileTabQuests, language)
        case .stamps: UIStrings.string(.profileTabStamps, language)
        case .badges: UIStrings.string(.profileTabBadges, language)
        }
    }

    // MARK: - The three surfaces

    @ViewBuilder private var surface: some View {
        switch model.tab {
        case .quests: quests
        case .stamps: stamps
        case .badges: badges
        }
    }

    @ViewBuilder private var quests: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            HisploraFilterChips(
                options: ExplorerCardPresentation.QuestFilter.allCases,
                selection: Binding(get: { model.questFilter }, set: { model.questFilter = $0 }),
                title: title(for:))

            let rows = model.visibleQuests
            if rows.isEmpty {
                empty(emptyKey(for: model.questFilter))
            } else {
                LazyVStack(spacing: KultaraMetrics.md) {
                    ForEach(rows) { quest in
                        questRow(quest)
                    }
                }
            }
        }
    }

    /// A row that resumes when there is something to resume, and a plain row when there is not.
    /// A finished walk has nowhere to go from here — its record is the Journal's letter and its
    /// badge — and a button that does nothing is worse than no button (`NFR-A11Y-05`).
    @ViewBuilder private func questRow(_ quest: QuestRowPresentation) -> some View {
        if let runID = quest.resumeRunID {
            Button {
                onResumeRun(runID)
            } label: {
                card(quest)
            }
            .buttonStyle(.plain)
            .accessibilityHint(UIStrings.string(.profileQuestResumeHint, language))
        } else {
            card(quest)
        }
    }

    private func card(_ quest: QuestRowPresentation) -> some View {
        HisploraActivityCard(
            title: quest.title,
            detail: quest.detail,
            detailEmphasis: quest.detailEmphasis
        ) {
            // The wax seal on a finished row is the frame's own mark (`737:3971`); an unfinished
            // one carries the sealed scroll the transition screen already draws (`293:1599`), so
            // one drawn object stands for one idea rather than a glyph here and an illustration
            // two screens away. Neither is spoken: the row's own line says which it is.
            if quest.isComplete {
                HisploraQuestSeal()
            } else {
                questMark
            }
        }
    }

    /// The mark on an unfinished walk's row: the sealed scroll the transition screen already
    /// carries (`293:1599`), rather than SF Symbols' `scroll`. One drawn object for one idea —
    /// a quest — instead of a glyph here and an illustration two screens away.
    ///
    /// The symbol stays as the fallback for the same reason every packaged picture in this project
    /// has one: a dropped resource should cost the drawing, not the row.
    @ViewBuilder private var questMark: some View {
        if let scroll = TransitionScrollMetrics.image {
            scroll
                .resizable()
                .aspectRatio(TransitionScrollMetrics.aspectRatio, contentMode: .fit)
        } else {
            Image(systemName: "scroll")
                .font(.system(size: 28))
                .foregroundStyle(palette.brownMid.color)
        }
    }

    @ViewBuilder private var stamps: some View {
        if model.presentation.stamps.isEmpty {
            empty(.profileStampsEmpty)
        } else {
            LazyVGrid(columns: stampColumns, spacing: 20) {
                ForEach(model.presentation.stamps) { stamp in
                    HisploraStampCard(
                        title: stamp.placeName,
                        subtitle: stamp.region,
                        artworkName: stamp.artworkName)
                }
            }
            // `705:2769` insets the grid to 39 points from the screen's edge — 15 more than the
            // 24 this scroll already pads by — which is what cuts each stamp to the 151.8 points
            // the die is drawn at. The rows on the Quests tab are not inset like this; a stamp is
            // an object on the sheet and a row is the sheet's own width.
            .padding(.horizontal, 15)
        }
    }

    @ViewBuilder private var badges: some View {
        if model.presentation.badges.isEmpty {
            empty(.profileBadgesEmpty)
        } else {
            LazyVGrid(columns: twoColumns, spacing: KultaraMetrics.xl) {
                ForEach(model.presentation.badges) { badge in
                    HisploraSealBadge(
                        name: badge.name,
                        wax: HisploraWaxSealMetrics.Wax.forIndex(badge.waxIndex))
                }
            }
        }
    }

    /// 20 between the two columns, as `705:2769` sets them — the badges keep the wider gutter,
    /// because a seal is a round object with air of its own and a stamp is a rectangle.
    private var stampColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]
    }

    private var twoColumns: [GridItem] {
        [GridItem(.flexible(), spacing: KultaraMetrics.xl),
         GridItem(.flexible(), spacing: KultaraMetrics.xl)]
    }

    /// A tab with nothing in it says what would put something there, rather than showing a blank.
    private func empty(_ key: UIStringKey) -> some View {
        Text(UIStrings.string(key, language))
            .kultaraFont(.body)
            .foregroundStyle(palette.inkMuted.color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.vertical, KultaraMetrics.xxl)
    }
}
