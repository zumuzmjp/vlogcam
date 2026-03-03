import SwiftUI
import SwiftData

@Observable
class ClipPickupState {
    var isActive = false
    var pickedClips: [VideoClip] = []
    var sourcePage: AlbumPage?

    func pickup(clip: VideoClip, page: AlbumPage) {
        isActive = true
        sourcePage = page
        pickedClips = [clip]
    }

    func toggle(clip: VideoClip) {
        if let index = pickedClips.firstIndex(where: { $0.id == clip.id }) {
            pickedClips.remove(at: index)
            if pickedClips.isEmpty {
                cancel()
            }
        } else {
            pickedClips.append(clip)
        }
    }

    func cancel() {
        isActive = false
        pickedClips = []
        sourcePage = nil
    }

    func drop(to page: AlbumPage, context: ModelContext) {
        let maxSortOrder = (page.sortedClips.last?.sortOrder ?? -1) + 1
        for (offset, clip) in pickedClips.enumerated() {
            clip.page = page
            clip.sortOrder = maxSortOrder + offset
        }
        try? context.save()
        cancel()
    }

    func isPicked(_ clip: VideoClip) -> Bool {
        pickedClips.contains(where: { $0.id == clip.id })
    }
}
