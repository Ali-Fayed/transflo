import Foundation
import TransfloDomain

/// Lifecycle of one wheel job.
enum JobState: Equatable {
    case queued
    case running(fraction: Double)
    case succeeded(outputs: [URL])
    case failed(JobError)

    var isFinished: Bool {
        switch self {
        case .succeeded, .failed: true
        case .queued, .running: false
        }
    }
}
