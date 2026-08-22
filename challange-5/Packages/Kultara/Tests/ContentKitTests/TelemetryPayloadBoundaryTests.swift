import Foundation
import Testing

/// Design §2.4 and `03-security-privacy.md` §2 — **`ops.events` has no `user_id` column and must
/// never acquire one**, and the client half of that promise is that nothing identifying is ever put
/// into a payload in the first place.
///
/// The server already refuses to learn: `ingest` never reads a caller identity, and
/// `app.ingest_batch` names its columns so a stray field is dropped rather than stored. That is the
/// backstop. This is the near side — a payload that carries an identifier is a mistake whether or
/// not the database happens to discard it, because the value still crossed the wire.
///
/// **Scope is the payload path, not the app.** `TelemetryKit` and the one file that builds events
/// from it. Widening this to the whole app target would be a guard that `c2` phase 6 has to weaken:
/// sync code legitimately carries a user id, and a ban that gets shorter to make a scan pass is not
/// a ban (`m7` Decision 3).
///
/// Lives in `ContentKitTests` for the same reason its neighbours do: it links nothing, walks out
/// from `#filePath`, and runs on macOS in about a second.
struct TelemetryPayloadBoundaryTests {

    /// Every way an identifier has of arriving somewhere it does not belong.
    ///
    /// `deviceID` is on the list even though `c2` phase 2 adds one to the *Run record*: a device id
    /// is a sync column on user data, and putting it in an anonymous event would let one walker's
    /// events be collected together across every walk they ever take — which is precisely the
    /// property §2.4 buys by giving each Run its own pseudonymous key instead.
    static let identifiers = [
        "userID", "userId", "user_id",
        "accountID", "accountId", "account_id",
        "sessionID", "sessionId", "session_id",
        "deviceID", "deviceId", "device_id",
        "identifierForVendor", "advertisingIdentifier",
    ]

    static var telemetryKit: URL {
        PermissionCallBoundaryTests.packageTarget("TelemetryKit")
    }

    static var appTelemetryFile: URL {
        PermissionCallBoundaryTests.appTarget
            .appendingPathComponent("Services")
            .appendingPathComponent("AppTelemetry.swift")
    }

    @Test func noTelemetryPayloadCarriesAnIdentifier() throws {
        var offenders = try PermissionCallBoundaryTests.occurrences(
            of: Self.identifiers, under: Self.telemetryKit)
        offenders += try PermissionCallBoundaryTests.occurrences(
            of: Self.identifiers, under: Self.appTelemetryFile.deletingLastPathComponent(),
            onlyFileNamed: Self.appTelemetryFile.lastPathComponent)
        #expect(offenders.isEmpty, "\(offenders)")
    }

    /// The scan must fail rather than pass if the file it guards is renamed or moved.
    @Test func theFileThisGuardsExists() {
        #expect(FileManager.default.fileExists(atPath: Self.appTelemetryFile.path),
                "AppTelemetry.swift is not at \(Self.appTelemetryFile.path) — this guard is scanning nothing.")
    }
}
