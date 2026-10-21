import UIKit

/// Adapter over UIKit's background tasks: while jobs run, the app asks for time to finish them after
/// the user switches away, so a long video export isn't suspended halfway. App only: extensions
/// can't reach UIApplication.
final class MobileBackgroundTime: MobileBackgroundTimeRequesting {
    private var task: UIBackgroundTaskIdentifier = .invalid

    /// Begins or ends the request to match whether any job is running.
    func update(jobsRunning: Bool) {
        if jobsRunning { begin() } else { end() }
    }

    private func begin() {
        guard task == .invalid else { return }
        task = UIApplication.shared.beginBackgroundTask(withName: "Transflo jobs") { [weak self] in self?.end() }
    }

    private func end() {
        guard task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
