import Foundation
@testable import Transflo
import TransfloDomain

/// Records keyboard opens and answers with `opens`.
final class SpyKeyboardWheel: KeyboardWheelOpening {
    var opens = true
    private(set) var opened: [[URL]] = []

    func openForKeyboard(items: [URL], at point: WheelPoint) -> Bool {
        opened.append(items)
        return opens
    }
}
