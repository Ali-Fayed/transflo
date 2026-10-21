import Foundation
import TransfloDomain

/// Runs jobs without a result disc and reports each finished job (the job center, for watch folders).
protocol BackgroundJobScheduling: AnyObject {
    func scheduleInBackground(_ option: WheelOption, items: [URL])
    func observeFinishedJobs(_ handler: @escaping (JobRecord) -> Void)
}

extension JobCenter: BackgroundJobScheduling {}
