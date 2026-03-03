import Foundation

final class ClipStorageService {
    static let shared = ClipStorageService()

    func ensureDirectories() throws {
        try URL.ensureDirectoryExists(.clipsDirectory)
        try URL.ensureDirectoryExists(.thumbnailsDirectory)
    }

    func generateClipFileName() -> String {
        let timestamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        return "clip_\(timestamp).mov"
    }

    func generateThumbnailFileName(for clipFileName: String) -> String {
        clipFileName.replacingOccurrences(of: ".mov", with: "_thumb.jpg")
    }

    func clipURL(for fileName: String) -> URL {
        URL.clipsDirectory.appending(component: fileName)
    }

    func thumbnailURL(for fileName: String) -> URL {
        URL.thumbnailsDirectory.appending(component: fileName)
    }

    func deleteClipFile(_ fileName: String) {
        let url = clipURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteThumbnailFile(_ fileName: String) {
        let url = thumbnailURL(for: fileName)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteClipAndThumbnail(clipFileName: String, thumbnailFileName: String?) {
        deleteClipFile(clipFileName)
        if let thumbnailFileName {
            deleteThumbnailFile(thumbnailFileName)
        }
    }

    var totalStorageUsed: Int64 {
        let fm = FileManager.default
        let clipsPath = URL.clipsDirectory.path()
        let thumbsPath = URL.thumbnailsDirectory.path()
        var total: Int64 = 0
        for dir in [clipsPath, thumbsPath] {
            if let files = try? fm.contentsOfDirectory(atPath: dir) {
                for file in files {
                    let path = (dir as NSString).appendingPathComponent(file)
                    if let attrs = try? fm.attributesOfItem(atPath: path),
                       let size = attrs[.size] as? Int64 {
                        total += size
                    }
                }
            }
        }
        return total
    }

    var formattedStorageUsed: String {
        ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }
}
