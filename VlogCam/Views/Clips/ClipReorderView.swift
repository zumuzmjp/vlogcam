import SwiftUI

struct ClipReorderView: View {
    let page: AlbumPage
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var clips: [VideoClip] = []

    var body: some View {
        NavigationStack {
            ZStack {
                RetroTheme.background.ignoresSafeArea()
                if clips.isEmpty {
                    Text("No clips to reorder")
                        .font(VintageFont.body())
                        .foregroundStyle(RetroTheme.faded)
                } else {
                    List {
                        ForEach(clips) { clip in
                            HStack(spacing: 12) {
                                if let thumbnailURL = clip.thumbnailURL,
                                   let uiImage = UIImage(contentsOfFile: thumbnailURL.path()) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(9/16, contentMode: .fit)
                                        .frame(height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(RetroTheme.surfaceBackground)
                                        .frame(width: 34, height: 60)
                                        .overlay {
                                            Image(systemName: "video.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(RetroTheme.faded)
                                        }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(format: "%.1fs", clip.duration))
                                        .font(VintageFont.label())
                                        .foregroundStyle(RetroTheme.textPrimary)
                                    Text(clip.recordedAt.formatted(date: .omitted, time: .shortened))
                                        .font(VintageFont.caption())
                                        .foregroundStyle(RetroTheme.faded)
                                }
                                Spacer()
                            }
                            .listRowBackground(RetroTheme.cardBackground)
                        }
                        .onMove(perform: moveClip)
                    }
                    .scrollContentBackground(.hidden)
                    .environment(\.editMode, .constant(.active))
                }
            }
            .navigationTitle("Reorder Clips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveOrder()
                        dismiss()
                    }
                    .foregroundStyle(RetroTheme.accent)
                }
            }
            .onAppear {
                clips = page.sortedClips
            }
        }
    }

    private func moveClip(from source: IndexSet, to destination: Int) {
        clips.move(fromOffsets: source, toOffset: destination)
    }

    private func saveOrder() {
        for (index, clip) in clips.enumerated() {
            clip.sortOrder = index
        }
        try? modelContext.save()
    }
}
