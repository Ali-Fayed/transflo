import Foundation
import TransfloDomain
@testable import TransfloMobile

/// Records every scheduled job.
final class SpyJobScheduler: JobScheduling {
    private(set) var scheduled: [(option: WheelOption, items: [URL])] = []

    func schedule(_ option: WheelOption, items: [URL], near point: WheelPoint) {
        scheduled.append((option, items))
    }
}
