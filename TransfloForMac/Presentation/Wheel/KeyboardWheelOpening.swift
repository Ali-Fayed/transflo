import Foundation
import TransfloDomain

/// Opens the wheel for files without a drag, driven by the keyboard.
protocol KeyboardWheelOpening: AnyObject {
    /// Returns `false` when no wheel has options for `items`.
    @discardableResult
    func openForKeyboard(items: [URL], at point: WheelPoint) -> Bool
}
