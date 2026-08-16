import Foundation

/// Posts a batch. Abstracted so every response the ingest function can give is testable without it.
public protocol TelemetryTransport: Sendable {
    /// The HTTP status, or a thrown error. **Never** answers "is the network up?" (`AD-3`).
    func post(_ body: Data, to url: URL) async throws -> Int
}

public struct URLSessionTelemetryTransport: TelemetryTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func post(_ body: Data, to url: URL) async throws -> Int {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (_, response) = try await session.upload(for: request, from: body)
        return (response as? HTTPURLResponse)?.statusCode ?? 0
    }
}

/// Anonymous telemetry (`system-design.md` §10, design §6.2, `NFR-OBS-01`, `FR-ERR-10`).
///
/// Durable local queue, opportunistic flush, `POST /functions/v1/ingest`. A 200 marks rows sent;
/// **anything else leaves them queued** — any other status, and any thrown error, identically. The
/// endpoint is deliberately unauthenticated (`verify_jwt = false`), so nothing here holds a token
/// and nothing here asks a walker to have an account.
///
/// **No reachability check** (`AD-3`): the service attempts a flush and reads the outcome. It never
/// asks whether it should try.
///
/// **Optional at runtime.** If every flush fails forever, the queue grows to its cap and the app
/// behaves exactly as it does today. Nothing waits on a flush and nothing reads its result.
public actor TelemetryService {

    /// Matches the function's own `SUPPORTED_SCHEMA_VERSION` and `app.ingest_batch`'s check. A
    /// mismatch is rejected server-side rather than stored, which is deliberate (design §9.1).
    public static let schemaVersion = 1

    /// The function caps a batch at 200 rows and returns 400 above it, so the client never builds
    /// one it knows will be refused.
    public static let maxBatchRows = 200

    /// Events may be dropped when the queue has grown past this without a successful flush — an
    /// unbounded queue on a device that never gets a 200 is a disk-space bug. **Survey responses
    /// are never counted against it and never pruned** (`FR-ERR-10`): a lost event is a gap in a
    /// chart, a lost survey answer is a person's words.
    public static let maxQueuedEvents = 2_000

    private let url: URL
    private let transport: any TelemetryTransport
    private let store: any TelemetryQueueStore
    private var file: TelemetryQueueFile

    public init(url: URL, transport: any TelemetryTransport, store: any TelemetryQueueStore) {
        self.url = url
        self.transport = transport
        self.store = store
        self.file = store.load()
    }

    public var queuedEventCount: Int { file.events.count }
    public var queuedSurveyCount: Int { file.surveyResponses.count }

    /// Durable before it returns. The write is what makes §10 true; doing it lazily would make this
    /// an in-memory buffer with extra steps.
    public func record(_ event: TelemetryEvent) {
        file.events.append(event)
        if file.events.count > Self.maxQueuedEvents {
            // Oldest first. A telemetry queue that has not flushed in weeks is more useful holding
            // what happened recently than what happened when the problem started — and the survey
            // rows, which are the ones that matter, are not in this array.
            file.events.removeFirst(file.events.count - Self.maxQueuedEvents)
        }
        store.save(file)
    }

    public func record(_ response: SurveyResponse) {
        file.surveyResponses.append(response)
        store.save(file)
    }

    /// One opportunistic flush. Returns true when the server took the batch.
    ///
    /// Callers are expected to ignore the result. It is returned for the tests and for a caller
    /// that wants to flush again immediately when more rows are queued than one batch holds.
    @discardableResult
    public func flush() async -> Bool {
        let events = Array(file.events.prefix(Self.maxBatchRows))
        let remaining = Self.maxBatchRows - events.count
        let survey = remaining > 0 ? Array(file.surveyResponses.prefix(remaining)) : []
        if events.isEmpty && survey.isEmpty { return true }

        let payload = IngestBatch(
            schemaVersion: Self.schemaVersion, events: events, surveyResponses: survey)
        guard let body = try? FileTelemetryQueueStore.encoder.encode(payload) else { return false }

        // A thrown error and a 500 are the same event here: the rows are still queued and the next
        // flush will carry them. Distinguishing the two would be the beginning of a reachability
        // check.
        let status = (try? await transport.post(body, to: url)) ?? 0
        guard status == 200 else { return false }

        // Ids are UUIDv7 and the insert is `on conflict (id) do nothing`, so a flush that succeeded
        // server-side but whose response was lost costs a duplicate attempt, never a duplicate row.
        let sentEventIDs = Set(events.map(\.id))
        let sentSurveyIDs = Set(survey.map(\.id))
        file.events.removeAll { sentEventIDs.contains($0.id) }
        file.surveyResponses.removeAll { sentSurveyIDs.contains($0.id) }
        store.save(file)
        return true
    }

    struct IngestBatch: Encodable {
        let schemaVersion: Int
        let events: [TelemetryEvent]
        let surveyResponses: [SurveyResponse]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case events
            case surveyResponses = "survey_responses"
        }
    }
}
