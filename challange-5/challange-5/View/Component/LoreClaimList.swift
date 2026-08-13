import ContentKit
import DesignSystem
import SwiftUI

/// Shared by the checkpoint screen and the summary, so a claim cannot be styled one way while it is
/// being read and another way when it is remembered.
struct LoreClaimList: View {
    @Environment(\.kultaraPalette) private var palette
    let claims: [LoreClaimPresentation]
    let language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: KultaraMetrics.lg) {
            ForEach(claims) { claim in
                VStack(alignment: .leading, spacing: KultaraMetrics.sm) {
                    // `FR-CP-05` — the label is text on the page, never behind a tap, and it is
                    // never carried by colour alone (`NFR-A11Y-05`).
                    AccuracyChip(text: claim.block.accuracyLabel,
                                 appearance: claim.block.appearance,
                                 ink: claim.block.ink.path)
                    Text(claim.block.text)
                        .kultaraFont(.lore)
                        .foregroundStyle(palette.ink.color)
                        .fixedSize(horizontal: false, vertical: true)
                    // `FR-CP-06` — sources within one tap of the lore. A disclosure group is that
                    // one tap, and it keeps the citation on the same screen as the claim.
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 2) {
                            if claim.citations.isEmpty {
                                Text(UIStrings.string(.checkpointSourcesEmpty, language))
                                    .kultaraFont(.metadata)
                                    .foregroundStyle(palette.inkMuted.color)
                            }
                            ForEach(claim.citations, id: \.self) { citation in
                                Text("· \(citation)")
                                    .kultaraFont(.metadata)
                                    .foregroundStyle(palette.inkMuted.color)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } label: {
                        Text(UIStrings.string(.checkpointSourcesHeading, language))
                            .kultaraFont(.metadata)
                            .foregroundStyle(palette.seal.color)
                            .frame(minHeight: KultaraMetrics.minimumTapTarget,
                                   alignment: .leading)
                    }
                }
            }
        }
    }
}
