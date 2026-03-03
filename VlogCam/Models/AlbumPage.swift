import Foundation
import SwiftData

@Model
final class AlbumPage {
    var label: String
    var sortOrder: Int
    var album: VlogAlbum?

    @Relationship(deleteRule: .cascade, inverse: \VideoClip.page)
    var clips: [VideoClip] = []

    init(label: String, sortOrder: Int) {
        self.label = label
        self.sortOrder = sortOrder
    }

    var sortedClips: [VideoClip] {
        clips.sorted { $0.sortOrder < $1.sortOrder }
    }

    var totalDuration: Double {
        clips.reduce(0.0) { $0 + $1.duration }
    }
}
