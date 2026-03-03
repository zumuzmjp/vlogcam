import AVFoundation
import UIKit

enum ThumbnailGenerator {
    static func generateThumbnail(for videoURL: URL, at time: CMTime = CMTime(seconds: 0.1, preferredTimescale: 600)) async -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 534)

        do {
            let (cgImage, _) = try await generator.image(at: time)
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }

    static func saveThumbnail(_ image: UIImage, fileName: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return false }
        let url = URL.thumbnailsDirectory.appending(component: fileName)
        do {
            try URL.ensureDirectoryExists(.thumbnailsDirectory)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
