import Foundation

/// The durable side of `system-design.md` §10.
///
/// Rows are written to disk **before** a flush is attempted, never after. An event that vanishes
/// because the process died between "recorded" and "written" is the failure §10's wording rules
/// out, and it is the failure an in-memory buffer with a periodic save produces.
public struct TelemetryQueueFile: Codable, Sendable, Equatable {
    public var events: [TelemetryEvent]
    public var surveyResponses: [SurveyResponse]

    public init(events: [TelemetryEvent] = [], surveyResponses: [SurveyResponse] = []) {
        self.events = events
        self.surveyResponses = surveyResponses
    }
}

public protocol TelemetryQueueStore: Sendable {
    func load() -> TelemetryQueueFile
    func save(_ file: TelemetryQueueFile)
}

public struct FileTelemetryQueueStore: TelemetryQueueStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public init(directory: URL) {
        self.init(url: directory.appendingPathComponent("telemetry-queue.json"))
    }

    public func load() -> TelemetryQueueFile {
        guard let data = try? Data(contentsOf: url),
              let file = try? Self.decoder.decode(TelemetryQueueFile.self, from: data)
        else { return TelemetryQueueFile() }
        return file
    }

    public func save(_ file: TelemetryQueueFile) {
        guard let data = try? Self.encoder.encode(file) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
