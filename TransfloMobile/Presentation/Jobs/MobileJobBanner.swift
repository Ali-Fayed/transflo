import Foundation
import Observation

/// The iPhone and iPad job HUD: which job is shown, first as the centered progress disc (as on the
/// Mac) and, once minimized, as the banner at the bottom. A finished job stays a moment so its
/// result can be read (or shared), then it hides.
@Observable
final class MobileJobBanner: JobHUDPresenting {
    private(set) var jobID: UUID?
    /// The job moved from the centered disc to the bottom banner.
    private(set) var isMinimized = false
    @ObservationIgnored private let visibleFor: Duration
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    init(visibleFor: Duration = .seconds(4)) {
        self.visibleFor = visibleFor
    }

    func present(_ jobID: UUID) {
        hideTask?.cancel()
        self.jobID = jobID
        isMinimized = false
    }

    func minimize() {
        isMinimized = true
    }

    func jobFinished(_ jobID: UUID) {
        guard self.jobID == jobID else { return }
        hideTask?.cancel()
        hideTask = Task { [weak self, visibleFor] in
            try? await Task.sleep(for: visibleFor)
            guard !Task.isCancelled, self?.jobID == jobID else { return }
            self?.jobID = nil
        }
    }

    func dismiss() {
        hideTask?.cancel()
        jobID = nil
    }
}
