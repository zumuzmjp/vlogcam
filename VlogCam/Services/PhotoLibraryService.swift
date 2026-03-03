import Photos
import UIKit

final class PhotoLibraryService {
    enum PhotoError: Error, LocalizedError {
        case accessDenied
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied: return "Photo library access denied"
            case .saveFailed(let msg): return "Save failed: \(msg)"
            }
        }
    }

    func requestAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return status == .authorized || status == .limited
    }

    func saveVideo(at url: URL, albumTitle: String) async throws {
        guard await requestAccess() else {
            throw PhotoError.accessDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            guard let assetPlaceholder = request?.placeholderForCreatedAsset else { return }

            // Find or create album
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", albumTitle)
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

            if let existingAlbum = collections.firstObject {
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: existingAlbum)
                albumChangeRequest?.addAssets([assetPlaceholder] as NSArray)
            } else {
                let albumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
                albumRequest.addAssets([assetPlaceholder] as NSArray)
            }
        }
    }
}
