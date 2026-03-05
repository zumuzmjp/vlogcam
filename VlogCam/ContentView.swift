import SwiftUI

struct ContentView: View {
    @Binding var deepLinkAlbumID: String?
    @Binding var shouldOpenRecord: Bool
    @State private var showAlbums = false

    var body: some View {
        NavigationStack {
            CameraScreen(shouldOpenRecord: $shouldOpenRecord, onShowAlbums: {
                showAlbums = true
            })
            .navigationDestination(isPresented: $showAlbums) {
                AlbumShelfView(deepLinkAlbumID: $deepLinkAlbumID)
            }
        }
        .preferredColorScheme(.dark)
        .tint(RetroTheme.accent)
        .onChange(of: shouldOpenRecord) { _, newValue in
            if newValue {
                showAlbums = false
            }
        }
        .onChange(of: deepLinkAlbumID) { _, newValue in
            if newValue != nil {
                showAlbums = true
            }
        }
    }
}
