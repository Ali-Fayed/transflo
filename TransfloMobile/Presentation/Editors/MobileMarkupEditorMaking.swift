import Foundation
import TransfloDomain

/// Builds the markup editor for a tool, or `nil` when the tool has none.
protocol MobileMarkupEditorMaking {
    func editor(for tool: ToolKind, item: URL) -> MobileMarkupEditor?
}
