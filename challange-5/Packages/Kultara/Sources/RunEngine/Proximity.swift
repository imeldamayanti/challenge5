import ContentKit
import Foundation

// The notification rules, without CoreLocation and without `UNUserNotificationCenter`.
//
// Both values here exist so Phase C is testable at all (`s0` D10): quiet hours, rate limits and
// region selection are exactly the kind of rule that fails quietly and at night, and the app target
// has no unit-test bundle to catch it in. The service in `s3` is an adapter over these — hardware on
// one side, a decided fact on the other, the same shape that keeps `ArrivalEvaluator` testable.

// MARK: - ProximityAlert

/// The only thing persisted about a region entry: which target, and when (`schema.md` §B.8).
///
/// No coordinates, no dwell, no trajectory — a movement history is exactly what `NFR-PRIV-09`
/// forbids. These rows exist solely to enforce the rate limits in `FR-PROX-09`.
public struct ProximityAlert: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    /// A quest id or a sidequest id. One namespace, because the daily cap in `FR-PROX-09` is a cap
    /// on interruptions and the walker does not care which feature interrupted them.
    public let targetID: String
    public let shownAt: Date

    public init(id: UUID = UUID(), targetID: String, shownAt: Date) {
        self.id = id
        self.targetID = targetID
        self.shownAt = shownAt
    }
}

// MARK: - ProximityGate

/// Whether an alert may be posted right now, and if not, why
/// (`FR-PROX-08`, `FR-PROX-09`, `FR-PROX-10`, `FR-SIDE-12`).
public struct ProximityGate: Sendable {

    public struct Limits: Sendable, Equatable {
        /// `FR-PROX-10` — 22:00 to 07:00 local wall time.
        public var quietFrom = TimeOfDay(hour: 22, minute: 0)
        public var quietUntil = TimeOfDay(hour: 7, minute: 0)
        /// `FR-PROX-09` — at most one alert per target per 24 hours.
        public var perTargetCooldown: TimeInterval = 24 * 3600
        /// `FR-PROX-09` — and at most three in total per day.
        public var maxPerDay = 3

        public init(
            quietFrom: TimeOfDay = TimeOfDay(hour: 22, minute: 0),
            quietUntil: TimeOfDay = TimeOfDay(hour: 7, minute: 0),
            perTargetCooldown: TimeInterval = 24 * 3600,
            maxPerDay: Int = 3
        ) {
            self.quietFrom = quietFrom
            self.quietUntil = quietUntil
            self.perTargetCooldown = perTargetCooldown
            self.maxPerDay = maxPerDay
        }
    }

    public enum Decision: Sendable, Equatable {
        case allow
        case blockedByActiveRun
        case blockedByQuietHours
        case blockedByCooldown(secondsRemaining: TimeInterval)
        case blockedByDailyCap
        case blockedByCompletion

        public var isAllowed: Bool { self == .allow }
    }

    /// The order of the checks is the order of the reasons, and it is deliberate: an active Run
    /// outranks everything, because interrupting a walker mid-quest is the exact thing
    /// `FR-PROX-08` exists to forbid, and the caller should be told that rather than told about
    /// quiet hours.
    public static func decide(
        targetID: String,
        now: Date,
        calendar: Calendar,
        alerts: [ProximityAlert],
        hasActiveRun: Bool,
        isTargetCompleted: Bool,
        limits: Limits = .init()
    ) -> Decision {
        // `FR-PROX-08` / `FR-SIDE-12`.
        if hasActiveRun { return .blockedByActiveRun }
        if isTargetCompleted { return .blockedByCompletion }

        // `FR-PROX-10`. Wall time at the walker, not an instant in UTC — see `isQuiet`.
        if isQuiet(now: now, calendar: calendar, from: limits.quietFrom, until: limits.quietUntil) {
            return .blockedByQuietHours
        }

        // `FR-PROX-09`, per target.
        if let last = alerts
            .filter({ $0.targetID == targetID })
            .map(\.shownAt)
            .max() {
            let elapsed = now.timeIntervalSince(last)
            if elapsed < limits.perTargetCooldown {
                return .blockedByCooldown(secondsRemaining: limits.perTargetCooldown - elapsed)
            }
        }

        // `FR-PROX-09`, in total. Counted over the calendar day rather than a rolling 24 hours,
        // because "three per day" is a promise about a day as the user experiences one.
        let today = alerts.filter { calendar.isDate($0.shownAt, inSameDayAs: now) }
        if today.count >= limits.maxPerDay { return .blockedByDailyCap }

        return .allow
    }

    /// Quiet hours are local wall time, and that is deliberate.
    ///
    /// A walker in Denpasar at 22:30 must not be notified, whatever the phone's region settings say
    /// about anything else. `TimeOfDay` already exists for exactly this: opening hours are wall
    /// times at the site, never instants.
    ///
    /// The midnight wrap is the case to get right: `22:00 → 07:00` crosses a date boundary, and the
    /// naive `from <= t && t < until` blocks nothing at all.
    public static func isQuiet(
        now: Date,
        calendar: Calendar,
        from: TimeOfDay,
        until: TimeOfDay
    ) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let start = from.minutesFromMidnight
        let end = until.minutesFromMidnight

        // An empty window rather than a whole day: a product that wanted silence around the clock
        // would turn the feature off, not set both ends to the same minute.
        guard start != end else { return false }
        return start < end
            ? (minutes >= start && minutes < end)
            : (minutes >= start || minutes < end)
    }
}

// MARK: - RegionBudget

/// iOS monitors 20 regions per app, shared across quests and sidequests (`FR-PROX-14`,
/// `FR-SIDE-16`).
///
/// Validator rule V27 is the authoring half of the same limit and is a backstop, not a guarantee:
/// quest start regions share the budget, so a legal 20-slot collection can still exhaust it. This
/// is the runtime half, and it is what actually holds the line.
public enum RegionBudget {

    public static let iosRegionLimit = 20

    /// Quest starts outrank sidequests: a quest is the thing the app is for. Higher value ranks
    /// first; the numbers are spaced so a third kind of target can be slotted between them without
    /// renumbering anything.
    public static let questStartPriority = 100
    public static let sideQuestPriority = 10

    public struct Candidate: Sendable, Equatable, Identifiable {
        public let id: String
        public let coordinate: Coordinate
        public let radiusM: Int
        public let priority: Int

        public init(id: String, coordinate: Coordinate, radiusM: Int, priority: Int) {
            self.id = id
            self.coordinate = coordinate
            self.radiusM = radiusM
            self.priority = priority
        }
    }

    /// Nearest-first within priority, capped.
    ///
    /// Ties break deterministically by id, so two runs of the same input register the same regions
    /// and the app does not churn registrations on every launch — which costs battery and, worse,
    /// loses a region the walker was about to enter.
    ///
    /// `near: nil` — no coarse position yet — returns the first `limit` candidates by priority in
    /// authored order rather than nothing. Registering nothing because location has not warmed up
    /// is the failure mode that reads as "the feature doesn't work". Priority is still honoured
    /// there: dropping quest starts for whichever sidequests happened to be authored first would be
    /// a different silent failure.
    public static func select(
        candidates: [Candidate],
        near coordinate: Coordinate?,
        limit: Int = iosRegionLimit
    ) -> [Candidate] {
        guard limit > 0 else { return [] }

        guard let coordinate else {
            return Array(
                candidates.enumerated()
                    .sorted { lhs, rhs in
                        lhs.element.priority != rhs.element.priority
                            ? lhs.element.priority > rhs.element.priority
                            : lhs.offset < rhs.offset
                    }
                    .map(\.element)
                    .prefix(limit))
        }

        let ranked = candidates
            .map { (candidate: $0, distance: Geo.distanceM(coordinate, $0.coordinate)) }
            .sorted { lhs, rhs in
                if lhs.candidate.priority != rhs.candidate.priority {
                    return lhs.candidate.priority > rhs.candidate.priority
                }
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return lhs.candidate.id < rhs.candidate.id
            }
        return Array(ranked.map(\.candidate).prefix(limit))
    }
}
