import Foundation
import TransfloDomain

/// "Reveal" on iPhone and iPad: offers a job's results in the share sheet, where they can be saved,
/// sent or opened in another app.
nonisolated struct MobileShareRevealer: FileRevealing {
    private let present: @MainActor @Sendable ([URL]) -> Void

    init(present: @escaping @MainActor @Sendable ([URL]) -> Void) {
        self.present = present
    }

    func reveal(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task { @MainActor [present] in present(urls) }
    }
}
