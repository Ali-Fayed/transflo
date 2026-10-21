import Foundation
import Photos
import UniformTypeIdentifiers

nonisolated protocol PhotoLibrarySaving {
    func save(_ urls: [URL]) async throws
}

/// Requests add-only access, then saves the original encoded outputs in one Photos transaction.
nonisolated struct PhotoLibrarySaver: PhotoLibrarySaving {
    enum SaveError: Error { case permissionDenied, unsupported }

    static func accepts(_ urls: [URL]) -> Bool {
        let types: [UTType] = [.jpeg, .png, .heic, .heif, .gif]
        return !urls.isEmpty && urls.allSatisfy { url in
            guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
            return types.contains { type.conforms(to: $0) }
        }
    }

    nonisolated func save(_ urls: [URL]) async throws {
        guard Self.accepts(urls) else { throw SaveError.unsupported }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.permissionDenied }
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            for url in urls {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: url, options: nil)
            }
        }
    }
}
