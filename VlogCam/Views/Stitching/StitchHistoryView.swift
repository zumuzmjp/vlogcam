import SwiftUI
import AVKit

struct StitchHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [StitchCacheEntry] = []
    @State private var selectedEntry: StitchCacheEntry?
    @State private var player: AVPlayer?

    private let cacheService = StitchCacheService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                RetroTheme.background.ignoresSafeArea()

                if entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 40))
                            .foregroundStyle(RetroTheme.faded)
                        Text("No stitch history")
                            .font(VintageFont.body())
                            .foregroundStyle(RetroTheme.textSecondary)
                    }
                } else {
                    List {
                        ForEach(entries) { entry in
                            Button {
                                playEntry(entry)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.albumTitle)
                                            .font(VintageFont.body(14))
                                            .foregroundStyle(RetroTheme.textPrimary)
                                        HStack(spacing: 8) {
                                            if let pageLabel = entry.pageLabel {
                                                Text(pageLabel)
                                                    .font(VintageFont.caption())
                                                    .foregroundStyle(RetroTheme.accent)
                                            }
                                            Text("\(entry.clipCount) clips")
                                                .font(VintageFont.caption())
                                                .foregroundStyle(RetroTheme.faded)
                                            Text(String(format: "%.1fs", entry.totalDuration))
                                                .font(VintageFont.caption())
                                                .foregroundStyle(RetroTheme.faded)
                                        }
                                        Text(entry.createdAt, style: .relative)
                                            .font(VintageFont.caption())
                                            .foregroundStyle(RetroTheme.textSecondary)
                                    }
                                    Spacer()
                                    if selectedEntry?.id == entry.id {
                                        Image(systemName: "play.circle.fill")
                                            .foregroundStyle(RetroTheme.olive)
                                    } else {
                                        Image(systemName: "play.circle")
                                            .foregroundStyle(RetroTheme.accent)
                                    }
                                }
                            }
                            .listRowBackground(RetroTheme.cardBackground)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .scrollContentBackground(.hidden)

                    if let player {
                        VStack {
                            Spacer()
                            VideoPlayer(player: player)
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: RetroTheme.cornerRadius))
                                .padding()
                                .background(.ultraThinMaterial)
                        }
                    }
                }
            }
            .navigationTitle("Stitch History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        player?.pause()
                        dismiss()
                    }
                    .foregroundStyle(RetroTheme.accent)
                }
                if !entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                            .foregroundStyle(RetroTheme.accent)
                    }
                }
            }
            .onAppear {
                entries = cacheService.history()
            }
        }
    }

    private func playEntry(_ entry: StitchCacheEntry) {
        player?.pause()
        if selectedEntry?.id == entry.id {
            selectedEntry = nil
            player = nil
        } else {
            selectedEntry = entry
            player = AVPlayer(url: entry.fileURL)
            player?.play()
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            cacheService.delete(entries[index])
        }
        entries.remove(atOffsets: offsets)
        if let selected = selectedEntry, !entries.contains(where: { $0.id == selected.id }) {
            player?.pause()
            player = nil
            selectedEntry = nil
        }
    }
}
