import SwiftUI

struct AlbumDetailView: View {
    let album: VlogAlbum
    @State private var showEdit = false
    @State private var showStitchAll = false
    @State private var showMap = false
    @State private var pickupState = ClipPickupState()

    var body: some View {
        ZStack {
            RetroTheme.background.ignoresSafeArea()
            if album.sortedPages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(RetroTheme.faded)
                    Text("No pages yet")
                        .font(VintageFont.body())
                        .foregroundStyle(RetroTheme.textSecondary)
                    Text("Record clips to add pages")
                        .font(VintageFont.caption())
                        .foregroundStyle(RetroTheme.faded)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(album.sortedPages) { page in
                            FilmStripView(page: page)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .environment(pickupState)
            }
        }
        .overlay(alignment: .top) {
            if pickupState.isActive {
                ClipPickupBadge(pickupState: pickupState)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: pickupState.isActive)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if album.totalClipCount > 0 {
                    NavigationLink {
                        AlbumMapView(album: album)
                    } label: {
                        Image(systemName: "map")
                            .foregroundStyle(RetroTheme.accent)
                    }
                    Button {
                        showStitchAll = true
                    } label: {
                        Image(systemName: "film.stack")
                            .foregroundStyle(RetroTheme.accent)
                    }
                }
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(RetroTheme.accent)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditAlbumSheet(album: album)
        }
        .sheet(isPresented: $showStitchAll) {
            StitchPreviewView(album: album, page: nil)
        }
    }
}
