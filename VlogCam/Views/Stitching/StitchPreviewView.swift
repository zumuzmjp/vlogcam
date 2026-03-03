import SwiftUI
import AVKit

struct StitchPreviewView: View {
    let album: VlogAlbum
    let page: AlbumPage?
    @Environment(\.dismiss) private var dismiss
    @State private var isStitching = false
    @State private var progress: Float = 0
    @State private var stitchedURL: URL?
    @State private var error: String?
    @State private var player: AVPlayer?
    @State private var isSaving = false
    @State private var saved = false

    private let stitchService = VideoStitchingService()
    private let photoService = PhotoLibraryService()

    private var clipsToStitch: [VideoClip] {
        if let page {
            return page.sortedClips
        }
        return album.sortedPages.flatMap(\.sortedClips)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RetroTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    if let player {
                        VideoPlayer(player: player)
                            .clipShape(RoundedRectangle(cornerRadius: RetroTheme.cornerRadius))
                            .padding(.horizontal)
                    } else if isStitching {
                        StitchProgressView(progress: progress)
                    } else if let error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 40))
                                .foregroundStyle(RetroTheme.accent)
                            Text(error)
                                .font(VintageFont.body(14))
                                .foregroundStyle(RetroTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "film.stack")
                                .font(.system(size: 40))
                                .foregroundStyle(RetroTheme.faded)
                            Text("\(clipsToStitch.count) clips ready")
                                .font(VintageFont.body())
                                .foregroundStyle(RetroTheme.textPrimary)
                            let totalDur = clipsToStitch.reduce(0.0) { $0 + $1.duration }
                            Text(String(format: "Total: %.1fs", totalDur))
                                .font(VintageFont.caption())
                                .foregroundStyle(RetroTheme.faded)
                        }
                    }

                    Spacer()

                    if stitchedURL != nil && !saved {
                        Button("Save to Photos") {
                            saveToPhotos()
                        }
                        .buttonStyle(RetroButtonStyle())
                        .disabled(isSaving)
                    } else if saved {
                        Label("Saved!", systemImage: "checkmark.circle.fill")
                            .font(VintageFont.body())
                            .foregroundStyle(RetroTheme.olive)
                    } else if !isStitching {
                        Button("Stitch Clips") {
                            startStitching()
                        }
                        .buttonStyle(RetroButtonStyle())
                        .disabled(clipsToStitch.isEmpty)
                    }
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Stitch Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(RetroTheme.accent)
                }
            }
        }
    }

    private func startStitching() {
        isStitching = true
        error = nil
        Task {
            do {
                let url = try await stitchService.stitch(clips: clipsToStitch) { p in
                    progress = p
                }
                stitchedURL = url
                player = AVPlayer(url: url)
                player?.play()
            } catch {
                self.error = error.localizedDescription
            }
            isStitching = false
        }
    }

    private func saveToPhotos() {
        guard let url = stitchedURL else { return }
        isSaving = true
        Task {
            do {
                try await photoService.saveVideo(at: url, albumTitle: "VlogCam - \(album.title)")
                saved = true
                HapticService.notification(.success)
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}
