import ContentKit
import DesignSystem
import Foundation
import RunEngine

/// Which of a place's three drawings a reader has earned, worked out from their own records.
///
/// **The rule, in the reader's words:** answer one of a place's quests and its stamp shows the
/// first drawing; answer two and it shows the second; three or more and it stays on the third.
/// Each place counts on its own — leaving with tasks unanswered (`AD-2` — nothing here gates
/// progression) leaves that place on the tier its own work earned, and the next place starts again
/// at one. `DesignSystem.HisploraStampArtwork` owns the clamping and the file naming; this owns the
/// counting, because the count comes from a Run and a Run is not the design system's business.
///
/// **A skip does not count, as of 2026-08-26.** The drawing is what doing a quest buys, so a task
/// closed by tapping Skip leaves the tier where it was. This reverses the rule that stood earlier
/// the same day, and the argument it reversed is worth keeping because it is the good one: `AD-2`
/// means the app has no answer key, so it cannot grade one *answer* as better than another — but
/// the distinction being drawn here is not answer-quality, it is whether the walker engaged with
/// the task at all, and `TaskResult.skipped` records exactly that with no judgement needed.
///
/// `AD-2` is untouched either way. A skip still resolves the task, still gates nothing, and still
/// lets the walk leave the checkpoint; what it no longer does is advance a picture. The
/// checkpoint's task row draws no checkmark for it either (`CheckpointDetailScreen.isResolved`),
/// and the two must keep agreeing — a row ticked green beside a stamp that did not move is the
/// version of this that reads as a bug.
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

    /// What a stamp is *of*, and which checkpoint franked it.
    ///
    /// The checkpoint id is what carries the count: `Run.checkpointResults` is keyed by it, and the
    /// tasks a walker answered at a place live there. The place id is what carries the drawing.
    struct StampSource: Equatable {
        let placeID: String
        let checkpointID: String

        init(placeID: String, checkpointID: String) {
            self.placeID = placeID
            self.checkpointID = checkpointID
        }
    }

    /// quest id → (stamp id → where that stamp came from), resolved once per screen rather than
    /// per stamp.
    private let sourcesByStamp: [String: [String: StampSource]]

    init(runs: [Run], repository: any ContentRepository) {
        var sources: [String: [String: StampSource]] = [:]
        for questID in Set(runs.map(\.questID)) {
            guard let quest = (try? repository.quest(id: questID)) ?? nil else { continue }
            sources[questID] = Dictionary(
                quest.checkpoints.map {
                    ($0.stampId, StampSource(placeID: $0.placeId, checkpointID: $0.id))
                },
                uniquingKeysWith: { first, _ in first })
        }
        self.init(sourcesByStamp: sources)
    }

    /// The counting on its own, with the content lookup already done.
    ///
    /// Exists so the rule can be tested as the pure value it is — no repository, no bundle, and no
    /// dependence on what happens to be authored this week. The same argument
    /// `challange-5Tests/ContentFixtures.swift` opens with.
    init(sourcesByStamp: [String: [String: StampSource]]) {
        self.sourcesByStamp = sourcesByStamp
    }

    /// The resource stem for the stamp `run` franked at `stampSourceID`, or `nil` when the place is
    /// unknown or has no drawing.
    ///
    /// **The Run is the argument, not a tally taken across every Run.** The reader is told the
    /// drawing follows the quests they did at that place, and the quests they did at that place are
    /// recorded on the walk that did them — so a stamp in the Journal keeps showing what its own
    /// walk earned rather than being re-graded by a later one.
    func artworkName(run: Run, stampSourceID: String) -> String? {
        guard let (slug, checkpointID) = slugAndCheckpoint(forRun: run, stampSourceID: stampSourceID)
        else { return nil }
        return HisploraStampArtwork.resourceName(
            slug: slug, completedTasks: run.completedTaskCount(atCheckpoint: checkpointID))
    }

    /// The drawing the progress bar teases — one tier ahead of what `artworkName` would show, so
    /// resolving zero of a place's tasks previews the first, resolving one previews the second, and
    /// so on. `HisploraStampArtwork.tier`'s own clamp is what stops this running past the third once
    /// the place is fully resolved, so this needs none of its own.
    ///
    /// **This is the one screen that shows a stamp nobody has earned yet.** Every other caller —
    /// `StampAwardScreen`, the Journal, the Explorer's Card, the Trip Recap — reads `artworkName`
    /// unchanged and keeps showing the tier a walk actually banked. Only `452:3132`'s corner stamp
    /// is a preview rather than a record, because it is the one screen a walker is still standing
    /// on the checkpoint reading, where "the next drawing is one quest away" is a reason to keep
    /// going rather than a claim about what has already happened.
    func previewArtworkName(run: Run, stampSourceID: String) -> String? {
        guard let (slug, checkpointID) = slugAndCheckpoint(forRun: run, stampSourceID: stampSourceID)
        else { return nil }
        return HisploraStampArtwork.resourceName(
            slug: slug, completedTasks: run.completedTaskCount(atCheckpoint: checkpointID) + 1)
    }

    private func slugAndCheckpoint(
        forRun run: Run, stampSourceID: String
    ) -> (slug: String, checkpointID: String)? {
        guard let source = sourcesByStamp[run.questID]?[stampSourceID],
              let slug = Self.slugsByPlaceID[source.placeID]
        else { return nil }
        return (slug, source.checkpointID)
    }
}

extension Run {
    /// How many of a checkpoint's tasks the walker actually answered — a skip does not count, for
    /// the reason `StampArtworkResolver` gives. Zero for a checkpoint this walk never reached, which
    /// `HisploraStampArtwork.tier` floors to the first drawing.
    func completedTaskCount(atCheckpoint checkpointID: String) -> Int {
        guard let results = checkpointResults.first(where: { $0.checkpointID == checkpointID })
        else { return 0 }
        return results.taskResults.count { !$0.skipped }
    }
}
