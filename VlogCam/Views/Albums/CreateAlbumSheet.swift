import SwiftUI
import SwiftData

struct CreateAlbumSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""

    var body: some View {
        NavigationStack {
            ZStack {
                RetroTheme.background.ignoresSafeArea()
                VStack(spacing: 24) {
                    TextField("Album Title", text: $title)
                        .font(VintageFont.body(18))
                        .foregroundStyle(RetroTheme.textPrimary)
                        .padding()
                        .background(RetroTheme.surfaceBackground)
                        .clipShape(RoundedRectangle(cornerRadius: RetroTheme.smallCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: RetroTheme.smallCornerRadius)
                                .stroke(RetroTheme.warmBrown.opacity(0.5), lineWidth: 1)
                        )

                    Button("Create") {
                        createAlbum()
                    }
                    .buttonStyle(RetroButtonStyle())
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(RetroTheme.accent)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func createAlbum() {
        let album = VlogAlbum(title: title.trimmingCharacters(in: .whitespaces))
        let firstPage = AlbumPage(label: "Day 1", sortOrder: 0)
        firstPage.album = album
        modelContext.insert(album)
        dismiss()
    }
}
