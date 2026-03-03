import AVFoundation
import UIKit

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

    func stitch(clips: [VideoClip], progress: @escaping (Float) -> Void) async throws -> URL {
        guard !clips.isEmpty else { throw StitchError.noClips }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw StitchError.compositionFailed
        }

        var currentTime = CMTime.zero

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
                let transform = try await assetVideoTrack.load(.preferredTransform)
                videoTrack.preferredTransform = transform
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

        let outputURL = URL.documentsDirectory
            .appending(component: "stitched_\(ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")).mov")

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw StitchError.exportFailed("Cannot create export session")
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true

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
}
