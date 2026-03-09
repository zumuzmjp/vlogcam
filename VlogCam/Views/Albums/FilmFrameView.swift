import SwiftUI

struct FilmFrameView: View {
    let clip: VideoClip
    var allClips: [VideoClip] = []
    let frameIndex: Int

    @State private var showPlayer = false
    @State private var showDeleteConfirm = false
    @Environment(\.modelContext) private var modelContext
    @Environment(ClipPickupState.self) private var pickupState: ClipPickupState?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / 1.5 // 3:2 aspect
            ZStack {
                Color.black

                if let thumbnailURL = clip.thumbnailURL,
                   let uiImage = UIImage(contentsOfFile: thumbnailURL.path()) {
                    let needsRotation = uiImage.size.height > uiImage.size.width
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .rotationEffect(needsRotation ? .degrees(90) : .zero)
                        .frame(width: w, height: h)
                        .clipped()
                } else {
                    Image(systemName: "video.fill")
                        .foregroundStyle(RetroTheme.faded)
                }

                // Frame number overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(frameIndex + 1)A ▸")
                            .font(VintageFont.caption(8))
                            .foregroundStyle(RetroTheme.cream.opacity(0.6))
                            .padding(.trailing, 4)
                            .padding(.bottom, 2)
                    }
                }
            }
            .frame(width: w, height: h)
        }
        .aspectRatio(1.5, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .opacity(pickupState?.isPicked(clip) == true ? 0.3 : 1.0)
        .overlay {
            if let pickupState, pickupState.isPicked(clip) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
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
