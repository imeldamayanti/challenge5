import Foundation
import UIKit

/// The write side of a sidequest photo challenge (`s4` §7, `FR-SIDE-13`).
///
/// A protocol for the same reason every other store in this codebase is one, and because a view
/// model taking a concrete file-writer would need a fake file system to test the one thing worth
/// testing here — that a save produces a path, not that `FileManager` works.
@MainActor
protocol PhotoStore: AnyObject {
    /// Downscales and writes a JPEG, and returns a path relative to the app container —
    /// **never** absolute. An absolute path resolves to nothing after a restore from backup and
    /// the walker's photographs appear to have vanished (`NFR-REL-05`).
    func save(_ image: UIImage, recordID: UUID) throws -> String
    /// `FR-SET-02`. Returns how many photographs went, so the confirmation can name what was
    /// removed.
    @discardableResult func deleteAll() throws -> Int
    /// Reads one back by the relative path `save` returned.
    ///
    /// `nil` is a real state and stays one: a photograph deleted from Settings (`FR-SET-02`) or
    /// lost to a partial restore leaves a `TaskResult` still holding its path, and a summary that
    /// crashed or drew a broken-image glyph over that would be worse than one that simply has one
    /// fewer picture on it.
    func image(atRelativePath path: String) -> UIImage?
    /// Places bytes that came from somewhere else — a restore (`c2` phase 7), not a shutter.
    ///
    /// Separate from `save` on purpose: `save` downscales and re-encodes, which is right for a
    /// photograph straight off the camera and wrong for one that has already been through that
    /// once. A second pass would lose quality for no reason, and the file on the server is
    /// already what `save` produced.
    ///
    /// The path is derived from `recordID` by exactly the rule `save` uses, so a restored
    /// photograph lands where the record already says it is.
    @discardableResult func place(_ data: Data, recordID: UUID) throws -> String
    /// Whether the file is already there. Restore uses it to skip what it has.
    func hasImage(forRecordID recordID: UUID) -> Bool
    /// The path `save` and `place` produce for a record. The one naming rule, in one place, so a
    /// restored `TaskResult` can name its photograph before the bytes arrive.
    nonisolated static func relativePath(forRecordID recordID: UUID) -> String
}

enum PhotoStoreError: Error, CustomStringConvertible {
    case encodingFailed
    case unwritable(path: String, reason: String)

    var description: String {
        switch self {
        case .encodingFailed: "Could not encode the photograph."
        case .unwritable(let path, let reason): "Could not write \"\(path)\": \(reason)"
        }
    }
}

@MainActor
final class InMemoryPhotoStore: PhotoStore {
    private(set) var savedCount = 0

    func save(_ image: UIImage, recordID: UUID) throws -> String {
        savedCount += 1
        return "sidequest-photos/\(recordID.uuidString).jpg"
    }

    @discardableResult func deleteAll() throws -> Int {
        let count = savedCount
        savedCount = 0
        return count
    }

    /// Nothing was ever written, so nothing reads back.
    func image(atRelativePath path: String) -> UIImage? { nil }

    @discardableResult func place(_ data: Data, recordID: UUID) throws -> String {
        savedCount += 1
        return Self.relativePath(forRecordID: recordID)
    }

    func hasImage(forRecordID recordID: UUID) -> Bool { false }

    nonisolated static func relativePath(forRecordID recordID: UUID) -> String {
        "sidequest-photos/\(recordID.uuidString).jpg"
    }
}

/// One JPEG per photograph under `Documents/sidequest-photos/`, downscaled before it is written.
///
/// `Documents`, not `Application Support`: these are the walker's own photographs, not app state,
/// and iTunes/Finder file-sharing and iCloud backup both treat the two directories differently.
@MainActor
final class FilePhotoStore: PhotoStore {

    private let directory: URL
    /// Fifteen full-resolution photographs is a storage report nobody expects (`s4` §7); the long
    /// edge is capped well before that becomes a concern.
    private let maxLongEdge: CGFloat

    static func defaultDirectory() -> URL {
        let base = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("sidequest-photos", isDirectory: true)
    }

    init(directory: URL = FilePhotoStore.defaultDirectory(), maxLongEdge: CGFloat = 1600) {
        self.directory = directory
        self.maxLongEdge = maxLongEdge
    }

    func save(_ image: UIImage, recordID: UUID) throws -> String {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            throw PhotoStoreError.unwritable(path: directory.path, reason: String(describing: error))
        }

        guard let data = Self.downscaled(image, maxLongEdge: maxLongEdge)
            .jpegData(compressionQuality: 0.8)
        else { throw PhotoStoreError.encodingFailed }

        let target = directory.appendingPathComponent("\(recordID.uuidString).jpg")
        do {
            try data.write(to: target, options: .atomic)
        } catch {
            throw PhotoStoreError.unwritable(path: target.path, reason: String(describing: error))
        }
        return Self.relativePath(forRecordID: recordID)
    }

    @discardableResult func place(_ data: Data, recordID: UUID) throws -> String {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            throw PhotoStoreError.unwritable(path: directory.path, reason: String(describing: error))
        }
        let target = directory.appendingPathComponent("\(recordID.uuidString).jpg")
        do {
            try data.write(to: target, options: .atomic)
        } catch {
            throw PhotoStoreError.unwritable(path: target.path, reason: String(describing: error))
        }
        return Self.relativePath(forRecordID: recordID)
    }

    func hasImage(forRecordID recordID: UUID) -> Bool {
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("\(recordID.uuidString).jpg").path)
    }

    nonisolated static func relativePath(forRecordID recordID: UUID) -> String {
        "sidequest-photos/\(recordID.uuidString).jpg"
    }

    @discardableResult func deleteAll() throws -> Int {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return 0 }
        for name in names {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        return names.count
    }

    /// The paths `save` hands out are relative to `Documents`, which is where they are resolved
    /// against — never stored absolute (`NFR-REL-05`).
    func image(atRelativePath path: String) -> UIImage? {
        let base = directory.deletingLastPathComponent()
        guard let data = try? Data(contentsOf: base.appendingPathComponent(path)) else { return nil }
        return UIImage(data: data)
    }

    private static func downscaled(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let longEdge = max(image.size.width, image.size.height)
        guard longEdge > maxLongEdge, longEdge > 0 else { return image }
        let scale = maxLongEdge / longEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
