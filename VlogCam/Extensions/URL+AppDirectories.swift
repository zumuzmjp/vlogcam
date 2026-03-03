import Foundation

extension URL {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static var clipsDirectory: URL {
        documentsDirectory.appending(component: "Clips")
    }

    static var thumbnailsDirectory: URL {
        documentsDirectory.appending(component: "Thumbnails")
    }

    static func ensureDirectoryExists(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
