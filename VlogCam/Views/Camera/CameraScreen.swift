import SwiftUI
import SwiftData
import Combine
import WidgetKit

@MainActor
final class CameraViewModel: ObservableObject, ClipRecordingDelegate {
    let cameraService = CameraService()
    let recordingManager = ClipRecordingManager()
    let orientationManager = DeviceOrientationManager()

    @Published var selectedAlbum: VlogAlbum?
    @Published var showCreateAlbum = false

    // Forwarded from nested ObservableObjects (SwiftUI only observes direct @Published)
    @Published var isRecording = false
    @Published var recordingProgress: Double = 0
    @Published var maxDuration: Double = 3.0 {
        didSet { recordingManager.maxDuration = maxDuration }
    }
    @Published var permissionGranted = false
    @Published var iconRotationAngle: Double = 0

    var modelContext: ModelContext?

    init() {
        recordingManager.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: &$isRecording)
        recordingManager.$recordingProgress
            .receive(on: RunLoop.main)
            .assign(to: &$recordingProgress)
        cameraService.$permissionGranted
            .receive(on: RunLoop.main)
            .assign(to: &$permissionGranted)
        orientationManager.$iconRotationAngle
            .receive(on: RunLoop.main)
            .assign(to: &$iconRotationAngle)
    }

    func setup() async {
        await cameraService.checkPermissions()
        cameraService.setupSession()
        recordingManager.configure(movieOutput: cameraService.movieFileOutput)
        recordingManager.delegate = self
        cameraService.startSession()
        orientationManager.startMonitoring()
    }

    func handleRecordTap() {
        guard selectedAlbum != nil else {
            showCreateAlbum = true
            return
        }
        if recordingManager.isRecording {
            recordingManager.stopRecording()
        } else {
            recordingManager.startRecording(orientation: orientationManager.deviceOrientation)
        }
    }

    nonisolated func recordingDidStart() {
        Task { @MainActor in
            HapticService.impact(.medium)
        }
    }

    nonisolated func recordingDidFinish(outputURL: URL, duration: Double) {
        Task { @MainActor in
            HapticService.impact(.light)
            self.saveClip(outputURL: outputURL, duration: duration)
        }
    }

    nonisolated func recordingDidFail(error: Error) {
        Task { @MainActor in
            HapticService.notification(.error)
        }
    }

    private func saveClip(outputURL: URL, duration: Double) {
        guard let album = selectedAlbum, let modelContext else { return }
        let fileName = outputURL.lastPathComponent
        let thumbnailFileName = ClipStorageService.shared.generateThumbnailFileName(for: fileName)

        let page: AlbumPage
        if let lastPage = album.sortedPages.last {
            page = lastPage
        } else {
            let newPage = AlbumPage(label: "Day 1", sortOrder: 0)
            newPage.album = album
            modelContext.insert(newPage)
            page = newPage
        }

        let clip = VideoClip(
            fileName: fileName,
            duration: duration,
            sortOrder: page.clips.count
        )
        clip.thumbnailFileName = thumbnailFileName
        clip.page = page
        modelContext.insert(clip)
        try? modelContext.save()

        // Update widget data
        updateWidgetData()

        Task {
            if let image = await ThumbnailGenerator.generateThumbnail(for: outputURL) {
                _ = ThumbnailGenerator.saveThumbnail(image, fileName: thumbnailFileName)
            }
        }
    }

    func updateWidgetData() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<VlogAlbum>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        guard let albums = try? modelContext.fetch(descriptor) else { return }

        let snapshots = albums.map { album in
            SharedAlbumSnapshot(
                id: album.persistentModelID.hashValue.description,
                title: album.title,
                clipCount: album.totalClipCount,
                totalDuration: album.totalDuration,
                coverImageName: nil,
                updatedAt: .now
            )
        }
        let selectedID = selectedAlbum.map { $0.persistentModelID.hashValue.description }
        let data = SharedWidgetData(
            albums: snapshots,
            latestAlbumID: snapshots.first?.id,
            totalClips: snapshots.reduce(0) { $0 + $1.clipCount },
            selectedAlbumID: selectedID
        )
        SharedDataStore.shared.write(data)
    }
}

struct CameraScreen: View {
    @Binding var shouldOpenRecord: Bool
    @Query(sort: \VlogAlbum.createdAt, order: .reverse) private var albums: [VlogAlbum]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        AlbumSelectorView(albums: albums, selectedAlbum: $viewModel.selectedAlbum)
                        Spacer()
                        ClipCounterView(count: viewModel.selectedAlbum?.totalClipCount ?? 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ZStack {
                        if viewModel.permissionGranted {
                            CameraPreviewView(session: viewModel.cameraService.captureSession)
                                .clipShape(RoundedRectangle(cornerRadius: RetroTheme.cornerRadius))
                                .overlay {
                                    RetroOverlayView(isRecording: viewModel.isRecording)
                                    .clipShape(RoundedRectangle(cornerRadius: RetroTheme.cornerRadius))
                                }
                        } else {
                            Rectangle().fill(RetroTheme.surfaceBackground)
                                .clipShape(RoundedRectangle(cornerRadius: RetroTheme.cornerRadius))
                                .overlay {
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 40))
                                            .foregroundStyle(RetroTheme.faded)
                                        Text("Camera access required")
                                            .font(VintageFont.body(14))
                                            .foregroundStyle(RetroTheme.textSecondary)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    Spacer()

                    HStack(spacing: 40) {
                        Button {
                            viewModel.cameraService.switchCamera()
                        } label: {
                            Image(systemName: "camera.rotate")
                                .font(.system(size: 22))
                                .foregroundStyle(RetroTheme.cream)
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(viewModel.iconRotationAngle))
                        }

                        RecordButton(
                            isRecording: viewModel.isRecording,
                            progress: viewModel.recordingProgress
                        ) {
                            viewModel.handleRecordTap()
                        }

                        Menu {
                            Button("1 second") { viewModel.maxDuration = 1.0 }
                            Button("2 seconds") { viewModel.maxDuration = 2.0 }
                            Button("3 seconds") { viewModel.maxDuration = 3.0 }
                        } label: {
                            Text(String(format: "%.0fs", viewModel.maxDuration))
                                .font(VintageFont.label(14))
                                .foregroundStyle(RetroTheme.cream)
                                .frame(width: 44, height: 44)
                                .rotationEffect(.degrees(viewModel.iconRotationAngle))
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("VlogCam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                viewModel.modelContext = modelContext
                await viewModel.setup()
            }
            .onDisappear {
                viewModel.cameraService.stopSession()
                viewModel.orientationManager.stopMonitoring()
            }
            .onAppear {
                if viewModel.selectedAlbum == nil {
                    viewModel.selectedAlbum = albums.first
                }
            }
            .onChange(of: albums) { _, newAlbums in
                if viewModel.selectedAlbum == nil {
                    viewModel.selectedAlbum = newAlbums.first
                }
            }
            .onChange(of: viewModel.selectedAlbum) { _, _ in
                viewModel.updateWidgetData()
                WidgetCenter.shared.reloadTimelines(ofKind: "VlogCamLockScreenWidget")
            }
            .sheet(isPresented: $viewModel.showCreateAlbum) {
                CreateAlbumSheet()
            }
        }
    }
}
