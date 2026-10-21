import Foundation
import Observation

/// Keeps a denied or failed library save recoverable through Files, without losing the result.
@Observable
final class MobileImageSaveViewModel {
    private(set) var isSaving = false
    private(set) var saved = false
    private(set) var error: L10nKey?
    @ObservationIgnored private let saver: any PhotoLibrarySaving

    init(saver: any PhotoLibrarySaving = PhotoLibrarySaver()) { self.saver = saver }

    func save(_ urls: [URL]) async {
        guard !isSaving, !saved else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await saver.save(urls)
            saved = true
        } catch PhotoLibrarySaver.SaveError.permissionDenied {
            self.error = .mobilePhotosDenied
        } catch {
            self.error = .mobilePhotosFailed
        }
    }
}
