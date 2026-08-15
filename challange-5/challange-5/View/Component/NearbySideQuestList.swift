import ContentKit
import DesignSystem
import SwiftUI
import UIStringsKit

/// "Places nearby", in the Quests tab. Kultara — it is a catalogue surface inside museum chrome.
///
/// This is the entry point that makes the feature demonstrable before notifications exist (Phase
/// B), and it stays afterwards as the manual browse path: a walker who dismissed a notification
/// needs a way back, and `FR-SIDE-07` promises one.
///
/// The list is empty in the shipped content tree — `manifest.sideQuests` is `[]` until `s5`
/// authors places with consent records and openable citations — so it says so rather than
/// occupying the screen with nothing.
struct NearbySideQuestList: View {
    @Environment(\.kultaraPalette) private var palette

    let rows: [NearbySideQuestRow]
    let language: ContentLanguage
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.md) {
            KultaraSectionHeading(UIStrings.string(.sideQuestNearbyHeading, language))
            if rows.isEmpty {
                KultaraCard {
                    Text(UIStrings.string(.sideQuestNearbyEmpty, language))
                        .kultaraFont(.body)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(rows) { row in
                    Button { onSelect(row.id) } label: { card(row) }
                        .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card(_ row: NearbySideQuestRow) -> some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.xs) {
                Text(row.title)
                    .kultaraFont(.sectionHeading)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.placeName)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
                // No fix, no distance — a placeholder number here would be a number somebody walks
                // by. Sampling location for a browse list is what `NFR-BAT-04` and `AD-1` rule out.
                if let distanceText = row.distanceText {
                    Text(String(format: UIStrings.string(.sideQuestDistanceAway, language),
                                distanceText))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.inkMuted.color)
                        .monospacedDigit()
                }
                // A completed sidequest still lists: the story is the walker's own record now, and
                // reading it back is the point of having kept it (`FR-SIDE-07`, `FR-SIDE-10`).
                if row.isCompleted {
                    Text(UIStrings.string(.sideQuestLetterAwarded, language))
                        .kultaraFont(.metadata)
                        .foregroundStyle(palette.seal.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: KultaraMetrics.minimumTapTarget, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
