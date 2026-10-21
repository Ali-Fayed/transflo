import AppKit
import TransfloDomain

/// Copies text to the general pasteboard.
public struct PasteboardTextCopier: TextCopying {
    public init() {}

    public func copy(_ text: String) {
        Task { @MainActor in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
}
