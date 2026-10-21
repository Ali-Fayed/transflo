import Foundation

/// Decorator that removes the wedges hidden in Settings › Wheel from another provider's options.
///
/// Visibility is read on every call, so a change in Settings applies the next time a wheel opens.
public struct VisibilityFilteredWheelOptionsProvider: WheelOptionsProviding {
    private let base: any WheelOptionsProviding
    private let visibility: any WheelVisibilityRepository

    public init(base: any WheelOptionsProviding, visibility: any WheelVisibilityRepository) {
        self.base = base
        self.visibility = visibility
    }

    public func options(for wheel: WheelKind, items: [URL]) -> [WheelOption] {
        let current = visibility.loadWheelVisibility()
        return base.options(for: wheel, items: items).filter {
            // Recipes have no visibility checkbox; a stale hidden ID must not strand a saved recipe.
            if case .recipe = $0.kind { return true }
            return current.isVisible($0)
        }
    }
}
