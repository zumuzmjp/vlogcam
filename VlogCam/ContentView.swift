import SwiftUI

struct ContentView: View {
    @Binding var deepLinkAlbumID: String?
    @Binding var shouldOpenRecord: Bool
    @State private var selectedTab: Tab = .camera

    enum Tab: Hashable {
        case camera
        case albums
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CameraScreen(shouldOpenRecord: $shouldOpenRecord)
                .tabItem {
                    Label("Camera", systemImage: "video.fill")
                }
                .tag(Tab.camera)

            AlbumShelfView(deepLinkAlbumID: $deepLinkAlbumID)
                .tabItem {
                    Label("Albums", systemImage: "book.fill")
                }
                .tag(Tab.albums)
        }
        .preferredColorScheme(.dark)
        .tint(RetroTheme.accent)
        .onChange(of: shouldOpenRecord) { _, newValue in
            if newValue {
                selectedTab = .camera
            }
        }
        .onChange(of: deepLinkAlbumID) { _, newValue in
            if newValue != nil {
                selectedTab = .albums
            }
        }
    }
}
