import SwiftUI

struct AlbumPageView: View {
    let page: AlbumPage
    @State private var showReorder = false
    @State private var showStitch = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(page.label)
                    .font(VintageFont.title(20))
                    .foregroundStyle(RetroTheme.textPrimary)
                Spacer()
                if !page.sortedClips.isEmpty {
                    Text(String(format: "%.1fs", page.totalDuration))
                        .font(VintageFont.caption())
                        .foregroundStyle(RetroTheme.faded)
                }
            }
            .padding(.horizontal)

            if page.sortedClips.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "film")
                        .font(.system(size: 36))
                        .foregroundStyle(RetroTheme.faded)
                    Text("No clips on this page")
                        .font(VintageFont.body(14))
                        .foregroundStyle(RetroTheme.faded)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(page.sortedClips) { clip in
                            ClipThumbnailView(clip: clip)
                        }
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button {
                        showReorder = true
                    } label: {
                        Label("Reorder", systemImage: "arrow.up.arrow.down")
                            .font(VintageFont.label(13))
                    }
                    .buttonStyle(RetroButtonStyle(color: RetroTheme.warmBrown))

                    Button {
                        showStitch = true
                    } label: {
                        Label("Stitch", systemImage: "film.stack")
                            .font(VintageFont.label(13))
                    }
                    .buttonStyle(RetroButtonStyle())
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RetroTheme.cardBackground)
        .sheet(isPresented: $showReorder) {
            ClipReorderView(page: page)
        }
        .sheet(isPresented: $showStitch) {
            if let album = page.album {
                StitchPreviewView(album: album, page: page)
            }
        }
    }
}
