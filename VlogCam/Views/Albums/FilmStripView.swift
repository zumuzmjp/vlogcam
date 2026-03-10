import SwiftUI

struct FilmStripView: View {
    let page: AlbumPage
    @State private var showReorder = false
    @State private var showStitch = false
    @State private var showPreview = false
    @Environment(ClipPickupState.self) private var pickupState: ClipPickupState?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            // Page label header
            HStack {
                Text(page.label)
                    .font(VintageFont.caption(11))
                    .foregroundStyle(RetroTheme.textSecondary)
                Spacer()
                if !page.sortedClips.isEmpty {
                    Text(String(format: "%.1fs", page.totalDuration))
                        .font(VintageFont.caption(10))
                        .foregroundStyle(RetroTheme.faded)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 4)

            // Film strip rows (3 frames per strip)
            if page.sortedClips.isEmpty {
                VStack(spacing: 0) {
                    SprocketHoleRow()
                    emptyState
                    SprocketHoleRow()
                }
                .background(Color(white: 0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                let sorted = page.sortedClips
                let chunks = sorted.chunked(into: 3)
                VStack(spacing: 6) {
                    ForEach(Array(chunks.enumerated()), id: \.offset) { chunkIndex, chunk in
                        VStack(spacing: 0) {
                            SprocketHoleRow()
                            HStack(spacing: 3) {
                                ForEach(Array(chunk.enumerated()), id: \.element.id) { localIndex, clip in
                                    let globalIndex = chunkIndex * 3 + localIndex
                                    FilmFrameView(clip: clip, allClips: sorted, frameIndex: globalIndex)
                                }
                                // Fill empty slots so frames stay same width
                                if chunk.count < 3 {
                                    ForEach(0..<(3 - chunk.count), id: \.self) { _ in
                                        Color.clear.aspectRatio(1.5, contentMode: .fit)
                                    }
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            SprocketHoleRow()
                        }
                        .background(Color(white: 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            // Action row
            HStack(spacing: 10) {
                if let pickupState, pickupState.isActive, pickupState.sourcePage?.id != page.id {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pickupState.drop(to: page, context: modelContext)
                        }
                    } label: {
                        Label("Drop \(pickupState.pickedClips.count)", systemImage: "arrow.down.doc")
                            .font(VintageFont.label(11))
                    }
                    .buttonStyle(RetroButtonStyle())
                }

                Spacer()

                if !page.sortedClips.isEmpty {
                    Button {
                        showPreview = true
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(RetroButtonStyle(color: RetroTheme.accent))

                    Button {
                        showReorder = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(RetroButtonStyle(color: RetroTheme.warmBrown))

                    Button {
                        showStitch = true
                    } label: {
                        Image(systemName: "film.stack")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(RetroButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
        .padding(.horizontal, 12)
        .sheet(isPresented: $showReorder) {
            ClipReorderView(page: page)
        }
        .sheet(isPresented: $showStitch) {
            if let album = page.album {
                StitchPreviewView(album: album, page: page)
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            QuickPreviewPlayer(clips: page.sortedClips)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "film")
                .font(.system(size: 20))
                .foregroundStyle(RetroTheme.faded)
            Text("No clips")
                .font(VintageFont.caption(10))
                .foregroundStyle(RetroTheme.faded)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
