import Foundation
import TransfloDomain

/// Accepts wheel jobs to run in the background.
protocol JobScheduling: AnyObject {
    func schedule(_ option: WheelOption, items: [URL], near point: WheelPoint)
}
