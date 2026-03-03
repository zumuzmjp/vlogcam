import SwiftUI

struct ClipThumbnailView: View {
    let clip: VideoClip
    @State private var showPlayer = false
    @State private var showDeleteConfirm = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.black

            if let thumbnailURL = clip.thumbnailURL,
               let uiImage = UIImage(contentsOfFile: thumbnailURL.path()) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle()
                    .fill(RetroTheme.surfaceBackground)
                Image(systemName: "video.fill")
                    .foregroundStyle(RetroTheme.faded)
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(String(format: "%.1fs", clip.duration))
                        .font(VintageFont.caption(10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                }
            }
        }
        .aspectRatio(9/16, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture {
            showPlayer = true
        }
        .onLongPressGesture {
            showDeleteConfirm = true
        }
        .fullScreenCover(isPresented: $showPlayer) {
            ClipPlayerView(clip: clip)
        }
        .confirmationDialog("Delete Clip?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteClip()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this clip.")
        }
    }

    private func deleteClip() {
        ClipStorageService.shared.deleteClipAndThumbnail(
            clipFileName: clip.fileName,
            thumbnailFileName: clip.thumbnailFileName
        )
        modelContext.delete(clip)
        try? modelContext.save()
    }
}
