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

        let fileName = "\(recordID.uuidString).jpg"
        let target = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: target, options: .atomic)
        } catch {
            throw PhotoStoreError.unwritable(path: target.path, reason: String(describing: error))
        }
        return "sidequest-photos/\(fileName)"
    }

    @discardableResult func deleteAll() throws -> Int {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return 0 }
        for name in names {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
        return names.count
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
