import Foundation
@testable import Transflo

/// Records HUD calls.
final class SpyJobHUD: JobHUDPresenting {
    private(set) var presented: [UUID] = []
    private(set) var finished: [UUID] = []

    func present(_ jobID: UUID) {
        presented.append(jobID)
    }

    func jobFinished(_ jobID: UUID) {
        finished.append(jobID)
    }
}
