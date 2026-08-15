import ContentKit
import Foundation
import Testing
@testable import RunEngine

/// The notification rules. Every one of them fails at night, in the field, on somebody else's
/// phone — which is why they are values with an injected clock rather than a service (`s0` D10).
struct ProximityGateTests {

    /// Fixed to Bali's zone: quiet hours are local wall time at the walker, and a test that ran in
    /// the machine's zone would pass in Denpasar and fail in CI.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Makassar") ?? .gmt
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026, month: 9, day: day, hour: hour, minute: minute)) ?? Date()
    }

    private func decide(
        targetID: String = "sq-a",
        at now: Date,
        alerts: [ProximityAlert] = [],
        hasActiveRun: Bool = false,
        isTargetCompleted: Bool = false
    ) -> ProximityGate.Decision {
        ProximityGate.decide(
            targetID: targetID, now: now, calendar: calendar, alerts: alerts,
            hasActiveRun: hasActiveRun, isTargetCompleted: isTargetCompleted)
    }

    @Test func anAlertIsAllowedInTheMiddleOfTheDayWithNothingElseInTheWay() {
        #expect(decide(at: date(10, 14)) == .allow)
    }

    @Test func anAlertIsBlockedInsideQuietHoursAcrossMidnight() {
        // `FR-PROX-10` — 22:00 to 07:00. The window crosses a date boundary, and the naive
        // `from <= t && t < until` comparison blocks nothing at all.
        #expect(decide(at: date(10, 22, 30)) == .blockedByQuietHours)
        #expect(decide(at: date(10, 23, 59)) == .blockedByQuietHours)
        #expect(decide(at: date(11, 0, 1)) == .blockedByQuietHours)
        #expect(decide(at: date(11, 6, 59)) == .blockedByQuietHours)
        // The boundaries themselves: 22:00 is quiet, 07:00 is not.
        #expect(decide(at: date(10, 22, 0)) == .blockedByQuietHours)
        #expect(decide(at: date(11, 7, 0)) == .allow)
        #expect(decide(at: date(10, 21, 59)) == .allow)
    }

    @Test func aSecondAlertForTheSamePlaceWithin24HoursIsBlocked() throws {
        // `FR-PROX-09`, per target.
        let shown = date(10, 9)
        let alerts = [ProximityAlert(targetID: "sq-a", shownAt: shown)]

        let blocked = decide(targetID: "sq-a", at: date(10, 20), alerts: alerts)
        guard case .blockedByCooldown(let remaining) = blocked else {
            Issue.record("expected a cooldown block, got \(blocked)")
            return
        }
        #expect(abs(remaining - 13 * 3600) < 1)

        // A different place is not blocked by it.
        #expect(decide(targetID: "sq-b", at: date(10, 20), alerts: alerts) == .allow)
        // And 24 hours later the same place is allowed again.
        #expect(decide(targetID: "sq-a", at: date(11, 9, 1), alerts: alerts) == .allow)
    }

    @Test func aFourthAlertInOneDayIsBlockedEvenForDifferentPlaces() {
        // `FR-PROX-09`, in total. Three is the cap on interruptions, whatever produced them.
        let alerts = [
            ProximityAlert(targetID: "sq-a", shownAt: date(10, 8)),
            ProximityAlert(targetID: "sq-b", shownAt: date(10, 11)),
            ProximityAlert(targetID: "sq-c", shownAt: date(10, 15)),
        ]
        #expect(decide(targetID: "sq-d", at: date(10, 17), alerts: alerts) == .blockedByDailyCap)
        // The next calendar day starts a new count.
        #expect(decide(targetID: "sq-d", at: date(11, 9), alerts: alerts) == .allow)
    }

    @Test func threeAlertsInADayAreAllowedAndTheThirdIsNotTheOneBlocked() {
        let alerts = [
            ProximityAlert(targetID: "sq-a", shownAt: date(10, 8)),
            ProximityAlert(targetID: "sq-b", shownAt: date(10, 11)),
        ]
        #expect(decide(targetID: "sq-c", at: date(10, 15), alerts: alerts) == .allow)
    }

    @Test func noAlertIsAllowedWhileARunIsActive() {
        // `FR-PROX-08`, `FR-SIDE-12`. It outranks every other reason: a walker mid-quest is
        // engaged, and that is the fact the caller needs told.
        #expect(decide(at: date(10, 14), hasActiveRun: true) == .blockedByActiveRun)
        #expect(decide(at: date(10, 23), hasActiveRun: true, isTargetCompleted: true)
                == .blockedByActiveRun)
    }

    @Test func noAlertIsAllowedForASidequestAlreadyCompleted() {
        // `FR-SIDE-12`, `s0` D9.
        #expect(decide(at: date(10, 14), isTargetCompleted: true) == .blockedByCompletion)
    }

    @Test func aQuietWindowWithBothEndsEqualBlocksNothing() {
        // A product that wanted silence around the clock would turn the feature off.
        let limits = ProximityGate.Limits(
            quietFrom: TimeOfDay(hour: 22, minute: 0),
            quietUntil: TimeOfDay(hour: 22, minute: 0))
        #expect(ProximityGate.decide(
            targetID: "sq-a", now: date(10, 22, 30), calendar: calendar, alerts: [],
            hasActiveRun: false, isTargetCompleted: false, limits: limits) == .allow)
    }

    @Test func aQuietWindowInsideOneDayStillWorks() {
        // Not the shipped configuration, but the non-wrapping branch has to be right too.
        let limits = ProximityGate.Limits(
            quietFrom: TimeOfDay(hour: 12, minute: 0),
            quietUntil: TimeOfDay(hour: 14, minute: 0))
        func decision(_ hour: Int) -> ProximityGate.Decision {
            ProximityGate.decide(
                targetID: "sq-a", now: date(10, hour), calendar: calendar, alerts: [],
                hasActiveRun: false, isTargetCompleted: false, limits: limits)
        }
        #expect(decision(13) == .blockedByQuietHours)
        #expect(decision(11) == .allow)
        #expect(decision(14) == .allow)
    }
}

/// `FR-PROX-14` / `FR-SIDE-16` — the runtime half of the 20-region limit. Validator rule V27 is the
/// authoring half and is a backstop, not a guarantee: quest starts share the same budget.
struct RegionBudgetTests {

    private let denpasar = Coordinate(lat: -8.6570, lon: 115.2160)

    private func candidate(
        _ id: String,
        lat: Double,
        lon: Double = 115.2160,
        priority: Int = RegionBudget.sideQuestPriority
    ) -> RegionBudget.Candidate {
        RegionBudget.Candidate(
            id: id, coordinate: Coordinate(lat: lat, lon: lon), radiusM: 200, priority: priority)
    }

    @Test func regionSelectionPrefersQuestStartsThenNearestSidequests() {
        // A quest is the thing the app is for, so its start regions are never crowded out by a
        // sidequest that happens to be closer.
        let candidates = [
            candidate("sq-near", lat: -8.6571),
            candidate("sq-far", lat: -8.7000),
            candidate("quest-far", lat: -8.8000, priority: RegionBudget.questStartPriority),
        ]
        let selected = RegionBudget.select(candidates: candidates, near: denpasar, limit: 2)
        #expect(selected.map(\.id) == ["quest-far", "sq-near"])
    }

    @Test func regionSelectionIsCappedAtTheiOSLimit() {
        let candidates = (0..<30).map { candidate("sq-\($0)", lat: -8.6570 - Double($0) / 1000) }
        #expect(RegionBudget.select(candidates: candidates, near: denpasar).count
                == RegionBudget.iosRegionLimit)
        #expect(RegionBudget.select(candidates: candidates, near: nil).count
                == RegionBudget.iosRegionLimit)
    }

    @Test func regionSelectionIsStableForTheSameInput() {
        // Re-registering a different set on every launch costs battery and, worse, drops a region
        // the walker was about to enter. Equidistant candidates therefore tie by id.
        let tied = [
            candidate("sq-c", lat: -8.6580),
            candidate("sq-a", lat: -8.6580),
            candidate("sq-b", lat: -8.6580),
        ]
        let first = RegionBudget.select(candidates: tied, near: denpasar, limit: 2)
        let second = RegionBudget.select(candidates: tied.reversed(), near: denpasar, limit: 2)
        #expect(first.map(\.id) == ["sq-a", "sq-b"])
        #expect(first == second)
    }

    @Test func regionSelectionWithNoPositionStillReturnsRegions() {
        // `s2` §6 — registering nothing because location has not warmed up is the failure mode
        // that reads as "the feature doesn't work". Priority is still honoured.
        let candidates = [
            candidate("sq-1", lat: -8.6580),
            candidate("sq-2", lat: -8.6590),
            candidate("quest-1", lat: -8.9000, priority: RegionBudget.questStartPriority),
        ]
        let selected = RegionBudget.select(candidates: candidates, near: nil, limit: 2)
        #expect(selected.map(\.id) == ["quest-1", "sq-1"])
    }

    @Test func selectingIntoNoBudgetAtAllReturnsNothingRatherThanCrashing() {
        #expect(RegionBudget.select(
            candidates: [candidate("sq-1", lat: -8.6580)], near: denpasar, limit: 0).isEmpty)
    }
}
