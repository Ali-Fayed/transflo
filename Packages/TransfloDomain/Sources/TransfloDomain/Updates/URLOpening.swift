import Foundation

/// Opens a web or App Store link in its default app.
public protocol URLOpening: Sendable {
    func open(_ url: URL)
}
