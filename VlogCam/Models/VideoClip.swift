import Foundation
import SwiftData

@Model
final class VideoClip {
    var fileName: String
    var duration: Double
    var recordedAt: Date
    var sortOrder: Int
    var thumbnailFileName: String?
    var latitude: Double?
    var longitude: Double?
    var page: AlbumPage?

    init(fileName: String, duration: Double, recordedAt: Date = .now, sortOrder: Int) {
        self.fileName = fileName
        self.duration = duration
        self.recordedAt = recordedAt
        self.sortOrder = sortOrder
    }

    var fileURL: URL {
        URL.clipsDirectory.appending(component: fileName)
    }

    var thumbnailURL: URL? {
        guard let thumbnailFileName else { return nil }
        return URL.thumbnailsDirectory.appending(component: thumbnailFileName)
    }
}
