import Foundation
import TransfloDomain

/// `FileExistenceChecking` and `DirectoryChecking` backed by `FileManager`.
public struct FileManagerExistenceChecker: FileExistenceChecking, DirectoryChecking {
    public init() {}

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
