import SwiftUI
import AVKit

struct ClipPlayerView: View {
    let clip: VideoClip
    @State private var player: AVPlayer?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(RetroTheme.accent)
            }
        }
        .onAppear {
            let url = URL.clipsDirectory.appending(component: clip.fileName)
            let avPlayer = AVPlayer(url: url)
            avPlayer.actionAtItemEnd = .none

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: avPlayer.currentItem,
                queue: .main
            ) { _ in
                avPlayer.seek(to: .zero)
                avPlayer.play()
            }

            self.player = avPlayer
            avPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 2) {
                Text(String(format: "%.1fs", clip.duration))
                    .font(VintageFont.label())
                Text(clip.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(VintageFont.caption())
            }
            .foregroundStyle(RetroTheme.cream)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RetroTheme.cardBackground.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: RetroTheme.smallCornerRadius)
                    .stroke(RetroTheme.warmBrown.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: RetroTheme.smallCornerRadius))
            .padding(.top, 12)
        }
    }
}
