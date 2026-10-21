import Foundation

/// Tells the user an update is out; activating the notice opens `url`.
public protocol UpdateNotifying: Sendable {
    func notifyUpdate(title: String, body: String, opening url: URL)
}
