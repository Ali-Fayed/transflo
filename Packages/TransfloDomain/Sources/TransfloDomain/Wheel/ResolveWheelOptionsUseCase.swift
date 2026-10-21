import Foundation

/// Decides which wedges a wheel shows for the dragged files. Long lists are paged by the wheel.
public struct ResolveWheelOptionsUseCase: Sendable {
    private let provider: any WheelOptionsProviding

    public init(provider: any WheelOptionsProviding) {
        self.provider = provider
    }

    public func execute(wheel: WheelKind, items: [URL]) -> [WheelOption] {
        guard !items.isEmpty else { return [] }
        return provider.options(for: wheel, items: items)
    }
}
