import Foundation
import PostgREST
import RunEngine
import Storage
import UIKit

/// A walk's photographs, on the server. `c2` phase 4.
///
/// **A sidequest photograph gets no row and no upload, ever** (`FR-SIDE-13`). That is held
/// structurally rather than by a check: this type is handed a `Run` and reads only the
/// `TaskResult`s inside it, so a `SideQuestRecord`'s photograph is not something it can see. There
/// is no branch to get wrong, and `PhotoUploadBoundaryTests` scans the source to keep it that way.
nonisolated struct PhotoUploader: PhotoUploading {

    /// The long edge of the thumbnail. The Journal's grid and the Trip Collection's medallions draw
    /// at well under 200 points; 400 px covers 3× without sending a full derivative to lay out a
    /// row of pictures nobody has opened.
    static let thumbnailLongEdge: CGFloat = 400
    static let bucket = "trip-photos"
    static let contentType = "image/jpeg"

    /// Reading a photograph off disk is `@MainActor` (`PhotoStore` is), so it arrives as bytes
    /// through a closure rather than as a store this uploader would have to hop to.
    let loadImage: @Sendable @MainActor (String) -> UIImage?
    let session: any SupabaseSessionProviding

    func upload(
        photosFor run: Run,
        identity: SyncIdentity,
        configuration: BackendConfiguration?
    ) async throws -> [String: UUID] {
        guard let configuration, let token = await session.accessToken() else { return [:] }

        let headers = [
            "apikey": configuration.publishableKey,
            "Authorization": "Bearer \(token)",
        ]
        let storage = SupabaseStorageClient(configuration: .init(
            url: configuration.storageURL, headers: headers))
        let database = PostgrestClient(
            url: configuration.restURL, schema: "app", headers: headers,
            encoder: SyncWireFormat.encoder, decoder: SyncWireFormat.decoder)

        var identifiers: [String: UUID] = [:]
        for (checkpoint, task) in photographedTasks(in: run) {
            guard let path = task.photoRelativePath else { continue }
            // **The `TaskResult`'s own id is the photograph's id.** One photograph per task in this
            // app, so this is stable across pushes without a second table to remember it by — and a
            // re-push upserts the same row rather than creating a duplicate every foreground.
            let photoID = task.id
            identifiers[path] = photoID

            let loadImage = self.loadImage
            guard let image = await MainActor.run(body: { loadImage(path) }),
                  let derivatives = Derivatives(image)
            else {
                // The row is deliberately not written. A photograph whose bytes are gone — deleted
                // in Settings, lost to a partial restore — is not a row with a `storage_path`
                // pointing at nothing (`FR-SET-02`, `NFR-REL-05`).
                identifiers[path] = nil
                continue
            }

            // The bucket is not part of the object name. Supabase keeps the bucket in the request
            // and `{user_id}/…` is what `trip_photos_insert` checks, so a name that repeated the
            // bucket would fail the policy for a reason the error does not say.
            let prefix = "\(identity.userID.uuidString.lowercased())/\(photoID.uuidString.lowercased())"
            let fullPath = "\(prefix).jpg"
            let thumbPath = "\(prefix)-thumb.jpg"

            // **Row first, bytes second, `uploaded_at` last** (design §4.7). An object with no row
            // is invisible to the app and to the orphan sweeper; a row with `uploaded_at` null and
            // no bytes is a row the sweeper can find and clean up.
            try await database.from("photos").upsert(PhotoRow(
                id: photoID,
                runID: run.id,
                userID: identity.userID,
                checkpointID: checkpoint.checkpointID,
                storagePath: fullPath,
                thumbPath: thumbPath,
                size: derivatives.pixelSize,
                byteSize: derivatives.byteSize,
                capturedAt: task.completedAt,
                uploadedAt: nil,
                deviceID: identity.deviceID)).execute()

            let bucket = storage.from(Self.bucket)
            let options = FileOptions(contentType: Self.contentType, upsert: true)
            try await bucket.upload(fullPath, data: derivatives.full, options: options)
            try await bucket.upload(thumbPath, data: derivatives.thumbnail, options: options)

            // Stamped only once both objects are actually there — **with a revision bump**, or
            // `resolve_sync_conflict` reads it as an idempotent retry and drops it silently. See
            // `SyncConflictTrigger`; without this every photograph stays `uploaded_at` null and
            // every restored walk skips its pictures.
            if let revision = await SyncConflictTrigger.nextRevision(
                table: "photos", idColumn: "id", id: photoID, client: database) {
                try await database.from("photos")
                    .update([
                        "uploaded_at": SyncWireFormat.formatter.string(from: Date()),
                        "revision": "\(revision)",
                    ])
                    .eq("id", value: photoID.uuidString)
                    .execute()
            }
        }
        return identifiers
    }

    /// Every task in the walk that produced a photograph, with the checkpoint it belongs to.
    private func photographedTasks(in run: Run) -> [(CheckpointResult, TaskResult)] {
        run.orderedCheckpointResults.flatMap { checkpoint in
            checkpoint.taskResults
                .filter { $0.photoRelativePath != nil }
                .map { (checkpoint, $0) }
        }
    }

    /// The two objects, and the numbers the row needs about them.
    ///
    /// **Two, not one.** A grid that has to fetch full-size photographs to lay out a row of
    /// thumbnails is the difference between a Journal that opens and one that waits.
    struct Derivatives {
        let full: Data
        let thumbnail: Data
        let pixelSize: CGSize
        var byteSize: Int { full.count + thumbnail.count }

        init?(_ image: UIImage) {
            // `PhotoStore` already caps the long edge at 1600 on write, so the full derivative is
            // the file as stored rather than a second downscale of it.
            guard let full = image.jpegData(compressionQuality: 0.8),
                  let thumbnail = PhotoUploader
                      .downscaled(image, longEdge: PhotoUploader.thumbnailLongEdge)
                      .jpegData(compressionQuality: 0.7)
            else { return nil }
            self.full = full
            self.thumbnail = thumbnail
            // The **full** derivative's dimensions, so a grid can lay out before downloading
            // anything (`schema.md` §B.4).
            pixelSize = CGSize(
                width: image.size.width * image.scale, height: image.size.height * image.scale)
        }
    }

    static func downscaled(_ image: UIImage, longEdge: CGFloat) -> UIImage {
        let current = max(image.size.width, image.size.height)
        guard current > longEdge, current > 0 else { return image }
        let scale = longEdge / current
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - photos

nonisolated struct PhotoRow: Codable, Sendable, Equatable {
    let id: UUID
    let user_id: UUID
    let run_id: UUID?
    let checkpoint_id: String?
    let storage_path: String?
    let thumb_path: String?
    let content_type: String?
    let width_px: Int?
    let height_px: Int?
    let byte_size: Int?
    let captured_at: Date
    let uploaded_at: Date?
    let device_id: UUID
    let created_at: Date
    let updated_at: Date

    init(
        id: UUID,
        runID: UUID?,
        userID: UUID,
        checkpointID: String?,
        storagePath: String,
        thumbPath: String,
        size: CGSize,
        byteSize: Int,
        capturedAt: Date,
        uploadedAt: Date?,
        deviceID: UUID
    ) {
        self.id = id
        user_id = userID
        run_id = runID
        checkpoint_id = checkpointID
        storage_path = storagePath
        thumb_path = thumbPath
        content_type = PhotoUploader.contentType
        width_px = Int(size.width)
        height_px = Int(size.height)
        // Full **plus** thumb, because `FR-SET-03`'s storage report and the orphan sweeper both
        // care about what is actually stored rather than about what the walker photographed.
        byte_size = byteSize
        // The shutter time, not the upload time. `uploaded_at` is the other one and it is null
        // until the bytes are really there.
        captured_at = capturedAt
        uploaded_at = uploadedAt
        device_id = deviceID
        created_at = capturedAt
        updated_at = capturedAt
    }
}
