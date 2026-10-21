import Foundation

/// Deletes files, used to clean up partial outputs.
public protocol FileRemoving: Sendable {
    /// Removes the item at `url`; does nothing if it does not exist.
    func removeItemIfPresent(at url: URL)
}
