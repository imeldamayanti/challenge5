import Foundation

/// How precise a location fix was, as a token rather than a number (`c1` D5).
///
/// **No coordinate leaves the device in any form**, and a raw accuracy figure is close enough to
/// one to matter: metres-of-accuracy at a known checkpoint at a known minute narrows a device
/// considerably. Three bands are enough to answer the only question analysis asks — did the arrival
/// gate have a good fix, a usable one, or a bad one — and they are tokens (`lt20`, not `<20`) so
/// they survive JSON, a URL, a chart legend and a CSV without quoting.
public enum AccuracyBand: String, Codable, Sendable, CaseIterable {
    case lt20
    case b20_75
    case gt75

    public init(metres: Double) {
        switch metres {
        case ..<20: self = .lt20
        case ..<75: self = .b20_75
        default: self = .gt75
        }
    }
}

/// One anonymous event (`system-design.md` §10, design §2.4).
///
/// What it carries and what it must never carry are both structural. There is no `userID` field, no
/// `deviceID` field and no coordinate field — `ops.events` has no `user_id` column and must never
/// acquire one, and a type that cannot express an identifier is what makes that true here rather
/// than in a review.
public struct TelemetryEvent: Codable, Sendable, Equatable, Identifiable {

    public let id: UUID
    public let name: String
    /// Free-form, but see the initialiser: coordinates are not representable through it.
    public let params: [String: String]
    /// Pseudonymous, per Run (`c1` D6). Random, stored locally beside the Run, **never** written to
    /// `app.runs` — the whole point is that events can be grouped into a walk without the walk
    /// being attributable to a person.
    public let runKey: UUID?
    public let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, params
        case runKey = "run_key"
        case occurredAt = "occurred_at"
    }

    public init(
        id: UUID,
        name: String,
        params: [String: String] = [:],
        runKey: UUID? = nil,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.params = params
        self.runKey = runKey
        self.occurredAt = occurredAt
    }

    /// An arrival, reported as a checkpoint id and a band (`c1` D5).
    ///
    /// This is the only arrival constructor. There is no overload taking metres, a coordinate or a
    /// `CLLocation` — `TelemetryKit` imports neither CoreLocation nor anything that could carry one,
    /// and `ImportBoundaryTests` scans this target for exactly that.
    public static func arrival(
        id: UUID,
        checkpointID: String,
        band: AccuracyBand,
        method: String,
        runKey: UUID?,
        occurredAt: Date = Date()
    ) -> TelemetryEvent {
        TelemetryEvent(
            id: id,
            name: "checkpoint_arrived",
            params: ["checkpointID": checkpointID, "accuracyBand": band.rawValue, "method": method],
            runKey: runKey,
            occurredAt: occurredAt)
    }
}

/// One recall-survey answer (`FR-SURV`, `FR-ERR-10`).
public struct SurveyResponse: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let runKey: UUID?
    public let questID: String?
    public let questionID: String
    public let response: String
    public let occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case runKey = "run_key"
        case questID = "quest_id"
        case questionID = "question_id"
        case response
        case occurredAt = "occurred_at"
    }

    public init(
        id: UUID,
        runKey: UUID?,
        questID: String?,
        questionID: String,
        response: String,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.runKey = runKey
        self.questID = questID
        self.questionID = questionID
        self.response = response
        self.occurredAt = occurredAt
    }
}
