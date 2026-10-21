import Foundation
@testable import Transflo
import TransfloDomain

/// Records scheduled jobs.
final class SpyJobScheduler: JobScheduling {
    struct Scheduled: Equatable {
        let option: WheelOption
        let items: [URL]
        let point: WheelPoint
    }

    private(set) var scheduled: [Scheduled] = []

    func schedule(_ option: WheelOption, items: [URL], near point: WheelPoint) {
        scheduled.append(Scheduled(option: option, items: items, point: point))
    }
}
