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
    @State private var loadedFromCache = false
    @State private var showHistory = false
    @State private var outputFormat: VideoOutputFormat = .portrait16_9

    private let stitchService = VideoStitchingService()
    private let photoService = PhotoLibraryService()
    private let cacheService = StitchCacheService.shared

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
                            .aspectRatio(outputFormat.renderSize, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: RetroTheme.cornerRadius))
                            .padding(.horizontal)
                            .animation(.easeInOut(duration: 0.3), value: outputFormat)

                        if loadedFromCache {
                            Text("Loaded from cache")
                                .font(VintageFont.caption())
                                .foregroundStyle(RetroTheme.olive)
                        }
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
                            // Format shape preview
                            RoundedRectangle(cornerRadius: RetroTheme.cornerRadius)
                                .strokeBorder(RetroTheme.faded.opacity(0.4), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                .aspectRatio(outputFormat.renderSize, contentMode: .fit)
                                .overlay {
                                    VStack(spacing: 8) {
                                        Image(systemName: "film.stack")
                                            .font(.system(size: 32))
                                            .foregroundStyle(RetroTheme.faded)
                                        Text("\(clipsToStitch.count) clips ready")
                                            .font(VintageFont.body())
                                            .foregroundStyle(RetroTheme.textPrimary)
                                        let totalDur = clipsToStitch.reduce(0.0) { $0 + $1.duration }
                                        Text(String(format: "Total: %.1fs", totalDur))
                                            .font(VintageFont.caption())
                                            .foregroundStyle(RetroTheme.faded)
                                        Text(outputFormat.label)
                                            .font(VintageFont.lcd(14))
                                            .foregroundStyle(RetroTheme.accent)
                                    }
                                }
                                .padding(.horizontal)
                                .animation(.easeInOut(duration: 0.3), value: outputFormat)
                        }
                    }

                    Spacer()

                    // Output format selector
                    if stitchedURL == nil && !isStitching {
                        VStack(spacing: 8) {
                            Text("OUTPUT")
                                .font(VintageFont.caption(10))
                                .foregroundStyle(RetroTheme.faded)
                                .tracking(2)

                            HStack(spacing: 6) {
                                ForEach(VideoOutputFormat.allCases) { format in
                                    Button {
                                        outputFormat = format
                                        HapticService.impact(.light)
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: format.icon)
                                                .font(.system(size: 14))
                                            Text(format.label)
                                                .font(VintageFont.lcd(9))
                                        }
                                        .foregroundStyle(outputFormat == format ? RetroTheme.accent : RetroTheme.faded)
                                        .frame(width: 54, height: 46)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(outputFormat == format ? RetroTheme.accent.opacity(0.15) : RetroTheme.surfaceBackground)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(outputFormat == format ? RetroTheme.accent.opacity(0.5) : RetroTheme.metalDark.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    VStack(spacing: 12) {
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
                        }

                        if !isStitching {
                            if loadedFromCache {
                                Button("Re-stitch") {
                                    loadedFromCache = false
                                    saved = false
                                    player?.pause()
                                    player = nil
                                    stitchedURL = nil
                                }
                                .buttonStyle(RetroButtonStyle(color: RetroTheme.warmBrown))
                            } else if stitchedURL == nil {
                                Button("Stitch Clips") {
                                    startStitching()
                                }
                                .buttonStyle(RetroButtonStyle())
                                .disabled(clipsToStitch.isEmpty)
                            }
                        }
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(RetroTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showHistory) {
                StitchHistoryView()
            }
            .onAppear {
                loadCachedIfAvailable()
            }
        }
    }

    private func loadCachedIfAvailable() {
        let clips = clipsToStitch
        guard !clips.isEmpty else { return }
        if let entry = cacheService.cachedEntry(for: clips) {
            stitchedURL = entry.fileURL
            player = AVPlayer(url: entry.fileURL)
            player?.play()
            loadedFromCache = true
        }
    }

    private func startStitching() {
        isStitching = true
        error = nil
        player = nil
        stitchedURL = nil
        let clips = clipsToStitch
        let key = cacheService.cacheKey(for: clips)
        Task {
            do {
                let url = try await stitchService.stitch(clips: clips, outputFormat: outputFormat, cacheKey: key) { p in
                    progress = p
                }
                stitchedURL = url
                player = AVPlayer(url: url)
                player?.play()

                let totalDur = clips.reduce(0.0) { $0 + $1.duration }
                cacheService.save(
                    cacheKey: key,
                    albumTitle: album.title,
                    pageLabel: page?.label,
                    clipCount: clips.count,
                    totalDuration: totalDur,
                    fileURL: url
                )
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
