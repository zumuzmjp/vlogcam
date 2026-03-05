import SwiftUI
import MapKit

struct AlbumMapView: View {
    let album: VlogAlbum
    @State private var selectedClip: VideoClip?
    @State private var playingClip: VideoClip?
    @State private var position: MapCameraPosition = .automatic

    private var clipsWithLocation: [VideoClip] {
        album.sortedPages.flatMap(\.sortedClips).filter {
            $0.latitude != nil && $0.longitude != nil
        }
    }

    var body: some View {
        ZStack {
            RetroTheme.background.ignoresSafeArea()

            if clipsWithLocation.isEmpty {
                emptyState
            } else {
                mapContent
            }
        }
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playingClip) { clip in
            ClipPlayerView(clip: clip)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundStyle(RetroTheme.faded)
            Text("No locations recorded")
                .font(VintageFont.body())
                .foregroundStyle(RetroTheme.textSecondary)
            Text("Clips recorded with location enabled will appear here")
                .font(VintageFont.caption())
                .foregroundStyle(RetroTheme.faded)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Map

    private var mapContent: some View {
        Map(position: $position, selection: $selectedClip) {
            ForEach(clipsWithLocation) { clip in
                Annotation(
                    "",
                    coordinate: CLLocationCoordinate2D(
                        latitude: clip.latitude ?? 0,
                        longitude: clip.longitude ?? 0
                    ),
                    anchor: .bottom
                ) {
                    clipPin(clip: clip)
                }
                .tag(clip)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(RetroTheme.metalDark.opacity(0.5), lineWidth: 1)
        )
        .padding(10)
        .overlay(alignment: .bottom) {
            if let clip = selectedClip {
                selectedClipCard(clip: clip)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedClip?.id)
    }

    // MARK: - Pin

    private func clipPin(clip: VideoClip) -> some View {
        VStack(spacing: 0) {
            if let thumbName = clip.thumbnailFileName {
                let thumbURL = URL.thumbnailsDirectory.appending(component: thumbName)
                AsyncThumbnailPin(url: thumbURL, isSelected: selectedClip == clip)
            } else {
                Circle()
                    .fill(RetroTheme.accent)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    )
            }

            // Pin tail
            Triangle()
                .fill(selectedClip == clip ? RetroTheme.accent : RetroTheme.warmBrown)
                .frame(width: 12, height: 6)
        }
    }

    // MARK: - Selected Clip Card

    private func selectedClipCard(clip: VideoClip) -> some View {
        Button {
            playingClip = clip
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    if let thumbName = clip.thumbnailFileName {
                        let thumbURL = URL.thumbnailsDirectory.appending(component: thumbName)
                        AsyncThumbnailImage(url: thumbURL)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Image(systemName: "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let pageLabel = clip.page?.label {
                        Text(pageLabel)
                            .font(VintageFont.label(13))
                            .foregroundStyle(RetroTheme.accent)
                    }
                    Text(clip.recordedAt, style: .date)
                        .font(VintageFont.caption(11))
                        .foregroundStyle(RetroTheme.textPrimary)
                    Text(String(format: "%.1fs", clip.duration))
                        .font(VintageFont.caption(10))
                        .foregroundStyle(RetroTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(RetroTheme.accent)
            }
            .padding(10)
            .background(RetroTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(RetroTheme.metalDark.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Thumbnail Pin

private struct AsyncThumbnailPin: View {
    let url: URL
    let isSelected: Bool
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(RetroTheme.cardBackground)
            }
        }
        .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(isSelected ? RetroTheme.accent : RetroTheme.warmBrown, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .task {
            image = UIImage(contentsOfFile: url.path())
        }
    }
}

// MARK: - Async Thumbnail (reuse for card)

private struct AsyncThumbnailImage: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(RetroTheme.cardBackground)
            }
        }
        .task {
            image = UIImage(contentsOfFile: url.path())
        }
    }
}

// MARK: - Triangle Shape

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
