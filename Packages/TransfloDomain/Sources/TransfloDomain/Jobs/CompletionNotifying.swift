import Foundation

/// Posts a system notification when a long job finishes; activating it reveals `revealing`.
public protocol CompletionNotifying: Sendable {
    func notify(title: String, body: String, revealing urls: [URL])
}
