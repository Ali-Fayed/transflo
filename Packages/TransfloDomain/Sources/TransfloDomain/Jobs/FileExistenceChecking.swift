import Foundation

/// Answers whether something already exists at a file URL.
public protocol FileExistenceChecking: Sendable {
    func fileExists(at url: URL) -> Bool
}
