import SwiftUI

private let stripBorder: CGFloat = 8

struct AlbumFilmRow: View {
    let albums: [VlogAlbum]

    var body: some View {
        VStack(spacing: 0) {
            // Top label row
            HStack(spacing: stripBorder) {
                ForEach(albums) { album in
                    Text(album.title)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(RetroTheme.cream.opacity(0.6))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                if albums.count < 3 {
                    ForEach(0..<(3 - albums.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: stripBorder)
            .padding(.horizontal, stripBorder)

            // Thumbnail row
            HStack(spacing: stripBorder) {
                ForEach(albums) { album in
                    NavigationLink {
                        AlbumDetailView(album: album)
                    } label: {
                        AlbumThumbnail(album: album)
                    }
                }
                if albums.count < 3 {
                    ForEach(0..<(3 - albums.count), id: \.self) { _ in
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .padding(.horizontal, stripBorder)

            // Bottom label row
            HStack(spacing: stripBorder) {
                ForEach(albums) { album in
                    Text("\(dateLabel(album.createdAt)) \u{25B8}")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(RetroTheme.faded)
                        .frame(maxWidth: .infinity)
                }
                if albums.count < 3 {
                    ForEach(0..<(3 - albums.count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: stripBorder)
            .padding(.horizontal, stripBorder)
        }
        .background(Color(white: 0.15))
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd"
        return formatter.string(from: date)
    }
}

private struct AlbumThumbnail: View {
    let album: VlogAlbum

    private var latestClip: VideoClip? {
        album.sortedPages.last?.sortedClips.last
    }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                thumbnailContent
            }
            .clipShape(Rectangle())
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let clip = latestClip,
           let url = clip.thumbnailURL,
           let uiImage = UIImage(contentsOfFile: url.path()) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RetroTheme.surfaceBackground
                Image(systemName: "video.fill")
                    .font(.title2)
                    .foregroundStyle(RetroTheme.faded)
            }
        }
    }
}
