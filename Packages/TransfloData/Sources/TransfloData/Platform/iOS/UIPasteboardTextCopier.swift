#if canImport(UIKit) && !os(macOS)
import TransfloDomain
import UIKit

/// Puts text on the iPhone or iPad clipboard (Read QR, Describe Image).
public struct UIPasteboardTextCopier: TextCopying {
    public init() {}

    public func copy(_ text: String) {
        Task { @MainActor in UIPasteboard.general.string = text }
    }
}
#endif
