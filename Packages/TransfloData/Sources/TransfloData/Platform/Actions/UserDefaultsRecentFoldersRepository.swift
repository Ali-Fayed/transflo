import Foundation
import TransfloDomain

// @unchecked: `UserDefaults` is documented as thread-safe but is not annotated `Sendable` in the SDK.
/// Recent Move destinations in `UserDefaults`, stored as paths.
public struct UserDefaultsRecentFoldersRepository: RecentFoldersRepository, @unchecked Sendable {
    static let key = "actions.recentFolders"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> [URL] {
        (defaults.stringArray(forKey: Self.key) ?? []).map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    public func save(_ folders: [URL]) {
        defaults.set(folders.map(\.path), forKey: Self.key)
    }
}
