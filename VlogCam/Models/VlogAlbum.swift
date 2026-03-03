import Foundation
import SwiftData

@Model
final class VlogAlbum {
    var title: String
    var createdAt: Date
    @Attribute(.externalStorage) var coverImageData: Data?
    var photosAlbumIdentifier: String?

    @Relationship(deleteRule: .cascade, inverse: \AlbumPage.album)
    var pages: [AlbumPage] = []

    init(title: String, createdAt: Date = .now) {
        self.title = title
        self.createdAt = createdAt
    }

    var sortedPages: [AlbumPage] {
        pages.sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalClipCount: Int {
        pages.reduce(0) { $0 + $1.clips.count }
    }

    var totalDuration: Double {
        pages.reduce(0.0) { $0 + $1.clips.reduce(0.0) { $0 + $1.duration } }
    }
}
