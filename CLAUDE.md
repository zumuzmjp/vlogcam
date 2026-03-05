# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a native iOS app (Swift 5, iOS 17+, SwiftUI + SwiftData). Open `VlogCam.xcodeproj` in Xcode.

```bash
# Build from CLI
xcodebuild -project VlogCam.xcodeproj -scheme VlogCam -sdk iphoneos -configuration Debug build

# Build for device (requires signing)
xcodebuild -project VlogCam.xcodeproj -scheme VlogCam -sdk iphoneos -configuration Release archive -archivePath build/VlogCam.xcarchive
xcodebuild -exportArchive -archivePath build/VlogCam.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build/export
```

No tests or linting are configured.

## Architecture

**VlogCam** is a retro-styled vlog camera app. Users record short video clips (default 3s max), organize them into albums with pages, then stitch clips into a single video.

### Two Targets
- **VlogCam** — main app (bundle: `zumzumjp.VlogCam`)
- **VlogCamWidget** — WidgetKit extension with lock screen + home screen widgets

### Data Model (SwiftData)
`VlogAlbum` → has many `AlbumPage` (cascade delete) → has many `VideoClip` (cascade delete). All relationships use `sortOrder` for ordering.

### Key Layers

| Layer | Location | Purpose |
|-------|----------|---------|
| Models | `VlogCam/Models/` | SwiftData models: `VlogAlbum`, `AlbumPage`, `VideoClip`, `ClipPickupState` |
| Camera | `VlogCam/Camera/` | `CameraService` (AVCaptureSession), `ClipRecordingManager` (recording delegate, max duration timer), `DeviceOrientationManager`, `CameraPreviewView` (UIViewRepresentable) |
| Services | `VlogCam/Services/` | `ClipStorageService` (file I/O singleton), `VideoStitchingService` (AVComposition + letterbox), `StitchCacheService`, `ThumbnailGenerator`, `PhotoLibraryService`, `HapticService` |
| Views | `VlogCam/Views/` | Organized by feature: `Camera/`, `Albums/`, `Clips/`, `Stitching/` |
| Theme | `VlogCam/Theme/` | `RetroTheme` (color palette), `RetroButtonStyle`, `VintageFont` |
| Shared | `VlogCam/Shared/` | App Group container (`group.zumzumjp.VlogCam`), `SharedDataStore` (JSON bridge to widget), `DeepLink` (URL scheme: `vlogcam://`) |

### File Storage
Video clips and thumbnails are stored on the filesystem under the app's Documents directory:
- `Documents/Clips/` — recorded `.mov` files
- `Documents/Thumbnails/` — JPEG thumbnails
- `Documents/Stitched/` — stitched output videos

Path helpers are in `URL+AppDirectories.swift`.

### Widget Data Flow
Main app writes `SharedWidgetData` JSON to the App Group container → Widget reads via `WidgetDataProvider`. Deep links: `vlogcam://record`, `vlogcam://album/{id}`.

### Navigation
`ContentView` has a `TabView` with two tabs: Camera and Albums. Deep links switch tabs automatically.

### Video Stitching
`VideoStitchingService` composites clips into a 1080×1920 portrait video at 30fps using `AVMutableComposition` with letterbox transforms for landscape clips. Supports caching via `StitchCacheService`.
