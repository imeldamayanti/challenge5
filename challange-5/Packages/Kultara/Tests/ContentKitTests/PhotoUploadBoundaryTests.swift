import Foundation
import Testing

/// `FR-SIDE-13` — **a sidequest photograph never leaves the device.** `c2` phase 4.
///
/// The exclusion is structural rather than conditional: `PhotoUploader` is handed a `Run` and reads
/// only the `TaskResult`s inside it, so a `SideQuestRecord`'s photograph is not something it can
/// see. There is no branch that could be inverted. This suite is what keeps that true — the day
/// somebody gives the uploader a sidequest store "to reuse the upload code", it turns red.
///
/// In `ContentKitTests` for the same reason `PermissionCallBoundaryTests` is: it links nothing,
/// scans source text, and runs on macOS in two seconds.
struct PhotoUploadBoundaryTests {

    /// Everything that would let a sidequest photograph reach the network. Names, not concepts:
    /// a concept cannot be grepped.
    static let sideQuestTypes = [
        "SideQuestRecord",
        "SideQuestStore",
        "SideQuestEngine",
        "sideQuestStore",
        "sideQuestEngine",
        "sidequest-photos",
    ]

    /// The one file that turns a photograph into bytes on a server.
    static let uploaderFile = "PhotoUploader.swift"

    @Test func theUploaderCannotSeeASidequestPhotograph() throws {
        let offenders = try PermissionCallBoundaryTests.occurrences(
            of: Self.sideQuestTypes,
            under: PermissionCallBoundaryTests.appTarget.appendingPathComponent("Services"),
            onlyFileNamed: Self.uploaderFile)
        #expect(offenders.isEmpty, """
            FR-SIDE-13: a sidequest photograph must never be uploaded, and the upload path holds \
            that by having no way to reach one. Found: \(offenders)
            """)
    }

    /// The other half, and the one that would pass vacuously without it: prove the file is
    /// actually there and actually uploads. A scan that finds nothing because the filename changed
    /// is not a guard.
    @Test func theUploaderIsWhereThisSuiteThinksItIs() throws {
        let found = try PermissionCallBoundaryTests.occurrences(
            of: ["trip-photos"],
            under: PermissionCallBoundaryTests.appTarget.appendingPathComponent("Services"),
            onlyFileNamed: Self.uploaderFile)
        #expect(!found.isEmpty, "\(Self.uploaderFile) no longer names the bucket it uploads to.")
    }

    /// `NFR-PRIV-02` again, one layer out: a photograph's row carries where it was taken as a
    /// *checkpoint id*, never as a coordinate. `app.photos` has no lat/lon column and the DTO must
    /// not invent one by another name.
    @Test func aPhotographsRowCarriesNoCoordinate() throws {
        let offenders = try PermissionCallBoundaryTests.occurrences(
            of: ["latitude", "longitude", "coordinate", "CLLocation"],
            under: PermissionCallBoundaryTests.appTarget.appendingPathComponent("Services"),
            onlyFileNamed: Self.uploaderFile)
        #expect(offenders.isEmpty, "\(offenders)")
    }
}
