import Foundation

/// The folders a terminal opens for a selection: folders as themselves, files as their parent,
/// each folder once, in selection order.
public enum TerminalFolders {
    public static func folders(for items: [URL], isDirectory: (URL) -> Bool) -> [URL] {
        var seen: Set<String> = []
        return items.compactMap { item in
            let folder = (isDirectory(item) ? item : item.deletingLastPathComponent()).standardizedFileURL
            return seen.insert(folder.path).inserted ? folder : nil
        }
    }
}
