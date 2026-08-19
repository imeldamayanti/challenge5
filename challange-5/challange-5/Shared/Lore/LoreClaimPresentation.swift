import Foundation

/// One labelled claim with its citations, ready to render.
///
/// The citations travel with the claim rather than in a footnote block, because `FR-CP-06` puts
/// sources one tap from the lore screen and `FR-CP-05` keeps the accuracy label visible as text.
/// Splitting them would let a layout show the claim and lose the provenance.
struct LoreClaimPresentation: Sendable, Identifiable, Equatable {
    let id: Int
    let block: LoreBlockPresentation
    let citations: [String]
}
