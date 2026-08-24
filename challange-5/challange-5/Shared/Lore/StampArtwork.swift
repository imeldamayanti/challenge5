import ContentKit
import DesignSystem
import Foundation
import RunEngine

/// Which of a place's three drawings a reader has earned, worked out from their own records.
///
/// **The rule, in the reader's words:** finish one quest through a place and its stamp shows the
/// first drawing; finish two and it shows the second; three or more and it stays on the third.
/// `DesignSystem.HisploraStampArtwork` owns the clamping and the file naming; this owns the
/// counting, because the count comes from Runs and Runs are not the design system's business.
///
/// **Two joins, both to decoration only.** Nothing here is allowed to decide what a walk *was* —
/// `Run` already carries its own snapshots for that (`FR-DONE-05`, `FR-RUN-06`). It reaches into
/// content twice, for the same reason `SealedLetterPresentation` reaches for a hero picture: to
/// find out which drawing to hang in a window. Withdraw the content and both lookups return `nil`,
/// the window falls back to aged paper, and every word on the card still reads correctly.
struct StampArtworkResolver {

    /// Place id → the design's asset stem.
    ///
    /// **A table here rather than a field on `Place`.** A `Place.stampArtwork` would be the tidier
    /// home and costs a schema change, a validator rule and a `contentBundleVersion` bump for five
    /// rows that only exist because the design drew five places. When a sixth place is authored
    /// this table is the thing that has to change, and the fallback while it has not is the honest
    /// empty window rather than a wrong picture. That trade is worth revisiting the moment content
    /// stops being one quest.
    static let slugsByPlaceID: [String: String] = [
        "badung-pasar-badung": "badung",
        "badung-museum-bali": "balimuseum",
        "badung-catur-muka": "caturmuka",
        "badung-pura-maospahit": "maospahit",
        "badung-puri-agung-pemecutan": "pemecutan",
    ]

    /// How many *finished* walks have passed through each place. Abandoned and in-flight walks are
    /// not counted — the reader was told the drawing changes when a quest is finished.
    private let completedVisits: [String: Int]
    /// quest id → (stamp id → place id), resolved once per screen rather than per stamp.
    private let placesByStamp: [String: [String: String]]

    init(runs: [Run], repository: any ContentRepository) {
        var places: [String: [String: String]] = [:]
        for questID in Set(runs.map(\.questID)) {
            guard let quest = (try? repository.quest(id: questID)) ?? nil else { continue }
            places[questID] = Dictionary(
                quest.checkpoints.map { ($0.stampId, $0.placeId) },
                uniquingKeysWith: { first, _ in first })
        }
        self.init(runs: runs, placesByStamp: places)
    }

    /// The counting on its own, with the content lookup already done.
    ///
    /// Exists so the rule can be tested as the pure value it is — no repository, no bundle, and no
    /// dependence on what happens to be authored this week. The same argument
    /// `challange-5Tests/ContentFixtures.swift` opens with.
    init(runs: [Run], placesByStamp: [String: [String: String]]) {
        self.placesByStamp = placesByStamp

        var visits: [String: Int] = [:]
        for run in runs where run.state == .completed {
            // A place counts once per finished walk however many stamps that walk franked there.
            let visited = Set(run.awards
                .filter { $0.type == .stamp }
                .compactMap { placesByStamp[run.questID]?[$0.sourceID] })
            for placeID in visited { visits[placeID, default: 0] += 1 }
        }
        self.completedVisits = visits
    }

    /// The resource stem for the stamp a walk franked at `stampSourceID`, or `nil` when the place
    /// is unknown or has no drawing.
    func artworkName(questID: String, stampSourceID: String) -> String? {
        guard let placeID = placesByStamp[questID]?[stampSourceID],
              let slug = Self.slugsByPlaceID[placeID]
        else { return nil }
        return HisploraStampArtwork.resourceName(
            slug: slug, completedVisits: completedVisits[placeID] ?? 0)
    }
}
