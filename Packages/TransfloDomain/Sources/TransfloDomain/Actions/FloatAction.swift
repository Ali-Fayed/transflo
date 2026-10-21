import Foundation

/// Float: puts the files on the floating shelf.
public struct FloatAction: FileActionPerforming {
    private let shelf: any FileShelving

    public init(shelf: any FileShelving) {
        self.shelf = shelf
    }

    public func perform(on items: [URL], settings: ToolSettings?) async throws(JobError) -> [URL] {
        await shelf.add(items)
        return []
    }
}
