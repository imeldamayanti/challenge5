import Foundation
import RunEngine
import Storage

/// Fetches the bytes for photographs a restore brought back as rows. `c2` phase 7, blocker B9.
///
/// Split from `RunRestorer` because the two have opposite shapes: the restore is one read that must
/// either land or be reported, and this is a handful of independent fetches where each one failing
/// costs exactly one missing picture and nothing else.
nonisolated protocol RestoredPhotoDownloading: Sendable {
    func download(_ photos: [PhotoRow], token: String) async
}

nonisolated struct RestoredPhotoDownloader: RestoredPhotoDownloading {

    let configuration: BackendConfiguration
    /// Writing a photograph is `@MainActor` (`PhotoStore` is), so it goes through a closure rather
    /// than a store this type would have to hop to. Answers with `false` when the file is already
    /// there, so a second restore fetches nothing.
    let place: @Sendable @MainActor (Data, UUID) -> Void
    let alreadyHave: @Sendable @MainActor (UUID) -> Bool

    func download(_ photos: [PhotoRow], token: String) async {
        let storage = SupabaseStorageClient(configuration: .init(
            url: configuration.storageURL,
            headers: [
                "apikey": configuration.publishableKey,
                "Authorization": "Bearer \(token)",
            ]))
        let bucket = storage.from(PhotoUploader.bucket)

        for photo in photos {
            // A row whose bytes never landed carries `uploaded_at` null (phase 4's ordering), and
            // asking for an object that is not there is a 400 nobody needs to see.
            guard photo.uploaded_at != nil, let path = photo.storage_path else { continue }
            let alreadyHave = self.alreadyHave
            if await MainActor.run(body: { alreadyHave(photo.id) }) { continue }

            // **The full derivative, not the thumbnail.** The thumbnail exists so a grid can lay
            // out before downloading; nothing in this app lays out that way yet, and writing a
            // 400 px file where a screen expects the photograph would be a silent quality loss.
            // When a grid exists, this is where thumbnail-first belongs.
            guard let data = try? await bucket.download(path: path) else { continue }
            let place = self.place
            await MainActor.run { place(data, photo.id) }
        }
    }
}

/// Downloads nothing. What the app uses with no backend.
nonisolated struct NoRestoredPhotoDownloading: RestoredPhotoDownloading {
    func download(_ photos: [PhotoRow], token: String) async {}
}
