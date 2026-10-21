import Foundation

/// Limits expanded private scratch data, including hostile compressed documents.
enum ExtractionBudget {
    static let maximumBytes = 1_073_741_824
    static let maximumEntries = 20_000

    static func permits(_ folder: URL) -> Bool {
        // The enumerator yields nothing for a missing folder, which would otherwise pass as "empty".
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isFolder), isFolder.boolValue,
              let entries = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: []
        ) else { return false }
        var count = 0
        var bytes = 0
        for case let item as URL in entries {
            count += 1
            guard count <= maximumEntries,
                  let values = try? item.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]) else {
                return false
            }
            if values.isRegularFile == true {
                let size = values.fileSize ?? 0
                guard size >= 0, size <= maximumBytes - bytes else { return false }
                bytes += size
            }
        }
        return true
    }
}
