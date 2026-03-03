import SwiftUI

struct AlbumBookCover: View {
    let album: VlogAlbum

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(RetroTheme.leatherGradient)
                    .frame(height: 180)

                VStack(spacing: 4) {
                    Image(systemName: "video.fill")
                        .font(.title)
                        .foregroundStyle(RetroTheme.cream.opacity(0.8))
                    Text("\(album.totalClipCount)")
                        .font(VintageFont.title(28))
                        .foregroundStyle(RetroTheme.cream)
                    Text("clips")
                        .font(VintageFont.caption())
                        .foregroundStyle(RetroTheme.cream.opacity(0.7))
                }
            }
            .rotation3DEffect(.degrees(5), axis: (x: 0, y: 1, z: 0))
            .shadow(color: RetroTheme.cardShadow, radius: 8, x: 4, y: 4)

            Text(album.title)
                .font(VintageFont.label())
                .foregroundStyle(RetroTheme.textPrimary)
                .lineLimit(1)
        }
    }
}
