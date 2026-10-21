import Foundation
import TransfloDomain

/// Asks for an action's choice before it runs, such as Move's destination (Coordinator pattern).
protocol ActionPreparing: AnyObject {
    func needsPreparation(_ action: ActionKind) -> Bool
    /// Asks near `point`; `onReady` runs once with the choice, never when the user backs out.
    func prepare(
        _ action: ActionKind, items: [URL], near point: WheelPoint, onReady: @escaping (ToolSettings) -> Void
    )
}
