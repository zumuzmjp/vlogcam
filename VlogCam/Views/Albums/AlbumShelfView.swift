import SwiftUI
import SwiftData

struct AlbumShelfView: View {
    @Binding var deepLinkAlbumID: String?
    @Query(sort: \VlogAlbum.createdAt, order: .reverse) private var albums: [VlogAlbum]
    @Environment(\.modelContext) private var modelContext
    @State private var showCreateSheet = false
    @State private var albumToDelete: VlogAlbum?

    var body: some View {
        NavigationStack {
            ZStack {
                RetroTheme.background.ignoresSafeArea()
                if albums.isEmpty {
                    emptyState
                } else {
                    albumGrid
                }
            }
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(RetroTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateAlbumSheet()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(RetroTheme.faded)
            Text("No Albums Yet")
                .font(VintageFont.title(20))
                .foregroundStyle(RetroTheme.textPrimary)
            Text("Create your first vlog album")
                .font(VintageFont.body(14))
                .foregroundStyle(RetroTheme.textSecondary)
            Button("Create Album") {
                showCreateSheet = true
            }
            .buttonStyle(RetroButtonStyle())
        }
    }

    private var albumGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                ForEach(albums) { album in
                    NavigationLink {
                        AlbumDetailView(album: album)
                    } label: {
                        AlbumBookCover(album: album)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            albumToDelete = album
                        } label: {
                            Label("Delete Album", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
        .confirmationDialog("Delete Album?", isPresented: .init(
            get: { albumToDelete != nil },
            set: { if !$0 { albumToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let album = albumToDelete {
                    deleteAlbum(album)
                }
            }
            Button("Cancel", role: .cancel) { albumToDelete = nil }
        } message: {
            Text("This will delete all pages and clips in this album.")
        }
    }

    private func deleteAlbum(_ album: VlogAlbum) {
        // Delete all clip files first
        for page in album.pages {
            for clip in page.clips {
                ClipStorageService.shared.deleteClipAndThumbnail(
                    clipFileName: clip.fileName,
                    thumbnailFileName: clip.thumbnailFileName
                )
            }
        }
        modelContext.delete(album)
        try? modelContext.save()
    }
}
