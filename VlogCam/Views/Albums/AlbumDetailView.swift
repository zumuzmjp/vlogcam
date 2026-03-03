import SwiftUI

struct AlbumDetailView: View {
    let album: VlogAlbum
    @State private var currentPageIndex = 0
    @State private var showEdit = false
    @State private var showStitchAll = false

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
                PageCurlContainer(pages: album.sortedPages, currentIndex: $currentPageIndex)
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if album.totalClipCount > 0 {
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
