import Foundation
import TransfloDomain
@testable import TransfloMobile

/// No markup editors, for tests that only exercise the form editors.
struct StubMarkupEditors: MobileMarkupEditorMaking {
    func editor(for tool: ToolKind, item: URL) -> MobileMarkupEditor? { nil }
}
