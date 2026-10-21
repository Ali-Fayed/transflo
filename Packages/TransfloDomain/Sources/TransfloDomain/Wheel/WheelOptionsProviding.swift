import Foundation

/// Supplies the wedges for a wheel given the dragged files.
public protocol WheelOptionsProviding: Sendable {
    func options(for wheel: WheelKind, items: [URL]) -> [WheelOption]
}
