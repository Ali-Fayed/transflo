import Foundation
@testable import Transflo
import TransfloDomain

/// Records preparation requests; tests complete or drop the stored callback.
final class SpyActionPreparer: ActionPreparing {
    var preparing: Set<ActionKind> = [.move]
    /// One recorded `prepare` call.
    struct Request {
        let action: ActionKind
        let items: [URL]
        let point: WheelPoint
    }

    private(set) var requests: [Request] = []
    private(set) var pendingReady: ((ToolSettings) -> Void)?

    func needsPreparation(_ action: ActionKind) -> Bool {
        preparing.contains(action)
    }

    func prepare(
        _ action: ActionKind, items: [URL], near point: WheelPoint, onReady: @escaping (ToolSettings) -> Void
    ) {
        requests.append(Request(action: action, items: items, point: point))
        pendingReady = onReady
    }
}
