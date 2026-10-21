import Foundation

/// Shows files to the user, e.g. selected in Finder.
public protocol FileRevealing: Sendable {
    func reveal(_ urls: [URL])
}
