import ContentKit
import DesignSystem
import Foundation
import RunEngine
import UIStringsKit

@MainActor
@Observable
final class QuestPreviewViewModel {

    let questID: String
    let language: ContentLanguage

    let title: String
    let region: String
    let hookLore: [LoreBlockPresentation]
    let descriptionText: String

    let distanceText: String
    let walkingTimeText: String
    let totalDurationText: String

    let costText: String
    let costBreakdown: [(placeName: String, amountText: String)]
    let estimatedCostMinorUnits: Int
    let costBreakdownTotalMinor: Int

    let terrainText: String
    let recommendedWindowText: String
    let latestStartText: String
    let safetyNotes: String

    let checkpoints: [CheckpointPreviewRow]
    let routeImageURL: URL?

    /// `FR-DISC-06` — non-blocking, and it names the site that closes and its closing time, or it
    /// is not actionable.
    let lateStartWarning: String?

    /// What the start control does when tapped.
    ///
    /// `FR-START-08` is not weakened by any of these: none of them starts a Run. They open the
    /// arrival screen, where the radius and the accuracy gate decide. The distinction matters —
    /// preview must remain fully usable at any location on earth (`FR-DISC-01`), and the only way
    /// to have both is for the button to lead to the gate rather than through it.
    enum StartState: Sendable, Equatable {
        /// No Run store is wired — previews and tests. The screen says so rather than offering a
        /// control that does nothing.
        case unavailable
        case start
        /// `FR-START-06` — an existing draft, offering resume or restart.
        case resume(runID: UUID, progressText: String)
    }

    private(set) var startState: StartState = .unavailable
    private(set) var isChoosingResumeOrRestart = false
    let startUnavailableExplanation: String

    /// Called with `restart == true` when the user chose to discard an existing draft. The screen
    /// that owns location does the starting; this one only asks which walk is meant.
    var onBeginRun: ((_ restart: Bool) -> Void)?

    init?(
        repository: any ContentRepository,
        questID: String,
        language: ContentLanguage,
        runEngine: RunEngine? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        guard let quest = (try? repository.quest(id: questID)) ?? nil else { return nil }

        self.questID = quest.id
        self.language = language
        let formatter = ContentFormatter(language: language)

        title = quest.title.value(for: language)
        region = quest.region
        descriptionText = quest.description.value(for: language)
        hookLore = quest.hookLore.enumerated().map { index, block in
            LoreBlockPresentation(
                id: index,
                text: block.text.value(for: language),
                accuracyLabel: formatter.accuracyLabel(block.accuracy),
                appearance: block.accuracy == .documented ? .documented : .oral,
                ink: block.accuracy == .documented ? .documented : .oral)
        }

        distanceText = formatter.distance(metres: quest.route.totalDistanceM)
        walkingTimeText = formatter.duration(minutes: quest.route.walkingTimeMin)
        totalDurationText = formatter.duration(minutes: quest.route.totalDurationMin)

        costText = formatter.cost(
            amount: quest.estimatedCost.amount, currency: quest.estimatedCost.currency)
        estimatedCostMinorUnits = quest.estimatedCost.amount
        costBreakdownTotalMinor = quest.estimatedCost.breakdown.reduce(0) { $0 + $1.amount }
        costBreakdown = quest.estimatedCost.breakdown.map { entry in
            let place = (try? repository.place(id: entry.placeId)) ?? nil
            return (placeName: place?.nameOfficial.value(for: language) ?? entry.placeId,
                    amountText: formatter.cost(amount: entry.amount, currency: quest.estimatedCost.currency))
        }

        terrainText = quest.terrainSummary.value(for: language)
        recommendedWindowText = formatter.window(quest.recommendedStartWindow, calendar: calendar)
        latestStartText = formatter.time(quest.hardLatestStart, calendar: calendar)
        safetyNotes = quest.safetyNotes.value(for: language)

        let places = quest.orderedCheckpoints.map { checkpoint -> (Checkpoint, Place?) in
            (checkpoint, (try? repository.place(id: checkpoint.placeId)) ?? nil)
        }

        checkpoints = places.map { checkpoint, place in
            let steps: String? = {
                guard let place, place.accessibility.hasSteps else { return nil }
                if let count = place.accessibility.stepCount {
                    return "\(UIStrings.string(.previewStepsPresent, language)) · \(count)"
                }
                return UIStrings.string(.previewStepsPresent, language)
            }()
            let opening = place?.visitingHours.weekly.first.map {
                "\(formatter.time($0.open, calendar: calendar))–\(formatter.time($0.close, calendar: calendar))"
            } ?? ""
            return CheckpointPreviewRow(
                id: checkpoint.id,
                orderIndex: checkpoint.orderIndex,
                placeName: place?.nameOfficial.value(for: language) ?? checkpoint.placeId,
                isSacred: place?.isSacred ?? false,
                dressCodeText: place?.dressCode.value(for: language) ?? "",
                photoPolicyText: place.map { formatter.photoPolicy($0.photoPolicy.level) } ?? "",
                stepsText: steps,
                surfaceText: place?.accessibility.surface ?? "",
                accessibilityNotes: place?.accessibility.notes.value(for: language) ?? "",
                openingText: opening)
        }

        routeImageURL = (try? repository.assetURL(quest.route.previewImageAsset)) ?? nil

        startUnavailableExplanation = UIStrings.string(.previewStartUnavailableDetail, language)

        if let runEngine {
            if let draft = (try? runEngine.activeRun(questID: quest.id)) ?? nil {
                startState = .resume(
                    runID: draft.id,
                    progressText: String(
                        format: UIStrings.string(.checkpointProgress, language),
                        draft.reachedCount, draft.checkpointCount))
            } else {
                startState = .start
            }
        }

        // FR-DISC-06. The boundary belongs to the user: exactly at `hardLatestStart` is a start
        // time the content endorses, so the warning fires strictly after it.
        let minutesNow = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        if minutesNow > quest.hardLatestStart.minutesFromMidnight,
           let closing = Self.earliestClosing(for: quest, repository: repository) {
            let template = UIStrings.string(.previewLateWarning, language)
            lateStartWarning = String(
                format: template,
                closing.place.nameOfficial.value(for: language),
                formatter.time(closing.time, calendar: calendar))
        } else {
            lateStartWarning = nil
        }
    }

    // MARK: - Starting

    func tapStart() {
        switch startState {
        case .unavailable: break
        case .start: onBeginRun?(false)
        case .resume: isChoosingResumeOrRestart = true
        }
    }

    func chooseResume() {
        isChoosingResumeOrRestart = false
        onBeginRun?(false)
    }

    /// `FR-START-06` — the warning that photos and reflections go is shown by the dialog that calls
    /// this, not buried afterwards.
    func chooseRestart() {
        isChoosingResumeOrRestart = false
        onBeginRun?(true)
    }

    func cancelResumeChoice() {
        isChoosingResumeOrRestart = false
    }

    /// The site that shuts first is the one that decides whether the walk can finish, so it is the
    /// one the warning names.
    private static func earliestClosing(
        for quest: Quest,
        repository: any ContentRepository
    ) -> (place: Place, time: TimeOfDay)? {
        var earliest: (place: Place, time: TimeOfDay)?
        for checkpoint in quest.orderedCheckpoints {
            guard let place = (try? repository.place(id: checkpoint.placeId)) ?? nil,
                  let close = place.visitingHours.weekly.map(\.close).min() else { continue }
            if earliest == nil || close < earliest!.time {
                earliest = (place, close)
            }
        }
        return earliest
    }

    /// Every string this screen renders. Used by the `FR-DISC-04` test to prove no checkpoint lore
    /// or clue text has leaked in — the assertion is about the text, not about property names.
    var allRenderedText: [String] {
        var strings = [title, region, descriptionText, distanceText, walkingTimeText,
                       totalDurationText, costText, terrainText, recommendedWindowText,
                       latestStartText, safetyNotes, startUnavailableExplanation]
        strings += hookLore.flatMap { [$0.text, $0.accuracyLabel] }
        strings += costBreakdown.flatMap { [$0.placeName, $0.amountText] }
        strings += checkpoints.flatMap {
            [$0.placeName, $0.dressCodeText, $0.photoPolicyText, $0.stepsText ?? "",
             $0.surfaceText, $0.accessibilityNotes, $0.openingText]
        }
        if let lateStartWarning { strings.append(lateStartWarning) }
        return strings
    }
}
