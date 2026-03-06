import SwiftUI
import SwiftData
import Combine
import WidgetKit

@MainActor
final class CameraViewModel: ObservableObject, ClipRecordingDelegate {
    let cameraService = CameraService()
    let recordingManager = ClipRecordingManager()
    let orientationManager = DeviceOrientationManager()
    let locationService = LocationService()
    let filterProcessor = FilmFilterProcessor()
    private let videoFilterService = VideoFilterService()

    @Published var selectedAlbum: VlogAlbum?
    @Published var showCreateAlbum = false

    // Filter state
    @Published var selectedFilter: FilmFilterType = .none
    @Published var filterParams: FilmFilterParams = .defaultLight
    @Published var isProcessingFilter = false
    @Published var showFilterSelection = false

    // Forwarded from nested ObservableObjects (SwiftUI only observes direct @Published)
    @Published var isRecording = false
    @Published var recordingProgress: Double = 0
    @Published var maxDuration: Double = 3.0 {
        didSet { recordingManager.maxDuration = maxDuration }
    }
    @Published var permissionGranted = false
    @Published var iconRotationAngle: Double = 0
    @Published var displayZoomFactor: CGFloat = 1.0
    @Published var focusTapLocation: CGPoint?
    private var focusDismissTask: Task<Void, Never>?

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
        cameraService.$displayZoomFactor
            .receive(on: RunLoop.main)
            .assign(to: &$displayZoomFactor)
    }

    func setup() async {
        await cameraService.checkPermissions()
        cameraService.setupSession()
        recordingManager.configure(movieOutput: cameraService.movieFileOutput)
        recordingManager.delegate = self
        cameraService.startSession()
        orientationManager.startMonitoring()
        locationService.requestPermission()
        locationService.startUpdates()
    }

    func handleFocusTap(devicePoint: CGPoint, viewLocation: CGPoint) {
        cameraService.focus(at: devicePoint)
        focusTapLocation = viewLocation
        HapticService.impact(.light)

        focusDismissTask?.cancel()
        focusDismissTask = Task {
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            if !Task.isCancelled {
                focusTapLocation = nil
            }
        }
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
        if let location = locationService.lastLocation {
            clip.latitude = location.coordinate.latitude
            clip.longitude = location.coordinate.longitude
        }
        clip.page = page
        modelContext.insert(clip)
        try? modelContext.save()

        // Update widget data
        updateWidgetData()

        // Apply filter post-processing + generate thumbnail
        let currentFilter = selectedFilter
        let currentParams = filterParams
        Task {
            if currentFilter != .none {
                isProcessingFilter = true
                do {
                    _ = try await videoFilterService.applyFilter(
                        to: outputURL,
                        filter: currentFilter,
                        params: currentParams
                    )
                    print("[CameraVM] Filter applied successfully")
                } catch {
                    print("[CameraVM] Filter failed: \(error)")
                }
                isProcessingFilter = false
            }

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
    var onShowAlbums: () -> Void = {}
    @Query(sort: \VlogAlbum.createdAt, order: .reverse) private var albums: [VlogAlbum]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            // Camera body background
            RetroTheme.cameraBody.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: title + clip count
                topBar
                    .opacity(viewModel.showFilterSelection ? 0.3 : 1)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                // Main: preview + right controls
                HStack(spacing: 0) {
                    // Camera preview
                    cameraPreview
                        .padding(.leading, 10)

                    // Right control panel
                    rightControlPanel
                        .frame(width: 52)
                        .padding(.trailing, 6)
                }

                Spacer(minLength: 8)

                // Duration lever (above shutter)
                DurationLeverView(duration: $viewModel.maxDuration)
                    .padding(.bottom, 10)

                // Bottom bar: filter | shutter | album
                bottomBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }

            // Filter selection overlay
            filterSelectionOverlay
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .navigationBarHidden(true)
        .task {
            viewModel.modelContext = modelContext
            await viewModel.setup()
        }
        .onDisappear {
            viewModel.cameraService.stopSession()
            viewModel.orientationManager.stopMonitoring()
            viewModel.locationService.stopUpdates()
        }
        .onAppear {
            viewModel.cameraService.startSession()
            viewModel.orientationManager.startMonitoring()
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

    // MARK: - Filter Selection Overlay

    @ViewBuilder
    private var filterSelectionOverlay: some View {
        if viewModel.showFilterSelection {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.showFilterSelection = false
                    }

                FilterSelectionView(
                    viewModel: viewModel,
                    isPresented: $viewModel.showFilterSelection
                )
                .transition(.move(edge: .bottom))
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.showFilterSelection)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("3Sec Vlog")
                .font(VintageFont.lcd(14))
                .foregroundStyle(RetroTheme.faded.opacity(0.6))

            Spacer()

            AlbumSelectorView(
                albums: albums,
                selectedAlbum: $viewModel.selectedAlbum,
                clipCount: viewModel.selectedAlbum?.totalClipCount ?? 0
            )
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        ZStack {
            if viewModel.permissionGranted {
                FilteredCameraPreviewView(
                    session: viewModel.cameraService.captureSession,
                    cameraService: viewModel.cameraService,
                    filterProcessor: viewModel.filterProcessor,
                    filterType: viewModel.selectedFilter,
                    filterParams: viewModel.filterParams
                ) { devicePoint, viewLocation in
                    viewModel.handleFocusTap(devicePoint: devicePoint, viewLocation: viewLocation)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RetroOverlayView(isRecording: viewModel.isRecording)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .overlay {
                    if let loc = viewModel.focusTapLocation {
                        FocusRingView(position: loc)
                            .allowsHitTesting(false)
                    }
                }
                .overlay {
                    if viewModel.isProcessingFilter {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.black.opacity(0.3))
                            .overlay {
                                ProgressView()
                                    .tint(RetroTheme.cream)
                            }
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(RetroTheme.faded.opacity(0.4))
                            Text("Camera access required")
                                .font(VintageFont.caption(12))
                                .foregroundStyle(RetroTheme.faded.opacity(0.4))
                        }
                    }
            }
        }
        // Subtle inset border
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(RetroTheme.metalDark.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Right Control Panel

    private var rightControlPanel: some View {
        VStack(spacing: 10) {
            // Flash placeholder
            retroButton(icon: "bolt.fill") {}

            // Camera switch
            retroButton(icon: "camera.rotate") {
                viewModel.cameraService.switchCamera()
            }

            // Grid overlay placeholder
            retroButton(icon: "grid") {}

            Spacer()

            // Zoom dial
            ZoomDialView(
                displayZoom: $viewModel.displayZoomFactor,
                minZoom: viewModel.cameraService.minDisplayZoom,
                maxZoom: viewModel.cameraService.maxDisplayZoom,
                lensSwitchPoints: viewModel.cameraService.lensSwitchDisplayZooms
            ) { newZoom in
                viewModel.cameraService.setZoom(display: newZoom)
            }
        }
        .padding(.vertical, 10)
    }

    private func retroButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(RetroTheme.cream.opacity(0.7))
                .rotationEffect(.degrees(viewModel.iconRotationAngle))
                .animation(.easeInOut(duration: 0.3), value: viewModel.iconRotationAngle)
                .frame(width: 38, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(RetroTheme.cameraBodyLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(RetroTheme.metalDark.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            // Filter picker (left)
            filterPicker

            Spacer()

            // Shutter button (center)
            RetroShutterButton(
                isRecording: viewModel.isRecording,
                progress: viewModel.recordingProgress
            ) {
                viewModel.handleRecordTap()
            }

            Spacer()

            // Album thumbnail (right)
            albumThumbnail
        }
    }

    private var filterPicker: some View {
        Button {
            viewModel.showFilterSelection = true
            HapticService.impact(.light)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(filterCanisterColor.gradient)
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(viewModel.selectedFilter != .none
                                        ? RetroTheme.accent.opacity(0.5)
                                        : RetroTheme.metalDark.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(.white.opacity(0.15))
                            .frame(width: 44, height: 4)

                        Text(filterCanisterCode)
                            .font(VintageFont.caption(14))
                            .foregroundStyle(.white)
                            .fontWeight(.bold)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(.white.opacity(0.1))
                            .frame(width: 44, height: 3)
                    }
                    .rotationEffect(.degrees(viewModel.iconRotationAngle))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.iconRotationAngle)
                }

                Text(viewModel.selectedFilter.displayName)
                    .font(VintageFont.caption(8))
                    .foregroundStyle(viewModel.selectedFilter != .none
                                     ? RetroTheme.accent : RetroTheme.faded.opacity(0.5))
                    .tracking(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var filterCanisterColor: Color {
        switch viewModel.selectedFilter {
        case .none: return RetroTheme.cameraBodyLight
        case .glow: return Color(red: 0.75, green: 0.55, blue: 0.15)
        case .light: return Color(red: 0.35, green: 0.50, blue: 0.65)
        }
    }

    private var filterCanisterCode: String {
        switch viewModel.selectedFilter {
        case .none: return "STD"
        case .glow: return "GL"
        case .light: return "LT"
        }
    }

    private var albumThumbnail: some View {
        Button {
            onShowAlbums()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(RetroTheme.cameraBodyLight)
                    .frame(width: 56, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(RetroTheme.metalDark.opacity(0.5), lineWidth: 1)
                    )

                if let album = viewModel.selectedAlbum,
                   let lastClip = album.sortedPages.last?.sortedClips.last,
                   let thumbName = lastClip.thumbnailFileName {
                    let thumbURL = URL.thumbnailsDirectory.appending(component: thumbName)
                    AsyncThumbnailImage(url: thumbURL)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .rotationEffect(.degrees(viewModel.iconRotationAngle))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.iconRotationAngle)
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18))
                        .foregroundStyle(RetroTheme.faded.opacity(0.4))
                        .rotationEffect(.degrees(viewModel.iconRotationAngle))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.iconRotationAngle)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Async Thumbnail

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
                    .fill(RetroTheme.cameraBodyLight)
            }
        }
        .task {
            image = UIImage(contentsOfFile: url.path())
        }
    }
}
