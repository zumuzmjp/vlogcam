import SwiftUI
import SwiftData

struct EditAlbumSheet: View {
    @Bindable var album: VlogAlbum
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var newPageLabel = ""

    var body: some View {
        NavigationStack {
            ZStack {
                RetroTheme.background.ignoresSafeArea()
                List {
                    Section("Album Title") {
                        TextField("Title", text: $album.title)
                            .foregroundStyle(RetroTheme.textPrimary)
                    }

                    Section("Pages") {
                        ForEach(album.sortedPages) { page in
                            HStack {
                                Text(page.label)
                                    .foregroundStyle(RetroTheme.textPrimary)
                                Spacer()
                                Text("\(page.clips.count) clips")
                                    .font(VintageFont.caption())
                                    .foregroundStyle(RetroTheme.faded)
                            }
                        }
                        .onDelete(perform: deletePage)

                        HStack {
                            TextField("New Page", text: $newPageLabel)
                                .foregroundStyle(RetroTheme.textPrimary)
                            Button {
                                addPage()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(RetroTheme.accent)
                            }
                            .disabled(newPageLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .foregroundStyle(RetroTheme.accent)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func addPage() {
        let label = newPageLabel.trimmingCharacters(in: .whitespaces)
        guard !label.isEmpty else { return }
        let sortOrder = (album.pages.map(\.sortOrder).max() ?? -1) + 1
        let page = AlbumPage(label: label, sortOrder: sortOrder)
        page.album = album
        modelContext.insert(page)
        newPageLabel = ""
    }

    private func deletePage(at offsets: IndexSet) {
        let sorted = album.sortedPages
        for index in offsets {
            let page = sorted[index]
            // Delete clip files
            for clip in page.clips {
                ClipStorageService.shared.deleteClipAndThumbnail(
                    clipFileName: clip.fileName,
                    thumbnailFileName: clip.thumbnailFileName
                )
            }
            modelContext.delete(page)
        }
    }
}
