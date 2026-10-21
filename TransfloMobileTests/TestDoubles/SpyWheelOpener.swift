import Foundation
import TransfloDomain
@testable import TransfloMobile

/// Records the files the wheel was opened for and answers whether any wheel had options.
final class SpyWheelOpener: KeyboardWheelOpening {
    private(set) var opened: [[URL]] = []
    let hasOptions: Bool

    init(hasOptions: Bool = true) {
        self.hasOptions = hasOptions
    }

    func openForKeyboard(items: [URL], at point: WheelPoint) -> Bool {
        opened.append(items)
        return hasOptions
    }
}
