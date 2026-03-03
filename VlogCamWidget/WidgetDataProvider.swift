import Foundation

enum WidgetAppGroup {
    static let identifier = "group.zumzumjp.VlogCam"

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)!
    }
}

struct WidgetAlbumSnapshot: Codable {
    let id: String
    let title: String
    let clipCount: Int
    let totalDuration: Double
    let coverImageName: String?
    let updatedAt: Date
}

struct WidgetSharedData: Codable {
    let albums: [WidgetAlbumSnapshot]
    let latestAlbumID: String?
    let totalClips: Int
}

enum WidgetDataProvider {
    static func loadData() -> WidgetSharedData {
        let fileURL = WidgetAppGroup.containerURL.appending(component: "widget_data.json")
        guard FileManager.default.fileExists(atPath: fileURL.path()),
              let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: data) else {
            return WidgetSharedData(albums: [], latestAlbumID: nil, totalClips: 0)
        }
        return decoded
    }
}
