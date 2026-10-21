import Foundation
import TransfloDomain

/// The Actions wheel (and a full Tools list for previews). The Convert wheel comes from
/// `CatalogWheelOptionsProvider`, so this returns nothing for it.
public struct PreviewWheelOptionsProvider: WheelOptionsProviding {
    private let unavailableActions: Set<ActionKind>

    /// - Parameter unavailableActions: Actions this edition can't perform (Terminal on the App Store).
    public init(unavailableActions: Set<ActionKind> = []) {
        self.unavailableActions = unavailableActions
    }

    public func options(for wheel: WheelKind, items: [URL]) -> [WheelOption] {
        switch wheel {
        case .convert: []
        case .tools: ToolKind.allCases.map { WheelOption(.tool($0)) }
        case .actions: ActionKind.allCases.filter { !unavailableActions.contains($0) }.map { WheelOption(.action($0)) }
        }
    }
}
