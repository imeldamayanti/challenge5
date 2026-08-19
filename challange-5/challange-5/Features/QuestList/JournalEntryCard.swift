import ContentKit
import DesignSystem
import SwiftUI

struct JournalEntryCard: View {
    @Environment(\.kultaraPalette) private var palette

    let heading: String
    let entry: RunJournalSummary.Entry
    let actionTitle: String
    let language: ContentLanguage
    let action: () -> Void

    var body: some View {
        KultaraCard {
            VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                KultaraEyebrow(heading)
                Text(entry.title)
                    .kultaraFont(.questTitle)
                    .foregroundStyle(palette.ink.color)
                    .fixedSize(horizontal: false, vertical: true)
                Text(entry.progressText)
                    .kultaraFont(.metadata)
                    .foregroundStyle(palette.inkMuted.color)
                Button(actionTitle, action: action)
                    .buttonStyle(.ruled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
