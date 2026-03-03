import SwiftUI
import AVKit

struct ClipPagerView: View {
    let clips: [VideoClip]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var scrolledFileName: String?
    @State private var currentIndex: Int
    @State private var players: [Int: AVPlayer] = [:]

    init(clips: [VideoClip], initialIndex: Int) {
        self.clips = clips
        self.initialIndex = initialIndex
        _currentIndex = State(initialValue: initialIndex)
        _scrolledFileName = State(initialValue: clips[initialIndex].fileName)
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(clips.enumerated()), id: \.element.fileName) { index, clip in
                        clipPage(index: index)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .id(clip.fileName)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolledFileName)
            .scrollIndicators(.hidden)
        }
        .background(Color.black)
        .ignoresSafeArea()
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
            if currentIndex >= 0, currentIndex < clips.count {
                let clip = clips[currentIndex]
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
        .overlay(alignment: .bottom) {
            if clips.count > 1 {
                Text("\(currentIndex + 1) / \(clips.count)")
                    .font(VintageFont.caption())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            preparePlayer(at: currentIndex)
        }
        .onChange(of: scrolledFileName) {
            guard let name = scrolledFileName,
                  let newIndex = clips.firstIndex(where: { $0.fileName == name }) else { return }
            let oldIndex = currentIndex
            currentIndex = newIndex
            if oldIndex != newIndex {
                players[oldIndex]?.pause()
                preparePlayer(at: newIndex)
            }
        }
        .onDisappear {
            for (_, player) in players {
                player.pause()
            }
            players.removeAll()
        }
    }

    @ViewBuilder
    private func clipPage(index: Int) -> some View {
        ZStack {
            Color.black
            if let player = players[index] {
                VideoPlayer(player: player)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private func preparePlayer(at index: Int) {
        guard index >= 0, index < clips.count else { return }
        if let existing = players[index] {
            existing.seek(to: .zero)
            existing.play()
        } else {
            players[index] = makePlayer(for: clips[index])
            players[index]?.play()
        }
        for adj in [index - 1, index + 1] where adj >= 0 && adj < clips.count && players[adj] == nil {
            players[adj] = makePlayer(for: clips[adj])
        }
    }

    private func makePlayer(for clip: VideoClip) -> AVPlayer {
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
        return avPlayer
    }
}
