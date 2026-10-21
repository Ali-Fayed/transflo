import Foundation
import TransfloDomain

/// Shows and hides the wheel window and reports pointer activity over it.
/// Delivers promised files, then calls back with the ones that arrived (none if the source failed).
typealias PromisedFileDelivery = (@escaping @MainActor ([URL]) -> Void) -> Void

protocol WheelPresenting: AnyObject {
    /// Called as a drag moves over the wheel with the offset from its center (y up), or `nil` on exit.
    /// Returns whether the pointer is over a droppable wedge.
    var onHover: ((WheelPoint?) -> Bool)? { get set }
    /// Called on drop with the offset from the wheel center. Returns whether the drop was accepted.
    var onDrop: ((WheelPoint) -> Bool)? { get set }
    /// Called on a drop of promised files (Safari, Photos, Mail). The closure asks the source app to
    /// write them and calls back with the files that arrived. Returns whether the drop was accepted.
    var onPromisedDrop: ((WheelPoint, @escaping PromisedFileDelivery) -> Bool)? { get set }

    /// Keyboard mode: a key press while the wheel has focus.
    var onKey: ((WheelKeyCommand) -> Void)? { get set }
    /// Keyboard mode: the pointer moved over the wheel (offset from its center, y up).
    var onPointer: ((WheelPoint) -> Void)? { get set }
    /// Keyboard mode: a click with the offset from the wheel center. Returns whether it hit an option.
    var onClick: ((WheelPoint) -> Bool)? { get set }

    /// Shows the wheel centered on `point` (screen space).
    func show(at point: WheelPoint)
    /// Shows the wheel and gives it keyboard focus; hiding hands focus back to the previous app.
    func showInteractive(at point: WheelPoint)
    func hide()
}
