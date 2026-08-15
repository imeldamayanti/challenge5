import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// One of the Ngalcer frame's filler cards, drawn with the same chrome as a real one so the Home
/// screen reads as it was designed — and with none of the behaviour, because there is nothing
/// behind it. See `PlaceholderQuestCatalog` for why it exists and what it is not.
///
/// It carries the frame's three facts and no more. The real card's second line — distance, total
/// time, cost — is absent on purpose: those are `FR-DISC-02` / `FR-DISC-05` / `NFR-CONT-06` claims
/// about a walk, and inventing figures for a walk that does not exist is the one thing a
/// placeholder must not do.
///
/// It is not a `Button`, so it cannot be tapped into a dead end, and VoiceOver is told what it is
/// rather than left to infer it from a card that goes nowhere.
struct PlaceholderQuestCard: View {
    let entry: PlaceholderQuest
    let language: ContentLanguage

    private var formatter: ContentFormatter { ContentFormatter(language: language) }

    var body: some View {
        PhotoQuestCard(title: entry.title.value(for: language),
                       hero: Image(entry.imageName)) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: KultaraMetrics.md) { region; walking; checkpoints }
                VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                    region; walking; checkpoints
                }
            }
        }
        .accessibilityHint(UIStrings.string(.homePlaceholderCardHint, language))
    }

    private var region: some View {
        PhotoCardFact(symbolName: "mappin", label: UIStrings.string(.labelRegion, language),
                      value: entry.region.value(for: language))
    }
    private var walking: some View {
        PhotoCardFact(symbolName: "clock", label: UIStrings.string(.labelWalkingTime, language),
                      value: formatter.duration(minutes: entry.walkingTimeMin))
    }
    private var checkpoints: some View {
        PhotoCardFact(symbolName: "flag",
                      label: UIStrings.string(.previewCheckpointsHeading, language),
                      value: formatter.checkpointCount(entry.checkpointCount))
    }
}
