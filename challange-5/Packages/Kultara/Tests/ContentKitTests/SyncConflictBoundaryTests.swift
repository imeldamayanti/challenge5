import Foundation
import Testing

/// **The trap that cost two invisible defects**, pinned so a third does not happen. `c2` phases 4–5.
///
/// Every `app.*` row carries `resolve_sync_conflict` as a `before update` trigger
/// (migrations 0011 and 0012), and its second branch is:
///
///     if new.revision = old.revision and new.device_id = old.device_id then
///       return null;                            -- an idempotent retry, not a conflict
///
/// Right for a device re-pushing an unchanged row. Wrong for a **partial** update from the same
/// device — PostgREST leaves untouched columns alone, so both match, the row is not modified, and
/// the caller gets a 200 with nothing to notice.
///
/// What it broke, both silently:
///
/// - `uploaded_at` was never stamped on a photograph, so `RestoredPhotoDownloader` skipped every
///   real picture and a restored walk came back without them.
/// - `revoked_at` never landed on a share card: a walker presses "turn the link off", is told it
///   worked, and the link keeps serving.
///
/// Neither was found by reading. Both were found by a Deno test against a local stack
/// (`supabase/tests/functions/share.test.ts`, `c2.5.5`), which is also where the *behaviour* is
/// asserted — a trigger cannot be exercised from Swift. This suite asserts the **shape** of the
/// fix: that every partial update in the app goes through `SyncConflictTrigger`.
///
/// It is also the one place `revision` earns its keep after `c2` phase 2 cut it everywhere else.
/// Worth reading before anybody decides the column is dead weight.
struct SyncConflictBoundaryTests {

    /// Files that issue a partial update to an `app.*` row.
    static let updatingFiles = ["PhotoUploader.swift", "ShareCardService.swift"]

    static var services: URL {
        PermissionCallBoundaryTests.appTarget.appendingPathComponent("Services")
    }

    @Test func everyPartialUpdateGoesThroughTheRevisionBump() throws {
        for file in Self.updatingFiles {
            let bumps = try PermissionCallBoundaryTests.occurrences(
                of: ["SyncConflictTrigger.nextRevision"], under: Self.services, onlyFileNamed: file)
            #expect(!bumps.isEmpty, """
                \(file) issues a partial update to an app.* row without a revision bump, which \
                `resolve_sync_conflict` discards silently.
                """)
        }
    }

    /// And the helper is where they think it is — a scan that passes because somebody renamed it
    /// is not a guard.
    @Test func theRevisionBumpHelperExists() throws {
        let found = try PermissionCallBoundaryTests.occurrences(
            of: ["enum SyncConflictTrigger"], under: Self.services,
            onlyFileNamed: "SyncRecords.swift")
        #expect(!found.isEmpty, "SyncConflictTrigger no longer lives in SyncRecords.swift.")
    }
}
