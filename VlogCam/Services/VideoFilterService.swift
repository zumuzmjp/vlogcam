import AVFoundation
import CoreImage

final class VideoFilterService {
    enum FilterError: Error, LocalizedError {
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .exportFailed(let msg): return "Filter export failed: \(msg)"
            }
        }
    }

    func applyFilter(
        to inputURL: URL,
        filter: FilmFilterType,
        params: FilmFilterParams
    ) async throws -> URL {
        guard filter != .none else { return inputURL }

        let asset = AVURLAsset(url: inputURL)
        let processor = FilmFilterProcessor()

        let videoComposition = try await AVVideoComposition.videoComposition(
            withPropertiesOf: asset
        )

        let filterComposition = AVMutableVideoComposition()
        filterComposition.renderSize = videoComposition.renderSize
        filterComposition.frameDuration = videoComposition.frameDuration
        filterComposition.customVideoCompositorClass = nil

        // Use the CIFilter-based composition
        let ciFilterComposition = AVVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { request in
                let source = request.sourceImage.clampedToExtent()
                let filtered = processor.apply(filter: filter, params: params, to: source)
                    .cropped(to: request.sourceImage.extent)
                request.finish(with: filtered, context: nil)
            }
        )

        // Output to a temp file, then replace original
        let tempURL = inputURL.deletingLastPathComponent()
            .appending(component: "filtered_\(inputURL.lastPathComponent)")
        try? FileManager.default.removeItem(at: tempURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw FilterError.exportFailed("Cannot create export session")
        }

        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov
        exportSession.videoComposition = ciFilterComposition

        await exportSession.export()

        switch exportSession.status {
        case .completed:
            // Replace original with filtered version
            try FileManager.default.removeItem(at: inputURL)
            try FileManager.default.moveItem(at: tempURL, to: inputURL)
            return inputURL
        case .failed:
            // Clean up temp file on failure
            try? FileManager.default.removeItem(at: tempURL)
            let errorMsg = exportSession.error?.localizedDescription ?? "Unknown"
            print("[VideoFilterService] Export failed: \(errorMsg)")
            throw FilterError.exportFailed(errorMsg)
        case .cancelled:
            try? FileManager.default.removeItem(at: tempURL)
            throw FilterError.exportFailed("Export cancelled")
        default:
            try? FileManager.default.removeItem(at: tempURL)
            throw FilterError.exportFailed("Unknown status: \(exportSession.status.rawValue)")
        }
    }
}
