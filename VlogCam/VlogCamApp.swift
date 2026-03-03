import SwiftUI
import SwiftData

@main
struct VlogCamApp: App {
    let modelContainer: ModelContainer

    @State private var deepLinkAlbumID: String?
    @State private var shouldOpenRecord = false

    init() {
        do {
            let schema = Schema([VlogAlbum.self, AlbumPage.self, VideoClip.self])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkAlbumID: $deepLinkAlbumID, shouldOpenRecord: $shouldOpenRecord)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(modelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        guard let action = DeepLink.parse(url) else { return }
        switch action {
        case .record:
            shouldOpenRecord = true
        case .album(let id):
            deepLinkAlbumID = id
        }
    }
}
