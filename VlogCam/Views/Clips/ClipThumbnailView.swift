import SwiftUI

struct ClipThumbnailView: View {
    let clip: VideoClip
    var allClips: [VideoClip] = []
    @State private var showPlayer = false
    @State private var showDeleteConfirm = false
    @Environment(\.modelContext) private var modelContext
    @Environment(ClipPickupState.self) private var pickupState: ClipPickupState?

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
        .opacity(pickupState?.isPicked(clip) == true ? 0.3 : 1.0)
        .overlay {
            if let pickupState, pickupState.isPicked(clip) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pickupState?.isPicked(clip) ?? false)
        .onTapGesture {
            if let pickupState, pickupState.isActive {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pickupState.toggle(clip: clip)
                }
            } else {
                showPlayer = true
            }
        }
        .contextMenu {
            if pickupState?.isActive != true {
                if let pickupState, let page = clip.page {
                    Button {
                        pickupState.pickup(clip: clip, page: page)
                    } label: {
                        Label("Pick up", systemImage: "hand.pinch")
                    }
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .fullScreenCover(isPresented: $showPlayer) {
            if allClips.count > 1, let index = allClips.firstIndex(where: { $0.id == clip.id }) {
                ClipPagerView(clips: allClips, initialIndex: index)
            } else {
                ClipPlayerView(clip: clip)
            }
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
