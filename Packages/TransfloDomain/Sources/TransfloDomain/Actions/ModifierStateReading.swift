import Foundation

/// Reads modifier keys held right now.
public protocol ModifierStateReading: Sendable {
    var isOptionPressed: Bool { get }
}
