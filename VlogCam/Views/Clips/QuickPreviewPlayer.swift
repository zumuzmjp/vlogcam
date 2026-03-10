import SwiftUI
import AVKit

struct QuickPreviewPlayer: View {
    let clips: [VideoClip]
    @State private var player: AVQueuePlayer?
    @State private var currentIndex = 0
    @State private var observers: [NSObjectProtocol] = []
    @Environment(\.dismiss) private var dismiss

    private var totalDuration: Double {
        clips.reduce(0) { $0 + $1.duration }
    }

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
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .overlay(alignment: .top) {
            VStack(spacing: 2) {
                Text("Preview")
                    .font(VintageFont.label())
                Text(String(format: "%.1fs total", totalDuration))
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
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.15))
                        Capsule()
                            .fill(RetroTheme.accent)
                            .frame(width: geo.size.width * CGFloat(currentIndex + 1) / CGFloat(max(clips.count, 1)))
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 40)

                Text("\(currentIndex + 1) / \(clips.count)")
                    .font(VintageFont.caption(10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
            .padding(.bottom, 36)
        }
        .onAppear {
            guard !clips.isEmpty else { return }
            setupQueue()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func setupQueue() {
        cleanup()

        let items = clips.enumerated().map { index, clip -> AVPlayerItem in
            let url = URL.clipsDirectory.appending(component: clip.fileName)
            let item = AVPlayerItem(url: url)

            let obs = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                if index == clips.count - 1 {
                    setupQueue()
                } else {
                    currentIndex = index + 1
                }
            }
            observers.append(obs)

            return item
        }

        currentIndex = 0

        if let player {
            player.removeAllItems()
            for item in items {
                if player.canInsert(item, after: nil) {
                    player.insert(item, after: nil)
                }
            }
        } else {
            player = AVQueuePlayer(items: items)
        }
        player?.play()
    }

    private func cleanup() {
        for obs in observers {
            NotificationCenter.default.removeObserver(obs)
        }
        observers.removeAll()
        player?.pause()
        player?.removeAllItems()
    }
}
