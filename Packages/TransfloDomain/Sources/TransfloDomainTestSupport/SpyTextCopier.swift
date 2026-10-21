import Foundation
import TransfloDomain

// @unchecked: all mutable state is guarded by `lock`.
/// Records copied text.
public final class SpyTextCopier: TextCopying, @unchecked Sendable {
    private let lock = NSLock()
    private var texts: [String] = []

    public init() {}

    public var copied: [String] { lock.withLock { texts } }

    public func copy(_ text: String) {
        lock.withLock { texts.append(text) }
    }
}
