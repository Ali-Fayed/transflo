import Foundation
import Observation

/// One trip through the share sheet: stage what was shared, open the wheel for it, and finish when
/// the user cancels, dismisses the result, or acknowledges a failure.
@Observable
final class ShareSession {
    enum Phase: Equatable {
        case loading
        case choosing
        case finished
    }

    let container: MobileContainer
    private(set) var phase = Phase.loading
    @ObservationIgnored private let onFinish: () -> Void
    @ObservationIgnored private var finishedOnce = false

    init(container: MobileContainer, onFinish: @escaping () -> Void) {
        self.container = container
        self.onFinish = onFinish
    }

    var home: MobileHomeViewModel { container.screens.home }
    var jobs: JobListViewModel { container.screens.jobs }

    /// Whether anything still needs the user: a running job, an editor or a save prompt.
    var isBusy: Bool {
        jobs.hasActiveJobs || container.wheel.choices.isPresented || container.coordinator.sharing != nil
    }

    func receive(_ providers: [NSItemProvider]) async {
        let urls = await ItemProviderFileLoader.files(from: providers)
        defer { ItemProviderFileLoader.discard(urls) }
        guard !urls.isEmpty else {
            home.receiveFailed()
            phase = .finished
            return
        }
        await home.receive(urls)
        phase = container.wheel.presenter.isShown ? .choosing : .finished
    }

    /// The wheel closed: with nothing running or waiting, the user cancelled.
    func wheelClosed() {
        guard phase == .choosing, !isBusy, jobs.rows.isEmpty else { return }
        finish()
    }

    /// The save prompt closed after a successful job.
    func resultDismissed() {
        container.coordinator.sharingDismissed()
        if !isBusy { finish() }
    }

    func finish() {
        guard !finishedOnce else { return }
        finishedOnce = true
        onFinish()
    }
}
