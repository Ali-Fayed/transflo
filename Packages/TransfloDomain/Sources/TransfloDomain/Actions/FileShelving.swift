import Foundation

/// Keeps files on the floating shelf for later drags.
public protocol FileShelving: Sendable {
    func add(_ urls: [URL]) async
}
