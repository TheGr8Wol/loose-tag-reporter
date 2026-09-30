import Foundation
import UIKit
import TagReportingCore

/// Writes downscaled JPEG photos with EXIF/GPS stripped.
final class PhotoFileStore: Sendable {
    let rootURL: URL

    init(applicationSupportURL: URL) throws {
        rootURL = applicationSupportURL.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try DatabaseManager.applyDataProtection(to: rootURL)
    }

    func path(clientUUID: UUID, photoID: UUID) -> URL {
        let dir = rootURL.appendingPathComponent(clientUUID.uuidString, isDirectory: true)
        return dir.appendingPathComponent("\(photoID.uuidString).jpg")
    }

    /// Downscale longest edge ~1600px, JPEG ~0.6, strip metadata, target <~400KB.
    @discardableResult
    func writePhoto(clientUUID: UUID, photoID: UUID, imageData: Data) throws -> URL {
        let dest = path(clientUUID: clientUUID, photoID: photoID)
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let processed = try Self.downscaleAndStrip(imageData)
        try processed.write(to: dest, options: .atomic)
        try DatabaseManager.applyDataProtection(to: dest)
        return dest
    }

    func deletePhotos(clientUUID: UUID) {
        let dir = rootURL.appendingPathComponent(clientUUID.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
    }

    func sweepOrphans(knownClientUUIDs: Set<UUID>) throws {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        for url in contents {
            guard let uuid = UUID(uuidString: url.lastPathComponent) else {
                try? FileManager.default.removeItem(at: url)
                continue
            }
            if !knownClientUUIDs.contains(uuid) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static func downscaleAndStrip(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw RepositoryError.persistenceFailed("Invalid image data")
        }
        let maxEdge: CGFloat = 1600
        let size = image.size
        let scale = min(1, maxEdge / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        // Redraw strips EXIF/GPS.
        let redrawn = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = redrawn.jpegData(compressionQuality: 0.6) else {
            throw RepositoryError.persistenceFailed("JPEG encode failed")
        }
        return jpeg
    }
}
