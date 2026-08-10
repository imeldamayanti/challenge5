import Foundation

// Enums are stored as raw `String`, never `Int` — a persisted integer becomes unreadable the
// moment someone reorders a case (`schema.md` Appendix).

public enum PlaceType: String, Codable, Sendable, CaseIterable {
    case puri, pura, pasar, monumen, museum
    case ruangPublik = "ruang-publik"
}

public enum PhotoPolicyLevel: String, Codable, Sendable, CaseIterable {
    case allowed, restricted, prohibited
}

public enum AccuracyLabel: String, Codable, Sendable, CaseIterable {
    case documented, oral
}

public enum CheckpointRole: String, Codable, Sendable, CaseIterable {
    case start, middle, finish
}

/// `FR-TASK-05` limits mechanics at sacred Places to photo, reading, reflection and a single
/// light question. Puzzle, scavenger and timed mechanics are not representable.
public enum TaskType: String, Codable, Sendable, CaseIterable {
    case photo, reflection, question
}

/// The PRD's `sources[]` records citation *and* provenance kind: documented, oral, interview.
public enum SourceKind: String, Codable, Sendable, CaseIterable {
    case documented, oral, interview
}

/// `NFR-CONT-05` — distances must come from real walking directions. `haversine` exists as a
/// representable value only so the validator can reject it by name (V11).
public enum DistanceSource: String, Codable, Sendable, CaseIterable {
    case walkingDirections = "walking-directions"
    case haversine
}

public enum ConsentStatus: String, Codable, Sendable, CaseIterable {
    case granted, withdrawn, expired
}

public enum ConsentScope: String, Codable, Sendable, CaseIterable {
    case inclusion, photography, naming, imagery
}

// MARK: - CalendarDay

/// A calendar day with no time and no zone, as authored: `"2026-07-14"`. Consent grant and
/// expiry are days, not instants; decoding them as `Date` would invent a midnight in some
/// zone and make expiry comparisons depend on where the phone is.
public struct CalendarDay: Codable, Sendable, Equatable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Today in the device's current calendar. Used for consent expiry (V4).
    public static func today(calendar: Calendar = .current, now: Date = Date()) -> CalendarDay {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return CalendarDay(year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public var text: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = Self(text: raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a calendar day as YYYY-MM-DD, got \"\(raw)\"."))
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    init?(text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), day >= 1
        else { return nil }

        // Reject 30 February and friends: a plausible-looking but non-existent expiry date
        // would make a consent check pass against a day that never arrives.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar) else { return nil }

        self.init(year: year, month: month, day: day)
    }
}

// MARK: - TimeOfDay

/// A wall-clock time as authored: `"08:00"`. Opening hours and `hardLatestStart` are local wall
/// times at the site; they are never instants.
public struct TimeOfDay: Codable, Sendable, Equatable, Hashable, Comparable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesFromMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesFromMidnight < rhs.minutesFromMidnight
    }

    /// Clamps at midnight rather than wrapping. `hardLatestStart` is a closing time minus a
    /// duration (`schema.md` §A.5); if the quest is longer than the day is old, wrapping would
    /// produce a late-evening time that reads as a perfectly valid start.
    public func subtracting(minutes: Int) -> TimeOfDay {
        let total = max(0, minutesFromMidnight - minutes)
        return TimeOfDay(hour: total / 60, minute: total % 60)
    }

    public var text: String { String(format: "%02d:%02d", hour, minute) }

    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = Self(text: raw) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected a wall-clock time as HH:mm, got \"\(raw)\"."))
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    init?(text: String) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        self.init(hour: hour, minute: minute)
    }
}
