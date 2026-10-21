import Foundation
@testable import Transflo
import TransfloDomain

/// Records edit requests; tests apply or drop the stored callback.
final class SpyToolEditor: ToolEditing {
    var editable: Set<ToolKind> = [.crop]
    private(set) var requests: [(tool: ToolKind, items: [URL])] = []
    private(set) var pendingApply: ((ToolSettings) -> Void)?

    func canEdit(_ tool: ToolKind) -> Bool {
        editable.contains(tool)
    }

    func edit(_ tool: ToolKind, items: [URL], onApply: @escaping (ToolSettings) -> Void) {
        requests.append((tool, items))
        pendingApply = onApply
    }
}
