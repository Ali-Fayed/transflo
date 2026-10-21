import Foundation
import TransfloDomain

/// Returns fixed options per wheel, ignoring the items.
public struct StubWheelOptionsProvider: WheelOptionsProviding {
    private let options: [WheelKind: [WheelOption]]

    public init(_ options: [WheelKind: [WheelOption]]) {
        self.options = options
    }

    public func options(for wheel: WheelKind, items: [URL]) -> [WheelOption] {
        options[wheel] ?? []
    }
}
