import ContentKit
import Foundation
import PostgREST
import RunEngine
import TelemetryKit

/// The wire shapes, and nothing else.
///
/// **In `Services/`, never in `RunEngine`** (`01-architecture.md` §2). A `Codable` shaped for
/// PostgREST on the domain model would make the server's column names a migration risk for
/// `FileRunStore`, and would put snake-case keys on the type the whole app reads.
///
/// Every type here is `nonisolated`. The app target builds with MainActor default isolation, which
/// would otherwise put a `Codable` conformance and a value-type initialiser on the main actor —
/// and these are built inside a push, off it, which is the whole point of the push being an actor.
///
/// Phase 2's finding is what these are built from: the client already carries every value the
/// schema needs, so each DTO is a projection rather than a new record. Where a column has no client
/// field, the reason is written at the field.

// MARK: - Shared

/// `schema.md` §C.2. Sent on every row, and the one value here that comes from neither the record
/// nor the content: it is the installation, supplied by the caller at push time.
///
/// `revision` and `server_seq` are deliberately absent. Both have server defaults, and the client
/// that omits them is the correct client — see phase 2's cut list for why `revision` is not a thing
/// this app maintains.
nonisolated struct SyncStamp {
    let deviceID: UUID
    let createdAt: Date
    let updatedAt: Date
}

/// Timestamps go over the wire as ISO-8601 with fractional seconds, which is what `timestamptz`
/// round-trips without argument. A `Date` encoded by the default strategy is a float, and PostgREST
/// will take it and store something nobody meant.
nonisolated enum SyncWireFormat {
    /// `nonisolated(unsafe)`: `ISO8601DateFormatter` is not `Sendable`, and these two are created
    /// once, never mutated afterwards, and only read. Apple documents formatting as thread-safe on a
    /// formatter whose configuration is not being changed, which is the case here by construction.
    nonisolated(unsafe) static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()

    nonisolated(unsafe) static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = formatter.date(from: text) ?? fallbackFormatter.date(from: text) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Not an ISO-8601 timestamp: \(text)")
            }
            return date
        }
        return decoder
    }()

    nonisolated(unsafe) static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Postgres omits the fractional part when it is zero, so a value this app wrote as `.000` can
    /// come back without it. Reading has to accept both; writing only ever produces the first.
    nonisolated(unsafe) static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

/// An update that does **not** bump `revision` is silently discarded.
///
/// `app.runs`, `app.photos`, `app.checkpoint_results`, `app.task_results`, `app.awards` and
/// `app.share_cards` all carry `resolve_sync_conflict` as a `before update` trigger, and its second
/// branch reads:
///
///     if new.revision = old.revision and new.device_id = old.device_id then
///       return null;                            -- an idempotent retry, not a conflict
///
/// Which is right for what it was written for — a device re-pushing an unchanged row — and wrong
/// for a **partial** update from the same device. PostgREST leaves untouched columns alone, so
/// `revision` and `device_id` both match and the write is dropped. No error, no affected-rows
/// count anybody checks, nothing in the response to notice.
///
/// This bit twice, both times invisibly: `uploaded_at` never got stamped on a photograph, which
/// made every restored walk skip its pictures; and `revoked_at` never landed on a share card, which
/// is a link a walker believes is off and is not. **Any partial update to an `app.*` row goes
/// through `revisionBump`.**
///
/// It is also the one place `revision` earns its keep, after `c2` phase 2 cut it everywhere else —
/// worth remembering before deciding the column is dead weight.
nonisolated enum SyncConflictTrigger {
    /// Reads a row's current `revision` and answers the value an update must carry.
    static func nextRevision(
        table: String, idColumn: String, id: UUID, client: PostgrestClient
    ) async -> Int? {
        struct RevisionOnly: Decodable { let revision: Int }
        let rows: [RevisionOnly]? = try? await client.from(table)
            .select("revision")
            .eq(idColumn, value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let current = rows?.first?.revision else { return nil }
        return current + 1
    }
}

// MARK: - runs

nonisolated struct RunRow: Codable, Sendable, Equatable {
    let id: UUID
    let user_id: UUID
    let quest_id: String
    let content_version: String
    let language: String
    let state: String
    let current_checkpoint_index: Int
    let started_at: Date
    let completed_at: Date?
    let abandoned_at: Date?
    let abandon_reason: String?
    let device_id: UUID
    let created_at: Date
    let updated_at: Date

    init(_ run: Run, userID: UUID, stamp: SyncStamp) {
        id = run.id
        user_id = userID
        quest_id = run.questID
        content_version = run.contentVersion
        language = run.language.rawValue
        // `notStarted` has no server counterpart — the check constraint takes active, completed and
        // abandoned only. A Run in that state has not been walked and is not pushed at all
        // (`SyncCoordinator.pushable`), so this never fires; `active` is the honest fallback rather
        // than a crash on a state that cannot reach here.
        state = run.state == .notStarted ? RunState.active.rawValue : run.state.rawValue
        current_checkpoint_index = run.currentCheckpointIndex
        started_at = run.startedAt
        completed_at = run.completedAt
        abandoned_at = run.abandonedAt
        abandon_reason = run.abandonReason?.rawValue
        device_id = stamp.deviceID
        created_at = stamp.createdAt
        updated_at = stamp.updatedAt
    }
}

// MARK: - checkpoint_results

nonisolated struct CheckpointResultRow: Codable, Sendable, Equatable {
    let id: UUID
    let run_id: UUID
    let user_id: UUID
    let checkpoint_id: String
    let order_index: Int
    let arrived_at: Date
    let arrival_method: String
    let gps_accuracy_bucket: String?
    let lore_first_opened_at: Date?
    let stamp_awarded_at: Date?
    let snapshot_place_name: String
    let snapshot_lore: [LoreBlockSnapshot]
    let snapshot_sources: [String]
    let snapshot_content_version: String
    let device_id: UUID
    let created_at: Date
    let updated_at: Date

    init(_ result: CheckpointResult, runID: UUID, userID: UUID, deviceID: UUID) {
        id = result.id
        run_id = runID
        user_id = userID
        checkpoint_id = result.checkpointID
        order_index = result.orderIndex
        arrived_at = result.arrivedAt
        arrival_method = result.arrivalMethod.rawValue
        // `NFR-PRIV-02`. The metre value stays on the device; three bands are what leaves it, and
        // they are `TelemetryKit`'s rather than a second enum with the same three cases — the
        // column's check constraint accepts exactly those strings.
        gps_accuracy_bucket = result.gpsAccuracyM.map { AccuracyBand(metres: $0).rawValue }
        lore_first_opened_at = result.loreFirstOpenedAt
        // **There is no `lore_dwell_ms` column.** The `c2` plan says to push null into one; migration
        // `20260816160001_privacy_and_photo_path_integrity` dropped it, on `NFR-PRIV` grounds, and
        // the plan text was never updated. Read off the deployed project rather than the document.
        //
        // Sending it anyway would have been invisible: Swift's synthesised `Codable` omits a nil
        // optional entirely, so the first push landed with the field silently absent instead of
        // erroring. Worth knowing before adding a field to any of these types.
        stamp_awarded_at = result.stampAwardedAt
        snapshot_place_name = result.snapshotPlaceName
        snapshot_lore = result.snapshotLore
        // Projected from the lore rather than snapshotted separately. Order-preserving and
        // de-duplicated so the same citation used by three blocks appears once.
        var seen = Set<String>()
        snapshot_sources = result.snapshotLore
            .flatMap(\.sourceCitations)
            .filter { seen.insert($0).inserted }
        snapshot_content_version = result.snapshotContentVersion
        device_id = deviceID
        created_at = result.arrivedAt
        updated_at = result.arrivedAt
    }
}

// MARK: - task_results

nonisolated struct TaskResultRow: Codable, Sendable, Equatable {
    let id: UUID
    let checkpoint_result_id: UUID
    let run_id: UUID
    let user_id: UUID
    let task_id: String
    let type: String
    let skipped: Bool
    let answer_text: String?
    let photo_id: UUID?
    let completed_at: Date
    let device_id: UUID
    let created_at: Date
    let updated_at: Date

    init(
        _ result: TaskResult,
        checkpointResultID: UUID,
        runID: UUID,
        userID: UUID,
        deviceID: UUID,
        photoID: UUID?
    ) {
        id = result.id
        checkpoint_result_id = checkpointResultID
        run_id = runID
        user_id = userID
        task_id = result.taskID
        type = result.type.rawValue
        skipped = result.skipped
        answer_text = result.text
        // Phase 4 resolves this from `photoRelativePath`. Null until then, and `on delete set null`
        // on the column is what lets a photograph be removed without taking the answer with it.
        photo_id = photoID
        completed_at = result.completedAt
        device_id = deviceID
        created_at = result.completedAt
        updated_at = result.completedAt
    }
}

// MARK: - awards

nonisolated struct AwardRow: Codable, Sendable, Equatable {
    let id: UUID
    let user_id: UUID
    let run_id: UUID?
    let type: String
    let source_id: String
    let snapshot_name: String
    let awarded_at: Date
    let device_id: UUID
    let created_at: Date
    let updated_at: Date

    init(_ award: Award, runID: UUID?, userID: UUID, deviceID: UUID) {
        id = award.id
        user_id = userID
        run_id = runID
        type = award.type.rawValue
        source_id = award.sourceID
        snapshot_name = award.snapshotName
        awarded_at = award.awardedAt
        device_id = deviceID
        created_at = award.awardedAt
        updated_at = award.awardedAt
    }
}
