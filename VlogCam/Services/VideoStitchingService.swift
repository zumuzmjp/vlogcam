import AVFoundation
import UIKit

enum VideoOutputFormat: String, CaseIterable, Identifiable {
    case portrait16_9 = "9:16"
    case portrait4_3 = "3:4"
    case landscape16_9 = "16:9"
    case landscape4_3 = "4:3"
    case cinematic = "21:9"

    var id: String { rawValue }

    var label: String { rawValue }

    var renderSize: CGSize {
        switch self {
        case .portrait16_9:  return CGSize(width: 1080, height: 1920)
        case .portrait4_3:   return CGSize(width: 1080, height: 1440)
        case .landscape16_9: return CGSize(width: 1920, height: 1080)
        case .landscape4_3:  return CGSize(width: 1440, height: 1080)
        case .cinematic:     return CGSize(width: 1920, height: 822)
        }
    }

    /// Cinematic uses fill (crop top/bottom), others use fit (letterbox)
    var usesFillScaling: Bool {
        self == .cinematic
    }

    var isPortrait: Bool {
        switch self {
        case .portrait16_9, .portrait4_3: return true
        case .landscape16_9, .landscape4_3, .cinematic: return false
        }
    }

    var icon: String {
        switch self {
        case .cinematic: return "film"
        default: return isPortrait ? "rectangle.portrait" : "rectangle"
        }
    }
}

final class VideoStitchingService {
    enum StitchError: Error, LocalizedError {
        case noClips
        case compositionFailed
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noClips: return "No clips to stitch"
            case .compositionFailed: return "Failed to create composition"
            case .exportFailed(let msg): return "Export failed: \(msg)"
            }
        }
    }

    func stitch(clips: [VideoClip], outputFormat: VideoOutputFormat = .portrait16_9, cacheKey: String? = nil, progress: @escaping (Float) -> Void) async throws -> URL {
        guard !clips.isEmpty else { throw StitchError.noClips }

        try? URL.ensureDirectoryExists(URL.stitchedDirectory)

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw StitchError.compositionFailed
        }

        let renderSize = outputFormat.renderSize
        var currentTime = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []

        for clip in clips {
            let clipURL = URL.clipsDirectory.appending(component: clip.fileName)
            let asset = AVURLAsset(url: clipURL)
            let duration = try await asset.load(.duration)

            if let assetVideoTrack = try? await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetVideoTrack,
                    at: currentTime
                )

                let naturalSize = try await assetVideoTrack.load(.naturalSize)
                let preferredTransform = try await assetVideoTrack.load(.preferredTransform)
                let fitTransform = self.letterboxTransform(
                    naturalSize: naturalSize,
                    preferredTransform: preferredTransform,
                    renderSize: renderSize,
                    fill: outputFormat.usesFillScaling
                )

                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: currentTime, duration: duration)
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                layerInstruction.setTransform(fitTransform, at: currentTime)
                instruction.layerInstructions = [layerInstruction]
                instructions.append(instruction)
            }

            if let assetAudioTrack = try? await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: assetAudioTrack,
                    at: currentTime
                )
            }

            currentTime = CMTimeAdd(currentTime, duration)
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = instructions

        let filename: String
        if let cacheKey {
            filename = "stitch_\(cacheKey).mov"
        } else {
            filename = "stitched_\(ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")).mov"
        }
        let outputURL = URL.stitchedDirectory.appending(component: filename)
        // Remove existing file if re-stitching
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw StitchError.exportFailed("Cannot create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition

        // Progress monitoring
        let progressTask = Task {
            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    progress(exportSession.progress)
                }
            }
        }

        await exportSession.export()
        progressTask.cancel()

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw StitchError.exportFailed(exportSession.error?.localizedDescription ?? "Unknown")
        case .cancelled:
            throw StitchError.exportFailed("Export cancelled")
        default:
            throw StitchError.exportFailed("Unknown status")
        }
    }

    private func letterboxTransform(naturalSize: CGSize, preferredTransform: CGAffineTransform, renderSize: CGSize, fill: Bool = false) -> CGAffineTransform {
        // Calculate effective display size after applying preferredTransform
        let effectiveRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        let effectiveWidth = abs(effectiveRect.width)
        let effectiveHeight = abs(effectiveRect.height)

        // fit = letterbox (black bars), fill = crop (no bars, overflow clipped)
        let scaleX = renderSize.width / effectiveWidth
        let scaleY = renderSize.height / effectiveHeight
        let scale = fill ? max(scaleX, scaleY) : min(scaleX, scaleY)

        let scaledWidth = effectiveWidth * scale
        let scaledHeight = effectiveHeight * scale
        let offsetX = (renderSize.width - scaledWidth) / 2
        let offsetY = (renderSize.height - scaledHeight) / 2

        // Compose: preferredTransform → normalize origin → scale → center
        let normalizeX = -effectiveRect.origin.x
        let normalizeY = -effectiveRect.origin.y

        return preferredTransform
            .concatenating(CGAffineTransform(translationX: normalizeX, y: normalizeY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: offsetX, y: offsetY))
    }
}
