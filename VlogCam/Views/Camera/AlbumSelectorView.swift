import SwiftUI

struct AlbumSelectorView: View {
    let albums: [VlogAlbum]
    @Binding var selectedAlbum: VlogAlbum?
    var clipCount: Int = 0
    @State private var showPicker = false

    var body: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12))
                Text(selectedAlbum?.title ?? "No Album")
                    .font(VintageFont.label(13))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))

                // Clip count badge
                HStack(spacing: 3) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 10))
                    Text("\(clipCount)")
                        .font(VintageFont.caption())
                }
                .foregroundStyle(RetroTheme.accent)
                .padding(.leading, 4)
            }
            .foregroundStyle(RetroTheme.cream)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RetroTheme.darkBrown.opacity(0.8))
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                List(albums) { album in
                    Button {
                        selectedAlbum = album
                        showPicker = false
                    } label: {
                        HStack {
                            Text(album.title)
                                .foregroundStyle(RetroTheme.textPrimary)
                            Spacer()
                            if album.persistentModelID == selectedAlbum?.persistentModelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(RetroTheme.accent)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(RetroTheme.background)
                .navigationTitle("Select Album")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showPicker = false }
                            .foregroundStyle(RetroTheme.accent)
                    }
                }
            }
        }
    }
}
