import Foundation
import TransfloDomain

/// Opens an editor for interactive tools and reports the chosen settings.
protocol ToolEditing: AnyObject {
    func canEdit(_ tool: ToolKind) -> Bool
    /// Shows the editor for `items`; `onApply` runs once if the user applies, never on cancel.
    func edit(_ tool: ToolKind, items: [URL], onApply: @escaping (ToolSettings) -> Void)
}
