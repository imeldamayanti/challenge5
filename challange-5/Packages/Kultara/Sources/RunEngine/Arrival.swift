import ContentKit
import Foundation

/// One position sample, as a value. `CoreLocation` stays on the other side of this type so the
/// arrival rule — the part that can be wrong — is testable without a device (`system-design.md` §14).
public struct LocationFix: Sendable, Equatable {
    public let coordinate: Coordinate
    /// `CLLocation.horizontalAccuracy`, in metres. Negative means the fix is invalid, which is how
    /// CoreLocation reports one; it is normalised to `nil` before it reaches here.
    public let horizontalAccuracyM: Double
    public let timestamp: Date

    public init(coordinate: Coordinate, horizontalAccuracyM: Double, timestamp: Date) {
        self.coordinate = coordinate
        self.horizontalAccuracyM = horizontalAccuracyM
        self.timestamp = timestamp
    }
}

public enum Geo {

    static let earthRadiusM = 6_371_000.0

    /// Great-circle distance. `NFR-CONT-05` forbids haversine for a quest's *authored* route length
    /// — that figure must come from real walking directions. This is the other thing: how far the
    /// walker is from the checkpoint right now, which `FR-MAP-02` asks for as a straight line and
    /// which no routing engine is available offline to answer anyway.
    public static func distanceM(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = a.lat * .pi / 180
        let φ2 = b.lat * .pi / 180
        let dφ = (b.lat - a.lat) * .pi / 180
        let dλ = (b.lon - a.lon) * .pi / 180

        let h = sin(dφ / 2) * sin(dφ / 2)
            + cos(φ1) * cos(φ2) * sin(dλ / 2) * sin(dλ / 2)
        return 2 * earthRadiusM * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
}

/// When the manual override becomes offerable, and how long is left until then (`FR-ARR-03`).
///
/// The wait is bounded, and that is the whole point: `FR-ARR-05` forbids an indefinite spinner, so
/// the honest progress indicator is the one counting down to something that genuinely happens. A
/// walker who can see that the wait ends in 47 seconds is not being asked to trust a spinner.
///
/// It is a value with an injected clock rather than a timer, so the rule is testable without
/// waiting a minute for it.
public struct ManualOverrideSchedule: Sendable, Equatable {

    public let startedAt: Date
    public let delay: Duration
    /// `FR-ERR-02` — a refused permission makes the override available at once. Waiting a minute
    /// for a fix that cannot arrive is a minute of pretending to look, and there is nothing to
    /// count down to.
    public let isImmediate: Bool

    public init(startedAt: Date, delay: Duration, isImmediate: Bool = false) {
        self.startedAt = startedAt
        self.delay = delay
        self.isImmediate = isImmediate
    }

    private var delaySeconds: Double {
        Double(delay.components.seconds) + Double(delay.components.attoseconds) / 1e18
    }

    public func elapsedSeconds(at now: Date) -> Double {
        max(0, now.timeIntervalSince(startedAt))
    }

    /// Whole seconds left before the override appears, or `nil` when there is nothing to wait for.
    /// Rounded up, so the last second reads `0:01` rather than `0:00` while still unavailable.
    public func remainingSeconds(at now: Date) -> Int? {
        guard !isImmediate else { return nil }
        return max(0, Int((delaySeconds - elapsedSeconds(at: now)).rounded(.up)))
    }

    public func isAvailable(at now: Date) -> Bool {
        isImmediate || elapsedSeconds(at: now) >= delaySeconds
    }

    /// `0…1`, for a determinate progress indicator. Determinate is the requirement: the bar has an
    /// end because the wait has one.
    public func progress(at now: Date) -> Double {
        guard !isImmediate, delaySeconds > 0 else { return 1 }
        return min(1, max(0, elapsedSeconds(at: now) / delaySeconds))
    }
}

public enum ArrivalDecision: Sendable, Equatable {
    case arrived(distanceM: Double, accuracyM: Double)
    case outsideRadius(distanceM: Double, accuracyM: Double)
    /// Inside the radius, but by a fix too vague to prove it.
    case accuracyInsufficient(distanceM: Double, accuracyM: Double)

    public var isArrived: Bool {
        if case .arrived = self { return true }
        return false
    }

    public var distanceM: Double {
        switch self {
        case .arrived(let d, _), .outsideRadius(let d, _), .accuracyInsufficient(let d, _): d
        }
    }

    public var accuracyM: Double {
        switch self {
        case .arrived(_, let a), .outsideRadius(_, let a), .accuracyInsufficient(_, let a): a
        }
    }
}

public enum ArrivalEvaluator {

    /// `FR-ARR-01` — inside `arrivalRadiusM`, *and* with horizontal accuracy no worse than that
    /// radius.
    ///
    /// The accuracy half is the load-bearing half. Without it a 500 m cell-tower fix unlocks a 75 m
    /// checkpoint from the next neighbourhood, and the gate stops meaning anything. It is also
    /// exactly why the manual override is mandatory rather than a nicety (`FR-START-10`): inside a
    /// covered market the accuracy test fails legitimately and often.
    public static func decide(
        fix: LocationFix,
        target: Coordinate,
        radiusM: Int
    ) -> ArrivalDecision {
        let distance = Geo.distanceM(fix.coordinate, target)
        let radius = Double(radiusM)
        guard distance <= radius else {
            return .outsideRadius(distanceM: distance, accuracyM: fix.horizontalAccuracyM)
        }
        guard fix.horizontalAccuracyM <= radius else {
            return .accuracyInsufficient(distanceM: distance, accuracyM: fix.horizontalAccuracyM)
        }
        return .arrived(distanceM: distance, accuracyM: fix.horizontalAccuracyM)
    }

    /// `NFR-BAT-03` — accuracy is reduced beyond 300 m from the next checkpoint and raised on
    /// approach. Returned in metres so the caller maps it to whatever its platform calls the
    /// constant, and so this stays testable.
    public static func desiredAccuracyM(forDistanceM distance: Double) -> Double {
        distance > 300 ? 100 : 10
    }
}
