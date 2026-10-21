import Foundation
import TransfloDomain

/// `FolderAccessProviding` that answers every request with `grants` and records the folders asked about.
@MainActor
public final class FakeFolderAccess: FolderAccessProviding {
    public private(set) var granted: GrantedFolders
    public private(set) var requested: [URL] = []
    public var grants: Bool

    public init(granted: [URL] = [], grants: Bool = true) {
        self.granted = GrantedFolders(granted)
        self.grants = grants
    }

    public func requestAccess(to folder: URL) async -> Bool {
        requested.append(folder)
        if grants { granted.add(folder) }
        return grants
    }
}
