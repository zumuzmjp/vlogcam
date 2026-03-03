import Foundation

struct SharedAlbumSnapshot: Codable {
    let id: String
    let title: String
    let clipCount: Int
    let totalDuration: Double
    let coverImageName: String?
    let updatedAt: Date
}

struct SharedWidgetData: Codable {
    let albums: [SharedAlbumSnapshot]
    let latestAlbumID: String?
    let totalClips: Int
    let selectedAlbumID: String?
}

final class SharedDataStore {
    static let shared = SharedDataStore()
    private let fileName = "widget_data.json"

    private var fileURL: URL {
        AppGroup.containerURL.appending(component: fileName)
    }

    func write(_ data: SharedWidgetData) {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("SharedDataStore write error: \(error)")
        }
    }

    func read() -> SharedWidgetData? {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(SharedWidgetData.self, from: data)
        } catch {
            print("SharedDataStore read error: \(error)")
            return nil
        }
    }
}
